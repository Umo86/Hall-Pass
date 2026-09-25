"use server";

import { appUrl } from "@/lib/app-url";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { memberships, users } from "@/lib/db/schema";
import { writeAudit } from "@/lib/audit";
import { DEV_COOKIE, demoEmailAllowed, devAuthEnabled, getSession } from "@/lib/auth/actor";
import { createSupabaseServerClient, supabaseConfigured } from "@/lib/auth/supabase-server";
import { emailIsInvited, sendAccountEmail } from "@/lib/auth/account-link";
import { PORTAL_HOME, STAFF_HOME, safeNext } from "@/lib/edition-path";

export type AuthResult = { ok: true; message?: string } | { ok: false; error: string };

const emailSchema = z.object({
  email: z.string().email("Enter a valid email address"),
  next: z.string().max(500).optional(),
});
const passwordSchema = emailSchema.extend({
  password: z.string().min(1, "Enter your password"),
});

/**
 * Email and password sign-in: how everyone signs in once their account is
 * set up. An account alone isn't enough — the person must still be on the
 * team or hold a live partner invitation.
 */
export async function signInWithPassword(input: unknown): Promise<AuthResult> {
  const parsed = passwordSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { ok: false, error: "Authentication is not configured" };
  const { error } = await supabase.auth.signInWithPassword({
    email: parsed.data.email.trim().toLowerCase(),
    password: parsed.data.password,
  });
  if (error) return { ok: false, error: "Incorrect email or password" };
  if (!(await emailIsInvited(parsed.data.email))) {
    await supabase.auth.signOut();
    return {
      ok: false,
      error: "This account doesn't have access to Hall Pass — ask your admin for an invitation.",
    };
  }
  redirect(safeNext(parsed.data.next) ?? "/");
}

/** Same reply whoever asks, so nobody can find out who has an account. */
const LINK_SENT = "If you've been invited, a link is on its way to your inbox.";

/**
 * "Email me a link". Only invited people get anything: a link to create
 * their account the first time, or to sign in. Nobody else is emailed and no
 * account is ever created for them — there is no sign-up.
 */
export async function signInWithMagicLink(input: unknown): Promise<AuthResult> {
  const parsed = emailSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  if (!supabaseConfigured()) return { ok: false, error: "Authentication is not configured" };
  if (await emailIsInvited(parsed.data.email)) {
    const sent = await sendAccountEmail(parsed.data.email);
    if (sent === "not_sent") {
      return { ok: false, error: "Could not send the email — try again in a few minutes" };
    }
  }
  return { ok: true, message: LINK_SENT };
}

const newPasswordSchema = z
  .object({
    password: z.string().min(8, "Use at least 8 characters"),
    confirm: z.string(),
  })
  .refine((d) => d.password === d.confirm, { message: "The two passwords don't match" });

/** "Forgot password": email a link that lets them choose a new one. */
export async function sendPasswordReset(input: unknown): Promise<AuthResult> {
  const parsed = emailSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { ok: false, error: "Authentication is not configured" };
  // Only people with access are emailed; the reply is the same either way.
  if (!(await emailIsInvited(parsed.data.email))) {
    return {
      ok: true,
      message: "If that email has an account, a link to choose a new password is on its way.",
    };
  }
  const { error } = await supabase.auth.resetPasswordForEmail(parsed.data.email, {
    redirectTo: `${appUrl()}/auth/callback?next=/reset-password`,
  });
  // Same answer either way, so nobody can find out which emails have accounts.
  if (error && error.status !== 400 && error.status !== 404) {
    return { ok: false, error: "Could not send the email — try again shortly" };
  }
  return {
    ok: true,
    message: "If that email has an account, a link to choose a new password is on its way.",
  };
}

/** Set a new password (from the reset link, or while signed in). */
export async function updatePassword(input: unknown): Promise<AuthResult> {
  const parsed = newPasswordSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { ok: false, error: "Authentication is not configured" };
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user)
    return { ok: false, error: "The link has expired — ask for a new one from the sign-in page" };
  const { error } = await supabase.auth.updateUser({ password: parsed.data.password });
  if (error) {
    return {
      ok: false,
      error: /different|same/i.test(error.message)
        ? "Choose a password you haven't used before"
        : "Could not save the password — try again",
    };
  }
  await db.transaction(async (tx) => {
    await writeAudit(tx, {
      actorUserId: user.id,
      entityType: "user",
      entityId: user.id,
      action: "settings_change",
      summary: "Password changed",
    });
  });
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
 * Finish creating an account from the invitation email: the link has signed
 * the person in; now they choose their name and password. Their invitation
 * (team or partner) is applied at the same time.
 */
export async function completeAccount(input: unknown): Promise<AuthResult> {
  const parsed = completeSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { ok: false, error: "Authentication is not configured" };
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user?.email) {
    return {
      ok: false,
      error: "This link has expired — ask your admin to send the invitation again",
    };
  }
  if (!(await emailIsInvited(user.email))) {
    await supabase.auth.signOut();
    return { ok: false, error: "This invitation has been withdrawn — ask your admin" };
  }
  const { error } = await supabase.auth.updateUser({
    password: parsed.data.password,
    data: { full_name: parsed.data.fullName },
  });
  if (error && !/different|same/i.test(error.message)) {
    return { ok: false, error: "Could not save your password — try again" };
  }
  await db
    .insert(users)
    .values({ id: user.id, email: user.email.toLowerCase(), fullName: parsed.data.fullName })
    .onConflictDoUpdate({ target: users.id, set: { fullName: parsed.data.fullName } });
  await db.transaction(async (tx) => {
    await writeAudit(tx, {
      actorUserId: user.id,
      entityType: "user",
      entityId: user.id,
      action: "login",
      summary: `${user.email} set up their account`,
    });
  });
  // Loading the session applies their invitation (membership or partner access).
  const session = await getSession();
  if (!session) return { ok: false, error: "Your invitation couldn't be found — ask your admin" };
  redirect(session.actor.kind === "staff" ? STAFF_HOME : PORTAL_HOME);
}

/**
 * Development sign-in: assume a seeded user by email. Enabled only while
 * Supabase Auth is unconfigured and DEV_AUTH allows it (see lib/auth/actor).
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

export async function signOut(): Promise<void> {
  const supabase = await createSupabaseServerClient();
  if (supabase) await supabase.auth.signOut();
  const store = await cookies();
  store.delete(DEV_COOKIE);
  redirect("/login");
}
