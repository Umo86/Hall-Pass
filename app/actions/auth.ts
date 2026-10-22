"use server";

import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { memberships, users } from "@/lib/db/schema";
import { writeAudit } from "@/lib/audit";
import {
  DEV_COOKIE,
  accessRefusal,
  demoEmailAllowed,
  devAuthEnabled,
  getSession,
} from "@/lib/auth/actor";
import { authConfigured, demoAccountLocked, devLinksShown } from "@/lib/auth/config";
import { demoPasswordRefused, ensureDemoPassword } from "@/lib/auth/demo-logins";
import { getAuth } from "@/lib/auth/server";
import { getAuthSession } from "@/lib/auth/session";
import { auditSignIn, emailIsInvited } from "@/lib/auth/account-link";
import {
  createPasswordResetLink,
  createSignInLink,
  resetTokenVerification,
  sendPasswordResetLink,
  sendSignInLink,
} from "@/lib/auth/links";
import {
  hasPassword,
  normaliseEmail,
  resetPasswordWithVerification,
  setPasswordAndName,
} from "@/lib/auth/accounts";
import { allow } from "@/lib/auth/rate-limit";
import {
  ALREADY_HAS_PASSWORD,
  DEV_LINK,
  EMAIL_OFF_LINK,
  EMAIL_OFF_RESET,
  INCORRECT,
  LINK_SENT,
  NOT_SET_UP,
  RESET_SENT,
  TOO_MANY,
  UNAVAILABLE,
  signInErrorCode,
  signInErrorMessage,
} from "@/lib/auth/messages";
import { emailConfigured } from "@/lib/email/dispatch";
import { PORTAL_HOME, STAFF_HOME, safeNext } from "@/lib/edition-path";

export type AuthResult =
  { ok: true; message?: string; devLink?: string } | { ok: false; error: string };

const emailSchema = z.object({
  email: z.string().trim().email("Enter a valid email address").max(320),
  next: z.string().max(500).optional(),
});
const passwordSchema = emailSchema.extend({
  password: z.string().min(1, "Enter your password").max(1000),
});

/** The rate limiter's answer as a reply, or null to go ahead. */
function limitReply(gate: "ok" | "limited" | "unavailable"): AuthResult | null {
  if (gate === "ok") return null;
  return { ok: false, error: gate === "limited" ? TOO_MANY : UNAVAILABLE };
}

/**
 * Email and password sign-in: how everyone signs in once their account is
 * set up. An account alone isn't enough — Better Auth's session gate
 * (lib/auth/server.ts) refuses anyone no longer on the team or without a
 * live partner invitation, and the reply says who to ask.
 */
export async function signInWithPassword(input: unknown): Promise<AuthResult> {
  const parsed = passwordSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  if (!authConfigured()) return { ok: false, error: NOT_SET_UP };
  const email = normaliseEmail(parsed.data.email);
  const limited = limitReply(await allow("signIn", email));
  if (limited) return limited;
  // Demo logins (testing only): off on a Vercel deployment, the demo accounts
  // can't sign in; on, they take only the shared password, made theirs first.
  if (demoAccountLocked(email) || demoPasswordRefused(email, parsed.data.password)) {
    return { ok: false, error: INCORRECT };
  }
  await ensureDemoPassword(email, parsed.data.password).catch((err) =>
    console.error("ensureDemoPassword", err instanceof Error ? err.message : err),
  );
  let user: { id: string; email: string };
  try {
    const res = await getAuth().api.signInEmail({
      body: { email, password: parsed.data.password },
      headers: await headers(),
    });
    user = res.user;
  } catch (err) {
    // The password was right, but the session gate said no.
    if (signInErrorCode(err) === "FAILED_TO_CREATE_SESSION") {
      return { ok: false, error: await accessRefusal(email) };
    }
    const message = signInErrorMessage(err);
    if (message !== INCORRECT) {
      console.error(
        "signInWithPassword",
        signInErrorCode(err) ?? (err instanceof Error ? err.message : err),
      );
    }
    return { ok: false, error: message };
  }
  await auditSignIn(user, "password");
  redirect(safeNext(parsed.data.next) ?? "/");
}

