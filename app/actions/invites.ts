"use server";

import { randomUUID } from "node:crypto";
import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";
import { and, eq, isNull, or } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { externalGrants, memberships, staffInvites, users } from "@/lib/db/schema";
import { writeAudit } from "@/lib/audit";
import { DEV_COOKIE, devAuthEnabled, getSession } from "@/lib/auth/actor";
import { authConfigured } from "@/lib/auth/config";
import { createInvitedAccount } from "@/lib/auth/accounts";
import { getAuth } from "@/lib/auth/server";
import { allow } from "@/lib/auth/rate-limit";
import { NOT_SET_UP, TOO_MANY, UNAVAILABLE } from "@/lib/auth/messages";
import { claimStaffInvite } from "@/lib/auth/claim-staff-invite";
import { findValidGrant, findValidStaffInvite } from "@/lib/users/invite-lookup";
import { PORTAL_HOME, STAFF_HOME } from "@/lib/edition-path";
import { grantAuditPayload, grantLive, liveGrantSql } from "@/lib/users/external";
import { roleLabel } from "@/lib/format";

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
 * Create the invited person's account (users row plus password, audited)
 * with the password they chose. The invitation link (sent to that address)
 * proves the email is theirs. Null when real sign-in isn't set up here.
 */
async function createAccount(
  email: string,
  fullName: string,
  isExternal: boolean,
  account: NewAccount,
): Promise<{ userId: string; error?: never } | { error: string; userId?: never } | null> {
  if (!authConfigured()) return null;
  if (!account.password || account.password.length < 8) {
    return { error: "Choose a password of at least 8 characters" };
  }
  const created = await createInvitedAccount({
    email,
    fullName,
    isExternal,
    password: account.password,
  });
  if ("error" in created) {
    return {
      error:
        "You already have an account with this email — sign in with it first, then open this invitation link again.",
    };
  }
  return { userId: created.userId };
}

/**
 * Sign the new account in (after the invitation is claimed, so Better Auth's
 * session gate sees the membership or grant). False when it couldn't.
 */
async function signInNewAccount(email: string, password: string): Promise<boolean> {
  try {
    await getAuth().api.signInEmail({ body: { email, password }, headers: await headers() });
    return true;
  } catch (err) {
    console.error("signInNewAccount", err instanceof Error ? err.message : err);
    return false;
  }
}

const SIGN_IN_AFTER = "Your account was created — sign in with your new password.";

/** Accept an invitation (external grant or staff) and land in the right place. */
export async function acceptInvite(input: unknown): Promise<InviteResult> {
  const parsed = acceptSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  const { token, fullName } = parsed.data;
  const gate = await allow("inviteAccept", token.slice(0, 16));
  if (gate !== "ok") return { ok: false, error: gate === "limited" ? TOO_MANY : UNAVAILABLE };
  const account: NewAccount = { password: parsed.data.password };
  const res = await findValidGrant(token);
  if (!res.grant) {
    const staffRes = await findValidStaffInvite(token);
    if (!staffRes.invite) {
      const problem = res.problem ?? staffRes.problem;
      return { ok: false, error: problem?.error ?? "This invitation link is not valid." };
    }
    return acceptStaffInvite(staffRes.invite, fullName, account);
  }
  const grant = res.grant;

  const session = await getSession();

  if (session) {
    if (session.user.email.toLowerCase() !== grant.invitedEmail.toLowerCase()) {
      return { ok: false, error: "This invitation was sent to a different email address." };
    }
    if (session.actor.kind === "staff") {
      // A team member already sees everything; partner access would only confuse it.
      return {
        ok: false,
        error: "You're signed in as a team member, so you don't need this portal invitation.",
      };
    }
    const claimed = await claimGrant(grant.id, session.user.id, fullName);
    if (!claimed) return { ok: false, error: CLAIM_FAILED };
    redirect(PORTAL_HOME);
  }

  // Demo sign-in only while real sign-in isn't set up here.
  if (devAuthEnabled() && !authConfigured()) {
    // Development: create the user directly and sign them in by cookie.
    let user = await db.query.users.findFirst({ where: eq(users.email, grant.invitedEmail) });
    if (!user) {
      [user] = await db
        .insert(users)
        .values({ id: randomUUID(), email: grant.invitedEmail, fullName, isExternal: true })
        .returning();
    }
    const claimed = await claimGrant(grant.id, user.id, fullName);
    if (!claimed) return { ok: false, error: CLAIM_FAILED };
    const store = await cookies();
    store.set(DEV_COOKIE, user.email, { httpOnly: true, sameSite: "lax", path: "/" });
    redirect(PORTAL_HOME);
  }

  // Real sign-in: create their account with the password they chose, claim
  // the invitation, then sign them in.
  const created = await createAccount(grant.invitedEmail, fullName, true, account);
  if (!created) return { ok: false, error: NOT_SET_UP };
  if (created.error !== undefined) return { ok: false, error: created.error };
  const claimed = await claimGrant(grant.id, created.userId, fullName);
  if (!claimed) return { ok: false, error: CLAIM_FAILED };
  if (!(await signInNewAccount(grant.invitedEmail, account.password!))) {
    return { ok: false, error: SIGN_IN_AFTER };
  }
  redirect(PORTAL_HOME);
}

