import { afterEach, describe, expect, it, vi } from "vitest";

const ENV = { ...process.env };
afterEach(() => {
  process.env = { ...ENV };
  vi.resetModules();
});

async function devAuth(env: Record<string, string | undefined>) {
  for (const [k, v] of Object.entries(env)) {
    if (v === undefined) delete process.env[k];
    else process.env[k] = v;
  }
  const { devAuthEnabled } = await import("@/lib/auth/config");
  return devAuthEnabled();
}

const REAL_SIGN_IN = { BETTER_AUTH_SECRET: "x".repeat(40) };

describe("demo sign-in", () => {
  it("is never on for a Vercel deployment with real sign-in, even with DEV_AUTH=1", async () => {
    expect(await devAuth({ ...REAL_SIGN_IN, VERCEL_ENV: "production", DEV_AUTH: "1" })).toBe(false);
    expect(await devAuth({ ...REAL_SIGN_IN, VERCEL_ENV: "preview", DEV_AUTH: "1" })).toBe(false);
  });

  it("is never on for Vercel production, even without a secret", async () => {
    expect(
      await devAuth({
        BETTER_AUTH_SECRET: undefined,
        CRON_SECRET: undefined,
        VERCEL_ENV: "production",
        DEV_AUTH: "1",
      }),
    ).toBe(false);
  });

  it("still works locally for tests and demos", async () => {
    expect(
      await devAuth({ VERCEL_ENV: undefined, BETTER_AUTH_SECRET: undefined, DEV_AUTH: "1" }),
    ).toBe(true);
  });

  it("is off with real sign-in configured unless explicitly on locally", async () => {
    expect(await devAuth({ ...REAL_SIGN_IN, VERCEL_ENV: undefined, DEV_AUTH: undefined })).toBe(
      false,
    );
  });
});
