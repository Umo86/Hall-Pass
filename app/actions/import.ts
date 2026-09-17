"use server";

import { revalidatePath } from "next/cache";
import ExcelJS from "exceljs";
import { z } from "zod";
import { and, eq, ilike } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  halls,
  itemTypes,
  locations,
  signageItems,
  sponsors,
  suppliers,
} from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { nextSignageRef } from "@/lib/refs";

const rowSchema = z.object({
  ref: z.string().trim().optional().or(z.literal("")),
  name: z.string().trim().min(1, "Name is required"),
  type: z.string().trim().optional(),
  hall: z.string().trim().optional(),
  location: z.string().trim().optional(),
  widthMm: z.coerce.number().int().positive().optional().nullable(),
  heightMm: z.coerce.number().int().positive().optional().nullable(),
  quantity: z.coerce.number().int().positive().default(1),
  sided: z
    .string()
    .trim()
    .toLowerCase()
    .pipe(z.enum(["single", "double", ""]))
    .optional(),
  material: z.string().trim().optional(),
  finish: z.string().trim().optional(),
  fixing: z
    .string()
    .trim()
    .toLowerCase()
    .transform((v) => v.replace(/[ -]/g, "_"))
    .pipe(
      z.enum(["rigged", "freestanding", "wall_mounted", "shell_mounted", "floor", "digital", "other", ""]),
    )
    .optional(),
  sponsor: z.string().trim().optional(),
  supplier: z.string().trim().optional(),
  requiresVenueApproval: z
    .string()
    .trim()
    .toLowerCase()
    .transform((v) => ["y", "yes", "true", "1"].includes(v))
    .optional(),
  costEstimate: z.coerce.number().nonnegative().optional().nullable(),
  installDate: z.string().trim().optional(),
  installSlot: z
    .string()
    .trim()
    .toLowerCase()
    .pipe(z.enum(["am", "pm", "overnight", ""]))
    .optional(),
  description: z.string().trim().optional(),
});

export type ImportOutcome = {
  created: number;
  updated: number;
  errors: { row: number; message: string }[];
};

/**
 * Excel import (brief §10): parse → validate each row with the shared
 * schema, resolving names case-insensitively → commit in one transaction.
 * Upserts by ref when present, otherwise creates. When createMissing is
 * ticked, unknown suppliers and locations are created on the fly.
 */
