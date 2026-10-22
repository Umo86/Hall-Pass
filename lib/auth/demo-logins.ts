import "server-only";
import { createHash, timingSafeEqual } from "node:crypto";
import { and, asc, eq, sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { authAccount, authSession, externalGrants, memberships, users } from "@/lib/db/schema";
import { STAFF_ROLES, type ExternalRole, type StaffRole } from "@/lib/authz";
import { accessState } from "@/lib/access";
import { grantLive } from "@/lib/users/external";
import { roleLabel } from "@/lib/format";
import { writeAudit } from "@/lib/audit";
import { accountOrganisationId } from "./account-link";
import { demoLoginPassword, isDemoAccount } from "./config";
import { hashPassword, verifyPassword } from "./password";

/**
 * Demo logins (testing only, DEMO_LOGIN_PASSWORD): the seeded …@….test
 * accounts, listed on the sign-in page with the shared password, which
 * signing in with sets for them. What they may do is limited by authz
 * DEMO_DENIED; unset the variable and, on production, they can't sign in at
 * all (config.demoAccountLocked).
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

/** The demo accounts that can sign in now (active team members, partners with a live grant). */
export async function listDemoLogins(): Promise<DemoLogin[]> {
  if (!demoLoginPassword()) return [];
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
