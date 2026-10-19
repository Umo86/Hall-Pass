"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq, isNull, sql } from "drizzle-orm";
import { db, type Tx } from "@/lib/db/client";
import { locations, signageItems } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession, type Session } from "@/lib/auth/actor";
import { actorScope } from "@/lib/queries/edition-scope";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { notify } from "@/lib/notify";
import {
  assertItemLinks,
  defaultSignageWorkflowId,
  itemAuthzCtx,
  loadItemBundle,
  normaliseSignoffs,
  notifyOwnerChange,
  ownEdition,
  resolveItemCreationRecipients,
} from "@/lib/domain/signage";
import { checkPick, ownerRoleOf } from "@/lib/people";
import {
  ensureStandDesignWorkflow,
  mapPlanToWorkflow,
  panelSyncPatch,
} from "@/lib/domain/stand-designs";
import type { SignoffPlan } from "@/lib/workflow/types";
import { loadStepDefs } from "@/lib/workflow/persist";
import { formatStandPanelRef, nextStandDesignRef, nextStandItemSeq } from "@/lib/refs";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { itemPath } from "@/lib/edition-path";
import { plural } from "@/lib/format";
import { updateSignageItem } from "./signage";

const mm = z.coerce.number().int().positive().max(100_000).optional().nullable();
const uuidOrNull = z.string().uuid().optional().nullable();

const planSchema = z.preprocess(
  (v) => {
    if (typeof v !== "string") return v;
    if (!v) return null;
    try {
      return JSON.parse(v);
    } catch {
      return "invalid";
    }
  },
  z
    .array(z.object({ stepId: z.string().uuid(), userId: z.string().uuid().nullable() }))
    .max(20)
    .nullable(),
);

const standSchema = z
  .object({
    editionId: z.string().uuid(),
    name: z.string().trim().min(1, "Give the stand a name").max(300),
    standNumber: z.string().trim().max(50).optional().nullable(),
    hallId: uuidOrNull,
    locationId: uuidOrNull,
    widthMm: mm,
    depthMm: mm,
    heightMm: mm,
    category: z.enum(["organiser", "sponsor"]).default("organiser"),
    sponsorId: uuidOrNull,
    description: z.string().max(5000).optional().nullable(),
    signoffs: planSchema,
    /** Who runs the stand (default: whoever creates it); its panels follow. */
    ownerUserId: uuidOrNull,
  })
  .superRefine((d, ctx) => {
    if (d.category === "sponsor" && !d.sponsorId) {
      ctx.addIssue({ code: "custom", path: ["sponsorId"], message: "Choose the sponsor" });
    }
    if (!d.signoffs || d.signoffs.length === 0) {
      ctx.addIssue({
        code: "custom",
        path: ["signoffs"],
        message: "Choose at least one department to approve the design",
      });
    }
  });

const panelSchema = z.object({
  standId: z.string().uuid(),
  name: z.string().trim().min(1, "Name the panel").max(300),
  widthMm: z.coerce.number().int().positive("Enter the width").max(100_000),
  heightMm: z.coerce.number().int().positive("Enter the height").max(100_000),
  quantity: z.coerce.number().int().positive().max(10_000).default(1),
  material: z.string().trim().max(200).optional().nullable(),
  finish: z.string().trim().max(200).optional().nullable(),
  supplierId: uuidOrNull,
  description: z.string().max(5000).optional().nullable(),
});

function fieldErrors(error: z.ZodError): Record<string, string> {
  const out: Record<string, string> = {};
  for (const issue of error.issues) out[issue.path.join(".")] ??= issue.message;
  return out;
}

async function hallOfLocation(locationId: string): Promise<string | null> {
  const [row] = await db
    .select({ hallId: locations.hallId })
    .from(locations)
    .where(eq(locations.id, locationId))
    .limit(1);
  return row?.hallId ?? null;
}

/**
 * A new stand to design: where it is, how big, and who approves the design
 * (departments and, if wanted, a named person in each). Admins and
 * operations only.
 */
