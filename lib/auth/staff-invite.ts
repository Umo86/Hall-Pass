import "server-only";
import { and, eq, isNull } from "drizzle-orm";
import type { Tx } from "@/lib/db/client";
import { staffInvites } from "@/lib/db/schema";
import type { Feature, ManagerScope, PermissionOverrides, StaffRole } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { appUrl } from "@/lib/app-url";
import { brandName } from "@/lib/config";
import { renderNotificationEmail } from "@/lib/email/template";
import { sendEmail } from "@/lib/email/send";
import { generateInviteToken, hashInviteToken } from "./invite-token";
import { sendAccountEmail } from "./account-link";

/** Staff invitation links stop working after this many days. */
export const STAFF_INVITE_DAYS = 14;

/** An invitation is usable until it expires (old ones without a date never do). */
export function staffInviteExpired(invite: { expiresAt: Date | null }, now = new Date()): boolean {
  return invite.expiresAt != null && invite.expiresAt.getTime() <= now.getTime();
}

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
    fullName?: string;
    jobTitle?: string | null;
    departmentId?: string | null;
    /** Sections they will have; null or missing = every section. */
    features?: Feature[] | null;
    /** Copied onto the membership when accepted. */
    managerScope?: ManagerScope | null;
    accessEndsAt?: Date | null;
    /** Events they will work on (Users → Events); null or missing = every event. */
    editionIds?: string[] | null;
    invitedBy: string;
    summary: string;
  },
): Promise<{ inviteId: string; inviteUrl: string; expiresAt: Date }> {
  const email = opts.email.toLowerCase();
  const token = generateInviteToken();
  const expiresAt = new Date(Date.now() + STAFF_INVITE_DAYS * 24 * 60 * 60 * 1000);
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
      fullName: opts.fullName?.trim() ?? "",
      jobTitle: opts.jobTitle?.trim() || null,
      departmentId: opts.departmentId ?? null,
      features: opts.features ?? null,
      managerScope: opts.role === "admin" ? null : (opts.managerScope ?? null),
      accessEndsAt: opts.accessEndsAt ?? null,
      editionIds: opts.role === "admin" ? null : (opts.editionIds ?? null),
      expiresAt,
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
    after: {
      email,
      role: opts.role,
      departmentId: opts.departmentId ?? null,
      features: opts.features ?? null,
      managerScope: opts.managerScope ?? null,
      accessEndsAt: opts.accessEndsAt ?? null,
      ...(opts.role !== "admin" && opts.editionIds ? { editionIds: opts.editionIds } : {}),
    },
    summary: opts.summary,
    subjectEmail: email,
  });
  return { inviteId: invite.id, inviteUrl: `${appUrl()}/invite/${token}`, expiresAt };
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

export type InviteDelivery = {
  /** The invitation reached their inbox (Supabase, or our own email). */
  emailed: boolean;
  /**
   * Only when nothing could be emailed (e.g. a local setup without email):
   * the link to pass on by hand.
   */
  fallbackUrl?: string;
};

/**
 * Get an invitation to the person. First choice: Supabase emails them a link
 * to create their account (or to sign in, if they have one). If Supabase
 * can't, our own email with the invitation link; failing that, the link is
 * handed back for the admin to send.
 */
export async function deliverInvite(opts: {
  email: string;
  name?: string | null;
  inviterName: string;
  reason: string;
  inviteUrl: string;
  inviteId: string;
}): Promise<InviteDelivery> {
  const viaSupabase = await sendAccountEmail(opts.email, { fullName: opts.name });
  if (viaSupabase !== "not_sent") return { emailed: true };
  const viaEmail = await sendInviteEmail({
    to: opts.email,
    name: opts.name,
    inviterName: opts.inviterName,
    reason: opts.reason,
    inviteUrl: opts.inviteUrl,
    inviteId: opts.inviteId,
  });
  return viaEmail ? { emailed: true } : { emailed: false, fallbackUrl: opts.inviteUrl };
}
