"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq, inArray } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { changeRequests, memberships, signageItems, type FieldChange } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { INVALIDATABLE_STATUSES, signageTransition } from "@/lib/status/signage";
import { invalidateOnNewVersion } from "@/lib/workflow";
import { loadRun, persistRun } from "@/lib/workflow/persist";
import { itemAuthzCtx, itemEntityCtx, loadItemBundle } from "@/lib/domain/signage";
import { notify } from "@/lib/notify";

/**
 * Change requests (brief §5): once an item is locked by approvals, edits go
 * through a request that ops approve — approving applies the field changes
 * and, on a decided run, invalidates the affected steps (never silently).
 */

// Fields that change what was signed off; dates and the name do not.
const SPEC_FIELDS = new Set(["widthMm", "heightMm", "depthMm", "quantity", "material", "finish"]);

// Only plain, safely-applicable columns can change through a request.
const CHANGEABLE = z.object({
  name: z.string().min(1).max(300).optional(),
  widthMm: z.number().int().positive().nullable().optional(),
  heightMm: z.number().int().positive().nullable().optional(),
  depthMm: z.number().int().positive().nullable().optional(),
  quantity: z.number().int().positive().optional(),
  material: z.string().max(200).nullable().optional(),
  finish: z.string().max(200).nullable().optional(),
  installDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(),
  deliveryDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(),
});

// Before sign-off the item is edited directly; requests are for locked items.
const NOT_YET_SIGNED_OFF = ["draft", "awaiting_artwork", "in_review", "changes_requested"];

const raiseSchema = z.object({
  itemId: z.string().uuid(),
  reason: z.string().min(5, "Give a reason (at least a sentence)").max(2000),
  changes: CHANGEABLE.default({}),
});

