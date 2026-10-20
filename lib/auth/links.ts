import "server-only";
import { headers } from "next/headers";
import { emailConfigured } from "@/lib/email/configured";
import { safeNext } from "@/lib/edition-path";
import { authConfigured } from "./config";
import { normaliseEmail } from "./accounts";
import { getAuth, linkCapture } from "./server";

/**
 * Sign-in and password reset links: emailed (Resend), or handed back to pass
 * on (super admins; local development without email). Callers check who may
 * have one (lib/auth/account-link.ts:emailIsInvited) first.
 */
export type AccountEmailResult = "signin_sent" | "not_sent";

function magicLinkBody(email: string, next?: string | null) {
  return {
    email: normaliseEmail(email),
    callbackURL: safeNext(next) ?? "/",
    // Someone invited who has no account yet lands where they choose a password.
    newUserCallbackURL: "/auth/accept",
    errorCallbackURL: "/login",
  };
}

/** "Email me a link": a magic link to an invited email. New invitees land on /auth/accept. */
export async function sendSignInLink(
  email: string,
  opts: { next?: string | null } = {},
): Promise<AccountEmailResult> {
  if (!authConfigured() || !emailConfigured()) return "not_sent";
  try {
    await getAuth().api.signInMagicLink({
      body: magicLinkBody(email, opts.next),
      headers: await headers(),
    });
    return "signin_sent";
  } catch (err) {
    console.error("sendSignInLink", err instanceof Error ? err.message : err);
    return "not_sent";
  }
}

/** "Forgot password?": a reset email to someone with an account (silently nothing otherwise). */
export async function sendPasswordResetLink(email: string): Promise<AccountEmailResult> {
  if (!authConfigured() || !emailConfigured()) return "not_sent";
  try {
    await getAuth().api.requestPasswordReset({
      body: { email: normaliseEmail(email), redirectTo: "/reset-password" },
      headers: await headers(),
    });
    return "signin_sent";
  } catch (err) {
    console.error("sendPasswordResetLink", err instanceof Error ? err.message : err);
    return "not_sent";
  }
}

/** A one-time sign-in link, handed back instead of emailed. Null if none was made. */
export async function createSignInLink(
  email: string,
  next?: string | null,
): Promise<string | null> {
  if (!authConfigured()) return null;
  const holder: { url?: string } = {};
  try {
    const h = await headers();
    await linkCapture.run(holder, () =>
      getAuth().api.signInMagicLink({ body: magicLinkBody(email, next), headers: h }),
    );
  } catch (err) {
    console.error("createSignInLink", err instanceof Error ? err.message : err);
    return null;
  }
  return holder.url ?? null;
}

/** A one-time password reset link, handed back instead of emailed. Null if none was made. */
export async function createPasswordResetLink(email: string): Promise<string | null> {
  if (!authConfigured()) return null;
  const holder: { url?: string } = {};
  try {
    const h = await headers();
    await linkCapture.run(holder, () =>
      getAuth().api.requestPasswordReset({
        body: { email: normaliseEmail(email), redirectTo: "/reset-password" },
        headers: h,
      }),
    );
  } catch (err) {
    console.error("createPasswordResetLink", err instanceof Error ? err.message : err);
    return null;
  }
  return holder.url ?? null;
}

/**
 * The stored reset token (its row id and the user it belongs to) while it is
 * still valid, else null. Better Auth hashes the identifier itself.
 */
export async function resetTokenVerification(
  token: string,
): Promise<{ id: string; userId: string } | null> {
  if (!authConfigured() || !token || token.length > 200) return null;
  const ctx = await getAuth().$context;
  const v = await ctx.internalAdapter.findVerificationValue(`reset-password:${token}`);
  if (!v || v.expiresAt.getTime() <= Date.now()) return null;
  return { id: v.id, userId: v.value };
}

/** The user a reset token belongs to while it's still valid, else null (the /reset-password page). */
export async function resetTokenUserId(token: string): Promise<string | null> {
  return (await resetTokenVerification(token))?.userId ?? null;
}
