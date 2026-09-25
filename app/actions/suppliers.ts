"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, count, eq, inArray } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  externalGrants,
  signageItems,
  supplierServiceLinks,
  supplierServices,
  suppliers,
} from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";

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
  const { id, serviceIds, ...values } = parsed.data;
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
        throw new Error("Unknown service — reload the page");

      let row;
      let before: Record<string, unknown> | undefined;
      if (id) {
        const existing = await tx.query.suppliers.findFirst({
          where: and(eq(suppliers.id, id), eq(suppliers.organisationId, orgId)),
        });
        if (!existing) throw new Error("Supplier not found");
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
    return success({ id: supplierId }, "Supplier saved");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not save the supplier");
  }
}

/** Remove a supplier nobody depends on (no items, no portal access). */
export async function deleteSupplier(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can change suppliers");
  }
  try {
    await db.transaction(async (tx) => {
      const existing = await tx.query.suppliers.findFirst({
        where: and(
          eq(suppliers.id, parsed.data.id),
          eq(suppliers.organisationId, session.organisation.id),
        ),
      });
      if (!existing) throw new Error("Supplier not found");
      const [items] = await tx
        .select({ n: count() })
        .from(signageItems)
        .where(eq(signageItems.supplierId, existing.id));
      if (Number(items.n) > 0) {
        throw new Error(
          `${existing.name} is the supplier on ${items.n} item(s) — change those first`,
        );
      }
      const [grants] = await tx
        .select({ n: count() })
        .from(externalGrants)
        .where(
          and(eq(externalGrants.scopeType, "supplier"), eq(externalGrants.scopeId, existing.id)),
        );
      if (Number(grants.n) > 0) {
        throw new Error(
          `${existing.name} has portal access — revoke it under Settings → Team first`,
        );
      }
      await tx.delete(suppliers).where(eq(suppliers.id, existing.id));
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        actorUserId: session.user.id,
        entityType: "supplier",
        entityId: existing.id,
        action: "soft_delete",
        before: { name: existing.name },
        summary: `Removed supplier ${existing.name}`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, "Supplier removed");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not remove the supplier");
  }
}
