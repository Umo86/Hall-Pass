import { isAPIError } from "better-auth/api";

/**
 * What sign-in says, in one place (British English; the same reply for every
 * address wherever an answer could reveal who has an account). Pure;
 * unit-tested in tests/unit/auth-messages.test.ts.
 */
export const INCORRECT = "Incorrect email or password";
export const TOO_MANY = "Too many attempts — wait a few minutes and try again";
export const UNAVAILABLE =
  "Sign-in isn't working right now. Please try again in a few minutes, or tell the team who invited you.";
export const NOT_SET_UP = "Sign-in isn't set up on this site";
export const LINK_SENT = "If you've been invited, a link is on its way to your inbox.";
export const RESET_SENT =
  "If that email has an account, a link to choose a new password is on its way.";
export const EMAIL_OFF_LINK =
  "Email isn't set up on this site yet, so sign-in links can't be sent. Sign in with your password, or ask a super admin for a sign-in link.";
export const EMAIL_OFF_RESET =
  "Email isn't set up on this site yet, so reset links can't be sent. Ask a super admin for a password reset link.";
export const ALREADY_HAS_PASSWORD =
  "Your account already has a password, so nothing was changed. To choose a new one, use My account or a password reset link.";
export const DEV_LINK =
  "Email isn't set up here (development), so here is the link that would have been sent.";

/** Better Auth's error code (INVALID_EMAIL_OR_PASSWORD, FAILED_TO_CREATE_SESSION, …), if it is one. */
export function signInErrorCode(err: unknown): string | undefined {
  if (!isAPIError(err)) return undefined;
  const code = (err.body as { code?: unknown } | undefined)?.code;
  return typeof code === "string" ? code : undefined;
}

/**
 * What to tell someone whose password sign-in failed. A wrong email or
 * password gets the usual reply; a network or database failure says to try
 * again later; anything else names the code, so the team can look it up.
 */
export function signInErrorMessage(err: unknown): string {
  const code = signInErrorCode(err);
  if (code === "INVALID_EMAIL_OR_PASSWORD" || code === "PASSWORD_TOO_LONG") return INCORRECT;
  if (!code) return UNAVAILABLE;
  return `Sign-in isn't working right now (${code}). Please tell the team who invited you.`;
}

const EXPIRED = "That sign-in link has expired or was already used — ask for a new one below.";
const NOT_INVITED = "That email hasn't been invited here — ask your contact for an invitation.";

const NOTICES: Record<string, string> = {
  auth: EXPIRED,
  INVALID_TOKEN: EXPIRED,
  EXPIRED_TOKEN: EXPIRED,
  failed_to_create_user: NOT_INVITED,
  new_user_signup_disabled: NOT_INVITED,
  failed_to_create_session:
    "Your access is paused or has ended — sign in with your password to see who to ask.",
  rate_limited: "Too many attempts from your network — wait a minute, then open the link again.",
  unavailable: UNAVAILABLE,
};

/** The notice for /login?error=<code> (email links come back with one), or null. */
export function loginNotice(code: string | null | undefined): string | null {
  if (!code) return null;
  return Object.hasOwn(NOTICES, code) ? NOTICES[code] : "Sign-in didn't work — please try again.";
}
