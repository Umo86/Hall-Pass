import "server-only";
import { cache } from "react";
import { headers } from "next/headers";
import { authConfigured } from "./config";
import { getAuth } from "./server";

/**
 * Can this request send a Set-Cookie back? Server actions (a next-action
 * header) and route handlers (proxy.ts marks the path; ours that load a
 * session are under /api/) can. A page render can't: Next.js refuses cookie
 * writes while rendering, and Better Auth swallows that refusal.
 */
export function canSetCookies(h: Headers): boolean {
  if (h.get("next-action")) return true;
  return (h.get("x-hp-path") ?? "").startsWith("/api/");
}

/**
 * The Better Auth session on this request (cached per request), or null.
 * Never throws: a database hiccup reads as signed out, and is logged.
 *
 * Sessions last 30 days and roll once a day while people use the app. The
 * roll moves the database row and the cookie together, so it happens only
 * where the cookie can be rewritten: pages read the session without rolling
 * it, and the layouts' keep-alive ping (/api/session), the bell and server
 * actions roll it. Otherwise a page load would extend the row while the
 * browser's cookie still ran out 30 days after sign-in.
 */
export const getAuthSession = cache(async () => {
  if (!authConfigured()) return null;
  try {
    const h = await headers();
    return await getAuth().api.getSession({
      headers: h,
      query: canSetCookies(h) ? {} : { disableRefresh: true },
    });
  } catch (err) {
    console.error("getAuthSession", err);
    return null;
  }
});
