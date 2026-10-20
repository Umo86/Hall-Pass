import { NextResponse } from "next/server";
import { safeNext } from "@/lib/edition-path";
import { getAuthSession } from "@/lib/auth/session";

/**
 * Kept so old links keep working: email links from the previous sign-in
 * service (?code=…) can't be used any more. Signed in already → `next`;
 * otherwise the sign-in page says the link has expired and offers a new one.
 */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const next = safeNext(url.searchParams.get("next")) ?? "/";
  const session = await getAuthSession();
  return NextResponse.redirect(new URL(session ? next : "/login?error=auth", request.url));
}
