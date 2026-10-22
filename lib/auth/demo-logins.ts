import "server-only";
import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import { and, asc, desc, eq, isNotNull, isNull, sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  authAccount,
  authSession,
  editions,
  externalGrants,
  memberships,
  staffInvites,
  users,
} from "@/lib/db/schema";
import { STAFF_ROLES, type ExternalRole, type StaffRole } from "@/lib/authz";
import { accessState } from "@/lib/access";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { grantLive, liveGrantSql } from "@/lib/users/external";
import { roleLabel } from "@/lib/format";
import { writeAudit } from "@/lib/audit";
import { accountOrganisationId } from "./account-link";
import { demoLoginPassword, isDemoAccount } from "./config";
import { hashPassword, verifyPassword } from "./password";

/**
 * Demo logins (testing only, DEMO_LOGIN_PASSWORD): the seeded …@….test
 * accounts (plus a demo contractor, which the seed has none of), listed on
 * the sign-in page with the shared password, which signing in with sets for
 * them. What they may do is limited by authz DEMO_DENIED; unset the variable
 * and, on a Vercel deployment, they can't sign in at all
 * (config.demoAccountLocked).
 */

export type DemoLogin = { email: string; name: string; role: string; isExternal: boolean };

const EXTERNAL_ORDER: readonly ExternalRole[] = [
  "venue",
  "structural_engineer",
  "hs",
  "supplier",
  "exhibitor",
  "contractor",
  "sponsor",
];

type Candidate = {
  email: string;
  name: string;
  staffRole: StaffRole | null;
  externalRole: ExternalRole | null;
};

/** Staff from super admin down to viewer, then partners; one row per account. */
export function orderDemoLogins(candidates: readonly Candidate[]): DemoLogin[] {
  const rank = (c: Candidate) =>
    c.staffRole
      ? STAFF_ROLES.indexOf(c.staffRole)
      : STAFF_ROLES.length + EXTERNAL_ORDER.indexOf(c.externalRole as ExternalRole);
  const seen = new Set<string>();
  return [...candidates]
    .filter((c) => isDemoAccount(c.email) && (c.staffRole || c.externalRole))
    .sort((a, b) => rank(a) - rank(b) || a.email.localeCompare(b.email))
    .filter((c) => !seen.has(c.email) && Boolean(seen.add(c.email)))
    .map((c) => ({
      email: c.email,
      name: c.name || c.email.split("@")[0],
      role: roleLabel(c.staffRole ?? c.externalRole),
      isExternal: !c.staffRole,
    }));
}

/**
 * The one partner type the seed has no demo account for: a contractor, here
 * building the stand of the seeded demo exhibitor (Exhibitor Co).
 */
export const DEMO_CONTRACTOR = {
  email: "sam@standbuilders.test",
  fullName: "Sam at Stand Builders",
  exhibitorEmail: "stand@exhibitorco.test",
} as const;

type ContractorSpec = { email: string; fullName: string; exhibitorEmail: string };

/**
 * While demo logins are on, give the contractor role a demo account too: a
 * contractor grant for the stand the demo exhibitor's newest live grant names,
 * ending when that grant does, made once (audited). Nothing happens without
 * that live exhibitor grant, when its event is archived (read-only, as for
 * any partner invitation), when the address is a team member's or has an
 * open team invitation, or when the contractor already has a grant for that
 * event — a revoked one included, so removing it keeps it removed. Returns
 * whether it made one.
 */
export async function ensureDemoContractor(
  spec: ContractorSpec = DEMO_CONTRACTOR,
): Promise<boolean> {
  const email = spec.email.trim().toLowerCase();
  const exhibitorEmail = spec.exhibitorEmail.trim().toLowerCase();
  if (!demoLoginPassword() || !isDemoAccount(email) || !isDemoAccount(exhibitorEmail)) {
    return false;
  }
  return db.transaction(async (tx) => {
    // One at a time, so two sign-in pages loading together add one grant.
    await tx.execute(sql`SELECT pg_advisory_xact_lock(hashtext('hallpass:demo-contractor'))`);
    const [stand] = await tx
      .select({
        organisationId: externalGrants.organisationId,
        editionId: externalGrants.editionId,
        exhibitorId: externalGrants.scopeId,
        invitedBy: externalGrants.invitedBy,
        expiresAt: externalGrants.expiresAt,
        editionStatus: editions.status,
      })
      .from(externalGrants)
      .innerJoin(editions, eq(editions.id, externalGrants.editionId))
      .where(
        and(
          sql`lower(${externalGrants.invitedEmail}) = ${exhibitorEmail}`,
          eq(externalGrants.role, "exhibitor"),
          eq(externalGrants.scopeType, "exhibitor"),
          isNotNull(externalGrants.scopeId),
          liveGrantSql(new Date()),
        ),
      )
      .orderBy(desc(externalGrants.createdAt))
      .limit(1);
    if (!stand?.exhibitorId || editionIsReadOnly(stand.editionStatus)) return false;
    const [already] = await tx
      .select({ id: externalGrants.id })
      .from(externalGrants)
      .where(
        and(
          sql`lower(${externalGrants.invitedEmail}) = ${email}`,
          eq(externalGrants.editionId, stand.editionId),
        ),
      )
      .limit(1);
    if (already) return false;
    // An open team invitation for the address: signing in would claim it as staff.
    const [invited] = await tx
      .select({ id: staffInvites.id })
      .from(staffInvites)
      .where(
        and(
          sql`lower(${staffInvites.invitedEmail}) = ${email}`,
          isNull(staffInvites.acceptedAt),
          isNull(staffInvites.revokedAt),
        ),
      )
      .limit(1);
    if (invited) return false;
    await tx
      .insert(users)
      .values({ email, fullName: spec.fullName, isExternal: true, emailVerified: true })
      .onConflictDoNothing({ target: users.email });
    const user = await tx.query.users.findFirst({
      where: sql`lower(${users.email}) = ${email}`,
    });
    // Never make a team member's account a partner's.
    if (!user?.isExternal) return false;
    const [grant] = await tx
      .insert(externalGrants)
      .values({
        userId: user.id,
        invitedEmail: email,
        organisationId: stand.organisationId,
        editionId: stand.editionId,
        role: "contractor",
        scopeType: "exhibitor",
        scopeId: stand.exhibitorId,
        // No longer than the exhibitor's own access.
        expiresAt: stand.expiresAt,
        invitedBy: stand.invitedBy,
        // Accepted already; the token is random so no link can be made from it.
        inviteTokenHash: createHash("sha256").update(randomBytes(32)).digest("hex"),
        acceptedAt: new Date(),
      })
      .returning({ id: externalGrants.id });
    await writeAudit(tx, {
      organisationId: stand.organisationId,
      editionId: stand.editionId,
      actorType: "system",
      entityType: "external_grant",
      entityId: grant.id,
      action: "invite",
      after: { role: "contractor", scopeType: "exhibitor", scopeId: stand.exhibitorId },
      summary: "Demo contractor account added (DEMO_LOGIN_PASSWORD, testing only)",
      subjectUserId: user.id,
      subjectEmail: email,
    });
    return true;
  });
}

