import "server-only";
import { cache } from "react";
import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { after } from "next/server";
import { and, asc, eq, isNull, lt, or, sql } from "drizzle-orm";
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
import { accessState, type AccessBlock } from "@/lib/access";
import { activeMembership } from "@/lib/users/active";
import { createSupabaseServerClient, supabaseConfigured } from "./supabase-server";
import { claimStaffInvite, openStaffInviteFor } from "./claim-staff-invite";
import { PORTAL_HOME, STAFF_HOME, safeNext } from "@/lib/edition-path";
import { departmentIdsForUser } from "@/lib/domain/departments";

export const DEV_COOKIE = "hp-dev-user";

/**
 * Development sign-in is available when Supabase Auth is not configured and
 * explicitly enabled. It lets the seeded users be assumed via a cookie so
 * the platform can be demonstrated with only a database connection.
 * An explicit DEV_AUTH=1 always enables it (even with Supabase configured,
 * so a project without auth users yet is never locked out); the automatic
 * enable in local development applies only while Supabase is unconfigured.
 * On Vercel deployments with Supabase configured it is always off.
 */
export function devAuthEnabled(): boolean {
  // Never on a real deployment with Supabase sign-in: only invited people
  // with their own accounts get in there, whatever DEV_AUTH says.
  if (process.env.VERCEL_ENV && supabaseConfigured()) return false;
  if (process.env.DEV_AUTH === "1") return true;
  if (supabaseConfigured()) return false;
  return process.env.NODE_ENV === "development";
}

/**
 * Once real sign-in (Supabase) is set up, demo sign-in may only be used for
 * the seeded demo accounts (…@….test), never for real people's accounts.
 */
export function demoEmailAllowed(email: string): boolean {
  return !supabaseConfigured() || email.toLowerCase().endsWith(".test");
}

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

/**
 * Who a turned-away person should ask: whoever suspended them, else a
 * manager whose scope covers them, else a super admin (all with access).
 */
async function whoToAsk(m: MembershipRow): Promise<string | null> {
  const name = (u: { fullName: string; email: string }) => u.fullName || u.email;
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
  return admin ? name(admin) : null;
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
    if (state !== "active") return { blocked: { state, askName: await whoToAsk(membership) } };
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

  let grants = await db.query.externalGrants.findMany({
    where: eq(externalGrants.userId, user.id),
  });
  if (grants.length === 0) {
    // Claim invitations sent to this email on first sign-in.
    const claimed = await db
      .update(externalGrants)
      .set({ userId: user.id, acceptedAt: new Date() })
      .where(and(eq(externalGrants.invitedEmail, user.email), isNull(externalGrants.userId)))
      .returning();
    grants = claimed;
  }
  if (grants.length === 0) return null;
  const org = await db.query.organisations.findFirst({
    where: eq(organisations.id, grants[0].organisationId),
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
  };
  return {
    session: {
      actor,
      user: { id: user.id, email: user.email, fullName: user.fullName, isExternal: true },
      organisation: { id: org.id, brandName: org.brandName, settings: org.settings },
    },
  };
}

/** Who is signed in on this request (cached), or why they are turned away. */
const loadRequest = cache(async (): Promise<Loaded | null> => {
  const supabase = await createSupabaseServerClient();
  if (supabase) {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      const existing = await loadForUserId(user.id);
      if (existing) return existing;
      // First sign-in: create the app user row keyed by the auth uid.
      if (user.email) {
        await db
          .insert(users)
          .values({ id: user.id, email: user.email, fullName: "" })
          .onConflictDoNothing();
        return loadForUserId(user.id);
      }
      return null;
    }
    // No Supabase user: fall through — DEV_AUTH=1 keeps the dev cookie
    // usable even with Supabase configured, so demos are never locked out.
  }
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
