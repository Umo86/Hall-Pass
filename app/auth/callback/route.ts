import { NextResponse } from "next/server";

// Placeholder — the Supabase auth code exchange is wired up in Phase 0,
// milestone 0.C. Until then the callback simply returns to the sign-in page.
export async function GET(request: Request) {
  return NextResponse.redirect(new URL("/login", request.url));
}