export async function createStandDesign(input: unknown): Promise<ActionResult<{ ref: string }>> {
  const parsed = standSchema.safeParse(input);
  if (!parsed.success) return fail("Check the highlighted fields", fieldErrors(parsed.error));
  const session = await requireSession();
  if (!can(session.actor, { type: "stand_design.create" })) {
    return fail("Only Operations and super admins set up stands");
  }
  const data = parsed.data;
  if (!(await ownEdition(db, session.organisation.id, data.editionId, session.actor))) {
    return fail("Event not found");
  }
  try {
    await assertItemLinks(db, {
      organisationId: session.organisation.id,
      editionId: data.editionId,
      links: {
        hallId: data.hallId,
        locationId: data.locationId,
        sponsorId: data.category === "sponsor" ? data.sponsorId : null,
      },
    });
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Check the linked records");
  }
  const hallId = data.locationId
    ? ((await hallOfLocation(data.locationId)) ?? data.hallId)
    : data.hallId;
  // Another owner must be able to work on feature stands (lib/people.ts).
  let owner: { id: string; name: string; role: "ops" | "marketing" | null } | null = null;
  if (data.ownerUserId && data.ownerUserId !== session.user.id) {
    const res = await checkPick(db, session.organisation.id, data.ownerUserId, {
      type: "owner",
      item: { kind: "stand_design", sponsored: data.category === "sponsor" },
      editionId: data.editionId,
    });
    if (!res.ok) return fail(res.error, { ownerUserId: res.error });
    owner = { id: res.member.userId, name: res.member.name, role: ownerRoleOf(res.member) };
  }
  const ownerUserId = owner?.id ?? session.user.id;

  try {
    const ref = await db.transaction(async (tx) => {
      const [edition] = await tx.execute<{ code: string; status: string }>(
        sql`SELECT code, status FROM editions WHERE id = ${data.editionId}`,
      );
      if (!edition) throw new Error("Event not found");
      if (editionIsReadOnly(edition.status)) throw new Error(EDITION_LOCKED_MESSAGE);
      const workflowId = await ensureStandDesignWorkflow(tx, session.organisation.id);
      // Keep the chosen plan even when it matches the defaults: stands have
      // no category defaults of their own worth relying on.
      const checked = await normaliseSignoffs(tx, {
        organisationId: session.organisation.id,
        editionId: data.editionId,
        workflowId,
        category: data.category,
        plan: data.signoffs,
      });
      const signoffs = checked ?? data.signoffs ?? null;
      const { ref, seq } = await nextStandDesignRef(tx, data.editionId, edition.code);
      const [item] = await tx
        .insert(signageItems)
        .values({
          editionId: data.editionId,
          ref,
          seq,
          name: data.name,
          description: data.description || null,
          kind: "stand_design",
          category: data.category,
          signoffs,
          hallId: hallId ?? null,
          locationId: data.locationId ?? null,
          standNumber: data.standNumber || null,
          widthMm: data.widthMm ?? null,
          depthMm: data.depthMm ?? null,
          heightMm: data.heightMm ?? null,
          sponsorId: data.category === "sponsor" ? (data.sponsorId ?? null) : null,
          ownerRole: owner?.role ?? "ops",
          ownerUserId,
          workflowId,
          createdBy: session.user.id,
        })
        .returning();
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: data.editionId,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: item.id,
        action: "create",
        after: { ref, name: data.name, signoffs, ownerUserId },
        summary: `Created stand ${ref} — ${data.name}${owner ? ` (owner ${owner.name})` : ""}`,
      });
      const recipients = await resolveItemCreationRecipients(
        tx,
        session.organisation.id,
        { kind: "stand_design", category: data.category, ownerUserId, ownerRole: "ops" },
        session.user.id,
        data.editionId,
      );
      if (owner) {
        await notifyOwnerChange(tx, {
          actor: { id: session.user.id, name: session.user.fullName || session.user.email },
          to: owner,
          items: [
            {
              id: item.id,
              ref,
              name: data.name,
              kind: "stand_design",
              editionCode: edition.code,
              fromUserId: null,
            },
          ],
        });
      }
      await notify(tx, {
        userIds: recipients,
        kind: "item_created",
        title: `New stand: ${ref} — ${data.name}`,
        link: itemPath(edition.code, { kind: "stand_design", ref }),
        entityType: "signage_item",
        entityId: item.id,
      });
      return ref;
    });
    revalidatePath("/", "layout");
    return success({ ref }, `Created ${ref}`);
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}

