import "server-only";
import { and, eq, gt, ne, sql } from "drizzle-orm";
import { db, type Tx } from "@/lib/db/client";
import { authAccount, authSession, authVerification, users } from "@/lib/db/schema";
import { writeAudit } from "@/lib/audit";
import { accountOrganisationId } from "./account-link";
import { hashPassword, verifyPassword } from "./password";

/**
 * Password writes we own (invitation acceptance, "set up your account",
 * change password, reset by link), each in one transaction with its audit
 * row. Better Auth reads what these write: users is its user table and
 * auth_account (provider "credential", account id = the user id) holds the
 * password hash.
 */

/** Lower-case, trimmed. Better Auth looks people up by the lower-cased email. */
export const normaliseEmail = (e: string) => e.trim().toLowerCase();

function isUniqueViolation(err: unknown): boolean {
  const e = err as { code?: string; cause?: { code?: string } } | null;
  return e?.code === "23505" || e?.cause?.code === "23505";
}

/** Set (or replace) the person's password, inside the caller's transaction. */
async function upsertPasswordTx(tx: Tx, userId: string, hash: string): Promise<void> {
  await tx
    .insert(authAccount)
    .values({ userId, accountId: userId, providerId: "credential", password: hash })
    .onConflictDoUpdate({
      target: [authAccount.providerId, authAccount.accountId],
      set: { password: hash, updatedAt: new Date() },
    });
}

/** Sign someone out everywhere, inside the caller's transaction. Returns how many sessions ended. */
export async function revokeSessionsTx(tx: Tx, userId: string): Promise<number> {
  const rows = await tx
    .delete(authSession)
    .where(eq(authSession.userId, userId))
    .returning({ id: authSession.id });
  return rows.length;
}

/**
 * The account an invitation creates: the users row (email verified: the link
 * went to that inbox) plus its password, audited. "exists" when the email
 * already has an account (the caller tells them to sign in first, then open
 * the invitation again).
 */
export async function createInvitedAccount(opts: {
  email: string;
  fullName: string;
  isExternal: boolean;
  password: string;
}): Promise<{ userId: string } | { error: "exists" }> {
  const email = normaliseEmail(opts.email);
  const hash = await hashPassword(opts.password);
  try {
    return await db.transaction(async (tx) => {
      const [existing] = await tx
        .select({ id: users.id })
        .from(users)
        .where(sql`lower(${users.email}) = ${email}`)
        .limit(1);
      if (existing) return { error: "exists" as const };
      const [row] = await tx
        .insert(users)
        .values({
          email,
          fullName: opts.fullName.trim(),
          isExternal: opts.isExternal,
          emailVerified: true,
        })
        .returning({ id: users.id });
      await upsertPasswordTx(tx, row.id, hash);
      await writeAudit(tx, {
        actorUserId: row.id,
        entityType: "user",
        entityId: row.id,
        action: "create",
        summary: `${email} set up their account`,
        subjectUserId: row.id,
        subjectEmail: email,
      });
      return { userId: row.id };
    });
  } catch (err) {
    // Two tabs accepting at once: the second finds the email taken.
    if (isUniqueViolation(err)) return { error: "exists" };
    throw err;
  }
}

/**
 * The first password and the name of someone an email link has just signed
 * in (/auth/accept), audited ("set up their account"). Never replaces a
 * password: "exists" when they already have one (changing it is
 * changeOwnPassword's job, which asks for the current one and ends other
 * sessions), and nothing is written. Two tabs at once: the first wins.
 */
