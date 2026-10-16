import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/auth/supabase-server";
import { safeNext } from "@/lib/edition-path";
import { auditSignIn } from "@/lib/auth/account-link";

/** Supabase magic-link / OAuth code exchange. */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const next = safeNext(url.searchParams.get("next")) ?? "/";
  const supabase = await createSupabaseServerClient();
  if (supabase && code) {
    const { data, error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      if (data.user) await auditSignIn(data.user, "link");
      return NextResponse.redirect(new URL(next, request.url));
    }
  }
  return NextResponse.redirect(new URL("/login?error=auth", request.url));
}
