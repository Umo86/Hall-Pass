import { NextResponse } from "next/server";
import { authConfigured } from "@/lib/auth/config";
import { getAuth } from "@/lib/auth/server";

export const dynamic = "force-dynamic";

/**
 * Better Auth over HTTP, allowlisted: only the email-link landing is
 * reachable. Everything else (sign-in, reset, set-up) goes through server
 * actions, so no unused endpoint (sign-up, change-email, …) can be called.
 */
const OPEN = new Set(["/api/auth/magic-link/verify"]);

/** The email-link landings, as lib/auth/links.ts sets them (callbackURL: "next", else home). */
const LANDINGS = [
  ["callbackURL", "/"],
  ["newUserCallbackURL", "/auth/accept"],
  ["errorCallbackURL", "/login"],
] as const;

function toLogin(request: Request, error: string) {
  return NextResponse.redirect(new URL(`/login?error=${error}`, request.url), 303);
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  if (!authConfigured() || !OPEN.has(url.pathname)) {
    return new NextResponse("Not found", { status: 404 });
  }
  // A link cut short by a mail client (the token comes first) or typed by
  // hand gets the landings our links carry (lib/auth/links.ts): without
  // callbackURL Better Auth would sign them in and answer with raw JSON;
  // without newUserCallbackURL a new invitee would skip /auth/accept; without
  // errorCallbackURL a failure would land on the home page, not the notice.
  let filled = false;
  for (const [name, value] of LANDINGS) {
    if (url.searchParams.has(name)) continue;
    url.searchParams.set(name, value);
    filled = true;
  }
  if (filled) request = new Request(url, request);
  let res: Response;
  try {
    res = await getAuth().handler(request);
  } catch (err) {
    // Never a raw error page: the database or Better Auth failed.
    console.error("auth route", err instanceof Error ? err.message : err);
    return toLogin(request, "unavailable");
  }
  // Too many attempts from one network: a page, not raw JSON. The link isn't used up.
  if (res.status === 429) return toLogin(request, "rate_limited");
  if (res.status >= 500) {
    console.error("auth route", res.status);
    return toLogin(request, "unavailable");
  }
  return res;
}

export function POST() {
  return new NextResponse("Not found", { status: 404 });
}
