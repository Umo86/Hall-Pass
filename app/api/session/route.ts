import { NextResponse } from "next/server";
import { getAuthSession } from "@/lib/auth/session";

export const dynamic = "force-dynamic";

/**
 * Keep-alive for a signed-in session (components/auth/session-keep-alive.tsx,
 * in the staff and partner layouts). Page renders can't set cookies, so they
 * never roll a session (lib/auth/session.ts); here Better Auth extends it,
 * database row and cookie together, once a day. Says nothing but whether
 * someone is signed in.
 */
export async function GET() {
  const session = await getAuthSession();
  return new NextResponse(null, {
    status: session ? 204 : 401,
    headers: { "cache-control": "no-store" },
  });
}
