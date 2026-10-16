"use server";

import { revalidatePath } from "next/cache";
import { unstable_rethrow } from "next/navigation";
import { z } from "zod";
import { and, count, eq, inArray, sql } from "drizzle-orm";
import { db, type Tx } from "@/lib/db/client";
import {
  externalGrants,
  signageItems,
  snags,
  supplierServiceLinks,
  supplierServices,
  suppliers,
} from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { supplierRemoval, type SupplierUsage } from "@/components/suppliers/rules";

/** A refusal worded for the person; anything else is logged and replaced with a generic message. */
class Refusal extends Error {}

function failure(err: unknown, fallback: string, where: string): ActionResult<never> {
  if (err instanceof Refusal) return fail(err.message);
  console.error(where, err);
  return fail(fallback);
}

const opt = (max = 200) =>
  z
    .string()
    .trim()
    .max(max)
    .optional()
    .nullable()
    .transform((v) => (v ? v : null));

const supplierSchema = z.object({
  id: z.string().uuid().optional(),
  name: z.string().trim().min(1, "Give the company a name").max(200),
  serviceIds: z.array(z.string().uuid()).max(50).default([]),
  /** New things they do, added to the list as they're typed in. */
  newServices: z.array(z.string().trim().min(1).max(100)).max(10).default([]),
  contactName: opt(),
  email: opt().refine(
    (v) => v === null || z.string().email().safeParse(v).success,
    "Enter a valid email",
  ),
  phone: opt(50),
  notes: opt(2000),
});

/** Add or edit a supplier and the services they offer (admins and Operations). */
export async function saveSupplier(input: unknown): Promise<ActionResult<{ id: string }>> {
  const parsed = supplierSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can change suppliers");
  }
  const orgId = session.organisation.id;
  const { id, serviceIds, newServices, ...values } = parsed.data;
  try {
    const supplierId = await db.transaction(async (tx) => {
      // Services must be this organisation's.
      const services = serviceIds.length
        ? await tx
            .select({ id: supplierServices.id, name: supplierServices.name })
            .from(supplierServices)
            .where(
              and(
                eq(supplierServices.organisationId, orgId),
                inArray(supplierServices.id, serviceIds),
              ),
            )
        : [];
      if (services.length !== new Set(serviceIds).size)
        throw new Refusal("Unknown service — reload the page");
      // New "what they do" entries join the shared list (or reuse a match).
      if (newServices.length) {
        const existing = await tx
          .select({
            id: supplierServices.id,
            name: supplierServices.name,
            isArchived: supplierServices.isArchived,
          })
          .from(supplierServices)
          .where(eq(supplierServices.organisationId, orgId));
        let next = existing.length + 1;
        for (const raw of new Set(newServices.map((n) => n.replace(/\s+/g, " ")))) {
          const match = existing.find((e) => e.name.toLowerCase() === raw.toLowerCase());
          let service = match ? { id: match.id, name: match.name } : null;
          if (match?.isArchived) {
            await tx
              .update(supplierServices)
              .set({ isArchived: false })
              .where(eq(supplierServices.id, match.id));
          }
          if (!service) {
            [service] = await tx
              .insert(supplierServices)
              .values({ organisationId: orgId, name: raw, sortOrder: next++ })
              .returning({ id: supplierServices.id, name: supplierServices.name });
            await writeAudit(tx, {
              organisationId: orgId,
              actorUserId: session.user.id,
              entityType: "supplier_service",
              entityId: service.id,
              action: "create",
              after: { name: raw },
              summary: `Supplier service “${raw}” added`,
            });
          }
          if (!services.some((sv) => sv.id === service!.id)) services.push(service);
        }
      }

      let row;
      let before: Record<string, unknown> | undefined;
      if (id) {
        const existing = await tx.query.suppliers.findFirst({
          where: and(eq(suppliers.id, id), eq(suppliers.organisationId, orgId)),
        });
        if (!existing) throw new Refusal("Supplier not found — reload the page");
        const oldLinks = await tx
          .select({ name: supplierServices.name })
          .from(supplierServiceLinks)
          .innerJoin(supplierServices, eq(supplierServiceLinks.serviceId, supplierServices.id))
          .where(eq(supplierServiceLinks.supplierId, id));
        before = { ...values, name: existing.name, services: oldLinks.map((l) => l.name) };
        [row] = await tx.update(suppliers).set(values).where(eq(suppliers.id, id)).returning();
        await tx.delete(supplierServiceLinks).where(eq(supplierServiceLinks.supplierId, id));
      } else {
        [row] = await tx
          .insert(suppliers)
          .values({ ...values, organisationId: orgId })
          .returning();
      }
      if (services.length) {
        await tx
          .insert(supplierServiceLinks)
          .values(services.map((s) => ({ supplierId: row.id, serviceId: s.id })));
      }
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: "supplier",
        entityId: row.id,
        action: id ? "update" : "create",
        before,
        after: { ...values, services: services.map((s) => s.name) },
        summary: `${id ? "Updated" : "Added"} supplier ${values.name}${
          services.length ? ` (${services.map((s) => s.name).join(", ")})` : ""
        }`,
      });
      return row.id;
    });
    revalidatePath("/", "layout");
    return success({ id: supplierId }, `${values.name} saved`);
  } catch (err) {
    unstable_rethrow(err);
    return failure(err, "Could not save the supplier — please try again", "saveSupplier");
  }
}

