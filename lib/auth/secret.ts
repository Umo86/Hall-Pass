import "server-only";
import { createHmac } from "node:crypto";
import { DERIVED_SECRET_LABEL, authSecretSource } from "./config";

type Env = Record<string, string | undefined>;

/**
 * The secret Better Auth signs sessions and tokens with, or null when real
 * sign-in isn't set up (lib/auth/config.ts:authSecretSource says which rule
 * applies). On Vercel production without BETTER_AUTH_SECRET it is
 * HMAC-SHA256(CRON_SECRET, "hall-pass:better-auth:v1") in hex. Server-only:
 * the value never reaches client code.
 */
export function authSecret(env: Env = process.env): string | null {
  switch (authSecretSource(env)) {
    case "env":
      return env.BETTER_AUTH_SECRET!.trim();
    case "derived":
      return createHmac("sha256", env.CRON_SECRET!.trim())
        .update(DERIVED_SECRET_LABEL)
        .digest("hex");
    default:
      return null;
  }
}