/**
 * "Email me a link". Only invited people get anything: a sign-in link, which
 * creates the account the first time (then /auth/accept). Nobody else is
 * emailed and the reply is the same for every address — there is no sign-up.
 * Without email, local development shows the link; elsewhere the reply says
 * email isn't set up.
 */
export async function signInWithMagicLink(input: unknown): Promise<AuthResult> {
  const parsed = emailSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  if (!authConfigured()) return { ok: false, error: NOT_SET_UP };
  const email = normaliseEmail(parsed.data.email);
  const limited = limitReply(await allow("emailLink", email));
  if (limited) return limited;
  const invited = await emailIsInvited(email);
  if (!emailConfigured()) {
    if (!devLinksShown()) return { ok: false, error: EMAIL_OFF_LINK };
    const devLink = invited ? await createSignInLink(email, parsed.data.next) : null;
    return devLink ? { ok: true, message: DEV_LINK, devLink } : { ok: true, message: LINK_SENT };
  }
  if (invited && (await sendSignInLink(email, { next: parsed.data.next })) === "not_sent") {
    return { ok: false, error: "Could not send the email — try again in a few minutes" };
  }
  return { ok: true, message: LINK_SENT };
}

/**
 * "Forgot password?": email a link to choose a new one. Only people with
 * access are emailed; the reply is the same either way.
 */
export async function sendPasswordReset(input: unknown): Promise<AuthResult> {
  const parsed = emailSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  if (!authConfigured()) return { ok: false, error: NOT_SET_UP };
  const email = normaliseEmail(parsed.data.email);
  const limited = limitReply(await allow("emailLink", email));
  if (limited) return limited;
  const invited = await emailIsInvited(email);
  if (!emailConfigured()) {
    if (!devLinksShown()) return { ok: false, error: EMAIL_OFF_RESET };
    const devLink = invited ? await createPasswordResetLink(email) : null;
    return devLink ? { ok: true, message: DEV_LINK, devLink } : { ok: true, message: RESET_SENT };
  }
  if (invited && (await sendPasswordResetLink(email)) === "not_sent") {
    return { ok: false, error: "Could not send the email — try again in a few minutes" };
  }
  return { ok: true, message: RESET_SENT };
}

const LINK_EXPIRED = "The link has expired — ask for a new one from the sign-in page";

const newPasswordSchema = z
  .object({
    token: z.string().min(1, LINK_EXPIRED).max(200, LINK_EXPIRED),
    password: z.string().min(8, "Use at least 8 characters").max(200, "Use at most 200 characters"),
    confirm: z.string(),
  })
  .refine((d) => d.password === d.confirm, { message: "The two passwords don't match" });

/**
 * Choose a new password from the reset link (/reset-password?token=…). The
 * token is used up, the password saved and every session ended in one
 * transaction with its audit row; then the link signs them in, as before.
 */
export async function updatePassword(input: unknown): Promise<AuthResult> {
  const parsed = newPasswordSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  if (!authConfigured()) return { ok: false, error: NOT_SET_UP };
  const { token, password } = parsed.data;
  const limited = limitReply(await allow("resetSubmit", token.slice(0, 16)));
  if (limited) return limited;
  const verification = await resetTokenVerification(token);
  if (!verification) return { ok: false, error: LINK_EXPIRED };
  const user = await db.query.users.findFirst({ where: eq(users.id, verification.userId) });
  if (!user) return { ok: false, error: LINK_EXPIRED };
  const saved = await resetPasswordWithVerification({
    verificationId: verification.id,
    userId: user.id,
    email: user.email,
    password,
  });
  if (saved === "expired") return { ok: false, error: LINK_EXPIRED };
  try {
    const res = await getAuth().api.signInEmail({
      body: { email: user.email, password },
      headers: await headers(),
    });
    await auditSignIn(res.user, "password");
  } catch (err) {
    if (signInErrorCode(err) === "FAILED_TO_CREATE_SESSION") {
      return { ok: false, error: `Password saved. ${await accessRefusal(user.email)}` };
    }
    console.error("updatePassword: sign-in after reset", signInErrorCode(err) ?? err);
    return { ok: false, error: "Password saved — sign in with your new password." };
  }
  redirect("/");
}

