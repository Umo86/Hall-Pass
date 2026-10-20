import { type NextRequest, NextResponse } from "next/server";

const PATH_HEADER = "x-hp-path";

/**
 * Passes the requested path on so pages can send signed-out visitors back to
 * it after sign-in. Sessions are checked and refreshed by Better Auth where
 * they are used (pages, server actions, route handlers), never here: no auth
 * work and no database in the proxy.
 */
export function proxy(request: NextRequest) {
  const headers = new Headers(request.headers);
  headers.set(PATH_HEADER, `${request.nextUrl.pathname}${request.nextUrl.search}`);
  return NextResponse.next({ request: { headers } });
}

export const config = {
  matcher: [
    // Everything except static assets and files with an extension.
    "/((?!_next/static|_next/image|favicon.ico|images/|.*\\.(?:svg|png|jpg|jpeg|webp|ico)$).*)",
  ],
};
