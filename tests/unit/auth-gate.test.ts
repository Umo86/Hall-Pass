import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("next/headers", () => ({ cookies: vi.fn(), headers: vi.fn() }));

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
  const { devAuthEnabled } = await import("@/lib/auth/actor");
  return devAuthEnabled();
}

const SUPABASE = {
  NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_x",
};

describe("demo sign-in", () => {
  it("is never on for a Vercel deployment with Supabase sign-in, even with DEV_AUTH=1", async () => {
    expect(await devAuth({ ...SUPABASE, VERCEL_ENV: "production", DEV_AUTH: "1" })).toBe(false);
    expect(await devAuth({ ...SUPABASE, VERCEL_ENV: "preview", DEV_AUTH: "1" })).toBe(false);
  });

  it("still works locally for tests and demos", async () => {
    expect(
      await devAuth({
        VERCEL_ENV: undefined,
        NEXT_PUBLIC_SUPABASE_URL: undefined,
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: undefined,
        NEXT_PUBLIC_SUPABASE_ANON_KEY: undefined,
        DEV_AUTH: "1",
      }),
    ).toBe(true);
  });

  it("is off with Supabase configured unless explicitly on locally", async () => {
    expect(await devAuth({ ...SUPABASE, VERCEL_ENV: undefined, DEV_AUTH: undefined })).toBe(false);
  });
});
