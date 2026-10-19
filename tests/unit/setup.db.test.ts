/**
 * Event setup facts against a real database (TEST_DATABASE_URL): a fresh
 * organisation with nothing set up, then the same event with halls, signs,
 * sponsors and sign-off in place. Also the halls editor data and what a copy
 * would bring across.
 */
import { randomUUID } from "node:crypto";
import { eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "@/lib/db/schema";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let setup: typeof import("@/lib/queries/setup");
let departments: typeof import("@/lib/domain/departments");
const suffix = String(Date.now() % 1_000_000);
const perms = {
  details: true,
  halls: true,
  deadlines: true,
  signoff: true,
  people: true,
  types: true,
  suppliers: true,
  signs: true,
  sponsorship: true,
};

let orgId: string;
let venueId: string;
let edition: typeof schema.editions.$inferSelect;
let older: typeof schema.editions.$inferSelect;

d("event setup facts", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    await migrate(db, { migrationsFolder: "lib/db/migrations" });
    setup = await import("@/lib/queries/setup");
    departments = await import("@/lib/domain/departments");

    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Setup Org", slug: `setup-${suffix}` })
      .returning();
    orgId = org.id;
    const [series] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Setup Expo", code: `SE${suffix}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Setup Hall", code: `SH${suffix}` })
      .returning();
    venueId = venue.id;
    [older] = await db
      .insert(schema.editions)
      .values({
        eventId: series.id,
        venueId,
        name: "Setup Expo 2026",
        code: `SUA${suffix}`,
        buildStart: "2026-03-01",
        buildEnd: "2026-03-02",
        openStart: "2026-03-03",
        openEnd: "2026-03-04",
        breakdownEnd: "2026-03-05",
      })
      .returning();
    [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: series.id,
        venueId,
        name: "Setup Expo 2027",
        code: `SUB${suffix}`,
        buildStart: "2027-03-01",
        buildEnd: "2027-03-02",
        openStart: "2027-03-03",
        openEnd: "2027-03-04",
        breakdownEnd: "2027-03-05",
      })
      .returning();
  });

  afterAll(async () => {
    await client?.end();
  });

  it("a fresh organisation has nothing done but what needs no data", async () => {
    expect(await setup.countActiveEvents(orgId, null)).toBe(2);
    const { summary, steps } = await setup.getSetupStatus(edition, orgId, perms);
    const state = Object.fromEntries(steps.map((s) => [s.key, s.state]));
    expect(state).toMatchObject({
      details: "todo",
      halls: "todo",
      deadlines: "todo",
      signoff: "todo",
      types: "todo",
      signs: "todo",
      suppliers: "optional",
      sponsorship: "optional",
    });
    expect(summary).toMatchObject({ done: 0, total: 6, complete: false });
  });

  it("counts halls, signs, sponsors, sign-off and types once they exist", async () => {
    // Halls: one with two locations, then a second with none.
    const [hall] = await db
      .insert(schema.halls)
      .values({ editionId: edition.id, name: "Hall 1" })
      .returning();
    const [loc] = await db
      .insert(schema.locations)
      .values([
        { hallId: hall.id, name: "Main entrance", zone: "North" },
        { hallId: hall.id, name: "Registration" },
      ])
      .returning();
    await db.insert(schema.halls).values({ editionId: edition.id, name: "Hall 2", sortOrder: 1 });
    let status = await setup.getSetupStatus(edition, orgId, perms);
    expect(status.steps.find((s) => s.key === "halls")?.detail).toBe("Hall 2 has no locations yet");

    // Signs: one placed, one in Hall 1 without a location, one deleted.
    await db.insert(schema.signageItems).values([
      {
        editionId: edition.id,
        ref: `SIG-${edition.code}-001`,
        seq: 1,
        name: "Arch",
        hallId: hall.id,
        locationId: loc.id,
      },
      {
        editionId: edition.id,
        ref: `SIG-${edition.code}-002`,
        seq: 2,
        name: "Flag",
        hallId: hall.id,
      },
      {
        editionId: edition.id,
        ref: `SIG-${edition.code}-003`,
        seq: 3,
        name: "Gone",
        hallId: hall.id,
        deletedAt: new Date(),
      },
      {
        editionId: edition.id,
        ref: `SIG-${edition.code}-004`,
        seq: 4,
        name: "Lanyards",
        kind: "sponsorship_item",
      },
    ]);
    await db.insert(schema.sponsors).values({ editionId: edition.id, companyName: "BuildCo" });
    // Sign-off: a department with someone who has an account.
    const [dept] = await db
      .insert(schema.departments)
      .values({ organisationId: orgId, name: "Marketing", defaultFor: ["organiser"] })
      .returning();
    const userId = randomUUID();
    await db.insert(schema.users).values({ id: userId, email: `mk-${suffix}@setup.test` });
    await db
      .insert(schema.memberships)
      .values({ userId, organisationId: orgId, role: "marketing" });
    await db.insert(schema.approvers).values({
      organisationId: orgId,
      departmentId: dept.id,
      fullName: "Mia Marketing",
      email: `mk-${suffix}@setup.test`,
      userId,
      isMain: true,
    });
    await db.transaction((tx) => departments.ensureSignageWorkflow(tx, orgId));
    await db
      .insert(schema.itemTypes)
      .values({ organisationId: orgId, name: "Banner", code: "banner" });

    status = await setup.getSetupStatus(edition, orgId, perms);
    const s = Object.fromEntries(status.steps.map((x) => [x.key, x]));
    expect(s.halls.state).toBe("todo");
    expect(s.signs).toMatchObject({ state: "done", detail: "2 signs" });
    expect(s.sponsorship).toMatchObject({
      state: "done",
      detail: "1 sponsor · 1 sponsorship item",
    });
    expect(s.signoff).toMatchObject({ state: "done", detail: "Marketing signs off" });
    expect(s.types.state).toBe("done");
    expect(s.people).toMatchObject({ state: "todo", detail: "1 person" });
    expect(status.facts.deadlines).toEqual([]);

    // The halls editor sees the unplaced sign and the zone.
    const editor = await setup.hallsEditorData(edition.id);
    expect(editor.zones).toEqual(["North"]);
    expect(editor.halls[0]).toMatchObject({
      name: "Hall 1",
      itemCount: 2,
      unplacedCount: 1,
    });
    expect(editor.halls[0].locations.find((l) => l.name === "Main entrance")?.itemCount).toBe(1);
  });

  it("is complete once the dates and deadlines are confirmed and every hall has a location", async () => {
    const [hall2] = await db
      .select()
      .from(schema.halls)
      .where(eq(schema.halls.name, "Hall 2"))
      .then((rows) => rows.filter((h) => h.editionId === edition.id));
    await db.insert(schema.locations).values({ hallId: hall2.id, name: "Café" });
    await db
      .update(schema.editions)
      .set({ setupChecked: ["details", "deadlines"] })
      .where(eq(schema.editions.id, edition.id));
    const fresh = (
      await db.select().from(schema.editions).where(eq(schema.editions.id, edition.id))
    )[0];
    const { summary } = await setup.getSetupStatus(fresh, orgId, perms);
    expect(summary).toMatchObject({ done: 6, total: 6, complete: true });
    const many = await setup.getSetupSummaries([fresh, older], orgId, perms);
    expect(many.get(fresh.id)?.complete).toBe(true);
    expect(many.get(older.id)?.done).toBeLessThan(6);
  });

  it("offers earlier events at the same venue to copy halls from, with counts", async () => {
    // The 2027 event has the halls; the 2026 one can copy from it.
    const sources = await setup.hallCopySources(orgId, { id: older.id, venueId }, null);
    expect(sources).toEqual([
      { id: edition.id, name: edition.name, code: edition.code, halls: 2, locations: 3 },
    ]);
    // Someone limited to the 2026 event isn't told the 2027 one exists.
    expect(await setup.hallCopySources(orgId, { id: older.id, venueId }, [older.id])).toEqual([]);
    expect(
      (await setup.hallCopySources(orgId, { id: older.id, venueId }, [older.id, edition.id])).map(
        (s) => s.id,
      ),
    ).toEqual([edition.id]);
    const counts = (await setup.copySourceCounts(orgId, superAdminActor(orgId)))(edition.id);
    expect(counts).toMatchObject({ halls: 2, locations: 3, sponsors: 1, items: 3, deadlines: 0 });
  });

  it("archived events don't count as started", async () => {
    await db
      .update(schema.editions)
      .set({ status: "archived" })
      .where(eq(schema.editions.id, older.id));
    expect(await setup.countActiveEvents(orgId, null)).toBe(1);
    const venues = await setup.venuesForPicker(orgId);
    expect(venues.map((v) => v.id)).toEqual([venueId]);
  });
});

/** A super admin, as the copy form sees the person copying (Users → Events). */
function superAdminActor(organisationId: string) {
  return { kind: "staff" as const, userId: "copier", organisationId, role: "admin" as const };
}
