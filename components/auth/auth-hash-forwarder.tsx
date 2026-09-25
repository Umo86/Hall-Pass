"use client";

import { useEffect } from "react";

/**
 * If Supabase sends an invitation or recovery link back to a page other than
 * /auth/accept (e.g. the site root, when the redirect isn't allow-listed),
 * pass the session along to /auth/accept.
 */
export function AuthHashForwarder() {
  useEffect(() => {
    const { hash, pathname } = window.location;
    if (pathname === "/auth/accept") return;
    if (/(^|[#&])(access_token|error_description)=/.test(hash)) {
      window.location.replace(`/auth/accept${hash}`);
    }
  }, []);
  return null;
}
