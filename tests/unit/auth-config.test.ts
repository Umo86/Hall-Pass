import { createHmac } from "node:crypto";
import { describe, expect, it } from "vitest";
import {
  DERIVED_SECRET_LABEL,
  authBaseURL,
  authConfigured,
  authSecretSource,
  authTrustedOrigins,
  demoEmailAllowed,
  devAuthEnabled,
  devLinksShown,
} from "@/lib/auth/config";
import { authSecret } from "@/lib/auth/secret";

const SECRET = "x".repeat(40);
const CRON = "cron-secret-from-vercel-0123456789";
const derived = createHmac("sha256", CRON).update("hall-pass:better-auth:v1").digest("hex");

describe("the Better Auth secret", () => {
  it("is BETTER_AUTH_SECRET when it is set, anywhere", () => {
    expect(authSecret({ BETTER_AUTH_SECRET: SECRET })).toBe(SECRET);
    expect(authSecret({ BETTER_AUTH_SECRET: ` ${SECRET} ` })).toBe(SECRET);
    expect(authSecretSource({ BETTER_AUTH_SECRET: SECRET })).toBe("env");
    // It wins over the derived one on production too.
    expect(
      authSecret({ BETTER_AUTH_SECRET: SECRET, VERCEL_ENV: "production", CRON_SECRET: CRON }),
    ).toBe(SECRET);
  });

  it("on Vercel production without it, is HMAC-SHA256(CRON_SECRET, label) in hex", () => {
    expect(DERIVED_SECRET_LABEL).toBe("hall-pass:better-auth:v1");
    const env = { VERCEL_ENV: "production", CRON_SECRET: CRON };
    expect(authSecret(env)).toBe(derived);
    expect(authSecret(env)).toMatch(/^[0-9a-f]{64}$/);
    expect(authSecret(env)).not.toContain(CRON);
    expect(authSecretSource(env)).toBe("derived");
    expect(authConfigured(env)).toBe(true);
    // A blank BETTER_AUTH_SECRET counts as unset.
    expect(authSecret({ ...env, BETTER_AUTH_SECRET: "  " })).toBe(derived);
  });

  it("is never derived off production, or without CRON_SECRET", () => {
    for (const env of [
      { VERCEL_ENV: "preview", CRON_SECRET: CRON },
      { VERCEL_ENV: "development", CRON_SECRET: CRON },
      { CRON_SECRET: CRON },
      { NODE_ENV: "production", CRON_SECRET: CRON },
      { VERCEL_ENV: "production" },
      { VERCEL_ENV: "production", CRON_SECRET: " " },
      {},
    ]) {
      expect(authSecret(env), JSON.stringify(env)).toBeNull();
      expect(authSecretSource(env), JSON.stringify(env)).toBeNull();
      expect(authConfigured(env), JSON.stringify(env)).toBe(false);
    }
  });

  it("makes real sign-in configured when either source gives a secret", () => {
    expect(authConfigured({ BETTER_AUTH_SECRET: SECRET })).toBe(true);
    expect(authConfigured({ VERCEL_ENV: "production", CRON_SECRET: CRON })).toBe(true);
    expect(authConfigured({ BETTER_AUTH_SECRET: "" })).toBe(false);
  });
});

