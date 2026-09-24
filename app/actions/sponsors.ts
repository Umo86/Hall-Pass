"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { editions, events, sponsorEntitlements, sponsors } from "@/lib/db/schema";
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
 * existing ones are kept (items may already be linked to them).
 */
export async function saveSponsor(input: unknown): Promise<ActionResult> {
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
  if (!row) return fail("Edition not found");
  if (editionIsReadOnly(row.edition.status)) return fail(EDITION_LOCKED_MESSAGE);

  const values = {
    companyName: data.companyName,
    contactName: data.contactName,
    contactEmail: data.contactEmail,
    packageName: data.packageName,
  };
  try {
    await db.transaction(async (tx) => {
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
    });
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
  revalidatePath(`/${row.edition.code}`, "layout");
  return success(undefined, "Sponsor saved");
}
