/**
 * Archived suppliers against a real database (TEST_DATABASE_URL), with the
 * session stubbed: they are left out of the item form's picker except on an
 * item that already uses one, and choosing one anew (item form, new item,
 * new panel through the shared link check, bulk "Set supplier", import) is
 * refused in plain words. An item keeps the archived supplier it already has.
 * Archived venues follow the same rule for events.
 */
import { randomUUID } from "node:crypto";
import ExcelJS from "exceljs";
import { and, desc, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";
import type { Session } from "@/lib/auth/actor";
import type { StaffRole } from "@/lib/authz";
import { IMPORT_COLUMNS } from "@/lib/exports/import-columns";

const state = vi.hoisted(() => ({ session: null as unknown }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn(), revalidateTag: vi.fn() }));
vi.mock("@/lib/auth/actor", () => ({
  requireSession: async () => state.session,
  requireStaffSession: async () => state.session,
}));

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let signage: typeof import("@/app/actions/signage");
let bulk: typeof import("@/app/actions/signage-bulk");
let options: typeof import("@/lib/queries/item-form-options");
let domain: typeof import("@/lib/domain/signage");
let importer: typeof import("@/app/actions/import");
let editionActions: typeof import("@/app/actions/editions");
const n = Date.now() % 1_000_000;
let orgId: string;
let editionId: string;
let venueId: string;
const people: Record<string, { id: string; role: StaffRole }> = {};
const supplier: Record<"live" | "usedArchived" | "unusedArchived", string> = {
  live: "",
  usedArchived: "",
  unusedArchived: "",
};
let itemId: string;

async function addUser(key: string, role: StaffRole) {
  const id = randomUUID();
  await db.insert(schema.users).values({ id, email: `${key}-${n}@arch.test`, fullName: key });
  await db.insert(schema.memberships).values({ userId: id, organisationId: orgId, role });
  people[key] = { id, role };
}

function as(key: string) {
  const p = people[key];
  const session: Session = {
    actor: { kind: "staff", userId: p.id, organisationId: orgId, role: p.role },
    user: { id: p.id, email: `${key}@arch.test`, fullName: key, isExternal: false },
    organisation: {
      id: orgId,
      brandName: "Hall Pass",
      settings: {} as Session["organisation"]["settings"],
    },
  };
  state.session = session;
}

async function supplierOf(id: string) {
  const [row] = await db
    .select({ supplierId: schema.signageItems.supplierId })
    .from(schema.signageItems)
    .where(eq(schema.signageItems.id, id));
  return row?.supplierId ?? null;
}

const names = (o: { suppliers: { name: string }[] }) => o.suppliers.map((s) => s.name).sort();

/** An import sheet with the template's headings. */
async function sheet(rows: Record<string, string>[]): Promise<FormData> {
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet("Signs");
  const headings: string[] = [...IMPORT_COLUMNS];
  ws.addRow(headings);
  for (const r of rows) ws.addRow(headings.map((h) => r[h] ?? ""));
  const buf = Buffer.from(await wb.xlsx.writeBuffer());
  const fd = new FormData();
  fd.set("editionId", editionId);
  fd.set(
    "file",
    new File([buf], "schedule.xlsx", {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    }),
  );
  fd.set("dryRun", "on");
  return fd;
}

