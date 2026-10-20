"use client";

import { useEffect } from "react";

const HOUR = 60 * 60 * 1000;

/**
 * Keeps a signed-in session rolling (sessions last 30 days from the last
 * roll). Page renders can't rewrite the session cookie, so each full page
 * load, and every hour a tab stays open and visible, asks /api/session,
 * where Better Auth extends the session and its cookie together (once a
 * day at most). Renders nothing; failures are ignored.
 */
export function SessionKeepAlive() {
  useEffect(() => {
    const ping = () => {
      if (document.hidden) return;
      fetch("/api/session", { cache: "no-store", credentials: "same-origin" }).catch(() => {});
    };
    ping();
    const id = setInterval(ping, HOUR);
    return () => clearInterval(id);
  }, []);
  return null;
}
