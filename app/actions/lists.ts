"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq, max } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { itemTypes, supplierServices } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { defaultSignageWorkflowId } from "@/lib/domain/signage";
import { fail, success, type ActionResult } from "@/lib/actions/result";

/**
 * The pick-lists admins (and Operations) manage in Settings, which everyone
 * else chooses from: signage types and supplier services.
 */

const FIXINGS = [
  "rigged",
  "freestanding",
  "wall_mounted",
  "shell_mounted",
  "floor",
  "digital",
  "other",
] as const;

const itemTypeSchema = z
  .object({
    id: z.string().uuid().optional(),
    name: z.string().trim().min(1, "Give the type a name").max(100),
    kind: z.enum(["signage", "sponsorship_item"]),
    format: z
      .enum(["print", "digital", ""])
      .optional()
      .nullable()
      .transform((v) => (v ? v : null)),
    defaultFixingMethod: z
      .enum([...FIXINGS, ""])
      .optional()
      .nullable()
      .transform((v) => (v ? v : null)),
    requiresVenueApprovalDefault: z.boolean().default(false),
  })
  .superRefine((d, ctx) => {
    if (d.kind === "signage" && !d.format) {
      ctx.addIssue({
        code: "custom",
        path: ["format"],
        message: "Say whether it's print or digital",
      });
    }
  });

/** "Hanging banner" → "hanging_banner" (unique per organisation). */
function codeFrom(name: string) {
  return (
    name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "")
      .slice(0, 40) || "type"
  );
}

export async function saveItemType(input: unknown): Promise<ActionResult<{ id: string }>> {
  const parsed = itemTypeSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" }))
    return fail("Only admins and Operations manage signage types");
  const orgId = session.organisation.id;
  const data = parsed.data;
  const values = {
    name: data.name,
    kind: data.kind,
    format: data.kind === "signage" ? data.format : null,
    defaultFixingMethod: data.defaultFixingMethod,
    requiresVenueApprovalDefault: data.requiresVenueApprovalDefault,
  };
  try {
    const id = await db.transaction(async (tx) => {
      const clash = await tx.query.itemTypes.findFirst({
        where: and(eq(itemTypes.organisationId, orgId), eq(itemTypes.name, data.name)),
      });
      if (clash && clash.id !== data.id)
        throw new Error(`There is already a type called “${data.name}”`);
      if (data.id) {
        const [row] = await tx
          .update(itemTypes)
          .set(values)
          .where(and(eq(itemTypes.id, data.id), eq(itemTypes.organisationId, orgId)))
          .returning();
        if (!row) throw new Error("Type not found");
        await writeAudit(tx, {
          organisationId: orgId,
          actorUserId: session.user.id,
          entityType: "item_type",
          entityId: row.id,
          action: "settings_change",
          after: values,
          summary: `Signage type updated: ${row.name}`,
        });
        return row.id;
      }
      let code = codeFrom(data.name);
      for (
        let n = 2;
        await tx.query.itemTypes.findFirst({
          where: and(eq(itemTypes.organisationId, orgId), eq(itemTypes.code, code)),
        });
        n++
      ) {
        code = `${codeFrom(data.name)}_${n}`;
      }
      const [{ top }] = await tx
        .select({ top: max(itemTypes.sortOrder) })
        .from(itemTypes)
        .where(eq(itemTypes.organisationId, orgId));
      const [row] = await tx
        .insert(itemTypes)
        .values({
          ...values,
          organisationId: orgId,
          code,
          sortOrder: (top ?? 0) + 1,
          defaultWorkflowId: await defaultSignageWorkflowId(tx, orgId, null),
        })
        .returning();
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: "item_type",
        entityId: row.id,
        action: "create",
        after: values,
        summary: `Signage type added: ${row.name}`,
      });
      return row.id;
    });
    revalidatePath("/", "layout");
    return success({ id }, "Saved");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not save the type");
  }
}

