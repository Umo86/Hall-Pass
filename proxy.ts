import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";

const PATH_HEADER = "x-hp-path";

/**
 * Keeps Supabase sessions refreshed (per the Supabase SSR setup): expired
 * access tokens are renewed here so server components always see a valid
 * session. A no-op when Supabase auth is not configured (demo sign-in).
 */
export async function proxy(request: NextRequest) {
  // Pages read this to send signed-out visitors back here after sign-in.
  const withPath = () => {
    const headers = new Headers(request.headers);
    headers.set(PATH_HEADER, `${request.nextUrl.pathname}${request.nextUrl.search}`);
    return headers;
  };
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key =
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return NextResponse.next({ request: { headers: withPath() } });

  let response = NextResponse.next({ request: { headers: withPath() } });
  const supabase = createServerClient(url, key, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        for (const { name, value } of cookiesToSet) request.cookies.set(name, value);
        response = NextResponse.next({ request: { headers: withPath() } });
        for (const { name, value, options } of cookiesToSet) {
          response.cookies.set(name, value, options);
        }
      },
    },
  });
  // The getUser call triggers the token refresh when needed.
  await supabase.auth.getUser();
  return response;
}

export const config = {
  matcher: [
    // Everything except static assets and files with an extension.
    "/((?!_next/static|_next/image|favicon.ico|images/|.*\\.(?:svg|png|jpg|jpeg|webp|ico)$).*)",
  ],
};
