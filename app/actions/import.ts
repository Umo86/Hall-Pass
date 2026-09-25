"use server";

import { revalidatePath } from "next/cache";
import ExcelJS from "exceljs";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
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
import { defaultSignageWorkflowId } from "@/lib/domain/signage";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";

const rowSchema = z.object({
  ref: z.string().trim().optional().or(z.literal("")),
  name: z.string().trim().min(1, "Name is required"),
  type: z.string().trim().optional(),
  hall: z.string().trim().optional(),
  location: z.string().trim().optional(),
  widthMm: z.coerce.number().int().positive().optional().nullable(),
  heightMm: z.coerce.number().int().positive().optional().nullable(),
  quantity: z.coerce.number().int().positive().optional().nullable(),
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
  category: z
    .string()
    .trim()
    .toLowerCase()
    // Organiser or Sponsor; older sheets said directional/venue/sponsorship.
    .transform((v) =>
      ["directional", "venue", "wayfinding", "organizer"].includes(v)
        ? "organiser"
        : v === "sponsorship" || v === "sponsored"
          ? "sponsor"
          : v,
    )
    .pipe(z.enum(["organiser", "sponsor", ""], { message: "Category must be Organiser or Sponsor" }))
    .optional(),
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

  const [edition] = await db.execute<{ code: string; status: string }>(
    (await import("drizzle-orm")).sql`SELECT code, status FROM editions WHERE id = ${editionId}`,
  );
  if (!edition) return fail("Edition not found");
  if (editionIsReadOnly(edition.status)) return fail(EDITION_LOCKED_MESSAGE);

  const [typeRows, hallRows, locationRows, sponsorRows, supplierRows, itemRows] = await Promise.all([
    db
      .select()
      .from(itemTypes)
      .where(and(eq(itemTypes.organisationId, session.organisation.id), eq(itemTypes.kind, "signage"))),
    db.select().from(halls).where(eq(halls.editionId, editionId)),
    db
      .select({ id: locations.id, name: locations.name, hallId: locations.hallId })
      .from(locations)
      .innerJoin(halls, eq(locations.hallId, halls.id))
      .where(eq(halls.editionId, editionId)),
    db.select().from(sponsors).where(eq(sponsors.editionId, editionId)),
    db.select().from(suppliers).where(eq(suppliers.organisationId, session.organisation.id)),
    db
      .select({
        id: signageItems.id,
        ref: signageItems.ref,
        kind: signageItems.kind,
        status: signageItems.status,
        deletedAt: signageItems.deletedAt,
      })
      .from(signageItems)
      .where(eq(signageItems.editionId, editionId)),
  ]);
  const itemByRef = new Map(itemRows.map((i) => [i.ref.toUpperCase(), i]));
  // Only items still being prepared can be overwritten from a spreadsheet;
  // anything in sign-off changes on its own page so approvals stay honest.
  const EDITABLE = new Set(["draft", "awaiting_artwork", "changes_requested"]);
  /** The row's location: within its hall, or unique across halls when no hall is given. */
  const findLocation = (name: string, hallId: string | undefined) => {
    const matches = locationRows.filter(
      (l) => l.name.toLowerCase() === name.toLowerCase().trim() && (!hallId || l.hallId === hallId),
    );
    return matches.length === 1 ? matches[0] : matches.length > 1 ? "ambiguous" : undefined;
  };
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
      quantity: cell(8) || null,
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
      category: cell(20),
    };
    if (!raw.name && !raw.ref) return; // blank row
    const res = rowSchema.safeParse(raw);
    if (!res.success) {
      errors.push({ row: rowNumber, message: res.error.issues[0].message });
    } else {
      const d = res.data;
      const rowError = (message: string) => errors.push({ row: rowNumber, message });
      if (d.installDate && !/^\d{4}-\d{2}-\d{2}$/.test(d.installDate)) {
        return rowError(`Install date “${d.installDate}” — use YYYY-MM-DD (e.g. 2027-10-02)`);
      }
      if (d.ref) {
        const existing = itemByRef.get(d.ref.toUpperCase());
        if (!existing) return rowError(`No item ${d.ref} in this show — leave Ref blank to add a new one`);
        if (existing.deletedAt) return rowError(`${d.ref} was deleted — restore it first`);
        if (existing.kind !== "signage") return rowError(`${d.ref} is a sponsorship item, not signage`);
        if (!EDITABLE.has(existing.status)) {
          return rowError(`${d.ref} is already in sign-off — change it on its page`);
        }
      }
      // Unknown reference data is an error unless createMissing covers it.
      if (d.type && !byName(typeRows, d.type)) return rowError(`Unknown item type “${d.type}”`);
      if (d.sponsor && !byName(sponsorRows, d.sponsor)) return rowError(`Unknown sponsor “${d.sponsor}”`);
      const hall = d.hall ? byName(hallRows, d.hall) : undefined;
      if (d.hall && !hall && !createMissing) return rowError(`Unknown hall “${d.hall}”`);
      if (d.location) {
        const loc = hall ? findLocation(d.location, hall.id) : d.hall ? undefined : findLocation(d.location, undefined);
        if (loc === "ambiguous") {
          return rowError(`Location “${d.location}” is in more than one hall — add the hall`);
        }
        if (!loc && !createMissing) return rowError(`Unknown location “${d.location}”`);
        if (!loc && !d.hall) return rowError(`Location “${d.location}” needs a hall`);
      }
      if (!createMissing && d.supplier && !byName(supplierRows, d.supplier)) {
        return rowError(`Unknown supplier “${d.supplier}”`);
      }
      parsed.push({ rowNumber, data: d });
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
        let supplierId: string | null | undefined;
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
        let hall = data.hall ? byName(hallRows, data.hall) : undefined;
        if (data.hall && !hall) {
          const [nh] = await tx
            .insert(halls)
            .values({ editionId, name: data.hall, sortOrder: hallRows.length })
            .returning();
          hallRows.push(nh);
          hall = nh;
        }
        let locationId: string | undefined;
        if (data.location) {
          const found = findLocation(data.location, hall?.id);
          if (found && found !== "ambiguous") {
            locationId = found.id;
            if (!hall) hall = hallRows.find((h) => h.id === found.hallId);
          } else if (hall) {
            const [nl] = await tx
              .insert(locations)
              .values({ hallId: hall.id, name: data.location })
              .returning();
            locationRows.push({ id: nl.id, name: nl.name, hallId: nl.hallId });
            locationId = nl.id;
          }
        }
        const itemTypeId = data.type ? (byName(typeRows, data.type)?.id ?? null) : undefined;
        const sponsorId = data.sponsor ? (byName(sponsorRows, data.sponsor)?.id ?? null) : undefined;
        // Blank cells leave existing values alone; only filled cells change.
        const values = Object.fromEntries(
          Object.entries({
            name: data.name,
            description: data.description || undefined,
            itemTypeId,
            hallId: hall?.id,
            locationId,
            widthMm: data.widthMm ?? undefined,
            heightMm: data.heightMm ?? undefined,
            quantity: data.quantity ?? undefined,
            sided: (data.sided || undefined) as "single" | "double" | undefined,
            material: data.material || undefined,
            finish: data.finish || undefined,
            fixingMethod: (data.fixing || undefined) as typeof signageItems.$inferSelect.fixingMethod | undefined,
            sponsorId,
            supplierId,
            requiresVenueApproval:
              data.requiresVenueApproval ?? (data.fixing === "rigged" ? true : undefined),
            costEstimate: data.costEstimate != null ? String(data.costEstimate) : undefined,
            installDate: data.installDate || undefined,
            installSlot: (data.installSlot || undefined) as "am" | "pm" | "overnight" | undefined,
            category: data.category || undefined,
          }).filter(([, v]) => v !== undefined),
        ) as Partial<typeof signageItems.$inferInsert>;
        const existing = data.ref ? itemByRef.get(data.ref.toUpperCase()) : undefined;
        if (existing) {
          await tx.update(signageItems).set(values).where(eq(signageItems.id, existing.id));
          updated++;
        } else {
          const { ref, seq } = await nextSignageRef(tx, editionId, edition.code);
          await tx.insert(signageItems).values({
            ...values,
            name: data.name,
            editionId,
            ref,
            seq,
            kind: "signage",
            // Blank category: sponsored rows are sponsor signage, the rest organiser.
            category: data.category || (values.sponsorId ? "sponsor" : "organiser"),
            ownerRole: "ops",
            ownerUserId: session.user.id,
            workflowId: await defaultSignageWorkflowId(
              tx,
              session.organisation.id,
              values.itemTypeId ?? null,
            ),
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
