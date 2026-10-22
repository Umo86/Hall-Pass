import "server-only";
import { cache } from "react";
import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { after } from "next/server";
import { and, asc, desc, eq, isNull, lt, or, sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  externalGrants,
  memberships,
  organisations,
  users,
  type OrganisationSettings,
} from "@/lib/db/schema";
import {
  parseFeatures,
  type Actor,
  type ExternalActor,
  type PermissionOverrides,
  type StaffActor,
} from "@/lib/authz";
import { accessBlockMessage, accessState, type AccessBlock } from "@/lib/access";
import { activeMembership } from "@/lib/users/active";
import { brandName } from "@/lib/config";
import {
  demoAccountLocked,
  demoEmailAllowed,
  demoLoginPassword,
  devAuthEnabled,
  isDemoAccount,
} from "./config";
import { getAuthSession } from "./session";
import { claimStaffInvite, openStaffInviteFor } from "./claim-staff-invite";
import { PORTAL_HOME, STAFF_HOME, safeNext } from "@/lib/edition-path";
import { departmentIdsForUser } from "@/lib/domain/departments";
import { claimOpenGrants, partnerSessionGrants } from "@/lib/users/external";

export const DEV_COOKIE = "hp-dev-user";

// Demo sign-in rules live in ./config (pure, unit-tested); re-exported here
// so the pages and actions that ask keep one import.
export { demoEmailAllowed, devAuthEnabled };

export type Session = {
  actor: Actor;
  user: { id: string; email: string; fullName: string; isExternal: boolean };
  organisation: { id: string; brandName: string; settings: OrganisationSettings };
};

/** A session, or why a signed-in team member is turned away (Users v2). */
type Loaded =
  { session: Session; blocked?: undefined } | { session?: undefined; blocked: AccessBlock };

/**
 * Session for a user id without cookies — used by the tokenised iCal feed.
 * Suspended people and people whose access has ended get nothing.
 */
export async function sessionForUserId(userId: string): Promise<Session | null> {
  // A calendar app fetching the feed isn't the person being active.
  return (await loadForUserId(userId, { touch: false }))?.session ?? null;
}

async function loadForUserId(userId: string, opts?: LoadOpts): Promise<Loaded | null> {
  const user = await db.query.users.findFirst({ where: eq(users.id, userId) });
  if (!user) return null;
  return loadForUser(user, opts);
}

/** touch: record last activity (signed-in page loads; not the iCal feed). */
type LoadOpts = { touch?: boolean };

type MembershipRow = typeof memberships.$inferSelect;

type AskWho = { askName: string | null; askEmail: string | null };
const NOBODY: AskWho = { askName: null, askEmail: null };

/**
 * Who a turned-away person should ask: whoever suspended them, else a
 * manager whose scope covers them, else a super admin (all with access).
 */
async function whoToAsk(m: MembershipRow): Promise<AskWho> {
  const name = (u: { fullName: string; email: string }): AskWho => ({
    askName: u.fullName || u.email,
    askEmail: u.email,
  });
  const rows = await db
    .select({
      userId: memberships.userId,
      role: memberships.role,
      managerScope: memberships.managerScope,
      departmentId: memberships.departmentId,
      fullName: users.fullName,
      email: users.email,
    })
    .from(memberships)
    .innerJoin(users, eq(users.id, memberships.userId))
    .where(
      and(
        eq(memberships.organisationId, m.organisationId),
        activeMembership(),
        or(eq(memberships.role, "admin"), sql`${memberships.managerScope} IS NOT NULL`),
      ),
    )
    .orderBy(asc(memberships.createdAt));
  const others = rows.filter((r) => r.userId !== m.userId);
  const suspender = m.suspendedBy ? others.find((r) => r.userId === m.suspendedBy) : undefined;
  if (suspender) return name(suspender);
  const manager = others.find(
    (r) =>
      r.role !== "admin" &&
      (r.managerScope === "everyone" ||
        (r.managerScope === "department" &&
          m.departmentId != null &&
          r.departmentId === m.departmentId)),
  );
  if (manager && m.role !== "admin" && !m.managerScope) return name(manager);
  const admin = others.find((r) => r.role === "admin");
  return admin ? name(admin) : NOBODY;
}

