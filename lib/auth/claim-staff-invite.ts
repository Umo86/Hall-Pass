import "server-only";
import { and, desc, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { memberships, staffInvites, users } from "@/lib/db/schema";
import { writeAudit } from "@/lib/audit";

export type StaffInvite = typeof staffInvites.$inferSelect;

/** The newest invitation still open for this email, if any. */
export async function openStaffInviteFor(email: string): Promise<StaffInvite | null> {
  const invite = await db.query.staffInvites.findFirst({
    where: and(
      eq(staffInvites.invitedEmail, email.toLowerCase()),
      isNull(staffInvites.acceptedAt),
      isNull(staffInvites.revokedAt),
    ),
    orderBy: desc(staffInvites.createdAt),
  });
  return invite ?? null;
}

/**
 * Turn a staff invitation into a membership (role and permissions from the
 * invite), in one transaction with an audit record. A name is saved when
 * given (the invite form collects it; first sign-in may not have one).
 */
export async function claimStaffInvite(invite: StaffInvite, userId: string, fullName?: string) {
  await db.transaction(async (tx) => {
    const claimed = await tx
      .update(staffInvites)
      .set({ acceptedAt: new Date() })
      .where(
        and(
          eq(staffInvites.id, invite.id),
          isNull(staffInvites.acceptedAt),
          isNull(staffInvites.revokedAt),
        ),
      )
      .returning({ id: staffInvites.id });
    if (claimed.length === 0) return; // already used or revoked
    await tx
      .insert(memberships)
      .values({
        userId,
        organisationId: invite.organisationId,
        role: invite.role,
        permissionOverrides: invite.permissionOverrides,
      })
      .onConflictDoNothing();
    await tx
      .update(users)
      .set(fullName?.trim() ? { fullName: fullName.trim(), isExternal: false } : { isExternal: false })
      .where(eq(users.id, userId));
    await writeAudit(tx, {
      organisationId: invite.organisationId,
      actorUserId: userId,
      entityType: "staff_invite",
      entityId: invite.id,
      action: "invite",
      summary: `Staff invitation accepted (${invite.role})`,
    });
  });
}
