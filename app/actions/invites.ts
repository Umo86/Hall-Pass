"use server";

import { appUrl } from "@/lib/app-url";
import { randomUUID } from "node:crypto";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";
import { and, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { externalGrants, users } from "@/lib/db/schema";
import { writeAudit } from "@/lib/audit";
import { DEV_COOKIE, devAuthEnabled, getSession } from "@/lib/auth/actor";
import { createSupabaseServerClient } from "@/lib/auth/supabase-server";
import { hashInviteToken } from "@/lib/auth/invite-token";

export type InviteResult = { ok: true; message?: string } | { ok: false; error: string };

const acceptSchema = z.object({
  token: z.string().min(10),
  fullName: z.string().trim().min(1, "Enter your name").max(200),
});

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

export async function inviteDetails(token: string) {
  const res = await findValidGrant(token);
  if (res.error !== undefined) return { ok: false as const, error: res.error };
  return {
    ok: true as const,
    invitedEmail: res.grant.invitedEmail,
    role: res.grant.role,
    accepted: Boolean(res.grant.acceptedAt),
  };
}

/** Accept an external grant: set name, link the user, land in the portal. */
export async function acceptInvite(input: unknown): Promise<InviteResult> {
  const parsed = acceptSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  const { token, fullName } = parsed.data;
  const res = await findValidGrant(token);
  if (res.error !== undefined) return { ok: false, error: res.error };
  const grant = res.grant;

  const session = await getSession();

  if (session) {
    if (session.user.email.toLowerCase() !== grant.invitedEmail.toLowerCase()) {
      return { ok: false, error: "This invitation was sent to a different email address." };
    }
    await claimGrant(grant.id, session.user.id, fullName);
    redirect("/portal/approvals");
  }

  if (devAuthEnabled()) {
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

  // Production: send a magic link to the invited address; the grant is
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
