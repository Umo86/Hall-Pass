"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, count, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  editions,
  events,
  externalGrants,
  signageItems,
  sponsorEntitlements,
  sponsors,
} from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";

const optText = z
  .string()
  .trim()
  .max(300)
  .optional()
  .nullable()
  .transform((v) => (v ? v : null));

const schema = z.object({
  editionId: z.string().uuid(),
  id: z.string().uuid().optional(),
  companyName: z.string().trim().min(1, "Enter the sponsor's name").max(200),
  contactName: optText,
  contactEmail: z
    .string()
    .trim()
    .optional()
    .nullable()
    .transform((v) => (v ? v : null))
    .refine((v) => v === null || z.string().email().safeParse(v).success, "Enter a valid email"),
  packageName: optText,
  /** One entitlement per line, e.g. "6 x Logo on hanging banners". */
  entitlements: z.string().max(5000).optional().default(""),
});

/** "6 x Logo on banners" → { quantity: 6, description: "Logo on banners" }. */
function parseEntitlements(text: string) {
  return text
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const m = line.match(/^(\d+)\s*[x×]\s*(.+)$/i);
      return m
        ? { quantity: Math.max(1, Number(m[1])), description: m[2].trim() }
        : { quantity: 1, description: line };
    });
}

/**
 * Add or edit a sponsor for a show. New entitlement lines are added;
 * existing ones are edited or removed one by one (updateEntitlement,
 * removeEntitlement), since items may be linked to them.
 */
export async function saveSponsor(input: unknown): Promise<ActionResult<{ id: string }>> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "sponsorship.create" })) {
    return fail("You cannot manage sponsors");
  }
  const data = parsed.data;
  const [row] = await db
    .select({ edition: editions })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(editions.id, data.editionId), eq(events.organisationId, session.organisation.id)))
    .limit(1);
  if (!row) return fail("Event not found");
  if (editionIsReadOnly(row.edition.status)) return fail(EDITION_LOCKED_MESSAGE);

  const values = {
    companyName: data.companyName,
    contactName: data.contactName,
    contactEmail: data.contactEmail,
    packageName: data.packageName,
  };
  let savedId: string;
  try {
    savedId = await db.transaction(async (tx) => {
      let sponsorId = data.id;
      if (sponsorId) {
        const updated = await tx
          .update(sponsors)
          .set(values)
          .where(and(eq(sponsors.id, sponsorId), eq(sponsors.editionId, row.edition.id)))
          .returning({ id: sponsors.id });
        if (updated.length === 0) throw new Error("Sponsor not found");
      } else {
        const [created] = await tx
          .insert(sponsors)
          .values({ ...values, editionId: row.edition.id })
          .returning({ id: sponsors.id });
        sponsorId = created.id;
      }
      const existing = await tx
        .select({ description: sponsorEntitlements.description })
        .from(sponsorEntitlements)
        .where(eq(sponsorEntitlements.sponsorId, sponsorId));
      const known = new Set(existing.map((e) => e.description.toLowerCase()));
      const fresh = parseEntitlements(data.entitlements).filter(
        (e) => !known.has(e.description.toLowerCase()),
      );
      if (fresh.length > 0) {
        await tx
          .insert(sponsorEntitlements)
          .values(fresh.map((e) => ({ ...e, sponsorId: sponsorId! })));
      }
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: row.edition.id,
        actorUserId: session.user.id,
        entityType: "sponsor",
        entityId: sponsorId,
        action: data.id ? "update" : "create",
        after: { ...values, newEntitlements: fresh.length },
        summary: `${data.id ? "Updated" : "Added"} sponsor ${data.companyName}`,
      });
      return sponsorId;
    });
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
  revalidatePath(`/${row.edition.code}`, "layout");
  return success(
    { id: savedId },
    data.id ? `${data.companyName} saved` : `${data.companyName} added`,
  );
}

type Found =
  | { error: string; sponsor?: never; edition?: never }
  | {
      error?: never;
      sponsor: typeof sponsors.$inferSelect;
      edition: typeof editions.$inferSelect;
    };

/** A sponsor of one of this organisation's events, if it may be changed now. */
async function ownSponsor(sponsorId: string, organisationId: string): Promise<Found> {
  const [row] = await db
    .select({ sponsor: sponsors, edition: editions })
    .from(sponsors)
    .innerJoin(editions, eq(sponsors.editionId, editions.id))
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(sponsors.id, sponsorId), eq(events.organisationId, organisationId)))
    .limit(1);
  if (!row) return { error: "Sponsor not found" };
  if (editionIsReadOnly(row.edition.status)) return { error: EDITION_LOCKED_MESSAGE };
  return row;
}

/** How many items (deleted ones too — they still point at it) use an entitlement. */
async function itemsOnEntitlement(entitlementId: string): Promise<number> {
  const [{ n }] = await db
    .select({ n: count() })
    .from(signageItems)
    .where(eq(signageItems.sponsorEntitlementId, entitlementId));
  return Number(n);
}

const entitlementSchema = z.object({
  entitlementId: z.string().uuid(),
  description: z.string().trim().min(1, "Say what they get").max(300),
  quantity: z.coerce.number().int().min(1, "At least 1").max(100_000),
});

