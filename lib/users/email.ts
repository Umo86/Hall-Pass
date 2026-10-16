import "server-only";
import { emailConfigured } from "@/lib/email/dispatch";
import { supabaseConfigured } from "@/lib/auth/supabase-server";

/**
 * Can invitations reach people's inboxes here (Supabase sign-in emails or
 * our own email)? When not, Users offers "Copy link" instead of "Resend".
 */
export function invitesCanBeEmailed(): boolean {
  return emailConfigured() || supabaseConfigured();
}
