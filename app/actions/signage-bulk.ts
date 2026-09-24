"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { signageItems } from "@/lib/db/schema";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { editionIsReadOnly } from "@/lib/edition-lock";
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
  if (session.actor.kind !== "staff") return fail("Not permitted");
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

  // Field updates (supplier / install date + slot): checked and recorded
  // item by item, so each item's History shows the change.
  if (action === "set_supplier" && !can(session.actor, { type: "costs.edit" })) {
    return fail("You cannot set suppliers");
  }
  const set: Partial<typeof signageItems.$inferInsert> = {};
  if (action === "set_supplier") set.supplierId = parsed.data.supplierId ?? null;
  if (action === "set_install") {
    set.installDate = parsed.data.installDate ?? null;
    set.installSlot = parsed.data.installSlot ?? null;
  }
  let done = 0;
  let failed = 0;
  for (const id of ids) {
    try {
      const bundle = await loadItemBundle(db, id);
      if (
        !bundle ||
        bundle.item.deletedAt ||
        bundle.organisation.id !== session.organisation.id ||
        editionIsReadOnly(bundle.edition.status) ||
        !can(session.actor, { type: "signage.edit", item: itemAuthzCtx(bundle) }) ||
        (action === "set_install" && bundle.item.kind !== "signage")
      ) {
        failed += 1;
        continue;
      }
      const item = bundle.item as unknown as Record<string, unknown>;
      await db.transaction(async (tx) => {
        await tx.update(signageItems).set(set).where(eq(signageItems.id, id));
        await writeAudit(tx, {
          organisationId: session.organisation.id,
          editionId: bundle.edition.id,
          actorUserId: session.user.id,
          entityType: "signage_item",
          entityId: id,
          action: "update",
          before: Object.fromEntries(Object.keys(set).map((k) => [k, item[k] ?? null])),
          after: set,
          summary: `${bundle.item.ref}: ${action === "set_supplier" ? "supplier" : "install date"} changed (bulk)`,
        });
      });
      done += 1;
    } catch (err) {
      console.error("bulk update", id, err);
      failed += 1;
    }
  }
  revalidatePath("/", "layout");
  return success(
    { done, failed },
    `${done} item(s) updated${failed ? `, ${failed} could not be (no permission, locked or deleted)` : ""}`,
  );
}