export async function setPasswordAndName(opts: {
  userId: string;
  email: string;
  fullName: string;
  password: string;
}): Promise<"ok" | "exists"> {
  const hash = await hashPassword(opts.password);
  const organisationId = await accountOrganisationId(opts.userId);
  return db.transaction(async (tx) => {
    const [created] = await tx
      .insert(authAccount)
      .values({
        userId: opts.userId,
        accountId: opts.userId,
        providerId: "credential",
        password: hash,
      })
      .onConflictDoNothing({ target: [authAccount.providerId, authAccount.accountId] })
      .returning({ id: authAccount.id });
    if (!created) return "exists" as const;
    await tx
      .update(users)
      .set({ fullName: opts.fullName.trim(), emailVerified: true, updatedAt: new Date() })
      .where(eq(users.id, opts.userId));
    await writeAudit(tx, {
      organisationId,
      actorUserId: opts.userId,
      entityType: "user",
      entityId: opts.userId,
      action: "login",
      summary: `${normaliseEmail(opts.email)} set up their account`,
      subjectUserId: opts.userId,
      subjectEmail: opts.email,
    });
    return "ok" as const;
  });
}

/** The person's password hash, or null when they have none yet. */
async function currentHash(userId: string): Promise<string | null> {
  const [row] = await db
    .select({ password: authAccount.password })
    .from(authAccount)
    .where(and(eq(authAccount.userId, userId), eq(authAccount.providerId, "credential")))
    .limit(1);
  return row?.password ?? null;
}

/** Does this person have a password yet? (My account wording, /auth/accept.) */
export async function hasPassword(userId: string): Promise<boolean> {
  return Boolean(await currentHash(userId));
}

/**
 * Change your own password: checks the current one (when there is one),
 * saves the new one, and signs out every other session — in one transaction
 * with the audit row. The session making the change (keepToken) stays.
 */
export async function changeOwnPassword(opts: {
  userId: string;
  organisationId: string | null;
  currentPassword: string | null;
  newPassword: string;
  keepToken: string;
}): Promise<"ok" | "wrong_current"> {
  const existing = await currentHash(opts.userId);
  if (existing) {
    const ok = await verifyPassword({ hash: existing, password: opts.currentPassword ?? "" });
    if (!ok) return "wrong_current";
  }
  const hash = await hashPassword(opts.newPassword);
  await db.transaction(async (tx) => {
    await upsertPasswordTx(tx, opts.userId, hash);
    const ended = await tx
      .delete(authSession)
      .where(and(eq(authSession.userId, opts.userId), ne(authSession.token, opts.keepToken)))
      .returning({ id: authSession.id });
    await writeAudit(tx, {
      organisationId: opts.organisationId,
      actorUserId: opts.userId,
      entityType: "user",
      entityId: opts.userId,
      action: "settings_change",
      summary: "Password changed",
      after: { sessionsEnded: ended.length },
      subjectUserId: opts.userId,
    });
  });
  return "ok";
}

/**
 * A password reset by emailed link, in one transaction: the link's token is
 * used up (only if it is still valid), the password saved, every session
 * ended, and the audit row written. "expired" when the token was already used
 * or has run out. (better-auth 1.7.7's own resetPassword does these steps
 * one by one, outside a transaction: DECISIONS.md.)
 */
export async function resetPasswordWithVerification(opts: {
  verificationId: string;
  userId: string;
  email: string;
  password: string;
}): Promise<"ok" | "expired"> {
  const hash = await hashPassword(opts.password);
  const organisationId = await accountOrganisationId(opts.userId);
  return db.transaction(async (tx) => {
    const [used] = await tx
      .delete(authVerification)
      .where(
        and(
          eq(authVerification.id, opts.verificationId),
          eq(authVerification.value, opts.userId),
          gt(authVerification.expiresAt, new Date()),
        ),
      )
      .returning({ id: authVerification.id });
    if (!used) return "expired" as const;
    await upsertPasswordTx(tx, opts.userId, hash);
    const sessionsEnded = await revokeSessionsTx(tx, opts.userId);
    await writeAudit(tx, {
      organisationId,
      actorUserId: opts.userId,
      entityType: "user",
      entityId: opts.userId,
      action: "settings_change",
      summary: "Password changed (reset link)",
      after: { sessionsEnded },
      subjectUserId: opts.userId,
      subjectEmail: opts.email,
    });
    return "ok" as const;
  });
}
