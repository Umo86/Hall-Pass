import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/auth/supabase-server";
import { safeNext } from "@/lib/edition-path";

/** Supabase magic-link / OAuth code exchange. */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const next = safeNext(url.searchParams.get("next")) ?? "/";
  const supabase = await createSupabaseServerClient();
  if (supabase && code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return NextResponse.redirect(new URL(next, request.url));
  }
  return NextResponse.redirect(new URL("/login?error=auth", request.url));
}
