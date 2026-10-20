/**
 * Email goes out through Resend only when BOTH RESEND_API_KEY and EMAIL_FROM
 * are set; until then every email is only logged (email_log). Callers import
 * it from lib/email/dispatch.ts; it lives here so lib/email/send.ts can use
 * it without an import cycle.
 */
export function emailConfigured(): boolean {
  return Boolean(process.env.RESEND_API_KEY && process.env.EMAIL_FROM);
}
