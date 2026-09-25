"use server";

import { appUrl } from "@/lib/app-url";
import { randomUUID } from "node:crypto";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";
import { and, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { externalGrants, staffInvites, users } from "@/lib/db/schema";
import { writeAudit } from "@/lib/audit";
import { DEV_COOKIE, devAuthEnabled, getSession } from "@/lib/auth/actor";
import { createSupabaseServerClient, supabaseConfigured } from "@/lib/auth/supabase-server";
import { hashInviteToken } from "@/lib/auth/invite-token";
import { claimStaffInvite } from "@/lib/auth/claim-staff-invite";
import { STAFF_HOME } from "@/lib/edition-path";
import { supabaseAdmin } from "@/lib/auth/supabase-admin";

export type InviteResult = { ok: true; message?: string } | { ok: false; error: string };

const acceptSchema = z
  .object({
    token: z.string().min(10),
    fullName: z.string().trim().min(1, "Enter your name").max(200),
    // Needed unless already signed in as the invited email.
    password: z.string().max(200).optional(),
    confirm: z.string().max(200).optional(),
  })
  .refine((d) => !d.password || d.password === d.confirm, {
    message: "The two passwords don't match",
  });

type NewAccount = { password?: string };

/**
 * Create the invited person's login with the password they chose and sign
 * them in. The invitation link (sent to that address) proves the email is
 * theirs. Null when accounts can't be created here (no service key): the
 * caller falls back to an emailed sign-in link.
 */
async function createAccount(
  email: string,
  fullName: string,
  isExternal: boolean,
  account: NewAccount,
): Promise<{ userId: string; error?: never } | { error: string; userId?: never } | null> {
  const admin = supabaseAdmin();
  const supabase = await createSupabaseServerClient();
  if (!admin || !supabase) return null;
  if (!account.password || account.password.length < 8) {
    return { error: "Choose a password of at least 8 characters" };
  }
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: account.password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });
  if (error || !data.user) {
    if (error && (error.status === 422 || /already|exists|registered/i.test(error.message))) {
      return {
        error:
          "You already have an account with this email — sign in with it first, then open this invitation link again.",
      };
    }
    return { error: "Could not create your account — try again shortly." };
  }
  const { error: signInError } = await supabase.auth.signInWithPassword({
    email,
    password: account.password,
  });
  if (signInError) return { error: "Your account was created — sign in with your new password." };
  await db
    .insert(users)
    .values({ id: data.user.id, email: email.toLowerCase(), fullName, isExternal })
    .onConflictDoNothing();
  return { userId: data.user.id };
}

type Grant = typeof externalGrants.$inferSelect;

async function findValidGrant(
  token: string,
): Promise<{ grant: Grant; error?: never } | { grant?: never; error: string }> {
  const grant = await db.query.externalGrants.findFirst({
    where: eq(externalGrants.inviteTokenHash, hashInviteToken(token)),
  });
  if (!grant) return { error: "This invitation link is not valid." };
  if (grant.revokedAt) return { error: "This invitation has been revoked." };
  if (grant.expiresAt && grant.expiresAt.getTime() < Date.now()) {
    return { error: "This invitation has expired." };
  }
  return { grant };
}

type StaffInvite = typeof staffInvites.$inferSelect;

async function findValidStaffInvite(
  token: string,
): Promise<{ invite: StaffInvite; error?: never } | { invite?: never; error: string }> {
  const invite = await db.query.staffInvites.findFirst({
    where: eq(staffInvites.inviteTokenHash, hashInviteToken(token)),
  });
  if (!invite) return { error: "This invitation link is not valid." };
  if (invite.revokedAt) return { error: "This invitation has been revoked." };
  if (invite.acceptedAt) return { error: "This invitation has already been used — sign in instead." };
  return { invite };
}

export async function inviteDetails(token: string) {
  const res = await findValidGrant(token);
  if (res.error === undefined) {
    return {
      ok: true as const,
      kind: "external" as const,
      invitedEmail: res.grant.invitedEmail,
      role: res.grant.role,
      accepted: Boolean(res.grant.acceptedAt),
    };
  }
  const staffRes = await findValidStaffInvite(token);
  if (staffRes.error !== undefined) return { ok: false as const, error: res.error };
  return {
    ok: true as const,
    kind: "staff" as const,
    invitedEmail: staffRes.invite.invitedEmail,
    role: staffRes.invite.role,
    accepted: Boolean(staffRes.invite.acceptedAt),
  };
}

