"use server";

import { appUrl } from "@/lib/app-url";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  editions,
  events,
  exhibitors,
  externalGrants,
  sponsors,
  suppliers,
  venues,
} from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { generateInviteToken, hashInviteToken } from "@/lib/auth/invite-token";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { deliverInvite } from "@/lib/auth/staff-invite";
import { roleLabel } from "@/lib/format";

const inviteSchema = z.object({
  email: z.string().email(),
  editionId: z.string().uuid(),
  role: z.enum([
    "venue",
    "structural_engineer",
    "hs",
    "supplier",
    "exhibitor",
    "contractor",
    "sponsor",
  ]),
  scopeType: z.enum(["venue", "supplier", "exhibitor", "sponsor"]).optional().nullable(),
  scopeId: z.string().uuid().optional().nullable(),
  expiresAt: z.string().date().optional().nullable(),
});

/** Invite an external party; returns the invite link to share. */
export async function inviteExternal(input: unknown): Promise<ActionResult<{ inviteUrl: string }>> {
  const parsed = inviteSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) {
    return fail("Only admins manage external access");
  }
  const data = parsed.data;
  const orgId = session.organisation.id;
  const [edition] = await db
    .select({ id: editions.id })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(editions.id, data.editionId), eq(events.organisationId, orgId)))
    .limit(1);
  if (!edition) return fail("Edition not found");
  // The scope must be this organisation's, and for sponsors/exhibitors this show's.
  if (data.scopeType) {
    if (!data.scopeId) return fail("Choose who this invitation is for");
    const id = data.scopeId;
    const found =
      data.scopeType === "venue"
        ? await db.query.venues.findFirst({
            where: and(eq(venues.id, id), eq(venues.organisationId, orgId)),
          })
        : data.scopeType === "supplier"
          ? await db.query.suppliers.findFirst({
              where: and(eq(suppliers.id, id), eq(suppliers.organisationId, orgId)),
            })
          : data.scopeType === "sponsor"
            ? await db.query.sponsors.findFirst({
                where: and(eq(sponsors.id, id), eq(sponsors.editionId, data.editionId)),
              })
            : await db.query.exhibitors.findFirst({
                where: and(eq(exhibitors.id, id), eq(exhibitors.editionId, data.editionId)),
              });
    if (!found) return fail("That choice doesn't belong to this show");
  }
  const token = generateInviteToken();
  try {
    const grantId = await db.transaction(async (tx) => {
      const [grant] = await tx
        .insert(externalGrants)
        .values({
          invitedEmail: data.email.toLowerCase(),
          organisationId: session.organisation.id,
          editionId: data.editionId,
          role: data.role,
          scopeType: data.scopeType ?? null,
          scopeId: data.scopeId ?? null,
          expiresAt: data.expiresAt ? new Date(`${data.expiresAt}T23:59:59Z`) : null,
          invitedBy: session.user.id,
          inviteTokenHash: hashInviteToken(token),
        })
        .returning();
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: data.editionId,
        actorUserId: session.user.id,
        entityType: "external_grant",
        entityId: grant.id,
        action: "invite",
        after: { email: data.email, role: data.role, scopeType: data.scopeType },
        summary: `Invited ${data.email} as ${data.role}`,
      });
      return grant.id;
    });
    const inviteUrl = `${appUrl()}/invite/${token}`;
    const delivery = await deliverInvite({
      email: data.email,
      inviterName: session.user.fullName || session.user.email,
      reason: `You've been given access to ${session.organisation.brandName} as ${roleLabel(data.role)}.`,
      inviteUrl,
      inviteId: grantId,
    });
    revalidatePath("/settings");
    return delivery.emailed
      ? success({ inviteUrl: "" }, `Invitation emailed to ${data.email}`)
      : success(
          { inviteUrl: delivery.fallbackUrl! },
          "Invitation created — email isn't set up here, so send them this link yourself",
        );
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}

export async function revokeGrant(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ grantId: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) {
    return fail("Only admins manage external access");
  }
  await db.transaction(async (tx) => {
    const [grant] = await tx
      .update(externalGrants)
      .set({ revokedAt: new Date() })
      .where(
        and(
          eq(externalGrants.id, parsed.data.grantId),
          eq(externalGrants.organisationId, session.organisation.id),
        ),
      )
      .returning();
    if (!grant) return;
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: grant?.editionId,
      actorUserId: session.user.id,
      entityType: "external_grant",
      entityId: parsed.data.grantId,
      action: "grant_revoke",
      summary: `Revoked external access for ${grant?.invitedEmail ?? "unknown"}`,
    });
  });
  revalidatePath("/settings");
  return success(undefined, "Access revoked — effective immediately");
}