d("archived suppliers", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    signage = await import("@/app/actions/signage");
    bulk = await import("@/app/actions/signage-bulk");
    options = await import("@/lib/queries/item-form-options");
    domain = await import("@/lib/domain/signage");
    importer = await import("@/app/actions/import");
    editionActions = await import("@/app/actions/editions");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Archive Org", slug: `archive-${n}` })
      .returning();
    orgId = org.id;
    await addUser("ops", "ops");
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Archive Event", code: `AR${n}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Archive Venue", code: `ARV${n}` })
      .returning();
    venueId = venue.id;
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Archive Edition",
        code: `ARC${n}`,
        buildStart: "2027-10-01",
        buildEnd: "2027-10-04",
        openStart: "2027-10-05",
        openEnd: "2027-10-07",
        breakdownEnd: "2027-10-08",
      })
      .returning();
    editionId = edition.id;
    const rows = await db
      .insert(schema.suppliers)
      .values([
        { organisationId: orgId, name: "Live Print" },
        { organisationId: orgId, name: "Old Print", isArchived: true },
        { organisationId: orgId, name: "Gone Print", isArchived: true },
      ])
      .returning();
    supplier.live = rows.find((r) => r.name === "Live Print")!.id;
    supplier.usedArchived = rows.find((r) => r.name === "Old Print")!.id;
    supplier.unusedArchived = rows.find((r) => r.name === "Gone Print")!.id;
    const [item] = await db
      .insert(schema.signageItems)
      .values({
        editionId,
        ref: `SIG-ARC${n}-001`,
        seq: 1,
        name: "Sign with an archived supplier",
        status: "draft",
        createdBy: people.ops.id,
        ownerUserId: people.ops.id,
        supplierId: supplier.usedArchived,
      })
      .returning();
    itemId = item.id;
  });

  afterAll(async () => {
    if (editionId) {
      await db
        .update(schema.signageItems)
        .set({ deletedAt: new Date() })
        .where(eq(schema.signageItems.editionId, editionId));
    }
    await client?.end();
  });

  it("the new-item picker lists live suppliers only", async () => {
    const o = await options.itemFormOptions({
      organisationId: orgId,
      editionId,
      kind: "signage",
      withWorkflows: true,
    });
    expect(names(o)).toEqual(["Live Print"]);
  });

  it("an item's own archived supplier stays in its picker, marked archived", async () => {
    const o = await options.itemFormOptions({
      organisationId: orgId,
      editionId,
      kind: "signage",
      includeSupplierId: supplier.usedArchived,
    });
    expect(names(o)).toEqual(["Live Print", "Old Print (archived)"]);
    const none = await options.itemFormOptions({
      organisationId: orgId,
      editionId,
      kind: "signage",
      includeSupplierId: null,
    });
    expect(names(none)).toEqual(["Live Print"]);
  });

  it("an edit form that doesn't say which item keeps archived suppliers this event uses", async () => {
    const o = await options.itemFormOptions({ organisationId: orgId, editionId, kind: "signage" });
    expect(names(o)).toEqual(["Live Print", "Old Print (archived)"]);
  });

  it("the item form refuses an archived supplier picked anew", async () => {
    as("ops");
    const res = await signage.updateSignageItem({
      id: itemId,
      name: "Sign with an archived supplier",
      supplierId: supplier.unusedArchived,
    });
    expect(res.ok).toBe(false);
    expect(!res.ok && res.error).toBe(
      "Gone Print is archived — restore it in Suppliers, or choose another supplier",
    );
    expect(await supplierOf(itemId)).toBe(supplier.usedArchived);
  });

  it("saving an item that already has an archived supplier keeps it", async () => {
    as("ops");
    const res = await signage.updateSignageItem({
      id: itemId,
      name: "Sign with an archived supplier (renamed)",
      supplierId: supplier.usedArchived,
    });
    expect(res).toMatchObject({ ok: true });
    expect(await supplierOf(itemId)).toBe(supplier.usedArchived);
    const [audit] = await db
      .select()
      .from(schema.auditLog)
      .where(and(eq(schema.auditLog.entityId, itemId), eq(schema.auditLog.action, "update")))
      .orderBy(desc(schema.auditLog.createdAt))
      .limit(1);
    expect(audit?.summary).toContain("(name)");
  });

  it("a new item can't start with an archived supplier", async () => {
    as("ops");
    const res = await signage.createSignageItem({
      editionId,
      name: "New sign",
      supplierId: supplier.usedArchived,
    });
    expect(res.ok).toBe(false);
    expect(!res.ok && res.error).toMatch(/^Old Print is archived/);
  });

  it("every caller of the link check refuses an archived supplier picked anew", async () => {
    const check = (supplierId: string, currentSupplierId?: string | null) =>
      domain.assertItemLinks(db, {
        organisationId: orgId,
        editionId,
        links: { supplierId },
        currentSupplierId,
      });
    await expect(check(supplier.unusedArchived)).rejects.toThrow(
      "Gone Print is archived — restore it in Suppliers, or choose another supplier",
    );
    await expect(check(supplier.usedArchived, supplier.live)).rejects.toThrow(/^Old Print/);
    await expect(check(supplier.usedArchived, supplier.usedArchived)).resolves.toBeUndefined();
    await expect(check(supplier.live)).resolves.toBeUndefined();
  });

  it("an import can't pick an archived supplier, but keeps one an item already has", async () => {
    as("ops");
    const refused = await importer.importSchedule(
      await sheet([{ Name: "Imported sign", Supplier: "gone print" }]),
    );
    expect(refused.ok && refused.data?.errors).toEqual([
      {
        row: 2,
        message: "Gone Print is archived — restore it in Suppliers, or choose another supplier",
      },
    ]);
    const kept = await importer.importSchedule(
      await sheet([{ Ref: `SIG-ARC${n}-001`, Name: "Renamed", Supplier: "Old Print" }]),
    );
    expect(kept.ok && kept.data?.errors).toEqual([]);
  });

  it("an archived venue can't be chosen for a new event or moved to, but an event keeps its own", async () => {
    as("ops");
    const [closed] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Closed Venue", code: `CLV${n}`, isArchived: true })
      .returning();
    const message =
      "Closed Venue is archived — restore it in Settings → Venues, or choose another venue";
    const created = await editionActions.createEdition({
      name: "New at a closed venue",
      code: `NC${n}`,
      openStart: "2027-11-05",
      openEnd: "2027-11-06",
      venueId: closed.id,
    });
    expect(created).toMatchObject({ ok: false, error: message });
    const details = {
      id: editionId,
      name: "Archive Edition",
      buildStart: "2027-10-01",
      buildEnd: "2027-10-04",
      openStart: "2027-10-05",
      openEnd: "2027-10-07",
      breakdownEnd: "2027-10-08",
    };
    const moved = await editionActions.saveEventDetails({ ...details, venueId: closed.id });
    expect(moved).toMatchObject({ ok: false, error: message });
    // The event's own venue, archived since, still saves.
    await db.update(schema.venues).set({ isArchived: true }).where(eq(schema.venues.id, venueId));
    const kept = await editionActions.saveEventDetails({ ...details, venueId });
    expect(kept).toMatchObject({ ok: true });
  });

  it("bulk Set supplier refuses an archived supplier and takes a live one", async () => {
    as("ops");
    const refused = await bulk.bulkSignageAction({
      ids: [itemId],
      action: "set_supplier",
      supplierId: supplier.unusedArchived,
    });
    expect(refused.ok).toBe(false);
    expect(!refused.ok && refused.error).toMatch(/^Gone Print is archived/);
    expect(await supplierOf(itemId)).toBe(supplier.usedArchived);

    const ok = await bulk.bulkSignageAction({
      ids: [itemId],
      action: "set_supplier",
      supplierId: supplier.live,
    });
    expect(ok).toMatchObject({ ok: true });
    expect(await supplierOf(itemId)).toBe(supplier.live);
  });
});
