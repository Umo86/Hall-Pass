/**
 * Suppliers, venues and organisation settings against a real database
 * (TEST_DATABASE_URL), with the session stubbed: suppliers archive and
 * restore with an audit row, can only be deleted when nothing (live or
 * deleted) uses them; venues get a code made from their name and can be
 * archived; organisation settings are saved with an audit row; people
 * without settings.manage are refused.
 */
import { randomUUID } from "node:crypto";
import { and, desc, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";
import type { Session } from "@/lib/auth/actor";
import type { StaffRole } from "@/lib/authz";

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
let supplierActions: typeof import("@/app/actions/suppliers");
let directory: typeof import("@/app/actions/directory");
let organisation: typeof import("@/app/actions/organisation");
const n = Date.now() % 1_000_000;
let orgId: string;
let editionId: string;
const people: Record<string, { id: string; role: StaffRole }> = {};

async function addUser(key: string, role: StaffRole) {
  const id = randomUUID();
  await db.insert(schema.users).values({ id, email: `${key}-${n}@sup.test`, fullName: key });
  await db.insert(schema.memberships).values({ userId: id, organisationId: orgId, role });
  people[key] = { id, role };
}

function as(key: string) {
  const p = people[key];
  const session: Session = {
    actor: { kind: "staff", userId: p.id, organisationId: orgId, role: p.role },
    user: { id: p.id, email: `${key}@sup.test`, fullName: key, isExternal: false },
    organisation: {
      id: orgId,
      brandName: "Hall Pass",
      settings: {} as Session["organisation"]["settings"],
    },
  };
  state.session = session;
}

async function lastAudit(entityId: string) {
  const [row] = await db
    .select()
    .from(schema.auditLog)
    .where(eq(schema.auditLog.entityId, entityId))
    .orderBy(desc(schema.auditLog.createdAt))
    .limit(1);
  return row;
}

let seq = 0;
async function item(supplierId: string, deleted = false) {
  seq++;
  await db.insert(schema.signageItems).values({
    editionId,
    ref: `SIG-SUP${n}-${String(seq).padStart(3, "0")}`,
    seq,
    name: `Supplier sign ${seq}`,
    supplierId,
    createdBy: people.ops.id,
    deletedAt: deleted ? new Date() : null,
  });
}

async function supplierId(name: string) {
  const row = await db.query.suppliers.findFirst({
    where: and(eq(schema.suppliers.organisationId, orgId), eq(schema.suppliers.name, name)),
  });
  return row!.id;
}

d("suppliers, venues and organisation settings", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    supplierActions = await import("@/app/actions/suppliers");
    directory = await import("@/app/actions/directory");
    organisation = await import("@/app/actions/organisation");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Suppliers Org", slug: `suppliers-${n}` })
      .returning();
    orgId = org.id;
    await addUser("admin", "admin");
    await addUser("ops", "ops");
    await addUser("viewer", "viewer");
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Supplier Event", code: `SE${n}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Supplier Venue", code: `SV${n}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Supplier Edition",
        code: `SUP${n}`,
        buildStart: "2027-10-01",
        buildEnd: "2027-10-04",
        openStart: "2027-10-05",
        openEnd: "2027-10-07",
        breakdownEnd: "2027-10-08",
      })
      .returning();
    editionId = edition.id;
  });

  afterAll(async () => {
    await client?.end();
  });

  it("refuses supplier changes from people without suppliers.manage", async () => {
    as("viewer");
    const res = await supplierActions.saveSupplier({ name: "Nope Ltd" });
    expect(res).toMatchObject({
      ok: false,
      error: "You need “Manage suppliers” for that — ask a super admin",
    });
    const archived = await supplierActions.setSupplierArchived({
      id: randomUUID(),
      archived: true,
    });
    expect(archived.ok).toBe(false);
  });

  it("archives and restores a supplier, with an audit row each time", async () => {
    as("ops");
    const saved = await supplierActions.saveSupplier({ name: "Archive Print Co" });
    expect(saved).toMatchObject({ ok: true, message: "Archive Print Co saved" });
    const id = saved.ok ? saved.data!.id : "";
    await item(id);

    const archived = await supplierActions.setSupplierArchived({ id, archived: true });
    expect(archived).toMatchObject({ ok: true });
    expect(archived.ok && archived.message).toMatch(/Archive Print Co archived/);
    let row = await db.query.suppliers.findFirst({ where: eq(schema.suppliers.id, id) });
    expect(row!.isArchived).toBe(true);
    let audit = await lastAudit(id);
    expect(audit.summary).toBe("Archived supplier Archive Print Co");
    expect(audit.actorUserId).toBe(people.ops.id);

    const restored = await supplierActions.setSupplierArchived({ id, archived: false });
    expect(restored).toMatchObject({ ok: true, message: "Archive Print Co restored" });
    row = await db.query.suppliers.findFirst({ where: eq(schema.suppliers.id, id) });
    expect(row!.isArchived).toBe(false);
    audit = await lastAudit(id);
    expect(audit.summary).toBe("Restored supplier Archive Print Co");
  });

  it("won't archive another organisation's supplier", async () => {
    const [other] = await db
      .insert(schema.organisations)
      .values({ name: "Other Org", slug: `other-sup-${n}` })
      .returning();
    const [theirs] = await db
      .insert(schema.suppliers)
      .values({ organisationId: other.id, name: "Their Supplier" })
      .returning();
    as("admin");
    const res = await supplierActions.setSupplierArchived({ id: theirs.id, archived: true });
    expect(res.ok).toBe(false);
    const row = await db.query.suppliers.findFirst({ where: eq(schema.suppliers.id, theirs.id) });
    expect(row!.isArchived).toBe(false);
  });

  it("deletes only a supplier nothing uses, and says why otherwise", async () => {
    as("ops");
    await supplierActions.saveSupplier({ name: "Live Use Ltd" });
    await supplierActions.saveSupplier({ name: "Deleted Use Ltd" });
    await supplierActions.saveSupplier({ name: "Portal Use Ltd" });
    await supplierActions.saveSupplier({ name: "Unused Ltd" });
    const live = await supplierId("Live Use Ltd");
    const deleted = await supplierId("Deleted Use Ltd");
    const portal = await supplierId("Portal Use Ltd");
    const unused = await supplierId("Unused Ltd");
    await item(live);
    await item(deleted, true);
    await db.insert(schema.externalGrants).values({
      invitedEmail: `portal-${n}@sup.test`,
      organisationId: orgId,
      editionId,
      role: "supplier",
      scopeType: "supplier",
      scopeId: portal,
      inviteTokenHash: `hash-${n}`,
    });

    const a = await supplierActions.deleteSupplier({ id: live });
    expect(a).toMatchObject({ ok: false });
    expect(!a.ok && a.error).toMatch(/is the supplier on 1 item\. Archive it instead/);

    const b = await supplierActions.deleteSupplier({ id: deleted });
    expect(!b.ok && b.error).toMatch(/1 deleted item still uses Deleted Use Ltd.*Recycle bin/);

    const c = await supplierActions.deleteSupplier({ id: portal });
    expect(!c.ok && c.error).toMatch(/1 person from Portal Use Ltd has portal access/);

    const ok = await supplierActions.deleteSupplier({ id: unused });
    expect(ok).toMatchObject({ ok: true, message: "Unused Ltd deleted" });
    expect(await db.query.suppliers.findFirst({ where: eq(schema.suppliers.id, unused) })).toBe(
      undefined,
    );
    const audit = await lastAudit(unused);
    expect(audit.summary).toBe("Deleted supplier Unused Ltd (unused)");

    // Still there.
    for (const id of [live, deleted, portal]) {
      expect(
        await db.query.suppliers.findFirst({ where: eq(schema.suppliers.id, id) }),
      ).toBeTruthy();
    }
  });

  it("makes a venue code from the name, keeps it on edit, and archives the venue", async () => {
    as("ops");
    const first = await directory.saveDirectoryEntry({
      type: "venue",
      values: { name: `Excel ${n}`, address: "Royal Victoria Dock" },
    });
    expect(first).toMatchObject({ ok: true, message: `Excel ${n} saved` });
    const second = await directory.saveDirectoryEntry({
      type: "venue",
      values: { name: `Excel ${n}` },
    });
    expect(second.ok).toBe(true);
    const rows = await db
      .select()
      .from(schema.venues)
      .where(and(eq(schema.venues.organisationId, orgId), eq(schema.venues.name, `Excel ${n}`)))
      .orderBy(schema.venues.createdAt);
    expect(rows.map((r) => r.code)).toEqual([`EXCEL${n}`, `EXCEL${n}-2`]);

    const edited = await directory.saveDirectoryEntry({
      type: "venue",
      id: rows[0].id,
      values: { name: `ExCeL ${n}`, address: "1 Western Gateway" },
    });
    expect(edited.ok).toBe(true);
    const after = await db.query.venues.findFirst({ where: eq(schema.venues.id, rows[0].id) });
    expect(after).toMatchObject({ name: `ExCeL ${n}`, code: `EXCEL${n}` });

    const archived = await directory.setVenueArchived({ id: rows[0].id, archived: true });
    expect(archived.ok).toBe(true);
    const gone = await db.query.venues.findFirst({ where: eq(schema.venues.id, rows[0].id) });
    expect(gone!.isArchived).toBe(true);
    expect((await lastAudit(rows[0].id)).summary).toBe(`Archived venue ExCeL ${n}`);

    as("viewer");
    const refused = await directory.setVenueArchived({ id: rows[0].id, archived: false });
    expect(refused.ok).toBe(false);
  });

  it("renames an event series without asking for a code", async () => {
    as("admin");
    const [series] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Old Series", code: `OLD${n}` })
      .returning();
    const res = await directory.saveDirectoryEntry({
      type: "event",
      id: series.id,
      values: { name: "New Series" },
    });
    expect(res).toMatchObject({ ok: true, message: "New Series saved" });
    const row = await db.query.events.findFirst({ where: eq(schema.events.id, series.id) });
    expect(row).toMatchObject({ name: "New Series", code: `OLD${n}` });
    expect((await lastAudit(series.id)).summary).toBe("Updated event series New Series");
  });

  it("saves organisation settings with an audit row, keeping the rest", async () => {
    as("viewer");
    const refused = await organisation.updateOrganisationSettings({
      brandName: "Nope",
      currency: "GBP",
      escalateAfterDays: 2,
      installPhotoRequired: true,
    });
    expect(refused).toMatchObject({ ok: false });

    as("ops");
    const bad = await organisation.updateOrganisationSettings({
      brandName: "Media10",
      currency: "GBP",
      escalateAfterDays: 0,
      installPhotoRequired: true,
    });
    expect(bad).toMatchObject({ ok: false, error: "Chase after at least 1 day" });
    const tooMany = await organisation.updateOrganisationSettings({
      brandName: "Media10",
      currency: "JPY",
      escalateAfterDays: 3,
      installPhotoRequired: true,
    });
    expect(tooMany.ok).toBe(false);

    const ok = await organisation.updateOrganisationSettings({
      brandName: "Media10 Events",
      currency: "EUR",
      escalateAfterDays: 5,
      installPhotoRequired: false,
    });
    expect(ok).toMatchObject({ ok: true, message: "Settings for Media10 Events saved" });
    const org = await db.query.organisations.findFirst({
      where: eq(schema.organisations.id, orgId),
    });
    expect(org!.brandName).toBe("Media10 Events");
    expect(org!.settings).toMatchObject({
      currency: "EUR",
      escalate_after_days: 5,
      install_photo_required: false,
      cost_threshold_for_director: 5000,
    });
    const audit = await lastAudit(orgId);
    expect(audit.action).toBe("settings_change");
    expect(audit.actorUserId).toBe(people.ops.id);
    expect(audit.summary).toMatch(/brandName/);
    expect(audit.summary).toMatch(/escalate_after_days/);
  });
});