/** Contractors checked by this server instance; a failure is tried again next time. */
const contractorsChecked = new Set<string>();

/**
 * The demo accounts that can sign in now (active team members, partners with
 * a live grant), the demo contractor made first if it is missing.
 */
export async function listDemoLogins(
  contractor: ContractorSpec = DEMO_CONTRACTOR,
): Promise<DemoLogin[]> {
  if (!demoLoginPassword()) return [];
  if (!contractorsChecked.has(contractor.email)) {
    const checked = await ensureDemoContractor(contractor).then(
      () => true,
      (err) => {
        console.error("ensureDemoContractor", err instanceof Error ? err.message : err);
        return false;
      },
    );
    if (checked) contractorsChecked.add(contractor.email);
  }
  const now = new Date();
  const rows = await db
    .select({
      email: users.email,
      name: users.fullName,
      membership: {
        role: memberships.role,
        suspendedAt: memberships.suspendedAt,
        accessEndsAt: memberships.accessEndsAt,
      },
      grant: {
        role: externalGrants.role,
        revokedAt: externalGrants.revokedAt,
        expiresAt: externalGrants.expiresAt,
      },
    })
    .from(users)
    .leftJoin(memberships, eq(memberships.userId, users.id))
    .leftJoin(externalGrants, eq(externalGrants.userId, users.id))
    .where(sql`lower(${users.email}) LIKE '%.test'`)
    .orderBy(asc(users.createdAt));
  return orderDemoLogins(
    rows.map((r) => ({
      email: r.email,
      name: r.name,
      staffRole:
        r.membership?.role && accessState(r.membership, now) === "active"
          ? r.membership.role
          : null,
      externalRole: r.grant?.role && grantLive(r.grant, now) ? r.grant.role : null,
    })),
  );
}

/** Equal passwords, compared in constant time (digests, so lengths don't leak). */
function samePassword(a: string, b: string): boolean {
  const digest = (s: string) => createHash("sha256").update(s).digest();
  return timingSafeEqual(digest(a), digest(b));
}

/**
 * While demo logins are on, a demo account takes only the current shared
 * password: not an old one, nor one a tester set for themselves.
 */
export function demoPasswordRefused(email: string, password: string): boolean {
  const demo = demoLoginPassword();
  return Boolean(demo && isDemoAccount(email) && !samePassword(password, demo));
}

/**
 * Before a password sign-in: when demo logins are on and someone signs in to a
 * demo account with the shared password, make sure that is its password (set
 * the first time, and again if a tester changed it). Anything else is left
 * alone. Returns whether the account now has the demo password.
 */
export async function ensureDemoPassword(email: string, password: string): Promise<boolean> {
  const demo = demoLoginPassword();
  if (!demo || !isDemoAccount(email) || !samePassword(password, demo)) return false;
  const user = await db.query.users.findFirst({
    where: sql`lower(${users.email}) = ${email.trim().toLowerCase()}`,
  });
  if (!user) return false;
  const [account] = await db
    .select({ password: authAccount.password })
    .from(authAccount)
    .where(and(eq(authAccount.userId, user.id), eq(authAccount.providerId, "credential")))
    .limit(1);
  if (account?.password && (await verifyPassword({ hash: account.password, password: demo }))) {
    return true;
  }
  const hash = await hashPassword(demo);
  const organisationId = await accountOrganisationId(user.id);
  await db.transaction(async (tx) => {
    await tx
      .insert(authAccount)
      .values({ userId: user.id, accountId: user.id, providerId: "credential", password: hash })
      .onConflictDoUpdate({
        target: [authAccount.providerId, authAccount.accountId],
        set: { password: hash, updatedAt: new Date() },
      });
    if (!user.emailVerified) {
      await tx
        .update(users)
        .set({ emailVerified: true, updatedAt: new Date() })
        .where(eq(users.id, user.id));
    }
    // Sessions from an earlier password (an old shared one) end with it.
    await tx.delete(authSession).where(eq(authSession.userId, user.id));
    await writeAudit(tx, {
      organisationId,
      actorType: "system",
      entityType: "user",
      entityId: user.id,
      action: "settings_change",
      summary: "Demo login password set (DEMO_LOGIN_PASSWORD, testing only)",
      subjectUserId: user.id,
      subjectEmail: user.email,
    });
  });
  return true;
}
