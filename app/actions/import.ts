"use server";

import {
  archivedSupplierMessage,
  notifyOwnerChange,
  ownEdition,
  type OwnerChange,
} from "@/lib/domain/signage";
import { loadTeam, ownerRoleOf, refusalFor, refusalMessage } from "@/lib/people";

import { revalidatePath } from "next/cache";
import ExcelJS from "exceljs";
import { z } from "zod";
import { and, eq, inArray } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { halls, itemTypes, locations, signageItems, sponsors, suppliers } from "@/lib/db/schema";
import { can, type SignageItemCtx } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { nextSignageRef } from "@/lib/refs";
import { defaultSignageWorkflowId } from "@/lib/domain/signage";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { importColumnFinder, type ImportColumn } from "@/lib/exports/import-columns";
import { SIGNAGE_KINDS } from "@/lib/edition-path";

const rowSchema = z.object({
  ref: z.string().trim().optional().or(z.literal("")),
  name: z.string().trim().min(1, "Name is required"),
  type: z.string().trim().optional(),
  hall: z.string().trim().optional(),
  location: z.string().trim().optional(),
  standNumber: z.string().trim().max(50).optional(),
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
      z.enum([
        "rigged",
        "freestanding",
        "wall_mounted",
        "shell_mounted",
        "floor",
        "digital",
        "other",
        "",
      ]),
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
    .pipe(
      z.enum(["organiser", "sponsor", ""], { message: "Category must be Organiser or Sponsor" }),
    )
    .optional(),
});

export type ImportOutcome = {
  created: number;
  updated: number;
  errors: { row: number; message: string }[];
  /** A check only (dryRun): nothing was written. */
  dryRun?: boolean;
  /** Halls, locations and suppliers the sheet adds (when createMissing is ticked). */
  adds?: { halls: number; locations: number; suppliers: number };
  /**
   * The "Owner email" column: rows owned by the person named, rows left to
   * you (blank, not on the team, or can't work on that item), and why.
   */
  owners?: { fromSheet: number; toYou: number; notes: { row: number; message: string }[] };
};

/**
 * Excel import (brief §10): parse → validate each row with the shared
 * schema, resolving names case-insensitively → commit in one transaction.
 * Upserts by ref when present, otherwise creates. When createMissing is
 * ticked, unknown suppliers and locations are created on the fly. With
 * dryRun ("on") the sheet is checked the same way and the outcome (new,
 * updated, errors) returned without writing anything.
 */
