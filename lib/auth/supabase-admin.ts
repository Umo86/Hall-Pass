import "server-only";
import { createClient } from "@supabase/supabase-js";

/**
 * Service-role Supabase client for account admin (creating an invited
 * person's login with their chosen password). Null when not configured.
 */
export function supabaseAdmin() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  // New projects issue sb_secret_… keys in place of the legacy service role key.
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY ?? process.env.SUPABASE_SECRET_KEY;
  if (!url || !key) return null;
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}