/** Everything that refers to a supplier, live or deleted (see supplierRemoval). */
async function supplierUsage(tx: Tx, supplierId: string): Promise<SupplierUsage> {
  // One after another: they share the transaction's connection.
  const [items] = await tx
    .select({
      live: sql<number>`count(*) filter (where ${signageItems.deletedAt} is null)`,
      deleted: sql<number>`count(*) filter (where ${signageItems.deletedAt} is not null)`,
    })
    .from(signageItems)
    .where(eq(signageItems.supplierId, supplierId));
  const [snagRows] = await tx
    .select({ n: count() })
    .from(snags)
    .where(eq(snags.assignedSupplierId, supplierId));
  const [grants] = await tx
    .select({
      live: sql<number>`count(*) filter (where ${externalGrants.revokedAt} is null and (${externalGrants.expiresAt} is null or ${externalGrants.expiresAt} > now()))`,
      all: count(),
    })
    .from(externalGrants)
    .where(and(eq(externalGrants.scopeType, "supplier"), eq(externalGrants.scopeId, supplierId)));
  const liveGrants = Number(grants.live);
  return {
    liveItems: Number(items.live),
    deletedItems: Number(items.deleted),
    snags: Number(snagRows.n),
    liveGrants,
    pastGrants: Number(grants.all) - liveGrants,
  };
}

/**
 * Archive a supplier (hidden from the list and the item pickers; items keep
 * it) or put it back.
 */
export async function setSupplierArchived(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid(), archived: z.boolean() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can change suppliers");
  }
  const { id, archived } = parsed.data;
  try {
    const name = await db.transaction(async (tx) => {
      const [row] = await tx
        .update(suppliers)
        .set({ isArchived: archived, updatedAt: new Date() })
        .where(and(eq(suppliers.id, id), eq(suppliers.organisationId, session.organisation.id)))
        .returning({ id: suppliers.id, name: suppliers.name });
      if (!row) throw new Refusal("Supplier not found — reload the page");
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        actorUserId: session.user.id,
        entityType: "supplier",
        entityId: row.id,
        action: "update",
        before: { archived: !archived },
        after: { archived },
        summary: `${archived ? "Archived" : "Restored"} supplier ${row.name}`,
      });
      return row.name;
    });
    revalidatePath("/", "layout");
    return success(
      undefined,
      archived ? `${name} archived — hidden from lists and pickers` : `${name} restored`,
    );
  } catch (err) {
    unstable_rethrow(err);
    return failure(err, "Could not update the supplier — please try again", "setSupplierArchived");
  }
}

/**
 * Delete a supplier for good. Only when nothing uses it — not a live item, a
 * deleted one, a snag or portal access; otherwise it can be archived.
 */
export async function deleteSupplier(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can change suppliers");
  }
  try {
    const name = await db.transaction(async (tx) => {
      const existing = await tx.query.suppliers.findFirst({
        where: and(
          eq(suppliers.id, parsed.data.id),
          eq(suppliers.organisationId, session.organisation.id),
        ),
      });
      if (!existing) throw new Refusal("Supplier not found — reload the page");
      const removal = supplierRemoval(existing.name, await supplierUsage(tx, existing.id));
      if (!removal.canDelete) throw new Refusal(removal.reason);
      await tx.delete(suppliers).where(eq(suppliers.id, existing.id));
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        actorUserId: session.user.id,
        entityType: "supplier",
        entityId: existing.id,
        action: "soft_delete",
        before: { name: existing.name, archived: existing.isArchived },
        summary: `Deleted supplier ${existing.name} (unused)`,
      });
      return existing.name;
    });
    revalidatePath("/", "layout");
    return success(undefined, `${name} deleted`);
  } catch (err) {
    unstable_rethrow(err);
    return failure(err, "Could not delete the supplier — please try again", "deleteSupplier");
  }
}
