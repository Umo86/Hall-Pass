import "server-only";
import { createHmac } from "node:crypto";
import { headers } from "next/headers";
import { sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { authSecret } from "./secret";

/**
 * One rate limiter, in our database (auth_rate_limit), for our server actions
 * and for Better Auth's HTTP endpoint (rateLimit.customStorage in
 * lib/auth/server.ts). Windows are fixed from their first request.
 */
export type Rule = { window: number; max: number }; // window in seconds

/** Server-action limits (per subject and per IP). Windows ≤ 15 minutes. */
export const LIMITS = {
  signIn: { subject: { window: 900, max: 10 }, ip: { window: 900, max: 50 } },
  // Magic link and reset requests.
  emailLink: { subject: { window: 900, max: 5 }, ip: { window: 900, max: 20 } },
  resetSubmit: { subject: { window: 900, max: 10 }, ip: { window: 900, max: 20 } },
  inviteAccept: { subject: { window: 900, max: 10 }, ip: { window: 900, max: 30 } },
  changePassword: { subject: { window: 900, max: 10 }, ip: { window: 900, max: 30 } },
  accessLink: { subject: { window: 900, max: 30 }, ip: { window: 900, max: 60 } },
} as const satisfies Record<string, { subject: Rule; ip: Rule }>;

export type LimitedAction = keyof typeof LIMITS;

/** On in production (NODE_ENV=production), elsewhere only with AUTH_RATE_LIMIT=1. */
export function rateLimitEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return env.NODE_ENV === "production" || env.AUTH_RATE_LIMIT === "1";
}

/** HMAC so the table never holds IPs, emails or tokens in clear. */
export function bucketKey(raw: string, secret: string = authSecret() ?? "dev"): string {
  return createHmac("sha256", secret).update(raw).digest("hex");
}

export function retryAfterSeconds(windowStart: number, window: number, now = Date.now()): number {
  return Math.max(1, Math.ceil((windowStart + window * 1000 - now) / 1000));
}

/** One atomic statement: count this request in the window, say whether it is allowed. */
export async function consumeRateLimit(
  rawKey: string,
  rule: Rule,
): Promise<{ allowed: boolean; retryAfter: number | null }> {
  const now = Date.now();
  const since = now - rule.window * 1000;
  const [row] = await db.execute<{ count: number; last_request: string | number }>(sql`
    INSERT INTO auth_rate_limit (key, count, last_request) VALUES (${bucketKey(rawKey)}, 1, ${now})
    ON CONFLICT (key) DO UPDATE SET
      count = CASE WHEN auth_rate_limit.last_request <= ${since} THEN 1 ELSE auth_rate_limit.count + 1 END,
      last_request = CASE WHEN auth_rate_limit.last_request <= ${since} THEN ${now} ELSE auth_rate_limit.last_request END
    RETURNING count, last_request`);
  const allowed = Number(row.count) <= rule.max;
  return {
    allowed,
    retryAfter: allowed ? null : retryAfterSeconds(Number(row.last_request), rule.window, now),
  };
}

/** The caller's IP on Vercel (x-real-ip), else the first x-forwarded-for, else "unknown". */
export async function clientIp(): Promise<string> {
  const h = await headers();
  return h.get("x-real-ip")?.trim() || h.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
}

/**
 * May this action go ahead for `subject` (an email, a user id or a token
 * prefix) from this IP? "limited" when either bucket is full; "unavailable"
 * when the limiter can't be asked (the database refused or is down) — the
 * caller then fails closed with an honest message, never "too many attempts".
 */
export async function allow(
  action: LimitedAction,
  subject: string,
): Promise<"ok" | "limited" | "unavailable"> {
  if (!rateLimitEnabled()) return "ok";
  const rules = LIMITS[action];
  try {
    const ip = await clientIp();
    const [a, b] = await Promise.all([
      consumeRateLimit(`action:${action}:subject:${subject.trim().toLowerCase()}`, rules.subject),
      consumeRateLimit(`action:${action}:ip:${ip}`, rules.ip),
    ]);
    return a.allowed && b.allowed ? "ok" : "limited";
  } catch (err) {
    // Never the key: it holds the email, user id or IP.
    console.error("rate limit unavailable", action, err instanceof Error ? err.message : err);
    return "unavailable";
  }
}
