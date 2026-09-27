import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { resolveSupabaseKey, supabaseUrl } from "./supabase-config";

/** New projects issue sb_publishable_… keys in place of the legacy anon key. */
export function supabasePublicKey(): string | undefined {
  return resolveSupabaseKey();
}

export function supabaseConfigured(): boolean {
  return Boolean(supabaseUrl() && supabasePublicKey());
}

/** Server-side Supabase client bound to the request cookies. */
export async function createSupabaseServerClient() {
  if (!supabaseConfigured()) return null;
  const cookieStore = await cookies();
  return createServerClient(supabaseUrl()!, supabasePublicKey()!, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Called from a Server Component — middleware refresh handles it.
        }
      },
    },
  });
}
