import "server-only";
import { and, desc, eq, gt, isNull, or, sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { externalGrants, memberships, staffInvites, users } from "@/lib/db/schema";
import { writeAudit } from "@/lib/audit";
import { activeMembership } from "@/lib/users/active";

/*
 * Who may get in, and the sign-in audit row. Better Auth (lib/auth/server.ts)
 * calls both, so this file must never import lib/auth/server.ts.
 */

/**
 * Is this email allowed in? Only people with an active team
 * membership (not suspended, access not ended), an open staff invitation or
 * a live partner invitation. Everyone else is turned away without an email
 * — there is no sign-up. A suspended team member is refused even if an
 * invitation for their email is still open.
 */
export async function emailIsInvited(email: string): Promise<boolean> {
  const e = email.trim().toLowerCase();
  const [member] = await db
    .select({ id: memberships.id, active: sql<boolean>`${activeMembership()}` })
    .from(memberships)
    .innerJoin(users, eq(users.id, memberships.userId))
    .where(eq(users.email, e))
    .limit(1);
  if (member) return Boolean(member.active);
  const [invite] = await db
    .select({ id: staffInvites.id })
    .from(staffInvites)
    .where(
      and(
        eq(staffInvites.invitedEmail, e),
        isNull(staffInvites.acceptedAt),
        isNull(staffInvites.revokedAt),
      ),
    )
    .limit(1);
  if (invite) return true;
  const grants = await db
    .select({ expiresAt: externalGrants.expiresAt })
    .from(externalGrants)
    .where(and(eq(externalGrants.invitedEmail, e), isNull(externalGrants.revokedAt)));
  return grants.some((g) => !g.expiresAt || g.expiresAt.getTime() > Date.now());
}

/**
 * Record a sign-in in the audit log (Users → access history and "last
 * active"). Never fails the sign-in.
 */
export async function auditSignIn(
  user: { id: string; email?: string | null },
  how: "password" | "link",
): Promise<void> {
  try {
    const email = user.email?.trim().toLowerCase() ?? null;
    const organisationId = await accountOrganisationId(user.id);
    await db.transaction(async (tx) => {
      await writeAudit(tx, {
        organisationId,
        actorUserId: user.id,
        entityType: "user",
        entityId: user.id,
        action: "login",
        summary: `${email ?? "Someone"} signed in (${how === "password" ? "password" : "email link"})`,
        subjectUserId: user.id,
        subjectEmail: email,
      });
    });
  } catch (err) {
    console.error("auditSignIn", err);
  }
}

/**
 * The organisation a person's account belongs to, for their audit rows: their
 * team's, else (a partner) that of their newest live grant, as their session
 * picks it — never an arbitrary or revoked one. Null when neither exists.
 */
export async function accountOrganisationId(userId: string): Promise<string | null> {
  const [member] = await db
    .select({ organisationId: memberships.organisationId })
    .from(memberships)
    .where(eq(memberships.userId, userId))
    .limit(1);
  if (member) return member.organisationId;
  const now = new Date();
  const [grant] = await db
    .select({ organisationId: externalGrants.organisationId })
    .from(externalGrants)
    .where(
      and(
        eq(externalGrants.userId, userId),
        isNull(externalGrants.revokedAt),
        or(isNull(externalGrants.expiresAt), gt(externalGrants.expiresAt, now)),
      ),
    )
    .orderBy(desc(externalGrants.createdAt))
    .limit(1);
  return grant?.organisationId ?? null;
}
