"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, inArray, isNull, ne } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { editions, signageItems } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { submitForReview, softDeleteSignageItem } from "./signage";

const schema = z.object({
  ids: z.array(z.string().uuid()).min(1),
  action: z.enum(["set_supplier", "set_install", "submit", "delete"]),
  supplierId: z.string().uuid().optional().nullable(),
  installDate: z.string().date().optional().nullable(),
  installSlot: z.enum(["am", "pm", "overnight"]).optional().nullable(),
});

export async function bulkSignageAction(input: unknown): Promise<ActionResult<{ done: number; failed: number }>> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return fail("Invalid bulk action");
  const session = await requireSession();
  const { ids, action } = parsed.data;

  if (action === "submit") {
    let done = 0;
    let failed = 0;
    for (const id of ids) {
      const res = await submitForReview({ id });
      if (res.ok) done += 1;
      else failed += 1;
    }
    return success({ done, failed }, `${done} submitted${failed ? `, ${failed} could not be` : ""}`);
  }
  if (action === "delete") {
    if (!can(session.actor, { type: "signage.delete" })) return fail("You cannot delete items");
    let done = 0;
    let failed = 0;
    for (const id of ids) {
      const res = await softDeleteSignageItem({ id });
      if (res.ok) done += 1;
      else failed += 1;
    }
    return success({ done, failed }, `${done} deleted${failed ? `, ${failed} could not be` : ""}`);
  }

  // Field updates: supplier / install date + slot.
  if (!can(session.actor, { type: "costs.edit" }) && action === "set_supplier") {
    return fail("You cannot set suppliers");
  }
  const set: Partial<typeof signageItems.$inferInsert> = {};
  if (action === "set_supplier") set.supplierId = parsed.data.supplierId ?? null;
  if (action === "set_install") {
    set.installDate = parsed.data.installDate ?? null;
    set.installSlot = parsed.data.installSlot ?? null;
  }
  await db.transaction(async (tx) => {
    await tx
      .update(signageItems)
      .set(set)
      .where(
        and(
          inArray(signageItems.id, ids),
          isNull(signageItems.deletedAt),
          // Archived editions are read-only; their items are silently excluded.
          inArray(
            signageItems.editionId,
            tx.select({ id: editions.id }).from(editions).where(ne(editions.status, "archived")),
          ),
        ),
      );
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      actorUserId: session.user.id,
      entityType: "signage_item",
      action: "update",
      after: { ids, ...set },
      summary: `Bulk ${action.replace("_", " ")} on ${ids.length} item(s)`,
    });
  });
  revalidatePath("/", "layout");
  return success({ done: ids.length, failed: 0 }, `${ids.length} item(s) updated`);
}