const LAST_SEEN_EVERY_MS = 15 * 60 * 1000;

/**
 * Record when someone was last active (users.last_seen_at), at most every
 * 15 minutes, after the response is sent. Never fails the request.
 */
function touchLastSeen(user: typeof users.$inferSelect) {
  const seen = user.lastSeenAt?.getTime() ?? 0;
  if (Date.now() - seen < LAST_SEEN_EVERY_MS) return;
  const write = async () => {
    try {
      await db
        .update(users)
        .set({ lastSeenAt: new Date() })
        .where(
          and(
            eq(users.id, user.id),
            or(
              isNull(users.lastSeenAt),
              lt(users.lastSeenAt, new Date(Date.now() - LAST_SEEN_EVERY_MS)),
            ),
          ),
        );
    } catch (err) {
      console.error("last seen", err);
    }
  };
  try {
    after(write);
  } catch {
    // Outside a request (scripts, tests): write it now, without waiting.
    void write();
  }
}

async function loadForUser(
  user: typeof users.$inferSelect,
  opts: LoadOpts = { touch: true },
): Promise<Loaded | null> {
  // Demo logins off on this Vercel deployment: no session, no calendar feed.
  if (demoAccountLocked(user.email)) return null;
  let membership = await db.query.memberships.findFirst({
    where: eq(memberships.userId, user.id),
  });
  if (!membership) {
    // First sign-in after a staff invitation: create the membership with the
    // invited role and overrides, then continue as ordinary staff.
    const invite = await openStaffInviteFor(user.email);
    if (invite) {
      await claimStaffInvite(invite, user.id);
      membership = await db.query.memberships.findFirst({
        where: eq(memberships.userId, user.id),
      });
    }
  }
  if (membership) {
    // Suspended, or access ended: turned away here, never on to the
    // partner-invitation branch below.
    const state = accessState(membership);
    if (state !== "active") return { blocked: { state, ...(await whoToAsk(membership)) } };
    const org = await db.query.organisations.findFirst({
      where: eq(organisations.id, membership.organisationId),
    });
    if (!org) return null;
    const actor: StaffActor = {
      kind: "staff",
      userId: user.id,
      organisationId: org.id,
      role: membership.role,
      overrides: membership.permissionOverrides as PermissionOverrides,
      signoffDepartmentIds: await departmentIdsForUser(db, org.id, user.id),
      departmentId: membership.departmentId,
      features: parseFeatures(membership.features),
      managerScope: membership.role === "admin" ? null : membership.managerScope,
      // Users → Events: null = every event (super admins always).
      editionIds: membership.role === "admin" ? null : (membership.editionIds ?? null),
      ...demoFlag(user.email),
    };
    if (opts.touch !== false) touchLastSeen(user);
    return {
      session: {
        actor,
        user: { id: user.id, email: user.email, fullName: user.fullName, isExternal: false },
        organisation: { id: org.id, brandName: org.brandName, settings: org.settings },
      },
    };
  }

  // Partners. Every sign-in claims invitations still open for this email —
  // not only the first — so a returning partner gets later invitations too
  // (each claim audited; the account marked external).
  const now = new Date();
  await claimOpenGrants(user, { now });
  const all = await db.query.externalGrants.findMany({
    where: eq(externalGrants.userId, user.id),
    orderBy: desc(externalGrants.createdAt),
  });
  if (all.length === 0) return null;
  // Only live grants count, in the organisation of the newest one.
  const picked = partnerSessionGrants(all, now);
  if (!picked) {
    // Everything was revoked or has ended: say so at sign-in, not an empty portal.
    return { blocked: { state: "ended", ...(await partnerInviter(all[0].invitedBy)) } };
  }
  const grants = picked.grants;
  const org = await db.query.organisations.findFirst({
    where: eq(organisations.id, picked.organisationId),
  });
  if (!org) return null;
  if (opts.touch !== false) touchLastSeen(user);
  const actor: ExternalActor = {
    kind: "external",
    userId: user.id,
    organisationId: org.id,
    grants: grants.map((g) => ({
      role: g.role,
      editionId: g.editionId,
      scopeType: g.scopeType,
      scopeId: g.scopeId,
      expiresAt: g.expiresAt,
      revokedAt: g.revokedAt,
    })),
    ...demoFlag(user.email),
  };
  return {
    session: {
      actor,
      user: { id: user.id, email: user.email, fullName: user.fullName, isExternal: true },
      organisation: { id: org.id, brandName: org.brandName, settings: org.settings },
    },
  };
}

