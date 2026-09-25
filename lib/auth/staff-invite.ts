import "server-only";
import { and, eq, isNull } from "drizzle-orm";
import type { Tx } from "@/lib/db/client";
import { staffInvites } from "@/lib/db/schema";
import type { PermissionOverrides, StaffRole } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { appUrl } from "@/lib/app-url";
import { brandName } from "@/lib/config";
import { renderNotificationEmail } from "@/lib/email/template";
import { sendEmail } from "@/lib/email/send";
import { generateInviteToken, hashInviteToken } from "./invite-token";

/**
 * Create a staff invitation (replacing any older one still open for the
 * email) and return its link. The invitee sets their name and password on
 * that page; the membership is created then.
 */
export async function createStaffInvite(
  tx: Tx,
  opts: {
    organisationId: string;
    email: string;
    role: StaffRole;
    overrides?: PermissionOverrides;
    invitedBy: string;
    summary: string;
  },
): Promise<{ inviteId: string; inviteUrl: string }> {
  const email = opts.email.toLowerCase();
  const token = generateInviteToken();
  await tx
    .update(staffInvites)
    .set({ revokedAt: new Date() })
    .where(
      and(
        eq(staffInvites.organisationId, opts.organisationId),
        eq(staffInvites.invitedEmail, email),
        isNull(staffInvites.acceptedAt),
        isNull(staffInvites.revokedAt),
      ),
    );
  const [invite] = await tx
    .insert(staffInvites)
    .values({
      organisationId: opts.organisationId,
      invitedEmail: email,
      role: opts.role,
      permissionOverrides: opts.overrides ?? {},
      invitedBy: opts.invitedBy,
      inviteTokenHash: hashInviteToken(token),
    })
    .returning();
  await writeAudit(tx, {
    organisationId: opts.organisationId,
    actorUserId: opts.invitedBy,
    entityType: "staff_invite",
    entityId: invite.id,
    action: "invite",
    after: { email, role: opts.role },
    summary: opts.summary,
  });
  return { inviteId: invite.id, inviteUrl: `${appUrl()}/invite/${token}` };
}

/** Email the invitation link. False when email isn't set up (share the link instead). */
export async function sendInviteEmail(opts: {
  to: string;
  name?: string | null;
  inviterName: string;
  reason: string;
  inviteUrl: string;
  inviteId: string;
}): Promise<boolean> {
  const { html, text } = await renderNotificationEmail({
    brandName,
    title: `${opts.inviterName} has invited you to ${brandName}`,
    bodyText: [
      opts.name ? `Hi ${opts.name.split(" ")[0]},` : "Hello,",
      opts.reason,
      "Open the link to set up your profile and choose a password. The link only works for this email address.",
    ].join(" "),
    ctaLabel: "Set up my account",
    ctaUrl: opts.inviteUrl,
  });
  return sendEmail({
    to: opts.to,
    subject: `You're invited to ${brandName}`,
    html,
    text,
    template: "staff_invite",
    entityType: "staff_invite",
    entityId: opts.inviteId,
  }).catch(() => false);
}
