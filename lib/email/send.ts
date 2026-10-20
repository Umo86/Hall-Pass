import "server-only";
import { Resend } from "resend";
import { db } from "@/lib/db/client";
import { emailLog } from "@/lib/db/schema";
import { emailConfigured } from "./configured";

export type EmailInput = {
  to: string;
  subject: string;
  html: string;
  text: string;
  template: string;
  entityType?: string | null;
  entityId?: string | null;
};

const MAX_ATTEMPTS = 3;

/**
 * Direct send with 3 retries and backoff, logged to email_log. When Resend
 * is not configured (RESEND_API_KEY and EMAIL_FROM) the attempt is logged as
 * failed so nothing is silent. There is no default sender: an unverified one
 * fails at Resend anyway, and the brand name is config, not a literal.
 */
export async function sendEmail(input: EmailInput): Promise<boolean> {
  if (!emailConfigured()) {
    await db.insert(emailLog).values({
      toEmail: input.to,
      template: input.template,
      entityType: input.entityType ?? null,
      entityId: input.entityId ?? null,
      status: "failed",
      error: "Email isn't set up (RESEND_API_KEY and EMAIL_FROM)",
      attempts: 0,
    });
    return false;
  }
  const from = process.env.EMAIL_FROM!;

  const resend = new Resend(process.env.RESEND_API_KEY);
  let lastError = "";
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    try {
      const { data, error } = await resend.emails.send({
        from,
        to: input.to,
        subject: input.subject,
        html: input.html,
        text: input.text,
      });
      if (error) throw new Error(error.message);
      await db.insert(emailLog).values({
        toEmail: input.to,
        template: input.template,
        entityType: input.entityType ?? null,
        entityId: input.entityId ?? null,
        providerMessageId: data?.id ?? null,
        status: "sent",
        attempts: attempt,
        sentAt: new Date(),
      });
      return true;
    } catch (err) {
      lastError = err instanceof Error ? err.message : String(err);
      if (attempt < MAX_ATTEMPTS) {
        await new Promise((r) => setTimeout(r, attempt * 1000));
      }
    }
  }
  await db.insert(emailLog).values({
    toEmail: input.to,
    template: input.template,
    entityType: input.entityType ?? null,
    entityId: input.entityId ?? null,
    status: "failed",
    error: lastError,
    attempts: MAX_ATTEMPTS,
  });
  return false;
}