describe("demo sign-in (devAuthEnabled)", () => {
  it("is never on for Vercel production, whatever DEV_AUTH says", () => {
    expect(devAuthEnabled({ VERCEL_ENV: "production", DEV_AUTH: "1" })).toBe(false);
    expect(
      devAuthEnabled({ VERCEL_ENV: "production", DEV_AUTH: "1", BETTER_AUTH_SECRET: SECRET }),
    ).toBe(false);
    expect(devAuthEnabled({ VERCEL_ENV: "production", DEV_AUTH: "1", CRON_SECRET: CRON })).toBe(
      false,
    );
    expect(
      devAuthEnabled({ VERCEL_ENV: "production", DEV_AUTH: "1", NODE_ENV: "development" }),
    ).toBe(false);
    // A production deployment of a custom environment set up as production.
    expect(devAuthEnabled({ VERCEL_TARGET_ENV: "production", DEV_AUTH: "1" })).toBe(false);
  });

  it("is off on a Vercel preview with real sign-in, on without it when DEV_AUTH=1", () => {
    expect(
      devAuthEnabled({ VERCEL_ENV: "preview", DEV_AUTH: "1", BETTER_AUTH_SECRET: SECRET }),
    ).toBe(false);
    expect(devAuthEnabled({ VERCEL_ENV: "preview", DEV_AUTH: "1" })).toBe(true);
    expect(devAuthEnabled({ VERCEL_ENV: "preview" })).toBe(false);
  });

  it("works locally next to real sign-in when DEV_AUTH=1 (CI and demos)", () => {
    expect(devAuthEnabled({ DEV_AUTH: "1", BETTER_AUTH_SECRET: SECRET })).toBe(true);
    expect(devAuthEnabled({ DEV_AUTH: "1", NODE_ENV: "test" })).toBe(true);
  });

  it("is on in local development only while real sign-in isn't set up", () => {
    expect(devAuthEnabled({ NODE_ENV: "development" })).toBe(true);
    expect(devAuthEnabled({ NODE_ENV: "development", BETTER_AUTH_SECRET: SECRET })).toBe(false);
    expect(devAuthEnabled({ NODE_ENV: "production" })).toBe(false);
    expect(devAuthEnabled({ NODE_ENV: "test" })).toBe(false);
  });

  it("with real sign-in, only lets the seeded …@….test accounts in", () => {
    expect(demoEmailAllowed("admin@media10.test", { BETTER_AUTH_SECRET: SECRET })).toBe(true);
    expect(demoEmailAllowed("Admin@Media10.TEST", { BETTER_AUTH_SECRET: SECRET })).toBe(true);
    expect(demoEmailAllowed("owner@example.com", { BETTER_AUTH_SECRET: SECRET })).toBe(false);
    expect(demoEmailAllowed("owner@example.com", {})).toBe(true);
  });
});

describe("auth base URL and trusted origins", () => {
  it("prefers NEXT_PUBLIC_APP_URL, then Vercel's production domain, then localhost:PORT", () => {
    expect(
      authBaseURL({
        NEXT_PUBLIC_APP_URL: "https://hall-pass-alpha.vercel.app/",
        VERCEL_PROJECT_PRODUCTION_URL: "other.vercel.app",
      }),
    ).toBe("https://hall-pass-alpha.vercel.app");
    expect(
      authBaseURL({
        VERCEL_PROJECT_PRODUCTION_URL: "hall-pass-alpha.vercel.app",
        VERCEL_URL: "hall-pass-abc123.vercel.app",
      }),
    ).toBe("https://hall-pass-alpha.vercel.app");
    expect(authBaseURL({ VERCEL_URL: "hall-pass-abc123.vercel.app" })).toBe(
      "https://hall-pass-abc123.vercel.app",
    );
    expect(authBaseURL({ PORT: "3901" })).toBe("http://localhost:3901");
    expect(authBaseURL({})).toBe("http://localhost:3000");
  });

  it("trusts the base URL plus this deployment's own Vercel URLs, once each", () => {
    expect(
      authTrustedOrigins({
        NEXT_PUBLIC_APP_URL: "https://hall-pass-alpha.vercel.app",
        VERCEL_URL: "hall-pass-abc123.vercel.app",
        VERCEL_BRANCH_URL: "hall-pass-git-main.vercel.app",
      }),
    ).toEqual([
      "https://hall-pass-alpha.vercel.app",
      "https://hall-pass-abc123.vercel.app",
      "https://hall-pass-git-main.vercel.app",
    ]);
    expect(
      authTrustedOrigins({
        VERCEL_PROJECT_PRODUCTION_URL: "hall-pass-alpha.vercel.app",
        VERCEL_URL: "hall-pass-alpha.vercel.app",
      }),
    ).toEqual(["https://hall-pass-alpha.vercel.app"]);
    expect(authTrustedOrigins({ PORT: "3901" })).toEqual(["http://localhost:3901"]);
  });
});

describe("dev links (the link that would have been emailed)", () => {
  it("shows only in local development with email off", () => {
    expect(devLinksShown({ NODE_ENV: "development" })).toBe(true);
    expect(devLinksShown({ NODE_ENV: "development", RESEND_API_KEY: "re_x" })).toBe(true);
    expect(
      devLinksShown({ NODE_ENV: "development", RESEND_API_KEY: "re_x", EMAIL_FROM: "a@b.c" }),
    ).toBe(false);
    expect(devLinksShown({ NODE_ENV: "development", VERCEL_ENV: "preview" })).toBe(false);
    expect(devLinksShown({ NODE_ENV: "development", VERCEL_ENV: "production" })).toBe(false);
    expect(devLinksShown({ NODE_ENV: "production" })).toBe(false);
    expect(devLinksShown({ NODE_ENV: "test" })).toBe(false);
  });
});