/**
 * A graphic panel on a stand, at any point before the stand is complete (so
 * printers can quote early; its graphic waits for the design's approval).
 * It takes the stand's place and approvers (matched department by
 * department on the print workflow), then goes through graphics sign-off
 * and print → delivered → installed like a sign.
 */
export async function addStandPanel(input: unknown): Promise<ActionResult<{ ref: string }>> {
  const parsed = panelSchema.safeParse(input);
  if (!parsed.success) return fail("Check the highlighted fields", fieldErrors(parsed.error));
  const session = await requireSession();
  if (!can(session.actor, { type: "stand_design.create" })) {
    return fail("Only Operations and super admins add panels");
  }
  const data = parsed.data;
  const bundle = await loadItemBundle(db, data.standId, actorScope(session));
  if (!bundle || bundle.item.deletedAt || bundle.item.kind !== "stand_design") {
    return fail("Stand not found");
  }
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "signage.edit", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot change this stand");
  }
  if (data.supplierId) {
    try {
      await assertItemLinks(db, {
        organisationId: session.organisation.id,
        editionId: bundle.edition.id,
        links: { supplierId: data.supplierId },
      });
    } catch (err) {
      return fail(err instanceof Error ? err.message : "Check the supplier");
    }
  }

  try {
    const ref = await db.transaction(async (tx) => {
      // Lock the stand so two panels added at once get different numbers,
      // and so its approval can't change underneath us.
      const [stand] = await tx
        .select()
        .from(signageItems)
        .where(eq(signageItems.id, data.standId))
        .for("update");
      if (stand.status === "closed") {
        throw new Error("This stand is complete — panels can no longer be added");
      }
      const [{ n }] = await tx
        .select({ n: sql<number>`count(*)::int` })
        .from(signageItems)
        .where(and(eq(signageItems.parentItemId, stand.id)));
      const panelNo = Number(n) + 1;
      const ref = formatStandPanelRef(stand.ref, panelNo);

      // Same approvers as the stand, on the print workflow's own steps.
      const workflowId = await defaultSignageWorkflowId(tx, session.organisation.id, null);
      const [fromSteps, toSteps] = await Promise.all([
        stand.workflowId ? loadStepDefs(tx, stand.workflowId) : [],
        workflowId ? loadStepDefs(tx, workflowId) : [],
      ]);
      const mapped = mapPlanToWorkflow(stand.signoffs ?? null, fromSteps, toSteps);
      const signoffs = mapped
        ? await normaliseSignoffs(tx, {
            organisationId: session.organisation.id,
            editionId: stand.editionId,
            workflowId,
            category: stand.category,
            plan: mapped,
          })
        : null;

      const [item] = await tx
        .insert(signageItems)
        .values({
          editionId: stand.editionId,
          ref,
          seq: await nextStandItemSeq(tx, stand.editionId),
          name: data.name,
          description: data.description || null,
          kind: "stand_panel",
          parentItemId: stand.id,
          category: stand.category,
          signoffs,
          hallId: stand.hallId,
          locationId: stand.locationId,
          standNumber: stand.standNumber,
          sponsorId: stand.sponsorId,
          isSponsorDeliverable: Boolean(stand.sponsorId),
          widthMm: data.widthMm,
          heightMm: data.heightMm,
          quantity: data.quantity,
          material: data.material || null,
          finish: data.finish || null,
          supplierId: data.supplierId ?? null,
          // A panel is its stand's owner's to run.
          ownerRole: stand.ownerRole,
          ownerUserId: stand.ownerUserId ?? session.user.id,
          workflowId,
          createdBy: session.user.id,
        })
        .returning();
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: stand.editionId,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: stand.id,
        action: "update",
        after: { panel: ref, name: data.name },
        summary: `Added panel ${ref} — ${data.name}`,
      });
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: stand.editionId,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: item.id,
        action: "create",
        after: { ref, name: data.name, stand: stand.ref },
        summary: `Created panel ${ref} — ${data.name} on ${stand.ref}`,
      });
      return ref;
    });
    revalidatePath("/", "layout");
    return success({ ref }, `Added ${ref}`);
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}