export async function importSchedule(formData: FormData): Promise<ActionResult<ImportOutcome>> {
  const editionId = formData.get("editionId");
  const file = formData.get("file");
  const createMissing = formData.get("createMissing") === "on";
  const dryRun = formData.get("dryRun") === "on";
  if (typeof editionId !== "string" || !(file instanceof File)) return fail("Invalid import");
  const session = await requireSession();
  // Importing needs both "Add signage" and "Import from Excel and bulk actions".
  if (!can(session.actor, { type: "signage.import" })) return fail("You cannot import items");
  // Ticking "create what's missing" adds halls and locations, or suppliers,
  // only for people who may add them anyway.
  const makeHalls = createMissing && can(session.actor, { type: "halls.manage" });
  const makeSuppliers = createMissing && can(session.actor, { type: "suppliers.manage" });

  const wb = new ExcelJS.Workbook();
  await wb.xlsx.load(await file.arrayBuffer());
  const ws = wb.worksheets[0];
  if (!ws) return fail("The workbook has no sheets");

  // Only into this organisation's own shows, and ones they can open (Users → Events).
  const edition = await ownEdition(db, session.organisation.id, editionId, session.actor);
  if (!edition) return fail("Event not found");
  if (editionIsReadOnly(edition.status)) return fail(EDITION_LOCKED_MESSAGE);

  const [typeRows, hallRows, locationRows, sponsorRows, supplierRows, itemRows] = await Promise.all(
    [
      db
        .select()
        .from(itemTypes)
        .where(
          and(eq(itemTypes.organisationId, session.organisation.id), eq(itemTypes.kind, "signage")),
        ),
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
          supplierId: signageItems.supplierId,
          ownerUserId: signageItems.ownerUserId,
          sponsorId: signageItems.sponsorId,
          requiresVenueApproval: signageItems.requiresVenueApproval,
        })
        .from(signageItems)
        .where(
          and(
            eq(signageItems.editionId, editionId),
            inArray(signageItems.kind, [...SIGNAGE_KINDS]),
          ),
        ),
    ],
  );
  const itemByRef = new Map(itemRows.map((i) => [i.ref.toUpperCase(), i]));
  /** An existing item as authorisation sees it. */
  const itemCtx = (i: (typeof itemRows)[number]): SignageItemCtx => ({
    organisationId: session.organisation.id,
    editionId,
    venueId: edition.venueId,
    kind: i.kind,
    ownerUserId: i.ownerUserId,
    sponsorId: i.sponsorId,
    supplierId: i.supplierId,
    requiresVenueApproval: i.requiresVenueApproval,
    status: i.status,
  });
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
    rows.find((r) => (r.name ?? r.companyName ?? "").toLowerCase() === name.toLowerCase().trim());
  // A live supplier wins over an archived one of the same name.
  const supplierByName = (name: string) =>
    byName(
      supplierRows.filter((r) => !r.isArchived),
      name,
    ) ?? byName(supplierRows, name);

  const parsed: Array<{
    rowNumber: number;
    data: z.infer<typeof rowSchema>;
    ownerEmail: string;
  }> = [];
  const errors: { row: number; message: string }[] = [];

  // Columns are found by their headings, so older sheets still import.
  const headings: string[] = [];
  ws.getRow(1).eachCell({ includeEmpty: true }, (c, i) => {
    const v = c.value;
    headings[i - 1] =
      v == null
        ? ""
        : typeof v === "object" && "richText" in v
          ? v.richText.map((t) => t.text).join("")
          : typeof v === "object" && "text" in v
            ? String(v.text)
            : String(v);
  });
  const column = importColumnFinder(Array.from(headings, (h) => h ?? ""));
  // "Owner email" (or "Owner"): who each new row belongs to.
  const ownerColumn = (() => {
    const i = Array.from(headings, (h) => (h ?? "").toLowerCase().replace(/[^a-z]/g, "")).findIndex(
      (h) => h === "owneremail" || h === "owner",
    );
    return i === -1 ? null : i + 1;
  })();
  const team = await loadTeam(db, session.organisation.id);
  const importerRole = session.actor.kind === "staff" ? session.actor.role : null;
  const ownerNotes: { row: number; message: string }[] = [];
  /**
   * Who owns a row: the person in "Owner email" when they are an active
   * member who can work on this kind of item, otherwise the importer (null
   * for an update leaves the owner as it is).
   */
  const ownerFor = (
    rowNumber: number,
    email: string,
    item: { sponsored: boolean; isUpdate: boolean },
  ): { userId: string; name: string; role: "ops" | "marketing" | null } | null => {
    const trimmed = email.trim().toLowerCase();
    const me = {
      userId: session.user.id,
      name: "you",
      role: ownerRoleOf({ role: importerRole ?? "viewer" }),
    };
    if (!trimmed) return item.isUpdate ? null : me;
    const m = team.find((x) => x.email.toLowerCase() === trimmed);
    const ownable = { kind: "signage" as const, sponsored: item.sponsored };
    const purpose = { type: "owner" as const, item: ownable, editionId: edition.id };
    const refusal = refusalFor(purpose, m, {
      organisationId: session.organisation.id,
    });
    if (!m || refusal) {
      const why = !m
        ? `${email.trim()} isn't on the team`
        : refusalMessage(m.name, refusal!, purpose).replace(/ — pick someone else$/, "");
      ownerNotes.push({
        row: rowNumber,
        message: item.isUpdate ? `${why} — owner left as it was` : `${why} — given to you`,
      });
      return item.isUpdate ? null : me;
    }
    return { userId: m.userId, name: m.name, role: ownerRoleOf(m) };
  };

  ws.eachRow((row, rowNumber) => {
    if (rowNumber === 1) return; // header
    const cell = (i: number) => {
      const v = row.getCell(i).value;
      if (v == null) return "";
      if (typeof v === "object" && "text" in v) return String(v.text);
      if (v instanceof Date) return v.toISOString().slice(0, 10);
      return String(v);
    };
    const at = (name: ImportColumn) => {
      const i = column(name);
      return i ? cell(i) : "";
    };
    const raw = {
      ref: at("Ref"),
      name: at("Name"),
      type: at("Type"),
      hall: at("Hall"),
      location: at("Location"),
      standNumber: at("Stand no."),
      widthMm: at("Width mm") || null,
      heightMm: at("Height mm") || null,
      quantity: at("Quantity") || null,
      sided: at("Sided"),
      material: at("Material"),
      finish: at("Finish"),
      fixing: at("Fixing"),
      sponsor: at("Sponsor"),
      supplier: at("Supplier"),
      requiresVenueApproval: at("Requires venue approval"),
      costEstimate: at("Cost estimate") || null,
      installDate: at("Install date"),
      installSlot: at("Install slot"),
      description: at("Description"),
      category: at("Category"),
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
        if (!existing)
          return rowError(`No item ${d.ref} in this event — leave Ref blank to add a new one`);
        if (existing.deletedAt) return rowError(`${d.ref} was deleted — restore it first`);
        if (existing.kind !== "signage")
          return rowError(`${d.ref} is a sponsorship item, not signage`);
        if (!EDITABLE.has(existing.status)) {
          return rowError(`${d.ref} is already in sign-off — change it on its page`);
        }
        if (!can(session.actor, { type: "signage.edit", item: itemCtx(existing) })) {
          return rowError(`${d.ref} isn't yours to change`);
        }
        // Supplier and cost are left as they are for people who can't edit costs.
        if (!can(session.actor, { type: "costs.edit", item: itemCtx(existing) })) {
          d.supplier = undefined;
          d.costEstimate = undefined;
        }
      }
      // Unknown reference data is an error unless createMissing covers it.
      if (d.type && !byName(typeRows, d.type)) return rowError(`Unknown item type “${d.type}”`);
      if (d.sponsor && !byName(sponsorRows, d.sponsor))
        return rowError(`Unknown sponsor “${d.sponsor}”`);
      const hall = d.hall ? byName(hallRows, d.hall) : undefined;
      if (d.hall && !hall && !makeHalls) return rowError(`Unknown hall “${d.hall}”`);
      if (d.location) {
        const loc = hall
          ? findLocation(d.location, hall.id)
          : d.hall
            ? undefined
            : findLocation(d.location, undefined);
        if (loc === "ambiguous") {
          return rowError(`Location “${d.location}” is in more than one hall — add the hall`);
        }
        if (!loc && !makeHalls) return rowError(`Unknown location “${d.location}”`);
        if (!loc && !d.hall) return rowError(`Location “${d.location}” needs a hall`);
      }
      const supplier = d.supplier ? supplierByName(d.supplier) : undefined;
      if (!makeSuppliers && d.supplier && !supplier) {
        return rowError(`Unknown supplier “${d.supplier}”`);
      }
      // An archived supplier stays on an item that has it, but isn't picked anew.
      const current = d.ref ? itemByRef.get(d.ref.toUpperCase()) : undefined;
      if (supplier?.isArchived && supplier.id !== current?.supplierId) {
        return rowError(archivedSupplierMessage(supplier.name));
      }
      parsed.push({
        rowNumber,
        data: d,
        ownerEmail: ownerColumn ? cell(ownerColumn) : "",
      });
    }
  });

  if (errors.length > 0) {
    return success(
      { created: 0, updated: 0, errors, ...(dryRun ? { dryRun: true } : {}) },
      "Fix the highlighted rows and re-upload",
    );
  }
  if (parsed.length === 0) return fail("No rows found to import");
  // Who owns each row, worked out once for the check and the import alike.
  const owners = parsed.map(({ rowNumber, data, ownerEmail }) =>
    ownerFor(rowNumber, ownerEmail, {
      sponsored: Boolean(data.sponsor) || data.category === "sponsor",
      isUpdate: Boolean(data.ref),
    }),
  );
  // The template always has the column; report on it only when someone filled it in.
  const ownersUsed = Boolean(ownerColumn) && parsed.some((p) => p.ownerEmail.trim() !== "");
  const ownerSummary = {
    fromSheet: owners.filter((o) => o && o.userId !== session.user.id).length,
    toYou: parsed.filter((p, i) => !p.data.ref && owners[i]?.userId === session.user.id).length,
    notes: ownerNotes,
  };
  const ownerWords =
    ownerColumn && ownerSummary.fromSheet + ownerNotes.length > 0
      ? ` — ${ownerSummary.fromSheet} owned by the people named${ownerNotes.length ? `, ${ownerNotes.length} left to you or unchanged (see the rows)` : ""}`
      : "";

  if (dryRun) {
    // What the import would do, worked out the same way as below.
    const updated = parsed.filter((p) => p.data.ref).length;
    const newSuppliers = new Set<string>();
    const newHalls = new Set<string>();
    const newLocations = new Set<string>();
    for (const { data } of parsed) {
      if (data.supplier && !supplierByName(data.supplier)) {
        newSuppliers.add(data.supplier.toLowerCase());
      }
      const hall = data.hall ? byName(hallRows, data.hall) : undefined;
      if (data.hall && !hall) newHalls.add(data.hall.toLowerCase());
      if (data.location) {
        const found = hall
          ? findLocation(data.location, hall.id)
          : data.hall
            ? undefined
            : findLocation(data.location, undefined);
        if (!found && data.hall) {
          newLocations.add(`${data.hall.toLowerCase()}\u0000${data.location.toLowerCase().trim()}`);
        }
      }
    }
    return success(
      {
        created: parsed.length - updated,
        updated,
        errors: [],
        dryRun: true,
        adds: {
          halls: newHalls.size,
          locations: newLocations.size,
          suppliers: newSuppliers.size,
        },
        ...(ownersUsed ? { owners: ownerSummary } : {}),
      },
      `Checked: ${parsed.length - updated} new, ${updated} updated, nothing imported yet${ownerWords}`,
    );
  }

  try {
    let created = 0;
    let updated = 0;
    const given = new Map<string, { name: string; items: OwnerChange[] }>();
    await db.transaction(async (tx) => {
      for (const [index, { data }] of parsed.entries()) {
        const owner = owners[index];
        let supplierId: string | null | undefined;
        if (data.supplier) {
          const existing = supplierByName(data.supplier);
          if (existing) supplierId = existing.id;
          else {
            const [ns] = await tx
              .insert(suppliers)
              .values({
                organisationId: session.organisation.id,
                name: data.supplier,
                kind: "other",
              })
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
        const sponsorId = data.sponsor
          ? (byName(sponsorRows, data.sponsor)?.id ?? null)
          : undefined;
        // Blank cells leave existing values alone; only filled cells change.
        const values = Object.fromEntries(
          Object.entries({
            name: data.name,
            description: data.description || undefined,
            itemTypeId,
            hallId: hall?.id,
            locationId,
            standNumber: data.standNumber || undefined,
            widthMm: data.widthMm ?? undefined,
            heightMm: data.heightMm ?? undefined,
            quantity: data.quantity ?? undefined,
            sided: (data.sided || undefined) as "single" | "double" | undefined,
            material: data.material || undefined,
            finish: data.finish || undefined,
            fixingMethod: (data.fixing || undefined) as
              typeof signageItems.$inferSelect.fixingMethod | undefined,
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
        const note = (o: NonNullable<typeof owner>, item: OwnerChange) => {
          if (o.userId === session.user.id) return;
          const entry = given.get(o.userId) ?? { name: o.name, items: [] };
          entry.items.push(item);
          given.set(o.userId, entry);
        };
        if (existing) {
          // An update changes the owner only when the sheet names someone who can own it.
          const ownerSet =
            owner && owner.userId !== existing.ownerUserId
              ? { ownerUserId: owner.userId, ...(owner.role ? { ownerRole: owner.role } : {}) }
              : {};
          await tx
            .update(signageItems)
            .set({ ...values, ...ownerSet })
            .where(eq(signageItems.id, existing.id));
          if (owner && "ownerUserId" in ownerSet) {
            note(owner, {
              id: existing.id,
              ref: existing.ref,
              name: data.name,
              kind: existing.kind,
              editionCode: edition.code,
              fromUserId: existing.ownerUserId,
            });
          }
          updated++;
        } else {
          const { ref, seq } = await nextSignageRef(tx, editionId, edition.code);
          const o = owner ?? { userId: session.user.id, name: "you", role: null };
          const [row] = await tx
            .insert(signageItems)
            .values({
              ...values,
              name: data.name,
              editionId,
              ref,
              seq,
              kind: "signage",
              // Blank category: sponsored rows are sponsor signage, the rest organiser.
              category: data.category || (values.sponsorId ? "sponsor" : "organiser"),
              // The owning team follows the owner, as when adding a sign.
              ownerRole: o.role ?? "ops",
              ownerUserId: o.userId,
              workflowId: await defaultSignageWorkflowId(
                tx,
                session.organisation.id,
                values.itemTypeId ?? null,
              ),
              isSponsorDeliverable: Boolean(values.sponsorId),
              createdBy: session.user.id,
            })
            .returning({ id: signageItems.id });
          note(o, {
            id: row.id,
            ref,
            name: data.name,
            kind: "signage",
            editionCode: edition.code,
            fromUserId: null,
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
        after: {
          created,
          updated,
          rows: parsed.length,
          ...(ownerColumn
            ? { owners: [...given].map(([userId, g]) => ({ userId, items: g.items.length })) }
            : {}),
        },
        summary: `Schedule import: ${created} created, ${updated} updated${
          given.size ? ` — given to ${[...given.values()].map((g) => g.name).join(", ")}` : ""
        }`,
      });
      // Each person named in the sheet hears once which items are theirs.
      for (const [userId, g] of given) {
        await notifyOwnerChange(tx, {
          actor: { id: session.user.id, name: session.user.fullName || session.user.email },
          to: { id: userId, name: g.name },
          items: g.items,
        });
      }
    });
    revalidatePath("/", "layout");
    return success(
      { created, updated, errors: [], ...(ownersUsed ? { owners: ownerSummary } : {}) },
      `Imported ${created + updated} rows (${created} new, ${updated} updated)${ownerWords}`,
    );
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Import failed");
  }
}