/** Who a partner whose access is over should ask: whoever invited them. */
async function partnerInviter(invitedBy: string | null): Promise<AskWho> {
  if (!invitedBy) return NOBODY;
  const inviter = await db.query.users.findFirst({ where: eq(users.id, invitedBy) });
  return inviter ? { askName: inviter.fullName || inviter.email, askEmail: inviter.email } : NOBODY;
}

/** A demo login (DEMO_LOGIN_PASSWORD on, a …@….test account): limited by authz DEMO_DENIED. */
function demoFlag(email: string): { demo?: true } {
  return demoLoginPassword() !== null && isDemoAccount(email) ? { demo: true } : {};
}

/** Who is signed in on this request (cached), or why they are turned away. */
const loadRequest = cache(async (): Promise<Loaded | null> => {
  const auth = await getAuthSession();
  if (auth?.user) {
    // users is Better Auth's user table: the row always exists, with the same id.
    return loadForUserId(auth.user.id);
  }
  // No real session: DEV_AUTH keeps the demo cookie usable next to real sign-in.
  if (devAuthEnabled()) {
    const store = await cookies();
    const email = store.get(DEV_COOKIE)?.value;
    if (!email || !demoEmailAllowed(email)) return null;
    const user = await db.query.users.findFirst({ where: eq(users.email, email) });
    if (!user) return null;
    return loadForUser(user);
  }
  return null;
});

/**
 * Why a correct password got no session (Better Auth's session gate refused
 * it): suspended or ended, with who to ask, or not invited at all.
 */
export async function accessRefusal(email: string): Promise<string> {
  const user = await db.query.users.findFirst({
    where: eq(users.email, email.trim().toLowerCase()),
  });
  const loaded = user ? await loadForUser(user, { touch: false }) : null;
  if (loaded?.blocked) {
    const b = loaded.blocked;
    return `${accessBlockMessage(b)}${b.askEmail ? ` (${b.askEmail})` : ""}.`;
  }
  return `This account doesn't have access to ${brandName} — ask your contact there for an invitation.`;
}

/**
 * The current session, or null when signed out — or when the person's access
 * is suspended or has ended (getAccessBlock says which). Cached for the
 * request, so layouts, pages and actions share one lookup.
 */
export const getSession = cache(async (): Promise<Session | null> => {
  return (await loadRequest())?.session ?? null;
});

/**
 * Why the signed-in person was turned away (suspended or access ended) and
 * who to ask, for the sign-in page; null otherwise.
 */
export async function getAccessBlock(): Promise<AccessBlock | null> {
  return (await loadRequest())?.blocked ?? null;
}

export async function requireSession(): Promise<Session> {
  const session = await getSession();
  if (!session) {
    // Come back to the page they asked for once signed in (path set in proxy.ts).
    const path = safeNext((await headers()).get("x-hp-path"));
    redirect(path && path !== "/" ? `/login?next=${encodeURIComponent(path)}` : "/login");
  }
  return session;
}

export async function requireStaffSession(): Promise<Session & { actor: StaffActor }> {
  const session = await requireSession();
  if (session.actor.kind !== "staff") redirect(PORTAL_HOME);
  return session as Session & { actor: StaffActor };
}

export async function requirePortalSession(): Promise<Session & { actor: ExternalActor }> {
  const session = await requireSession();
  if (session.actor.kind !== "external") redirect(STAFF_HOME);
  return session as Session & { actor: ExternalActor };
}