/** Accept an invitation (external grant or staff) and land in the right place. */
export async function acceptInvite(input: unknown): Promise<InviteResult> {
  const parsed = acceptSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  const { token, fullName } = parsed.data;
  const account: NewAccount = { password: parsed.data.password };
  const res = await findValidGrant(token);
  if (res.error !== undefined) {
    const staffRes = await findValidStaffInvite(token);
    if (staffRes.error !== undefined) return { ok: false, error: res.error };
    return acceptStaffInvite(staffRes.invite, token, fullName, account);
  }
  const grant = res.grant;

  const session = await getSession();

  if (session) {
    if (session.user.email.toLowerCase() !== grant.invitedEmail.toLowerCase()) {
      return { ok: false, error: "This invitation was sent to a different email address." };
    }
    await claimGrant(grant.id, session.user.id, fullName);
    redirect("/portal/approvals");
  }

  // With real sign-in configured, invitees always get an email link.
  if (devAuthEnabled() && !supabaseConfigured()) {
    // Development: create the user directly and sign them in by cookie.
    let user = await db.query.users.findFirst({ where: eq(users.email, grant.invitedEmail) });
    if (!user) {
      [user] = await db
        .insert(users)
        .values({ id: randomUUID(), email: grant.invitedEmail, fullName, isExternal: true })
        .returning();
    }
    await claimGrant(grant.id, user.id, fullName);
    const store = await cookies();
    store.set(DEV_COOKIE, user.email, { httpOnly: true, sameSite: "lax", path: "/" });
    redirect("/portal/approvals");
  }

  // Production: create their account with the password they chose.
  const created = await createAccount(grant.invitedEmail, fullName, true, account);
  if (created) {
    if (created.error !== undefined) return { ok: false, error: created.error };
    await claimGrant(grant.id, created.userId, fullName);
    redirect("/portal/approvals");
  }

  // No service key: send a magic link to the invited address; the grant is
  // claimed by email match on first sign-in (lib/auth/actor.ts).
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { ok: false, error: "Authentication is not configured" };
  const base = appUrl();
  const { error } = await supabase.auth.signInWithOtp({
    email: grant.invitedEmail,
    options: { emailRedirectTo: `${base}/auth/callback?next=/invite/${token}` },
  });
  if (error) return { ok: false, error: "Could not send the sign-in link — try again shortly." };
  return { ok: true, message: `A sign-in link has been sent to ${grant.invitedEmail}.` };
}

/** Staff invitation: create the membership now (or via first sign-in). */
async function acceptStaffInvite(
  invite: typeof staffInvites.$inferSelect,
  token: string,
  fullName: string,
  account: NewAccount,
): Promise<InviteResult> {
  const session = await getSession();

  if (session) {
    if (session.user.email.toLowerCase() !== invite.invitedEmail.toLowerCase()) {
      return { ok: false, error: "This invitation was sent to a different email address." };
    }
    await claimStaffInvite(invite, session.user.id, fullName);
    redirect(STAFF_HOME);
  }

  // With real sign-in configured, invitees always get an email link.
  if (devAuthEnabled() && !supabaseConfigured()) {
    let user = await db.query.users.findFirst({ where: eq(users.email, invite.invitedEmail) });
    if (!user) {
      [user] = await db
        .insert(users)
        .values({ id: randomUUID(), email: invite.invitedEmail, fullName })
        .returning();
    }
    await claimStaffInvite(invite, user.id, fullName);
    const store = await cookies();
    store.set(DEV_COOKIE, user.email, { httpOnly: true, sameSite: "lax", path: "/" });
    redirect(STAFF_HOME);
  }

  // Production: create their account with the password they chose.
  const created = await createAccount(invite.invitedEmail, fullName, false, account);
  if (created) {
    if (created.error !== undefined) return { ok: false, error: created.error };
    await claimStaffInvite(invite, created.userId, fullName);
    redirect(STAFF_HOME);
  }

  // No service key: magic link; the membership is created by email match at
  // first sign-in (lib/auth/actor.ts).
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { ok: false, error: "Authentication is not configured" };
  const { error } = await supabase.auth.signInWithOtp({
    email: invite.invitedEmail,
    options: {
      emailRedirectTo: `${appUrl()}/auth/callback?next=${encodeURIComponent(
        `/invite/${token}?name=${encodeURIComponent(fullName)}`,
      )}`,
    },
  });
  if (error) return { ok: false, error: "Could not send the sign-in link — try again shortly." };
  return { ok: true, message: `A sign-in link has been sent to ${invite.invitedEmail}.` };
}

async function claimGrant(grantId: string, userId: string, fullName: string) {
  await db.transaction(async (tx) => {
    const [grant] = await tx
      .update(externalGrants)
      .set({ userId, acceptedAt: new Date() })
      .where(and(eq(externalGrants.id, grantId), isNull(externalGrants.revokedAt)))
      .returning();
    await tx.update(users).set({ fullName, isExternal: true }).where(eq(users.id, userId));
    await writeAudit(tx, {
      organisationId: grant?.organisationId,
      editionId: grant?.editionId,
      actorUserId: userId,
      entityType: "external_grant",
      entityId: grantId,
      action: "invite",
      summary: `Invitation accepted (${grant?.role ?? "external"})`,
    });
  });
}
