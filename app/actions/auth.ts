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
import { createSupabaseServerClient } from "@/lib/auth/supabase-server";
import { PORTAL_HOME, STAFF_HOME, safeNext } from "@/lib/edition-path";

export type AuthResult = { ok: true; message?: string } | { ok: false; error: string };

const emailSchema = z.object({
  email: z.string().email("Enter a valid email address"),
  next: z.string().max(500).optional(),
});
const passwordSchema = emailSchema.extend({
  password: z.string().min(1, "Enter your password"),
});

/** Staff password sign-in (development convenience; magic link in production). */
export async function signInWithPassword(input: unknown): Promise<AuthResult> {
  const parsed = passwordSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { ok: false, error: "Authentication is not configured" };
  const { error } = await supabase.auth.signInWithPassword(parsed.data);
  if (error) return { ok: false, error: "Incorrect email or password" };
  redirect(safeNext(parsed.data.next) ?? "/");
}

/** Magic link for staff and external users alike. */
export async function signInWithMagicLink(input: unknown): Promise<AuthResult> {
  const parsed = emailSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { ok: false, error: "Authentication is not configured" };
  const base = appUrl();
  const { error } = await supabase.auth.signInWithOtp({
    email: parsed.data.email,
    options: {
      emailRedirectTo: `${base}/auth/callback${
        safeNext(parsed.data.next) ? `?next=${encodeURIComponent(safeNext(parsed.data.next)!)}` : ""
      }`,
    },
  });
  if (error) return { ok: false, error: "Could not send the magic link — try again shortly" };
  return { ok: true, message: "Check your inbox for a sign-in link." };
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

export async function currentSessionRedirect(): Promise<void> {
  const session = await getSession();
  if (!session) redirect("/login");
  redirect(session.actor.kind === "staff" ? STAFF_HOME : PORTAL_HOME);
}
