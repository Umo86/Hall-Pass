import "server-only";
import { emailConfigured } from "@/lib/email/dispatch";

/**
 * Can invitations reach people's inboxes here (our own email, through
 * Resend)? When not, Users offers "Copy link" instead of "Resend".
 */
export function invitesCanBeEmailed(): boolean {
  return emailConfigured();
}
