import "server-only";
import { brandName } from "@/lib/config";
import { renderNotificationEmail } from "@/lib/email/template";
import { sendEmail } from "@/lib/email/send";

/**
 * The two emails Better Auth asks us to send (lib/auth/server.ts). They go
 * through Resend like every other email and are logged in email_log. Each
 * returns whether it was sent.
 */
export async function sendMagicLinkEmail(opts: {
  to: string;
  url: string;
  userId?: string | null;
}): Promise<boolean> {
  const { html, text } = await renderNotificationEmail({
    brandName,
    title: `Sign in to ${brandName}`,
    bodyText:
      "Use this link to sign in. It works once and stops working after an hour. If you didn't ask for it, you can ignore this email.",
    ctaLabel: "Sign in",
    ctaUrl: opts.url,
  });
  return sendEmail({
    to: opts.to,
    subject: `Your sign-in link for ${brandName}`,
    html,
    text,
    template: "magic_link",
    entityType: "user",
    entityId: opts.userId ?? null,
  });
}

export async function sendPasswordResetEmail(opts: {
  to: string;
  name?: string | null;
  userId: string;
  url: string;
}): Promise<boolean> {
  const { html, text } = await renderNotificationEmail({
    brandName,
    title: `Choose a new password for ${brandName}`,
    bodyText:
      "Someone asked to reset the password for this email address. Use the link within an hour to choose a new one. If it wasn't you, ignore this email — your password stays as it is.",
    ctaLabel: "Choose a new password",
    ctaUrl: opts.url,
  });
  return sendEmail({
    to: opts.to,
    subject: `Choose a new password for ${brandName}`,
    html,
    text,
    template: "password_reset",
    entityType: "user",
    entityId: opts.userId,
  });
}
