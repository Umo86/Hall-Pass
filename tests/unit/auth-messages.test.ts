import { APIError } from "better-auth/api";
import { describe, expect, it } from "vitest";
import {
  INCORRECT,
  UNAVAILABLE,
  loginNotice,
  signInErrorCode,
  signInErrorMessage,
} from "@/lib/auth/messages";

const apiError = (code: string, status: "UNAUTHORIZED" | "BAD_REQUEST" = "UNAUTHORIZED") =>
  new APIError(status, { code, message: code.toLowerCase() });

describe("what a failed password sign-in says", () => {
  it("a wrong email or password, or a password that's too long, is just 'incorrect'", () => {
    expect(signInErrorMessage(apiError("INVALID_EMAIL_OR_PASSWORD"))).toBe(INCORRECT);
    expect(signInErrorMessage(apiError("PASSWORD_TOO_LONG", "BAD_REQUEST"))).toBe(INCORRECT);
    expect(INCORRECT).toBe("Incorrect email or password");
  });

  it("a network or database error says sign-in isn't working right now", () => {
    expect(signInErrorMessage(new Error("connect ECONNREFUSED 127.0.0.1:5432"))).toBe(UNAVAILABLE);
    expect(signInErrorMessage(new TypeError("fetch failed"))).toBe(UNAVAILABLE);
    expect(UNAVAILABLE).toBe(
      "Sign-in isn't working right now. Please try again in a few minutes, or tell the team who invited you.",
    );
  });

  it("anything else names the code so the team can find it", () => {
    expect(signInErrorMessage(apiError("SOMETHING_NEW", "BAD_REQUEST"))).toBe(
      "Sign-in isn't working right now (SOMETHING_NEW). Please tell the team who invited you.",
    );
  });

  it("reads the code only from Better Auth errors", () => {
    expect(signInErrorCode(apiError("FAILED_TO_CREATE_SESSION"))).toBe("FAILED_TO_CREATE_SESSION");
    expect(signInErrorCode(new Error("FAILED_TO_CREATE_SESSION"))).toBeUndefined();
    expect(signInErrorCode(null)).toBeUndefined();
  });
});

describe("the notice on /login?error=…", () => {
  it("explains each error an email link can come back with", () => {
    const expired = "That sign-in link has expired or was already used — ask for a new one below.";
    expect(loginNotice("auth")).toBe(expired);
    expect(loginNotice("INVALID_TOKEN")).toBe(expired);
    expect(loginNotice("EXPIRED_TOKEN")).toBe(expired);
    const notInvited = "That email hasn't been invited here — ask your contact for an invitation.";
    expect(loginNotice("failed_to_create_user")).toBe(notInvited);
    expect(loginNotice("new_user_signup_disabled")).toBe(notInvited);
    expect(loginNotice("failed_to_create_session")).toBe(
      "Your access is paused or has ended — sign in with your password to see who to ask.",
    );
    expect(loginNotice("rate_limited")).toBe(
      "Too many attempts from your network — wait a minute, then open the link again.",
    );
    expect(loginNotice("unavailable")).toBe(UNAVAILABLE);
  });

  it("has a plain fallback, and nothing without an error", () => {
    expect(loginNotice("something_else")).toBe("Sign-in didn't work — please try again.");
    expect(loginNotice(undefined)).toBeNull();
    expect(loginNotice("")).toBeNull();
  });
});