async function loadEntitlement(entitlementId: string, organisationId: string) {
  const [ent] = await db
    .select()
    .from(sponsorEntitlements)
    .where(eq(sponsorEntitlements.id, entitlementId))
    .limit(1);
  if (!ent) return { error: "Entitlement not found" } as const;
  const found = await ownSponsor(ent.sponsorId, organisationId);
  if (found.error !== undefined) return { error: found.error } as const;
  return { ent, ...found } as const;
}

/** Correct what a sponsor is entitled to (a typo, a changed quantity). */
export async function updateEntitlement(input: unknown): Promise<ActionResult> {
  const parsed = entitlementSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "sponsorship.create" })) {
    return fail("You cannot manage sponsors");
  }
  const found = await loadEntitlement(parsed.data.entitlementId, session.organisation.id);
  if (found.error !== undefined) return fail(found.error);
  const { ent, sponsor, edition } = found;
  const after = { description: parsed.data.description, quantity: parsed.data.quantity };
  await db.transaction(async (tx) => {
    await tx.update(sponsorEntitlements).set(after).where(eq(sponsorEntitlements.id, ent.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: edition.id,
      actorUserId: session.user.id,
      entityType: "sponsor",
      entityId: sponsor.id,
      action: "update",
      before: { entitlementId: ent.id, description: ent.description, quantity: ent.quantity },
      after: { entitlementId: ent.id, ...after },
      summary: `Changed ${sponsor.companyName}'s entitlement to ${after.quantity > 1 ? `${after.quantity} × ` : ""}${after.description}`,
    });
  });
  revalidatePath(`/${edition.code}`, "layout");
  return success(undefined, `${sponsor.companyName}: entitlement saved`);
}

/** Remove an entitlement nothing is linked to. */
export async function removeEntitlement(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ entitlementId: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "sponsorship.create" })) {
    return fail("You cannot manage sponsors");
  }
  const found = await loadEntitlement(parsed.data.entitlementId, session.organisation.id);
  if (found.error !== undefined) return fail(found.error);
  const { ent, sponsor, edition } = found;
  const linked = await itemsOnEntitlement(ent.id);
  if (linked > 0) {
    return fail(
      `${linked} item${linked === 1 ? " counts" : "s count"} towards it — change ${linked === 1 ? "that item" : "those items"} first`,
    );
  }
  await db.transaction(async (tx) => {
    await tx.delete(sponsorEntitlements).where(eq(sponsorEntitlements.id, ent.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: edition.id,
      actorUserId: session.user.id,
      entityType: "sponsor",
      entityId: sponsor.id,
      action: "update",
      before: { entitlementId: ent.id, description: ent.description, quantity: ent.quantity },
      after: { entitlementId: ent.id, removed: true },
      summary: `Removed entitlement "${ent.description}" from ${sponsor.companyName}`,
    });
  });
  revalidatePath(`/${edition.code}`, "layout");
  return success(undefined, `Removed "${ent.description}" from ${sponsor.companyName}`);
}

/**
 * Remove a sponsor added by mistake: only while nothing points at them —
 * no items (deleted ones included) and no live portal access.
 */
export async function removeSponsor(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ sponsorId: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "sponsorship.create" })) {
    return fail("You cannot manage sponsors");
  }
  const found = await ownSponsor(parsed.data.sponsorId, session.organisation.id);
  if (found.error !== undefined) return fail(found.error);
  const { sponsor, edition } = found;
  const [[items], [grants]] = await Promise.all([
    db.select({ n: count() }).from(signageItems).where(eq(signageItems.sponsorId, sponsor.id)),
    db
      .select({ n: count() })
      .from(externalGrants)
      .where(
        and(
          eq(externalGrants.scopeType, "sponsor"),
          eq(externalGrants.scopeId, sponsor.id),
          isNull(externalGrants.revokedAt),
        ),
      ),
  ]);
  if (Number(items.n) > 0) {
    return fail(
      `${sponsor.companyName} has ${Number(items.n)} item${Number(items.n) === 1 ? "" : "s"} (including any deleted) — they can't be removed`,
    );
  }
  if (Number(grants.n) > 0) {
    return fail(
      `${sponsor.companyName} has portal access — remove it under Users → External first`,
    );
  }
  const ents = await db
    .select()
    .from(sponsorEntitlements)
    .where(eq(sponsorEntitlements.sponsorId, sponsor.id));
  await db.transaction(async (tx) => {
    await tx.delete(sponsorEntitlements).where(eq(sponsorEntitlements.sponsorId, sponsor.id));
    await tx.delete(sponsors).where(eq(sponsors.id, sponsor.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: edition.id,
      actorUserId: session.user.id,
      entityType: "sponsor",
      entityId: sponsor.id,
      action: "update",
      after: { removed: true },
      before: {
        companyName: sponsor.companyName,
        contactName: sponsor.contactName,
        contactEmail: sponsor.contactEmail,
        packageName: sponsor.packageName,
        entitlements: ents.map((e) => ({ description: e.description, quantity: e.quantity })),
      },
      summary: `Removed sponsor ${sponsor.companyName}`,
    });
  });
  revalidatePath(`/${edition.code}`, "layout");
  return success(undefined, `Removed ${sponsor.companyName}`);
}