export async function importSchedule(formData: FormData): Promise<ActionResult<ImportOutcome>> {
  const editionId = formData.get("editionId");
  const file = formData.get("file");
  const createMissing = formData.get("createMissing") === "on";
  if (typeof editionId !== "string" || !(file instanceof File)) return fail("Invalid import");
  const session = await requireSession();
  if (!can(session.actor, { type: "signage.create" })) return fail("You cannot import items");

  const wb = new ExcelJS.Workbook();
  await wb.xlsx.load(await file.arrayBuffer());
  const ws = wb.worksheets[0];
  if (!ws) return fail("The workbook has no sheets");

  const [edition] = await db.execute<{ code: string }>(
    (await import("drizzle-orm")).sql`SELECT code FROM editions WHERE id = ${editionId}`,
  );
  if (!edition) return fail("Edition not found");

  const [typeRows, hallRows, locationRows, sponsorRows, supplierRows] = await Promise.all([
    db.select().from(itemTypes).where(eq(itemTypes.organisationId, session.organisation.id)),
    db.select().from(halls).where(eq(halls.editionId, editionId)),
    db
      .select({ id: locations.id, name: locations.name, hallId: locations.hallId })
      .from(locations)
      .innerJoin(halls, eq(locations.hallId, halls.id))
      .where(eq(halls.editionId, editionId)),
    db.select().from(sponsors).where(eq(sponsors.editionId, editionId)),
    db.select().from(suppliers).where(eq(suppliers.organisationId, session.organisation.id)),
  ]);
  const byName = <T extends { name?: string; companyName?: string }>(rows: T[], name: string) =>
    rows.find(
      (r) => (r.name ?? r.companyName ?? "").toLowerCase() === name.toLowerCase().trim(),
    );

  const parsed: Array<{ rowNumber: number; data: z.infer<typeof rowSchema> }> = [];
  const errors: { row: number; message: string }[] = [];

  ws.eachRow((row, rowNumber) => {
    if (rowNumber === 1) return; // header
    const cell = (i: number) => {
      const v = row.getCell(i).value;
      if (v == null) return "";
      if (typeof v === "object" && "text" in v) return String(v.text);
      if (v instanceof Date) return v.toISOString().slice(0, 10);
      return String(v);
    };
    const raw = {
      ref: cell(1),
      name: cell(2),
      type: cell(3),
      hall: cell(4),
      location: cell(5),
      widthMm: cell(6) || null,
      heightMm: cell(7) || null,
      quantity: cell(8) || 1,
      sided: cell(9),
      material: cell(10),
      finish: cell(11),
      fixing: cell(12),
      sponsor: cell(13),
      supplier: cell(14),
      requiresVenueApproval: cell(15),
      costEstimate: cell(16) || null,
      installDate: cell(17),
      installSlot: cell(18),
      description: cell(19),
    };
    if (!raw.name && !raw.ref) return; // blank row
    const res = rowSchema.safeParse(raw);
    if (!res.success) {
      errors.push({ row: rowNumber, message: res.error.issues[0].message });
    } else {
      // Unknown reference data is an error unless createMissing covers it.
      if (res.data.type && !byName(typeRows, res.data.type)) {
        errors.push({ row: rowNumber, message: `Unknown item type “${res.data.type}”` });
        return;
      }
      if (res.data.hall && !byName(hallRows, res.data.hall)) {
        errors.push({ row: rowNumber, message: `Unknown hall “${res.data.hall}”` });
        return;
      }
      if (res.data.sponsor && !byName(sponsorRows, res.data.sponsor)) {
        errors.push({ row: rowNumber, message: `Unknown sponsor “${res.data.sponsor}”` });
        return;
      }
      if (!createMissing) {
        if (res.data.supplier && !byName(supplierRows, res.data.supplier)) {
          errors.push({ row: rowNumber, message: `Unknown supplier “${res.data.supplier}”` });
          return;
        }
        if (res.data.location && !locationRows.find((l) => l.name.toLowerCase() === res.data.location!.toLowerCase())) {
          errors.push({ row: rowNumber, message: `Unknown location “${res.data.location}”` });
          return;
        }
      }
      parsed.push({ rowNumber, data: res.data });
    }
  });

  if (errors.length > 0) {
    return success({ created: 0, updated: 0, errors }, "Fix the highlighted rows and re-upload");
  }
  if (parsed.length === 0) return fail("No rows found to import");

  try {
    let created = 0;
    let updated = 0;
    await db.transaction(async (tx) => {
      for (const { data } of parsed) {
        let supplierId: string | null = null;
        if (data.supplier) {
          const existing = byName(supplierRows, data.supplier);
          if (existing) supplierId = existing.id;
          else {
            const [ns] = await tx
              .insert(suppliers)
              .values({ organisationId: session.organisation.id, name: data.supplier, kind: "other" })
              .returning();
            supplierRows.push(ns);
            supplierId = ns.id;
          }
        }
        const hall = data.hall ? byName(hallRows, data.hall) : undefined;
        let locationId: string | null = null;
        if (data.location) {
          const existing = locationRows.find(
            (l) => l.name.toLowerCase() === data.location!.toLowerCase(),
          );
          if (existing) locationId = existing.id;
          else if (hall) {
            const [nl] = await tx
              .insert(locations)
              .values({ hallId: hall.id, name: data.location })
              .returning();
            locationRows.push({ id: nl.id, name: nl.name, hallId: nl.hallId });
            locationId = nl.id;
          }
        }
        const values = {
          name: data.name,
          description: data.description || null,
          itemTypeId: data.type ? (byName(typeRows, data.type)?.id ?? null) : null,
          hallId: hall?.id ?? null,
          locationId,
          widthMm: data.widthMm ?? null,
          heightMm: data.heightMm ?? null,
          quantity: data.quantity,
          sided: (data.sided || "single") as "single" | "double",
          material: data.material || null,
          finish: data.finish || null,
          fixingMethod: (data.fixing || null) as typeof signageItems.$inferSelect.fixingMethod,
          sponsorId: data.sponsor ? (byName(sponsorRows, data.sponsor)?.id ?? null) : null,
          supplierId,
          requiresVenueApproval: data.requiresVenueApproval ?? data.fixing === "rigged",
          costEstimate: data.costEstimate != null ? String(data.costEstimate) : null,
          installDate: data.installDate || null,
          installSlot: (data.installSlot || null) as "am" | "pm" | "overnight" | null,
        };
        const existing = data.ref
          ? await tx
              .select()
              .from(signageItems)
              .where(and(eq(signageItems.editionId, editionId), ilike(signageItems.ref, data.ref)))
              .limit(1)
          : [];
        if (existing.length > 0) {
          await tx.update(signageItems).set(values).where(eq(signageItems.id, existing[0].id));
          updated++;
        } else {
          const { ref, seq } = await nextSignageRef(tx, editionId, edition.code);
          await tx.insert(signageItems).values({
            ...values,
            editionId,
            ref,
            seq,
            isSponsorDeliverable: Boolean(values.sponsorId),
            createdBy: session.user.id,
          });
          created++;
        }
      }
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId,
        actorUserId: session.user.id,
        entityType: "edition",
        entityId: editionId,
        action: "import",
        after: { created, updated, rows: parsed.length },
        summary: `Schedule import: ${created} created, ${updated} updated`,
      });
    });
    revalidatePath("/", "layout");
    return success(
      { created, updated, errors: [] },
      `Imported ${created + updated} rows (${created} new, ${updated} updated)`,
    );
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Import failed");
  }
}