const completeSchema = z
  .object({
    fullName: z.string().trim().min(1, "Enter your name").max(200),
    password: z.string().min(8, "Use at least 8 characters").max(200),
    confirm: z.string(),
  })
  .refine((d) => d.password === d.confirm, { message: "The two passwords don't match" });

/**
 * Finish creating an account after an email link for someone invited
 * (/auth/accept): the link has signed them in; now they choose their name
 * and password. Their invitation (team or partner) is applied at the same
 * time.
 */
export async function completeAccount(input: unknown): Promise<AuthResult> {
  const parsed = completeSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  if (!authConfigured()) return { ok: false, error: NOT_SET_UP };
  const auth = await getAuthSession();
  if (!auth?.user) {
    return {
      ok: false,
      error: "This link has expired — ask the person who invited you to send it again",
    };
  }
  if (!(await emailIsInvited(auth.user.email))) {
    await getAuth()
      .api.signOut({ headers: await headers() })
      .catch(() => {});
    return {
      ok: false,
      error: "This invitation has been withdrawn — ask the person who invited you",
    };
  }
  // Set-up is for a first password only. Replacing one goes through My
  // account (current password, other sessions ended) or a reset link.
  if (await hasPassword(auth.user.id)) return { ok: false, error: ALREADY_HAS_PASSWORD };
  const saved = await setPasswordAndName({
    userId: auth.user.id,
    email: auth.user.email,
    fullName: parsed.data.fullName,
    password: parsed.data.password,
  });
  if (saved === "exists") return { ok: false, error: ALREADY_HAS_PASSWORD };
  // Loading the session applies their invitation (membership or partner access).
  const session = await getSession();
  if (!session) {
    return {
      ok: false,
      error: "Your invitation couldn't be found — ask the person who invited you",
    };
  }
  redirect(session.actor.kind === "staff" ? STAFF_HOME : PORTAL_HOME);
}

/**
 * Development sign-in: assume a seeded user by email. Only where demo
 * sign-in is allowed (lib/auth/config.ts: never on Vercel production).
 */
export async function devSignIn(input: unknown): Promise<AuthResult> {
  if (!devAuthEnabled()) return { ok: false, error: "Development sign-in is disabled" };
  const parsed = emailSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  if (!demoEmailAllowed(parsed.data.email)) {
    return { ok: false, error: "Demo sign-in only works for demo accounts — use your email link" };
  }
  const user = await db.query.users.findFirst({ where: eq(users.email, parsed.data.email) });
  if (!user) return { ok: false, error: "No such user — run the seed first" };
  const store = await cookies();
  store.set(DEV_COOKIE, user.email, { httpOnly: true, sameSite: "lax", path: "/" });
  const membership = await db.query.memberships.findFirst({
    where: eq(memberships.userId, user.id),
  });
  await db.transaction(async (tx) => {
    await writeAudit(tx, {
      actorUserId: user.id,
      entityType: "user",
      entityId: user.id,
      action: "login",
      summary: `${user.email} signed in (development)`,
    });
  });
  redirect(safeNext(parsed.data.next) ?? (membership ? STAFF_HOME : PORTAL_HOME));
}

/** Sign out: the session row is deleted and its cookie cleared (and the demo cookie). */
export async function signOut(): Promise<void> {
  if (authConfigured()) {
    await getAuth()
      .api.signOut({ headers: await headers() })
      .catch(() => {});
  }
  const store = await cookies();
  store.delete(DEV_COOKIE);
  redirect("/login");
}