/**
 * Bring a stand's panels into line with it: where it is (until a panel is
 * installed) and, while a panel is still a draft, whose stand it is and who
 * signs it off. One audit row per panel changed. Returns how many changed.
 */
async function syncPanelsToStand(tx: Tx, session: Session, standId: string): Promise<number> {
  const [stand] = await tx
    .select()
    .from(signageItems)
    .where(eq(signageItems.id, standId))
    .for("update");
  if (!stand || stand.kind !== "stand_design") return 0;
  const panels = await tx
    .select()
    .from(signageItems)
    .where(and(eq(signageItems.parentItemId, stand.id), isNull(signageItems.deletedAt)));
  if (panels.length === 0) return 0;
  const fromSteps = stand.workflowId ? await loadStepDefs(tx, stand.workflowId) : [];
  const stepsByWorkflow = new Map<string, Awaited<ReturnType<typeof loadStepDefs>>>();
  const defaultWorkflowId = await defaultSignageWorkflowId(tx, session.organisation.id, null);
  let changed = 0;
  for (const panel of panels) {
    let mapped: SignoffPlan | null = panel.signoffs ?? null;
    if (panel.status === "draft") {
      const workflowId = panel.workflowId ?? defaultWorkflowId;
      if (workflowId && !stepsByWorkflow.has(workflowId)) {
        stepsByWorkflow.set(workflowId, await loadStepDefs(tx, workflowId));
      }
      const plan = mapPlanToWorkflow(
        stand.signoffs ?? null,
        fromSteps,
        (workflowId && stepsByWorkflow.get(workflowId)) || [],
      );
      mapped = plan
        ? await normaliseSignoffs(tx, {
            organisationId: session.organisation.id,
            editionId: stand.editionId,
            workflowId,
            category: stand.category,
            plan,
          })
        : null;
    }
    const patch = panelSyncPatch(stand, panel, mapped);
    const keys = Object.keys(patch);
    if (keys.length === 0) continue;
    await tx
      .update(signageItems)
      .set(patch as Partial<typeof signageItems.$inferInsert>)
      .where(eq(signageItems.id, panel.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: stand.editionId,
      actorUserId: session.user.id,
      entityType: "signage_item",
      entityId: panel.id,
      action: "update",
      before: Object.fromEntries(keys.map((k) => [k, panel[k as keyof typeof panel] ?? null])),
      after: patch,
      summary: `Updated ${panel.ref} to match its stand ${stand.ref} (${keys
        .filter((k) => k !== "isSponsorDeliverable")
        .join(", ")})`,
    });
    changed++;
  }
  return changed;
}

/**
 * Save a stand (the same checks, rules and audit as any item), then bring
 * its panels into line: its hall, location and stand no. until a panel is
 * installed; whose stand it is and who signs off while a panel is a draft.
 */
export async function updateStandDesign(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).passthrough().safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id, actorScope(session));
  if (!bundle || bundle.item.deletedAt || bundle.item.kind !== "stand_design") {
    return fail("Stand not found");
  }
  const saved = await updateSignageItem(input);
  if (!saved.ok) return saved;
  // updateSignageItem checked the right to edit and the event; the panels
  // are the stand's own, so the same right covers them.
  let followed = 0;
  try {
    followed = await db.transaction((tx) => syncPanelsToStand(tx, session, bundle.item.id));
  } catch (err) {
    console.error("updateStandDesign: panels", err);
    return success(
      undefined,
      `${saved.message ?? "Saved"} — but its panels could not be updated to match; save again`,
    );
  }
  if (followed > 0) revalidatePath("/", "layout");
  return success(
    undefined,
    followed > 0
      ? `${saved.message ?? "Saved"} — ${plural(followed, "panel")} updated to match`
      : saved.message,
  );
}
