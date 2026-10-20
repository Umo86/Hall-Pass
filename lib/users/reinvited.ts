import "server-only";
import { and, eq, gt, inArray, isNull, ne, or } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import { externalGrants, memberships, staffInvites, users } from "@/lib/db/schema";

/**
 * Accounts a super admin of this organisation may make a sign-in or reset
 * link for although they aren't a member or an accepted partner here (yet):
 * someone invited again — an open staff invitation, or a live partner
 * invitation, in this organisation — who already has an account from
 * before (a removed team member, a partner whose access was revoked or ran
 * out). Without email such a person has no other way back in: the
 * invitation page asks them to sign in first, and "Forgot password?" can't
 * send anything.
 *
 * Never an account tied to another organisation (a member or partner there,
 * or invited there): inviting someone's email here must not hand a link to
 * their access elsewhere. Keyed by lower-cased email.
 */
export async function reinvitedAccounts(
  db: Db | Tx,
  organisationId: string,
  emails: readonly string[],
): Promise<Map<string, string>> {
  const list = [...new Set(emails.map((e) => e.trim().toLowerCase()))].filter(Boolean);
  const found = new Map<string, string>();
  if (list.length === 0) return found;
  const accounts = await db
    .select({ id: users.id, email: users.email })
    .from(users)
    .where(inArray(users.email, list));
  if (accounts.length === 0) return found;
  const now = new Date();
  const openInvite = and(
    isNull(staffInvites.acceptedAt),
    isNull(staffInvites.revokedAt),
    or(isNull(staffInvites.expiresAt), gt(staffInvites.expiresAt, now)),
  );
  const liveGrant = and(
    isNull(externalGrants.revokedAt),
    or(isNull(externalGrants.expiresAt), gt(externalGrants.expiresAt, now)),
  );
  const emailsOf = accounts.map((a) => a.email);
  const ids = accounts.map((a) => a.id);
  const [invitesHere, grantsHere, membersElsewhere, grantsElsewhere, invitesElsewhere] =
    await Promise.all([
      db
        .select({ email: staffInvites.invitedEmail })
        .from(staffInvites)
        .where(
          and(
            eq(staffInvites.organisationId, organisationId),
            inArray(staffInvites.invitedEmail, emailsOf),
            openInvite,
          ),
        ),
      db
        .select({ email: externalGrants.invitedEmail })
        .from(externalGrants)
        .where(
          and(
            eq(externalGrants.organisationId, organisationId),
            inArray(externalGrants.invitedEmail, emailsOf),
            liveGrant,
          ),
        ),
      db
        .select({ userId: memberships.userId })
        .from(memberships)
        .where(
          and(inArray(memberships.userId, ids), ne(memberships.organisationId, organisationId)),
        ),
      db
        .select({ userId: externalGrants.userId, email: externalGrants.invitedEmail })
        .from(externalGrants)
        .where(
          and(
            ne(externalGrants.organisationId, organisationId),
            or(inArray(externalGrants.userId, ids), inArray(externalGrants.invitedEmail, emailsOf)),
          ),
        ),
      db
        .select({ email: staffInvites.invitedEmail })
        .from(staffInvites)
        .where(
          and(
            ne(staffInvites.organisationId, organisationId),
            inArray(staffInvites.invitedEmail, emailsOf),
            isNull(staffInvites.acceptedAt),
            isNull(staffInvites.revokedAt),
          ),
        ),
    ]);
  const invitedHere = new Set([...invitesHere, ...grantsHere].map((r) => r.email));
  const tiedIds = new Set([
    ...membersElsewhere.map((r) => r.userId),
    ...grantsElsewhere.flatMap((r) => (r.userId ? [r.userId] : [])),
  ]);
  const tiedEmails = new Set([
    ...grantsElsewhere.map((r) => r.email),
    ...invitesElsewhere.map((r) => r.email),
  ]);
  for (const a of accounts) {
    if (invitedHere.has(a.email) && !tiedIds.has(a.id) && !tiedEmails.has(a.email)) {
      found.set(a.email, a.id);
    }
  }
  return found;
}
