import "server-only";
/**
 * Find the invitation behind an /invite/[token] link — a partner's
 * external grant or a staff invitation — and say why it can't be used
 * when it can't (revoked, used, expired, unknown).
 */
import { and, asc, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  approvers,
  departments,
  externalGrants,
  organisations,
  staffInvites,
  users,
} from "@/lib/db/schema";
import { hashInviteToken } from "@/lib/auth/invite-token";
import { staffInviteExpired } from "@/lib/auth/staff-invite";

export type Grant = typeof externalGrants.$inferSelect;
export type StaffInvite = typeof staffInvites.$inferSelect;

export type InviteProblem = {
  error: string;
  reason: "invalid" | "revoked" | "used" | "expired";
  /** Who sent it, so an expired invitation can say whom to ask. */
  inviterName?: string | null;
};

async function inviterName(id: string | null): Promise<string | null> {
  if (!id) return null;
  const u = await db.query.users.findFirst({ where: eq(users.id, id) });
  return u ? u.fullName || u.email : null;
}

export async function findValidGrant(
  token: string,
): Promise<{ grant: Grant; problem?: never } | { grant?: never; problem: InviteProblem | null }> {
  const grant = await db.query.externalGrants.findFirst({
    where: eq(externalGrants.inviteTokenHash, hashInviteToken(token)),
  });
  if (!grant) return { problem: null };
  if (grant.revokedAt) {
    return { problem: { error: "This invitation has been withdrawn.", reason: "revoked" } };
  }
  if (grant.expiresAt && grant.expiresAt.getTime() < Date.now()) {
    return {
      problem: {
        error: "This invitation has expired.",
        reason: "expired",
        inviterName: await inviterName(grant.invitedBy),
      },
    };
  }
  return { grant };
}

export async function findValidStaffInvite(
  token: string,
): Promise<
  { invite: StaffInvite; problem?: never } | { invite?: never; problem: InviteProblem | null }
> {
  const invite = await db.query.staffInvites.findFirst({
    where: eq(staffInvites.inviteTokenHash, hashInviteToken(token)),
  });
  if (!invite) return { problem: null };
  if (invite.revokedAt) {
    return { problem: { error: "This invitation has been cancelled.", reason: "revoked" } };
  }
  if (invite.acceptedAt) {
    return {
      problem: {
        error: "This invitation has already been used — sign in instead.",
        reason: "used",
      },
    };
  }
  if (staffInviteExpired(invite)) {
    return {
      problem: {
        error: "This invitation has expired.",
        reason: "expired",
        inviterName: await inviterName(invite.invitedBy),
      },
    };
  }
  return { invite };
}

export type InviteDetails =
  | {
      ok: true;
      kind: "external" | "staff";
      invitedEmail: string;
      role: string;
      accepted: boolean;
      /** The organisation's brand ("Media10"), not the product name. */
      brandName: string | null;
      fullName: string;
      departmentName: string | null;
      /** They were also added to sign off artwork. */
      signsOff: boolean;
      /** Departments (live, signing off) they become main approver for when they accept. */
      mainFor: string[];
    }
  | ({ ok: false } & InviteProblem);

/** Everything the invitation page shows, without accepting anything. */
export async function inviteDetails(token: string): Promise<InviteDetails> {
  const g = await findValidGrant(token);
  if (g.grant) {
    const org = await db.query.organisations.findFirst({
      where: eq(organisations.id, g.grant.organisationId),
    });
    return {
      ok: true,
      kind: "external",
      invitedEmail: g.grant.invitedEmail,
      role: g.grant.role,
      accepted: Boolean(g.grant.acceptedAt),
      brandName: org?.brandName ?? null,
      fullName: "",
      departmentName: null,
      signsOff: false,
      mainFor: [],
    };
  }
  const s = await findValidStaffInvite(token);
  if (!s.invite) {
    const problem = g.problem ?? s.problem;
    return problem
      ? { ok: false, ...problem }
      : { ok: false, error: "This invitation link is not valid.", reason: "invalid" };
  }
  const invite = s.invite;
  const [org, dept, approver, asks] = await Promise.all([
    db.query.organisations.findFirst({ where: eq(organisations.id, invite.organisationId) }),
    invite.departmentId
      ? db.query.departments.findFirst({
          where: and(
            eq(departments.id, invite.departmentId),
            eq(departments.organisationId, invite.organisationId),
          ),
        })
      : Promise.resolve(undefined),
    // Approvers were added by name; only this organisation's entries count.
    db.query.approvers.findFirst({
      where: and(
        eq(approvers.organisationId, invite.organisationId),
        eq(approvers.email, invite.invitedEmail.toLowerCase()),
      ),
    }),
    // Departments still signing off that asked for them as main approver.
    db
      .select({ name: departments.name })
      .from(approvers)
      .innerJoin(departments, eq(departments.id, approvers.departmentId))
      .where(
        and(
          eq(approvers.organisationId, invite.organisationId),
          eq(approvers.email, invite.invitedEmail.toLowerCase()),
          isNull(approvers.userId),
          eq(approvers.mainOnAccept, true),
          eq(departments.signsOff, true),
          eq(departments.isArchived, false),
        ),
      )
      .orderBy(asc(departments.sortOrder), asc(departments.name)),
  ]);
  return {
    ok: true,
    kind: "staff",
    invitedEmail: invite.invitedEmail,
    role: invite.role,
    accepted: false,
    brandName: org?.brandName ?? null,
    fullName: invite.fullName || approver?.fullName || "",
    departmentName: dept && !dept.isArchived ? dept.name : null,
    signsOff: Boolean(approver),
    mainFor: asks.map((a) => a.name),
  };
}
