import "server-only";
import { and, desc, eq, gt, isNull, or } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { memberships, staffInvites, users } from "@/lib/db/schema";
import { writeAudit } from "@/lib/audit";
import { linkApproversToUser, syncDepartmentSteps } from "@/lib/domain/departments";
import { applyMainOnAcceptTx, lockPeople, pendingMainAsksTx } from "@/lib/users/manage";

export type StaffInvite = typeof staffInvites.$inferSelect;

/** The newest invitation still open (not used, cancelled or expired) for this email. */
export async function openStaffInviteFor(email: string): Promise<StaffInvite | null> {
  const invite = await db.query.staffInvites.findFirst({
    where: and(
      eq(staffInvites.invitedEmail, email.toLowerCase()),
      isNull(staffInvites.acceptedAt),
      isNull(staffInvites.revokedAt),
      or(isNull(staffInvites.expiresAt), gt(staffInvites.expiresAt, new Date())),
    ),
    orderBy: desc(staffInvites.createdAt),
  });
  return invite ?? null;
}

/**
 * Turn a staff invitation into a membership (role, permissions, department,
 * sections and job title from the invite), in one transaction with an audit
 * record. A name is saved when given (the invite form collects it; first
 * sign-in may not have one). Used, cancelled or expired invitations do
 * nothing (an expired invitation's "main approver when they accept" simply
 * waits). Departments that asked for them as main approver get them now,
 * and the sign-off steps are re-synced after that, so open default
 * sign-offs move to the new main.
 *
 * Only `invite.id` and `invite.organisationId` are taken from the caller's
 * copy: everything the membership gets is read from the row as it is once
 * the people lock is held, so an edit to the invitation saved after the
 * caller read it (events, end date, role) is never lost.
 */
export async function claimStaffInvite(
  invite: Pick<StaffInvite, "id" | "organisationId">,
  userId: string,
  fullName?: string,
) {
  await db.transaction(async (tx) => {
    // People changes one after another: Departments' "Don't make main" or an
    // edit to the invitation can't interleave with the take-over.
    await lockPeople(tx, invite.organisationId);
    // The invitation as it stands now (not as the caller read it, before the
    // lock): what was saved meanwhile is what the person gets.
    const [row] = await tx
      .update(staffInvites)
      .set({ acceptedAt: new Date() })
      .where(
        and(
          eq(staffInvites.id, invite.id),
          isNull(staffInvites.acceptedAt),
          isNull(staffInvites.revokedAt),
          or(isNull(staffInvites.expiresAt), gt(staffInvites.expiresAt, new Date())),
        ),
      )
      .returning();
    if (!row) return; // already used, cancelled or expired
    await tx
      .insert(memberships)
      .values({
        userId,
        organisationId: row.organisationId,
        role: row.role,
        permissionOverrides: row.permissionOverrides,
        departmentId: row.departmentId,
        features: row.features,
        jobTitle: row.jobTitle,
        // Users v2: a manager's scope and an access end date come across too.
        managerScope: row.role === "admin" ? null : row.managerScope,
        accessEndsAt: row.accessEndsAt,
        // Users → Events: the events come across too (an event archived
        // meanwhile still counts). Super admins are never limited.
        editionIds: row.role === "admin" ? null : (row.editionIds ?? null),
      })
      .onConflictDoNothing();
    // Asks for them as main approver, read before linking clears them.
    const asks = await pendingMainAsksTx(tx, row.organisationId, row.invitedEmail);
    // Approver entries waiting for this person now point at their account.
    const linked = await linkApproversToUser(
      tx,
      { id: userId, email: row.invitedEmail },
      row.organisationId,
    );
    await tx
      .update(users)
      .set(
        fullName?.trim()
          ? { fullName: fullName.trim(), isExternal: false }
          : row.fullName.trim()
            ? { fullName: row.fullName.trim(), isExternal: false }
            : { isExternal: false },
      )
      .where(eq(users.id, userId));
    const name = fullName?.trim() || row.fullName.trim() || row.invitedEmail;
    const { promoted } = asks.length
      ? await applyMainOnAcceptTx(tx, {
          organisationId: row.organisationId,
          user: { id: userId, email: row.invitedEmail, name },
          asks,
        })
      : { promoted: [] as string[] };
    for (const orgId of linked) await syncDepartmentSteps(tx, orgId);
    await writeAudit(tx, {
      organisationId: row.organisationId,
      actorUserId: userId,
      entityType: "staff_invite",
      entityId: row.id,
      action: "invite",
      after: promoted.length ? { mainApproverFor: promoted } : undefined,
      summary: `Staff invitation accepted (${row.role})`,
      subjectUserId: userId,
      subjectEmail: row.invitedEmail,
    });
  });
}
