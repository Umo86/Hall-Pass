import { describe, expect, it } from "vitest";
import {
  checkAuthService,
  databaseProjectRef,
  keyProjectRef,
  signInErrorMessage,
  supabaseProjectRef,
} from "@/lib/auth/supabase-diagnostics";

describe("signInErrorMessage", () => {
  it("keeps the usual reply for a wrong email or password", () => {
    expect(signInErrorMessage({ code: "invalid_credentials", status: 400 })).toBe(
      "Incorrect email or password",
    );
    expect(signInErrorMessage({ status: 400, message: "Invalid login credentials" })).toBe(
      "Incorrect email or password",
    );
  });

  it("says when the email isn't confirmed", () => {
    expect(signInErrorMessage({ code: "email_not_confirmed", status: 400 })).toMatch(/confirmed/);
  });

  it("reports set-up problems instead of blaming the password", () => {
    expect(signInErrorMessage({ status: 401, message: "Invalid API key" })).toBe(
      "Sign-in isn't working right now (Invalid API key). Please tell your admin.",
    );
    expect(
      signInErrorMessage({ code: "email_provider_disabled", message: "Email logins are disabled" }),
    ).toMatch(/Email logins are disabled/);
    expect(signInErrorMessage({ status: 0 })).toMatch(/no reply/);
  });
});

describe("supabaseProjectRef", () => {
  it("reads the project id from the URL", () => {
    expect(supabaseProjectRef("https://abcdefgh.supabase.co")).toBe("abcdefgh");
    expect(supabaseProjectRef(undefined)).toBe("not set");
    expect(supabaseProjectRef("nope")).toBe("invalid URL");
  });
});

describe("databaseProjectRef", () => {
  it("reads the project from pooler and direct URLs without exposing the password", () => {
    expect(
      databaseProjectRef(
        "postgresql://postgres.abcd1234:secret@aws-1-eu-west-2.pooler.supabase.com:6543/postgres",
      ),
    ).toBe("abcd1234");
    expect(
      databaseProjectRef("postgresql://postgres:secret@db.wxyz9876.supabase.co:5432/postgres"),
    ).toBe("wxyz9876");
    expect(databaseProjectRef("postgres://u:p@localhost:5432/x")).toBe("not a Supabase database");
    expect(databaseProjectRef(undefined)).toBe("not set");
  });
});

describe("checkAuthService", () => {
  const reply = (status: number, body: unknown = {}) =>
    (async () => new Response(JSON.stringify(body), { status })) as unknown as typeof fetch;

  it("reports each set-up problem", async () => {
    expect(await checkAuthService(undefined, "k")).toBe("not configured");
    expect(
      await checkAuthService(
        "https://x.supabase.co",
        "k",
        reply(200, { external: { email: true } }),
      ),
    ).toBe("ok");
    expect(
      await checkAuthService(
        "https://x.supabase.co",
        "k",
        reply(200, { external: { email: false } }),
      ),
    ).toBe("email sign-in is switched off");
    expect(await checkAuthService("https://x.supabase.co", "k", reply(401))).toBe("key rejected");
    expect(await checkAuthService("https://x.supabase.co", "k", reply(500))).toBe("error 500");
    const down = (async () => {
      throw new Error("offline");
    }) as unknown as typeof fetch;
    expect(await checkAuthService("https://x.supabase.co", "k", down)).toBe("unreachable");
  });
});

describe("sign-in service unreachable", () => {
  it("names the host it couldn't reach", () => {
    expect(
      signInErrorMessage(
        { name: "AuthRetryableFetchError", message: "fetch failed", status: 0 },
        "https://abc.supabase.co",
      ),
    ).toBe(
      "Sign-in isn't working right now: couldn't reach the sign-in service at abc.supabase.co. Please tell your admin.",
    );
  });
});

describe("keyProjectRef", () => {
  it("reads the project from a legacy anon key and not from a publishable key", () => {
    const payload = Buffer.from(JSON.stringify({ ref: "abcd1234", role: "anon" })).toString(
      "base64url",
    );
    expect(keyProjectRef(`h.${payload}.s`)).toBe("abcd1234");
    expect(keyProjectRef("sb_publishable_xyz")).toBe("unknown");
    expect(keyProjectRef(undefined)).toBe("not set");
  });
});
