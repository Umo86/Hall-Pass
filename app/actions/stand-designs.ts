"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq, sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { locations, signageItems } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { notify } from "@/lib/notify";
import {
  assertItemLinks,
  defaultSignageWorkflowId,
  itemAuthzCtx,
  loadItemBundle,
  normaliseSignoffs,
  ownEdition,
  resolveItemCreationRecipients,
} from "@/lib/domain/signage";
import { ensureStandDesignWorkflow, mapPlanToWorkflow } from "@/lib/domain/stand-designs";
import { loadStepDefs } from "@/lib/workflow/persist";
import { formatStandPanelRef, nextStandDesignRef, nextStandItemSeq } from "@/lib/refs";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { itemPath } from "@/lib/edition-path";
import { APPROVED_OR_LATER, type SignageStatus } from "@/lib/status/signage";

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
    return fail("Only admins and operations can set up stands");
  }
  const data = parsed.data;
  if (!(await ownEdition(db, session.organisation.id, data.editionId))) {
    return fail("Show not found");
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

  try {
    const ref = await db.transaction(async (tx) => {
      const [edition] = await tx.execute<{ code: string; status: string }>(
        sql`SELECT code, status FROM editions WHERE id = ${data.editionId}`,
      );
      if (!edition) throw new Error("Show not found");
      if (editionIsReadOnly(edition.status)) throw new Error(EDITION_LOCKED_MESSAGE);
      const workflowId = await ensureStandDesignWorkflow(tx, session.organisation.id);
      // Keep the chosen plan even when it matches the defaults: stands have
      // no category defaults of their own worth relying on.
      const checked = await normaliseSignoffs(tx, {
        organisationId: session.organisation.id,
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
          ownerRole: "ops",
          ownerUserId: session.user.id,
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
        after: { ref, name: data.name, signoffs },
        summary: `Created stand ${ref} — ${data.name}`,
      });
      const recipients = await resolveItemCreationRecipients(
        tx,
        session.organisation.id,
        { kind: "stand_design", category: data.category, ownerRole: "ops" },
        session.user.id,
      );
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
 * A graphic panel on an approved stand. It takes the stand's place and
 * approvers (matched department by department on the print workflow), then
 * goes through graphics sign-off and print → delivered → installed like a sign.
 */
export async function addStandPanel(input: unknown): Promise<ActionResult<{ ref: string }>> {
  const parsed = panelSchema.safeParse(input);
  if (!parsed.success) return fail("Check the highlighted fields", fieldErrors(parsed.error));
  const session = await requireSession();
  if (!can(session.actor, { type: "stand_design.create" })) {
    return fail("Only admins and operations can add panels");
  }
  const data = parsed.data;
  const bundle = await loadItemBundle(db, data.standId, {
    organisationId: session.organisation.id,
  });
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
      if (!APPROVED_OR_LATER.includes(stand.status as SignageStatus)) {
        throw new Error("Panels can be added once the stand design is approved");
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
          ownerRole: "ops",
          ownerUserId: session.user.id,
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