/** Staff invitation: create the membership now. */
async function acceptStaffInvite(
  invite: typeof staffInvites.$inferSelect,
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

  // Demo sign-in only while real sign-in isn't set up here.
  if (devAuthEnabled() && !authConfigured()) {
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

  // Real sign-in: create their account with the password they chose, claim
  // the invitation, then sign them in.
  const created = await createAccount(invite.invitedEmail, fullName, false, account);
  if (!created) return { ok: false, error: NOT_SET_UP };
  if (created.error !== undefined) return { ok: false, error: created.error };
  await claimStaffInvite(invite, created.userId, fullName);
  if (!(await signInNewAccount(invite.invitedEmail, account.password!))) {
    return { ok: false, error: SIGN_IN_AFTER };
  }
  redirect(STAFF_HOME);
}

const CLAIM_FAILED =
  "This invitation can't be used any more — it was withdrawn, has ended or belongs to another account. Ask whoever invited you.";

/**
 * Link one partner invitation to the account that opened it, with its
 * audit row (who, what for, when). Only a live grant nobody else has
 * claimed, and never for someone on a team (they would be marked as a
 * partner and lose staff-only content). False when nothing was claimed.
 */
async function claimGrant(grantId: string, userId: string, fullName: string): Promise<boolean> {
  return db.transaction(async (tx) => {
    const [member] = await tx
      .select({ id: memberships.id })
      .from(memberships)
      .where(eq(memberships.userId, userId))
      .limit(1);
    if (member) return false;
    const now = new Date();
    const [current] = await tx
      .select()
      .from(externalGrants)
      .where(eq(externalGrants.id, grantId))
      .for("update");
    // Opened again after signing in (which already claimed it): only the name
    // they typed is new, kept when their account has none yet.
    if (current?.userId === userId && current.acceptedAt && grantLive(current, now)) {
      const [user] = await tx
        .select({ fullName: users.fullName })
        .from(users)
        .where(eq(users.id, userId));
      if (user && !user.fullName.trim() && fullName.trim()) {
        await tx
          .update(users)
          .set({ fullName: fullName.trim(), updatedAt: now })
          .where(eq(users.id, userId));
        await writeAudit(tx, {
          organisationId: current.organisationId,
          actorUserId: userId,
          entityType: "user",
          entityId: userId,
          action: "update",
          after: { fullName: fullName.trim() },
          summary: `${current.invitedEmail} added their name`,
          subjectUserId: userId,
          subjectEmail: current.invitedEmail,
        });
      }
      return true;
    }
    const [grant] = await tx
      .update(externalGrants)
      .set({ userId, acceptedAt: now, updatedAt: now })
      .where(
        and(
          eq(externalGrants.id, grantId),
          or(isNull(externalGrants.userId), eq(externalGrants.userId, userId)),
          liveGrantSql(now),
        ),
      )
      .returning();
    if (!grant) return false;
    await tx
      .update(users)
      .set({ fullName, isExternal: true, updatedAt: now })
      .where(eq(users.id, userId));
    await writeAudit(tx, {
      organisationId: grant.organisationId,
      editionId: grant.editionId,
      actorUserId: userId,
      entityType: "external_grant",
      entityId: grant.id,
      action: "invite",
      after: { ...grantAuditPayload(grant), acceptedAt: now.toISOString(), how: "link" },
      summary: `${grant.invitedEmail} accepted their invitation as ${roleLabel(grant.role)}`,
      subjectUserId: userId,
      subjectEmail: grant.invitedEmail,
    });
    return true;
  });
}
