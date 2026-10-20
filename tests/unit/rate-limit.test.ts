import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const execute = vi.fn();
vi.mock("@/lib/db/client", () => ({ db: { execute: (...args: unknown[]) => execute(...args) } }));
vi.mock("next/headers", () => ({
  headers: async () => new Headers({ "x-real-ip": "198.51.100.7" }),
}));

const rl = await import("@/lib/auth/rate-limit");

const ENV = { ...process.env };
beforeEach(() => {
  execute.mockReset();
  process.env.AUTH_RATE_LIMIT = "1";
});
afterEach(() => {
  process.env = { ...ENV };
  vi.restoreAllMocks();
});

describe("rate limits: when they're on", () => {
  it("always in production, elsewhere only with AUTH_RATE_LIMIT=1", () => {
    expect(rl.rateLimitEnabled({ NODE_ENV: "production" })).toBe(true);
    expect(rl.rateLimitEnabled({ NODE_ENV: "development" })).toBe(false);
    expect(rl.rateLimitEnabled({ NODE_ENV: "test" })).toBe(false);
    expect(rl.rateLimitEnabled({ NODE_ENV: "development", AUTH_RATE_LIMIT: "1" })).toBe(true);
    expect(rl.rateLimitEnabled({ AUTH_RATE_LIMIT: "0" })).toBe(false);
  });

  it("every window is at most 15 minutes, and every limit is positive", () => {
    for (const [action, rules] of Object.entries(rl.LIMITS)) {
      for (const rule of [rules.subject, rules.ip]) {
        expect(rule.window, action).toBeLessThanOrEqual(900);
        expect(rule.window, action).toBeGreaterThan(0);
        expect(rule.max, action).toBeGreaterThan(0);
      }
    }
  });
});

describe("rate limits: bucket keys", () => {
  it("are an HMAC: stable, different per secret, never the raw key", () => {
    const raw = "action:signIn:subject:owner@example.com";
    const a = rl.bucketKey(raw, "secret-one");
    expect(a).toMatch(/^[0-9a-f]{64}$/);
    expect(rl.bucketKey(raw, "secret-one")).toBe(a);
    expect(rl.bucketKey(raw, "secret-two")).not.toBe(a);
    expect(rl.bucketKey("action:signIn:subject:other@example.com", "secret-one")).not.toBe(a);
    expect(a).not.toContain("owner");
    expect(a).not.toContain("example.com");
  });

  it("use the auth secret by default (the derived one on production too)", () => {
    process.env.BETTER_AUTH_SECRET = "y".repeat(40);
    expect(rl.bucketKey("k")).toBe(rl.bucketKey("k", "y".repeat(40)));
    delete process.env.BETTER_AUTH_SECRET;
    process.env.VERCEL_ENV = "production";
    process.env.CRON_SECRET = "cron-secret-0123456789";
    expect(rl.bucketKey("k")).not.toBe(rl.bucketKey("k", "dev"));
  });

  it("retry-after counts the seconds left in the window, at least one", () => {
    const now = 1_000_000;
    expect(rl.retryAfterSeconds(now - 60_000, 900, now)).toBe(840);
    expect(rl.retryAfterSeconds(now - 899_500, 900, now)).toBe(1);
    expect(rl.retryAfterSeconds(now - 2_000_000, 900, now)).toBe(1);
  });
});

describe("allow(): ok, limited or unavailable", () => {
  it("is ok when both the person's and the network's buckets have room", async () => {
    execute.mockResolvedValue([{ count: 1, last_request: String(Date.now()) }]);
    expect(await rl.allow("signIn", "Owner@Example.com ")).toBe("ok");
    expect(execute).toHaveBeenCalledTimes(2);
  });

  it("is limited once either bucket is over its limit", async () => {
    execute
      .mockResolvedValueOnce([{ count: 1, last_request: String(Date.now()) }])
      .mockResolvedValueOnce([{ count: 51, last_request: String(Date.now()) }]);
    expect(await rl.allow("signIn", "owner@example.com")).toBe("limited");
  });

  it("is unavailable, not limited, when the database write fails (and logs no key)", async () => {
    execute.mockRejectedValue(new Error("permission denied for table auth_rate_limit"));
    const log = vi.spyOn(console, "error").mockImplementation(() => {});
    expect(await rl.allow("signIn", "owner@example.com")).toBe("unavailable");
    expect(log).toHaveBeenCalled();
    const logged = JSON.stringify(log.mock.calls);
    expect(logged).toContain("rate limit unavailable");
    expect(logged).not.toContain("owner@example.com");
    expect(logged).not.toContain("198.51.100.7");
  });

  it("is always ok, without touching the database, when limits are off", async () => {
    delete process.env.AUTH_RATE_LIMIT;
    expect(await rl.allow("signIn", "owner@example.com")).toBe("ok");
    expect(execute).not.toHaveBeenCalled();
  });
});
