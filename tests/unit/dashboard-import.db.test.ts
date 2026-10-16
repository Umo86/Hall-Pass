/**
 * The schedule import's check (dry run) against a real database
 * (TEST_DATABASE_URL), with the session stubbed. The import sheet is
 * started from the dashboard, Setup and the Signage page; the check says
 * "2 new, 1 updated, 0 errors" (and what it would add) without writing
 * anything, and the real import then does exactly that, audited.
 */
import { randomUUID } from "node:crypto";
import ExcelJS from "exceljs";
import { and, count, eq } from "drizzle-orm";
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
let actions: typeof import("@/app/actions/import");
const n = Date.now() % 1_000_000;
const code = `IMP${n}`;
let orgId: string;
let editionId: string;
const people: Record<string, { id: string; role: StaffRole }> = {};

function as(key: string) {
  const p = people[key];
  const session: Session = {
    actor: {
      kind: "staff",
      userId: p.id,
      organisationId: orgId,
      role: p.role,
      signoffDepartmentIds: [],
    },
    user: { id: p.id, email: `${key}-${n}@import.test`, fullName: key, isExternal: false },
    organisation: {
      id: orgId,
      brandName: "Hall Pass",
      settings: {} as Session["organisation"]["settings"],
    },
  } as Session;
  state.session = session;
}

async function sheet(rows: Record<string, string>[]): Promise<File> {
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet("Signs");
  // The template's own headings (missing ones fall back to their old places).
  const headings: string[] = [...IMPORT_COLUMNS];
  ws.addRow(headings);
  for (const r of rows) ws.addRow(headings.map((h) => r[h] ?? ""));
  const buf = Buffer.from(await wb.xlsx.writeBuffer());
  return new File([buf], "schedule.xlsx", {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
}

function form(file: File, opts: { dryRun?: boolean; createMissing?: boolean } = {}) {
  const fd = new FormData();
  fd.set("editionId", editionId);
  fd.set("file", file);
  if (opts.dryRun) fd.set("dryRun", "on");
  if (opts.createMissing) fd.set("createMissing", "on");
  return fd;
}

async function snapshot() {
  const [items] = await db
    .select({ n: count() })
    .from(schema.signageItems)
    .where(eq(schema.signageItems.editionId, editionId));
  const [hallCount] = await db
    .select({ n: count() })
    .from(schema.halls)
    .where(eq(schema.halls.editionId, editionId));
  const [supplierCount] = await db
    .select({ n: count() })
    .from(schema.suppliers)
    .where(eq(schema.suppliers.organisationId, orgId));
  const [audits] = await db
    .select({ n: count() })
    .from(schema.auditLog)
    .where(and(eq(schema.auditLog.entityId, editionId), eq(schema.auditLog.action, "import")));
  const [existing] = await db
    .select({ name: schema.signageItems.name })
    .from(schema.signageItems)
    .where(eq(schema.signageItems.ref, `SIG-${code}-001`));
  return {
    items: items.n,
    halls: hallCount.n,
    suppliers: supplierCount.n,
    audits: audits.n,
    existingName: existing?.name,
  };
}

const rows: Record<string, string>[] = [
  { Name: `Entrance totem ${n}`, Hall: "Hall 1", Location: "Entrance" },
  { Ref: `SIG-${code}-001`, Name: `Renamed banner ${n}` },
  { Name: `Foyer flag ${n}`, Hall: "Hall 9", Location: "Foyer", Supplier: `New Print ${n}` },
];

d("schedule import: check first, then import", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    actions = await import("@/app/actions/import");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Import Org", slug: `import-${n}` })
      .returning();
    orgId = org.id;
    for (const [key, role] of [
      ["ops", "ops"],
      ["viewer", "viewer"],
    ] as const) {
      const id = randomUUID();
      await db.insert(schema.users).values({ id, email: `${key}-${n}@import.test`, fullName: key });
      await db.insert(schema.memberships).values({ userId: id, organisationId: orgId, role });
      people[key] = { id, role };
    }
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: `Import ${n}`, code: `IE${n}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: `Import venue ${n}`, code: `IV${n}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: `Import ${n}`,
        code,
        buildStart: "2027-10-01",
        buildEnd: "2027-10-04",
        openStart: "2027-10-05",
        openEnd: "2027-10-07",
        breakdownEnd: "2027-10-08",
      })
      .returning();
    editionId = edition.id;
    const [hall] = await db
      .insert(schema.halls)
      .values({ editionId, name: "Hall 1", sortOrder: 0 })
      .returning();
    await db.insert(schema.locations).values({ hallId: hall.id, name: "Entrance" });
    await db.insert(schema.signageItems).values({
      editionId,
      ref: `SIG-${code}-001`,
      seq: 1,
      name: "Old banner",
      kind: "signage",
    });
    // Keep the ref counter past the item made above.
    await db.insert(schema.editionCounters).values({ editionId, key: "signage", value: 1 });
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

  it("a check says what would happen and changes nothing", async () => {
    as("ops");
    const before = await snapshot();
    const res = await actions.importSchedule(
      form(await sheet(rows), { dryRun: true, createMissing: true }),
    );
    expect(res.ok).toBe(true);
    expect(res.ok && res.data).toEqual({
      created: 2,
      updated: 1,
      errors: [],
      dryRun: true,
      adds: { halls: 1, locations: 1, suppliers: 1 },
    });
    expect(await snapshot()).toEqual(before);
    expect(before.existingName).toBe("Old banner");
  });

  it("a check lists the rows to fix, the same as a real import would", async () => {
    as("ops");
    const res = await actions.importSchedule(form(await sheet(rows), { dryRun: true }));
    expect(res.ok && res.data).toEqual({
      created: 0,
      updated: 0,
      errors: [{ row: 4, message: "Unknown hall “Hall 9”" }],
      dryRun: true,
    });
  });

  it("people who can't add signs can't check a sheet either", async () => {
    as("viewer");
    const res = await actions.importSchedule(form(await sheet(rows), { dryRun: true }));
    expect(res).toMatchObject({ ok: false, error: "You cannot import items" });
  });

  it("the import then does what the check said, with one audit row", async () => {
    as("ops");
    const before = await snapshot();
    const res = await actions.importSchedule(form(await sheet(rows), { createMissing: true }));
    expect(res.ok && res.data).toEqual({ created: 2, updated: 1, errors: [] });
    const after = await snapshot();
    expect(after.items).toBe(before.items + 2);
    expect(after.halls).toBe(before.halls + 1);
    expect(after.suppliers).toBe(before.suppliers + 1);
    expect(after.audits).toBe(before.audits + 1);
    expect(after.existingName).toBe(`Renamed banner ${n}`);
  });
});
