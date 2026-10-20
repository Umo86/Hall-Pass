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

function toLogin(request: Request, error: string) {
  return NextResponse.redirect(new URL(`/login?error=${error}`, request.url), 303);
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  if (!authConfigured() || !OPEN.has(url.pathname)) {
    return new NextResponse("Not found", { status: 404 });
  }
  // A link missing its error landing (typed by hand, or cut short by a mail
  // client) fails to the sign-in page with a notice, not the home page.
  if (!url.searchParams.has("errorCallbackURL")) {
    url.searchParams.set("errorCallbackURL", "/login");
    request = new Request(url, request);
  }
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