const archiveSchema = z.object({ id: z.string().uuid(), archived: z.boolean() });

/** Hide a type from pickers (items that use it keep it). */
export async function setItemTypeArchived(input: unknown): Promise<ActionResult> {
  const parsed = archiveSchema.safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" }))
    return fail("Only admins and Operations manage signage types");
  try {
    await db.transaction(async (tx) => {
      const [row] = await tx
        .update(itemTypes)
        .set({ isArchived: parsed.data.archived })
        .where(
          and(
            eq(itemTypes.id, parsed.data.id),
            eq(itemTypes.organisationId, session.organisation.id),
          ),
        )
        .returning();
      if (!row) throw new Error("Type not found");
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        actorUserId: session.user.id,
        entityType: "item_type",
        entityId: row.id,
        action: "settings_change",
        after: { archived: parsed.data.archived },
        summary: `Signage type ${parsed.data.archived ? "hidden" : "restored"}: ${row.name}`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, parsed.data.archived ? "Hidden from pickers" : "Restored");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not update the type");
  }
}

const serviceSchema = z.object({
  id: z.string().uuid().optional(),
  name: z.string().trim().min(1, "Give the service a name").max(80),
});

export async function saveSupplierService(input: unknown): Promise<ActionResult<{ id: string }>> {
  const parsed = serviceSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" }))
    return fail("Only admins and Operations manage services");
  const orgId = session.organisation.id;
  try {
    const id = await db.transaction(async (tx) => {
      const clash = await tx.query.supplierServices.findFirst({
        where: and(
          eq(supplierServices.organisationId, orgId),
          eq(supplierServices.name, parsed.data.name),
        ),
      });
      if (clash && clash.id !== parsed.data.id) {
        if (clash.isArchived) {
          await tx
            .update(supplierServices)
            .set({ isArchived: false })
            .where(eq(supplierServices.id, clash.id));
          return clash.id;
        }
        throw new Error(`“${parsed.data.name}” is already on the list`);
      }
      let row;
      if (parsed.data.id) {
        [row] = await tx
          .update(supplierServices)
          .set({ name: parsed.data.name })
          .where(
            and(
              eq(supplierServices.id, parsed.data.id),
              eq(supplierServices.organisationId, orgId),
            ),
          )
          .returning();
        if (!row) throw new Error("Service not found");
      } else {
        const [{ top }] = await tx
          .select({ top: max(supplierServices.sortOrder) })
          .from(supplierServices)
          .where(eq(supplierServices.organisationId, orgId));
        [row] = await tx
          .insert(supplierServices)
          .values({ organisationId: orgId, name: parsed.data.name, sortOrder: (top ?? 0) + 1 })
          .returning();
      }
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: "supplier_service",
        entityId: row.id,
        action: parsed.data.id ? "settings_change" : "create",
        after: { name: row.name },
        summary: `Supplier service ${parsed.data.id ? "renamed" : "added"}: ${row.name}`,
      });
      return row.id;
    });
    revalidatePath("/", "layout");
    return success({ id }, "Saved");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not save the service");
  }
}

export async function setSupplierServiceArchived(input: unknown): Promise<ActionResult> {
  const parsed = archiveSchema.safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" }))
    return fail("Only admins and Operations manage services");
  try {
    await db.transaction(async (tx) => {
      const [row] = await tx
        .update(supplierServices)
        .set({ isArchived: parsed.data.archived })
        .where(
          and(
            eq(supplierServices.id, parsed.data.id),
            eq(supplierServices.organisationId, session.organisation.id),
          ),
        )
        .returning();
      if (!row) throw new Error("Service not found");
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        actorUserId: session.user.id,
        entityType: "supplier_service",
        entityId: row.id,
        action: "settings_change",
        after: { archived: parsed.data.archived },
        summary: `Supplier service ${parsed.data.archived ? "removed" : "restored"}: ${row.name}`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, parsed.data.archived ? "Removed from the list" : "Restored");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not update the service");
  }
}