export async function raiseChangeRequest(input: unknown): Promise<ActionResult> {
  const parsed = raiseSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "change_request.raise" })) {
    return fail("You cannot raise change requests");
  }
  const bundle = await loadItemBundle(db, parsed.data.itemId);
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (NOT_YET_SIGNED_OFF.includes(bundle.item.status)) {
    return fail("This item isn't signed off yet — change it directly on the Details tab");
  }
  if (bundle.item.kind !== "signage" && parsed.data.changes.installDate !== undefined) {
    return fail("Sponsorship items have no install date");
  }

  const item = bundle.item as unknown as Record<string, unknown>;
  const fieldChanges: FieldChange[] = Object.entries(parsed.data.changes)
    .filter(([field, to]) => to !== undefined && item[field] !== to)
    .map(([field, to]) => ({ field, from: item[field] ?? null, to: to ?? null }));

  try {
    await db.transaction(async (tx) => {
      const [row] = await tx
        .insert(changeRequests)
        .values({
          entityType: "signage_item",
          entityId: bundle.item.id,
          requestedBy: session.user.id,
          reason: parsed.data.reason,
          fieldChanges,
        })
        .returning();
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: "change_request",
        entityId: row.id,
        action: "create",
        after: { itemRef: bundle.item.ref, reason: parsed.data.reason, fieldChanges },
        summary: `Change request raised on ${bundle.item.ref}`,
      });
      const deciders = await tx
        .select({ userId: memberships.userId })
        .from(memberships)
        .where(
          and(
            eq(memberships.organisationId, session.organisation.id),
            inArray(memberships.role, ["admin", "ops"]),
          ),
        );
      await notify(tx, {
        userIds: deciders.map((u) => u.userId).filter((id) => id !== session.user.id),
        kind: "change_request",
        title: `Change request on ${bundle.item.ref}`,
        body: parsed.data.reason,
        link: `/${bundle.edition.code}/signage/${bundle.item.ref}?tab=changes`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, "Change request raised — ops will review it");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}

const decideSchema = z.object({
  id: z.string().uuid(),
  decision: z.enum(["approve", "reject"]),
  comment: z.string().max(2000).optional(),
});

export async function decideChangeRequest(input: unknown): Promise<ActionResult> {
  const parsed = decideSchema.safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  if (parsed.data.decision === "reject" && (parsed.data.comment?.trim().length ?? 0) < 5) {
    return fail("Say why you're rejecting it (at least a few words) — the requester sees this");
  }
  const session = await requireSession();
  if (!can(session.actor, { type: "change_request.approve" })) {
    return fail("Only admin or ops can decide change requests");
  }
  const [cr] = await db.select().from(changeRequests).where(eq(changeRequests.id, parsed.data.id));
  if (!cr || cr.entityType !== "signage_item") return fail("Change request not found");
  if (cr.status !== "open") return fail("This change request is already decided");
  const bundle = await loadItemBundle(db, cr.entityId);
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "signage.edit", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot change this item");
  }

  const touchesItem = cr.fieldChanges.some((c) => Object.hasOwn(CHANGEABLE.shape, c.field));
  if (parsed.data.decision === "approve" && touchesItem && bundle.item.status === "on_hold") {
    return fail("Resume the item before applying changes");
  }

  try {
    let message = "Change request rejected";
    await db.transaction(async (tx) => {
      const now = new Date();
      // Claim the request first: only one decision can ever apply it.
      const claimed = await tx
        .update(changeRequests)
        .set({
          status: parsed.data.decision === "reject" ? "rejected" : "approved",
          decidedBy: session.user.id,
          decidedAt: now,
        })
        .where(and(eq(changeRequests.id, cr.id), eq(changeRequests.status, "open")))
        .returning({ id: changeRequests.id });
      if (claimed.length === 0) throw new Error("This change request was already decided");
      if (parsed.data.decision === "approve") {
        // Apply the whitelisted field changes.
        const set: Record<string, unknown> = {};
        for (const change of cr.fieldChanges) {
          if (Object.hasOwn(CHANGEABLE.shape, change.field)) set[change.field] = change.to;
        }
        let reopenedIds: string[] = [];
        let status = bundle.item.status;
        const specChanged = Object.keys(set).some((f) => SPEC_FIELDS.has(f));
        if (specChanged && INVALIDATABLE_STATUSES.includes(status)) {
          // Same rule as new artwork: decided steps that invalidate reopen.
          const run = await loadRun(tx, "signage_item", bundle.item.id, bundle.item.currentRunNumber);
          const res = invalidateOnNewVersion(run, { entity: itemEntityCtx(bundle), now });
          await persistRun(tx, "signage_item", bundle.item.id, res.instances);
          reopenedIds = res.invalidated.map((i) => i.id);
          status = signageTransition(status, "new_version_after_approval");
          set.status = status;
          for (const inst of res.invalidated) {
            await notify(tx, {
              userIds: inst.decidedBy ? [inst.decidedBy] : [],
              kind: "approval_invalidated",
              title: `Approved change reopens your sign-off — ${bundle.item.ref}`,
              body: `${inst.stepName}: the item's spec changed after your decision and needs re-approval.`,
              link: `/${bundle.edition.code}/signage/${bundle.item.ref}?tab=approvals`,
            });
          }
        }
        if (Object.keys(set).length > 0) {
          await tx.update(signageItems).set(set).where(eq(signageItems.id, bundle.item.id));
          // Item-level history so the item's History tab shows the change.
          const item = bundle.item as unknown as Record<string, unknown>;
          await writeAudit(tx, {
            organisationId: session.organisation.id,
            editionId: bundle.edition.id,
            actorUserId: session.user.id,
            entityType: "signage_item",
            entityId: bundle.item.id,
            action: "update",
            before: Object.fromEntries(Object.keys(set).map((k) => [k, item[k] ?? null])),
            after: set,
            summary: `Change request applied to ${bundle.item.ref} (${Object.keys(set)
              .filter((k) => k !== "status")
              .join(", ")})`,
          });
        }
        await tx
          .update(changeRequests)
          .set({
            status: cr.fieldChanges.length > 0 ? "applied" : "approved",
            reopenedInstanceIds: reopenedIds,
          })
          .where(eq(changeRequests.id, cr.id));
        message =
          reopenedIds.length > 0
            ? `Changes applied — ${reopenedIds.length} approval(s) reopened`
            : "Changes applied";
      }
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: "change_request",
        entityId: cr.id,
        action: "decide",
        after: { itemRef: bundle.item.ref, comment: parsed.data.comment ?? null },
        summary: `Change request ${parsed.data.decision === "approve" ? "accepted" : "rejected"} on ${bundle.item.ref}${parsed.data.comment ? `: ${parsed.data.comment}` : ""}`,
      });
      await notify(tx, {
        userIds: [cr.requestedBy],
        kind: "change_request",
        title: `Your change request on ${bundle.item.ref} was ${parsed.data.decision === "approve" ? "accepted" : "rejected"}`,
        body: parsed.data.comment,
        link: `/${bundle.edition.code}/signage/${bundle.item.ref}?tab=changes`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, message);
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}
