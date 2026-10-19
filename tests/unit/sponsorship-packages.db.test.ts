/**
 * Sponsorship packages against a real database (TEST_DATABASE_URL), with
 * the session stubbed (as sponsorship-actions.db.test.ts): adding and
 * changing packages, selling one at an agreed price (what's included copied
 * and tagged, without duplicates), the last place under a race, changing
 * and removing a sponsor's package, archiving and deleting, who may and who
 * sees prices, copying an event, the sponsor report and the dashboard.
 */
import { randomUUID } from "node:crypto";
import ExcelJS from "exceljs";
import { and, eq, inArray } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";
import type { Session } from "@/lib/auth/actor";
import type { PermissionOverrides, StaffRole } from "@/lib/authz";

const state = vi.hoisted(() => ({ session: null as unknown }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn(), revalidateTag: vi.fn() }));
vi.mock("next/headers", () => ({
  cookies: async () => ({ get: () => undefined, set: () => {}, delete: () => {} }),
}));
vi.mock("@/lib/auth/actor", () => ({
  requireSession: async () => state.session,
  requireStaffSession: async () => state.session,
}));

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let pkgs: typeof import("@/app/actions/sponsorship-packages");
let sponsorsActions: typeof import("@/app/actions/sponsors");
let editionsActions: typeof import("@/app/actions/editions");
const n = Date.now() % 1_000_000;
let orgId: string;
let otherOrgId: string;
let editionId: string;
let secondEditionId: string;
let otherEditionId: string;
let archivedEditionId: string;
const editionsMade: string[] = [];
const people: Record<
  string,
  {
    id: string;
    role: StaffRole;
    org: string;
    overrides?: PermissionOverrides;
    editionIds?: string[];
  }
> = {};

async function addUser(
  key: string,
  role: StaffRole,
  org: string,
  extra: { overrides?: PermissionOverrides; editionIds?: string[] } = {},
) {
  const id = randomUUID();
  await db.insert(schema.users).values({ id, email: `${key}-${n}@packages.test`, fullName: key });
  await db.insert(schema.memberships).values({
    userId: id,
    organisationId: org,
    role,
    permissionOverrides: extra.overrides ?? {},
    editionIds: extra.editionIds ?? null,
  });
  people[key] = { id, role, org, ...extra };
}

function as(key: string) {
  const p = people[key];
  const session: Session = {
    actor: {
      kind: "staff",
      userId: p.id,
      organisationId: p.org,
      role: p.role,
      overrides: p.overrides,
      editionIds: p.editionIds ?? null,
      signoffDepartmentIds: [],
    },
    user: { id: p.id, email: `${key}-${n}@packages.test`, fullName: key, isExternal: false },
    organisation: {
      id: p.org,
      brandName: "Hall Pass",
      settings: {} as Session["organisation"]["settings"],
    },
  };
  state.session = session;
  return session;
}

let editionSeq = 0;
async function makeEdition(org: string, status: "planning" | "archived" = "planning") {
  editionSeq++;
  const tag = `${editionSeq}`;
  const [event] = await db
    .insert(schema.events)
    .values({ organisationId: org, name: `Packages ${tag}`, code: `PE${tag}X${n}` })
    .returning();
  const [venue] = await db
    .insert(schema.venues)
    .values({ organisationId: org, name: `Venue ${tag}`, code: `PV${tag}X${n}` })
    .returning();
  const [edition] = await db
    .insert(schema.editions)
    .values({
      eventId: event.id,
      venueId: venue.id,
      name: `Packages ${tag}`,
      code: `PKG${tag}X${n}`,
      status,
      buildStart: "2027-10-01",
      buildEnd: "2027-10-04",
      openStart: "2027-10-05",
      openEnd: "2027-10-07",
      breakdownEnd: "2027-10-08",
    })
    .returning();
  editionsMade.push(edition.id);
  return edition.id;
}

let seq = 0;
async function addItem(values: Partial<typeof schema.signageItems.$inferInsert>) {
  seq++;
  const [item] = await db
    .insert(schema.signageItems)
    .values({
      editionId,
      ref: `SIG-PKG${n}-${String(seq).padStart(3, "0")}`,
      seq,
      name: `Package thing ${seq}`,
      kind: "sponsorship_item",
      ...values,
    })
    .returning();
  return item;
}

const auditFor = (entityId: string) =>
  db.select().from(schema.auditLog).where(eq(schema.auditLog.entityId, entityId));

async function packageNamed(name: string, ed = editionId) {
  const [p] = await db
    .select()
    .from(schema.sponsorshipPackages)
    .where(
      and(eq(schema.sponsorshipPackages.editionId, ed), eq(schema.sponsorshipPackages.name, name)),
    );
  return p;
}

async function sponsorRow(id: string) {
  const [sp] = await db.select().from(schema.sponsors).where(eq(schema.sponsors.id, id));
  return sp;
}

async function entitlementsOf(sponsorId: string) {
  return db
    .select()
    .from(schema.sponsorEntitlements)
    .where(eq(schema.sponsorEntitlements.sponsorId, sponsorId))
    .orderBy(schema.sponsorEntitlements.createdAt, schema.sponsorEntitlements.description);
}

async function addPackage(input: Record<string, unknown>) {
  const res = await pkgs.savePackage({ editionId, ...input });
  if (!res.ok) throw new Error(res.error);
  return res.data!.id;
}

async function addSponsor(companyName: string, entitlements = "") {
  const res = await sponsorsActions.saveSponsor({ editionId, companyName, entitlements });
  if (!res.ok) throw new Error(res.error);
  return res.data!.id;
}

d("sponsorship packages", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 4, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    pkgs = await import("@/app/actions/sponsorship-packages");
    sponsorsActions = await import("@/app/actions/sponsors");
    editionsActions = await import("@/app/actions/editions");
    const [org, other] = await db
      .insert(schema.organisations)
      .values([
        { name: "Packages Org", slug: `packages-${n}` },
        { name: "Other Packages Org", slug: `packages-other-${n}` },
      ])
      .returning();
    orgId = org.id;
    otherOrgId = other.id;
    editionId = await makeEdition(orgId);
    secondEditionId = await makeEdition(orgId);
    archivedEditionId = await makeEdition(orgId, "archived");
    otherEditionId = await makeEdition(otherOrgId);
    await addUser("admin", "admin", orgId);
    await addUser("sales", "sales", orgId);
    await addUser("ops", "ops", orgId);
    await addUser("marketing", "marketing", orgId);
    await addUser("nocosts", "sales", orgId, { overrides: { "costs.view": false } });
    // A seller who only works on the second event.
    await addUser("limited", "sales", orgId, { editionIds: [secondEditionId] });
    await addUser("outsider", "admin", otherOrgId);
  });

  afterAll(async () => {
    for (const id of editionsMade) {
      await db
        .update(schema.signageItems)
        .set({ deletedAt: new Date() })
        .where(eq(schema.signageItems.editionId, id));
    }
    await client?.end();
  });

  it("adds a package with its lines and an audit row; new packages go last", async () => {
    as("sales");
    const res = await pkgs.savePackage({
      editionId,
      name: "Gold",
      price: "10000",
      places: "2",
      description: "Top billing",
      lines: "2 x Banners\nLogo in the event guide",
    });
    expect(res).toMatchObject({ ok: true, message: "Gold added" });
    const gold = await packageNamed("Gold");
    expect(gold).toMatchObject({ price: "10000.00", places: 2, description: "Top billing" });
    const lines = await db
      .select()
      .from(schema.sponsorshipPackageLines)
      .where(eq(schema.sponsorshipPackageLines.packageId, gold.id))
      .orderBy(schema.sponsorshipPackageLines.sortOrder);
    expect(lines.map((l) => [l.sortOrder, l.quantity, l.description])).toEqual([
      [1, 2, "Banners"],
      [2, 1, "Logo in the event guide"],
    ]);
    const audit = await auditFor(gold.id);
    expect(audit).toHaveLength(1);
    expect(audit[0]).toMatchObject({
      entityType: "sponsorship_package",
      action: "create",
      editionId,
      actorUserId: people.sales.id,
      summary: "Added package Gold at £10,000",
    });

    const second = await addPackage({ name: "Silver", lines: "" });
    const [silver] = await db
      .select()
      .from(schema.sponsorshipPackages)
      .where(eq(schema.sponsorshipPackages.id, second));
    expect(silver.sortOrder).toBeGreaterThan(gold.sortOrder);
    expect(silver.price).toBeNull();
    expect((await auditFor(second))[0].summary).toBe("Added package Silver (no price yet)");

    // A line listed twice, or over 100 lines, is refused before anything is written.
    expect(
      await pkgs.savePackage({ editionId, name: "Twice", lines: "Logo\n2 x  logo " }),
    ).toMatchObject({ ok: false, error: "“logo” is listed twice" });
  });

  it("refuses a duplicate name in the same event in any case, names an archived one, and allows it in another event", async () => {
    as("sales");
    expect(await pkgs.savePackage({ editionId, name: "gold" })).toMatchObject({
      ok: false,
      error: "There's already a package called Gold in this event",
    });
    const bronze = await addPackage({ name: "Bronze" });
    expect(await pkgs.setPackageArchived({ packageId: bronze, archived: true })).toMatchObject({
      ok: true,
      message: "Archived Bronze",
    });
    expect(await pkgs.savePackage({ editionId, name: "BRONZE" })).toMatchObject({
      ok: false,
      error: "There's an archived package called Bronze — restore it instead",
    });
    expect(await pkgs.setPackageArchived({ packageId: bronze, archived: false })).toMatchObject({
      ok: true,
      message: "Restored Bronze",
    });
    const elsewhere = await pkgs.savePackage({ editionId: secondEditionId, name: "Gold" });
    expect(elsewhere).toMatchObject({ ok: true });
  });

  it("refuses without sponsorship.sell (marketing), without costs.view, for another organisation's event, on an archived event, and in an event the seller can't open", async () => {
    as("marketing");
    const noSell = await pkgs.savePackage({ editionId, name: "Nope" });
    expect(noSell.ok).toBe(false);
    if (!noSell.ok) expect(noSell.error).toMatch(/Mark sold and manage sponsors and packages/);
    as("nocosts");
    expect((await pkgs.savePackage({ editionId, name: "Nope" })).ok).toBe(false);
    const gold = await packageNamed("Gold");
    expect(
      (await pkgs.sellPackage({ packageId: gold.id, newSponsorName: "X", agreedPrice: 1 })).ok,
    ).toBe(false);
    as("outsider");
    expect(await pkgs.savePackage({ editionId, name: "Nope" })).toMatchObject({
      ok: false,
      error: "Event not found",
    });
    expect(await pkgs.deletePackage({ packageId: gold.id })).toMatchObject({
      ok: false,
      error: "Package not found",
    });
    as("admin");
    expect(await pkgs.savePackage({ editionId: archivedEditionId, name: "Late" })).toMatchObject({
      ok: false,
    });
    // Limited to the second event: the first is "not found", the second is fine.
    as("limited");
    expect(await pkgs.savePackage({ editionId, name: "Nope" })).toMatchObject({
      ok: false,
      error: "Event not found",
    });
    expect(
      await pkgs.sellPackage({ packageId: gold.id, newSponsorName: "Sneaky Co", agreedPrice: 1 }),
    ).toMatchObject({ ok: false, error: "Package not found" });
    expect((await pkgs.savePackage({ editionId: secondEditionId, name: "Limited's own" })).ok).toBe(
      true,
    );
    expect(await packageNamed("Nope")).toBeUndefined();
  });

  it("sells a package: agreed price, reason only when it differs, lines copied and tagged without duplicates, package_name kept in step, one audit row", async () => {
    as("sales");
    const gold = await packageNamed("Gold");
    // A sponsor who already has one of the lines (different case and spacing).
    const buildCo = await addSponsor(`BuildCo ${n}`, "  logo in the EVENT   guide");
    // A different price needs a reason.
    expect(
      await pkgs.sellPackage({ packageId: gold.id, sponsorId: buildCo, agreedPrice: "9000" }),
    ).toMatchObject({ ok: false, error: "Say why the price is different (e.g. a discount)" });
    const res = await pkgs.sellPackage({
      packageId: gold.id,
      sponsorId: buildCo,
      agreedPrice: "9000",
      priceNote: "Early booking",
    });
    expect(res).toMatchObject({
      ok: true,
      message: `BuildCo ${n} bought Gold`,
      data: { mode: "new", added: 1, alreadyThere: 1, removed: 0, kept: 0 },
    });
    const sp = await sponsorRow(buildCo);
    expect(sp).toMatchObject({
      packageId: gold.id,
      packagePrice: "9000.00",
      packagePriceNote: "Early booking",
      packageName: "Gold",
    });
    expect(sp.packageSoldAt).toBeInstanceOf(Date);
    const ents = await entitlementsOf(buildCo);
    expect(ents.map((e) => [e.description, e.quantity, e.fromPackageId])).toEqual([
      ["logo in the EVENT   guide", 1, null],
      ["Banners", 2, gold.id],
    ]);
    const audit = (await auditFor(buildCo)).filter((a) => a.summary.includes("bought"));
    expect(audit).toHaveLength(1);
    expect(audit[0].summary).toBe(
      `BuildCo ${n} bought Gold for £9,000 (list £10,000: Early booking)`,
    );

    // The same price as the list: any reason typed is not stored.
    const toolMart = await addSponsor(`ToolMart ${n}`);
    const silver = await packageNamed("Silver");
    await pkgs.savePackage({
      editionId,
      id: silver.id,
      name: "Silver",
      price: "500",
      lines: "Flag",
    });
    expect(
      await pkgs.sellPackage({
        packageId: silver.id,
        sponsorId: toolMart,
        agreedPrice: "500",
        priceNote: "ignored",
      }),
    ).toMatchObject({ ok: true });
    expect((await sponsorRow(toolMart)).packagePriceNote).toBeNull();
  });

  it("refuses selling beyond places; two sales of the last place at once leave exactly one sold", async () => {
    as("sales");
    const gold = await packageNamed("Gold");
    const [a, b] = await Promise.all([
      pkgs.sellPackage({
        packageId: gold.id,
        newSponsorName: `Racer A ${n}`,
        agreedPrice: "10000",
      }),
      pkgs.sellPackage({
        packageId: gold.id,
        newSponsorName: `Racer B ${n}`,
        agreedPrice: "10000",
      }),
    ]);
    const results = [a, b];
    expect(results.filter((r) => r.ok)).toHaveLength(1);
    const refused = results.find((r) => !r.ok);
    expect(refused).toMatchObject({
      ok: false,
      error: "Gold is sold out (2 of 2) — offer more places under Edit package first",
    });
    const sold = await db
      .select()
      .from(schema.sponsors)
      .where(eq(schema.sponsors.packageId, gold.id));
    expect(sold).toHaveLength(2);
    // The refused sale's new sponsor was rolled back with it.
    const racers = await db
      .select()
      .from(schema.sponsors)
      .where(
        and(
          eq(schema.sponsors.editionId, editionId),
          inArray(schema.sponsors.companyName, [`Racer A ${n}`, `Racer B ${n}`]),
        ),
      );
    expect(racers).toHaveLength(1);
  });

  it("editing a sale changes price and reason only, never the date or entitlements", async () => {
    as("sales");
    const gold = await packageNamed("Gold");
    const [buildCo] = await db
      .select()
      .from(schema.sponsors)
      .where(eq(schema.sponsors.companyName, `BuildCo ${n}`));
    const before = await entitlementsOf(buildCo.id);
    // Sold out, but editing an existing sale still works.
    const res = await pkgs.sellPackage({
      packageId: gold.id,
      sponsorId: buildCo.id,
      agreedPrice: "8500",
      priceNote: "Bigger discount",
    });
    expect(res).toMatchObject({
      ok: true,
      message: `BuildCo ${n}'s Gold saved`,
      data: { mode: "edit" },
    });
    const after = await sponsorRow(buildCo.id);
    expect(after).toMatchObject({ packagePrice: "8500.00", packagePriceNote: "Bigger discount" });
    expect(after.packageSoldAt?.getTime()).toBe(buildCo.packageSoldAt?.getTime());
    expect(await entitlementsOf(buildCo.id)).toEqual(before);
    const audit = (await auditFor(buildCo.id)).map((a) => a.summary);
    expect(audit).toContain(`BuildCo ${n}'s Gold: price £9,000 → £8,500 (Bigger discount)`);
  });

  it("changing a sponsor's package keeps lines items count towards, removes the rest and adds the new package's lines", async () => {
    as("sales");
    const gold = await packageNamed("Gold");
    const platinum = await addPackage({
      name: "Platinum",
      price: "20000",
      places: "1",
      lines: "Banners\nEntrance branding",
    });
    const [buildCo] = await db
      .select()
      .from(schema.sponsors)
      .where(eq(schema.sponsors.companyName, `BuildCo ${n}`));
    // An item counts towards Gold's "Banners".
    const banners = (await entitlementsOf(buildCo.id)).find((e) => e.description === "Banners")!;
    await addItem({ sponsorId: buildCo.id, sponsorEntitlementId: banners.id, kind: "signage" });
    const res = await pkgs.sellPackage({
      packageId: platinum,
      sponsorId: buildCo.id,
      agreedPrice: "20000",
    });
    expect(res).toMatchObject({
      ok: true,
      message: `BuildCo ${n} now has Platinum (was Gold)`,
      // Banners kept (an item counts towards it) also stops Platinum adding it again.
      data: { mode: "change", added: 1, alreadyThere: 1, removed: 0, kept: 1 },
    });
    const ents = await entitlementsOf(buildCo.id);
    expect(ents.map((e) => [e.description, e.fromPackageId])).toEqual([
      ["logo in the EVENT   guide", null],
      ["Banners", gold.id],
      ["Entrance branding", platinum],
    ]);
    const sp = await sponsorRow(buildCo.id);
    expect(sp).toMatchObject({
      packageId: platinum,
      packageName: "Platinum",
      packagePriceNote: null,
    });
    expect((await auditFor(buildCo.id)).map((a) => a.summary)).toContain(
      `BuildCo ${n} moved from Gold to Platinum for £20,000`,
    );
  });

  it("removing a package clears price, reason, date and package_name and keeps lines items count towards", async () => {
    as("sales");
    const [buildCo] = await db
      .select()
      .from(schema.sponsors)
      .where(eq(schema.sponsors.companyName, `BuildCo ${n}`));
    const res = await pkgs.removeSponsorPackage({ sponsorId: buildCo.id });
    expect(res).toMatchObject({ ok: true, message: `Removed Platinum from BuildCo ${n}` });
    const sp = await sponsorRow(buildCo.id);
    expect(sp).toMatchObject({
      packageId: null,
      packagePrice: null,
      packagePriceNote: null,
      packageSoldAt: null,
      packageName: null,
    });
    const ents = await entitlementsOf(buildCo.id);
    // Platinum's own line went; Gold's linked line and their own line stay.
    expect(ents.map((e) => e.description)).toEqual(["logo in the EVENT   guide", "Banners"]);
    expect((await auditFor(buildCo.id)).map((a) => a.summary)).toContain(
      `BuildCo ${n} no longer has Platinum (removed 1 line)`,
    );
    expect(await pkgs.removeSponsorPackage({ sponsorId: buildCo.id })).toMatchObject({
      ok: false,
      error: `BuildCo ${n} has no package`,
    });
  });

  it("places can't go below what's sold; archived packages can't be sold but keep their sales", async () => {
    as("sales");
    // The editor always sends what's included (it replaces the lines).
    const goldLines = "2 x Banners\nLogo in the event guide";
    const gold = await packageNamed("Gold");
    // BuildCo moved to Platinum: only the racer who won has it now.
    const soldNow = (
      await db.select().from(schema.sponsors).where(eq(schema.sponsors.packageId, gold.id))
    ).length;
    expect(soldNow).toBe(1);
    const racer = (
      await db.select().from(schema.sponsors).where(eq(schema.sponsors.packageId, gold.id))
    )[0];
    const third = await addSponsor(`Third ${n}`);
    expect(
      await pkgs.sellPackage({ packageId: gold.id, sponsorId: third, agreedPrice: "10000" }),
    ).toMatchObject({ ok: true });
    expect(
      await pkgs.savePackage({
        editionId,
        id: gold.id,
        name: "Gold",
        price: "10000",
        places: "1",
        lines: goldLines,
      }),
    ).toMatchObject({
      ok: false,
      error: "2 are already sold — offer at least 2, or leave it empty for no limit",
    });
    expect(
      (
        await pkgs.savePackage({
          editionId,
          id: gold.id,
          name: "Gold",
          price: "10000",
          places: "",
          lines: goldLines,
        })
      ).ok,
    ).toBe(true);
    expect((await packageNamed("Gold")).places).toBeNull();

    expect(await pkgs.setPackageArchived({ packageId: gold.id, archived: true })).toMatchObject({
      ok: true,
    });
    const fresh = await addSponsor(`Fresh ${n}`);
    expect(
      await pkgs.sellPackage({ packageId: gold.id, sponsorId: fresh, agreedPrice: "10000" }),
    ).toMatchObject({ ok: false, error: "Gold is archived — restore it to sell it" });
    // An existing sale of it can still be edited, and its sales stay.
    expect(
      await pkgs.sellPackage({ packageId: gold.id, sponsorId: racer.id, agreedPrice: "10000" }),
    ).toMatchObject({ ok: true, data: { mode: "edit" } });
    expect(
      (await db.select().from(schema.sponsors).where(eq(schema.sponsors.packageId, gold.id)))
        .length,
    ).toBe(2);
    await pkgs.setPackageArchived({ packageId: gold.id, archived: false });
  });

  it("a package that was sold can't be deleted; one never sold can, with its lines", async () => {
    as("sales");
    const gold = await packageNamed("Gold");
    expect(await pkgs.deletePackage({ packageId: gold.id })).toMatchObject({
      ok: false,
      error: "2 sponsors have it — archive it instead",
    });
    // Nobody has it, but a line from it that an item counts towards stays.
    const keepsLine = await addPackage({ name: "Tagged", lines: "Tag line" });
    const tagged = await addSponsor(`Tagged Co ${n}`);
    await pkgs.sellPackage({ packageId: keepsLine, sponsorId: tagged, agreedPrice: "0" });
    const line = (await entitlementsOf(tagged)).find((e) => e.fromPackageId === keepsLine)!;
    await addItem({ sponsorId: tagged, sponsorEntitlementId: line.id, kind: "signage" });
    await pkgs.removeSponsorPackage({ sponsorId: tagged });
    expect(await pkgs.deletePackage({ packageId: keepsLine })).toMatchObject({
      ok: false,
      error: "Entitlements came from it — archive it instead",
    });

    const temp = await addPackage({ name: "Temp", lines: "2 x Flags" });
    expect(await pkgs.deletePackage({ packageId: temp })).toMatchObject({
      ok: true,
      message: "Removed Temp",
    });
    expect(await packageNamed("Temp")).toBeUndefined();
    const lines = await db
      .select()
      .from(schema.sponsorshipPackageLines)
      .where(eq(schema.sponsorshipPackageLines.packageId, temp));
    expect(lines).toHaveLength(0);
    const audit = await auditFor(temp);
    expect(audit.map((a) => a.summary)).toContain("Removed package Temp");
    const removed = audit.find((a) => a.summary === "Removed package Temp")!;
    expect(removed.after).toEqual({ removed: true });
    expect((removed.before as { lines: unknown[] }).lines).toEqual([
      { description: "Flags", quantity: 2 },
    ]);
  });

  it("setting a price fills it in for sponsors sold before it had one, when asked, each audited", async () => {
    as("sales");
    const open = await addPackage({ name: "Open", places: "" });
    const early = await addSponsor(`Early ${n}`);
    const late = await addSponsor(`Late ${n}`);
    await db
      .update(schema.sponsors)
      .set({ packageId: open, packageSoldAt: new Date(), packageName: "Open" })
      .where(inArray(schema.sponsors.id, [early, late]));
    // Late already agreed a price.
    await db
      .update(schema.sponsors)
      .set({ packagePrice: "100.00" })
      .where(eq(schema.sponsors.id, late));
    const res = await pkgs.savePackage({
      editionId,
      id: open,
      name: "Open",
      price: "750",
      applyPriceToUnpriced: true,
    });
    expect(res).toMatchObject({ ok: true, message: `Open saved — price set for Early ${n} too` });
    expect((await sponsorRow(early)).packagePrice).toBe("750.00");
    expect((await sponsorRow(late)).packagePrice).toBe("100.00");
    expect((await auditFor(early)).map((a) => a.summary)).toContain(
      `Early ${n}'s Open price set to £750 (the package price)`,
    );
    // Without the box, nothing is filled in.
    await db
      .update(schema.sponsors)
      .set({ packagePrice: null })
      .where(eq(schema.sponsors.id, early));
    await pkgs.savePackage({ editionId, id: open, name: "Open", price: "800" });
    expect((await sponsorRow(early)).packagePrice).toBeNull();
  });

  it("renaming a package renames it on its sponsors' package_name", async () => {
    as("sales");
    const open = await packageNamed("Open");
    expect(
      await pkgs.savePackage({ editionId, id: open.id, name: "Open Plus", price: "800" }),
    ).toMatchObject({ ok: true, message: "Open Plus saved" });
    const holders = await db
      .select()
      .from(schema.sponsors)
      .where(eq(schema.sponsors.packageId, open.id));
    expect(holders.map((h) => h.packageName)).toEqual(["Open Plus", "Open Plus"]);
    const audit = (await auditFor(open.id)).map((a) => a.summary);
    expect(audit.some((s) => s.startsWith("Changed package Open Plus: renamed from Open"))).toBe(
      true,
    );
  });

  it("move up and down renumber the order and are audited", async () => {
    as("sales");
    const live = async () =>
      (
        await db
          .select()
          .from(schema.sponsorshipPackages)
          .where(
            and(
              eq(schema.sponsorshipPackages.editionId, editionId),
              eq(schema.sponsorshipPackages.isArchived, false),
            ),
          )
          .orderBy(schema.sponsorshipPackages.sortOrder)
      ).map((p) => [p.sortOrder, p.name]);
    const before = await live();
    const second = before[1][1] as string;
    const p = await packageNamed(second);
    expect(await pkgs.movePackage({ packageId: p.id, direction: "up" })).toMatchObject({
      ok: true,
      message: `Moved ${second} up`,
    });
    const after = await live();
    expect(after.map((r) => r[0])).toEqual(after.map((_, i) => i + 1));
    expect(after[0][1]).toBe(second);
    expect(after[1][1]).toBe(before[0][1]);
    expect((await auditFor(p.id)).map((a) => a.summary)).toContain(`Moved package ${second} up`);
    // At the top: nothing changes and nothing is audited.
    const rows = (await auditFor(p.id)).length;
    expect(await pkgs.movePackage({ packageId: p.id, direction: "up" })).toMatchObject({
      ok: true,
    });
    expect((await auditFor(p.id)).length).toBe(rows);
  });

  it("a new sponsor created while selling is refused when one of that name is already on the event", async () => {
    as("sales");
    const open = await packageNamed("Open Plus");
    expect(
      await pkgs.sellPackage({
        packageId: open.id,
        newSponsorName: `  toolmart ${n} `,
        agreedPrice: "800",
      }),
    ).toMatchObject({
      ok: false,
      error: `ToolMart ${n} is already a sponsor — choose them from the list`,
    });
    const made = await pkgs.sellPackage({
      packageId: open.id,
      newSponsorName: `Gold Co ${n}`,
      agreedPrice: "800",
    });
    expect(made).toMatchObject({ ok: true, message: `Gold Co ${n} bought Open Plus` });
    const [goldCo] = await db
      .select()
      .from(schema.sponsors)
      .where(eq(schema.sponsors.companyName, `Gold Co ${n}`));
    expect((await auditFor(goldCo.id)).map((a) => a.summary)).toContain(
      `Added sponsor Gold Co ${n}`,
    );
  });

  it("a sponsor with a package can't be removed until the package is", async () => {
    as("sales");
    const [goldCo] = await db
      .select()
      .from(schema.sponsors)
      .where(eq(schema.sponsors.companyName, `Gold Co ${n}`));
    expect(await sponsorsActions.removeSponsor({ sponsorId: goldCo.id })).toMatchObject({
      ok: false,
      error: `Gold Co ${n} has the Open Plus package — remove it from their card first`,
    });
    await pkgs.removeSponsorPackage({ sponsorId: goldCo.id });
    expect(await sponsorsActions.removeSponsor({ sponsorId: goldCo.id })).toMatchObject({
      ok: true,
    });
  });

  it("removing a sponsor while a sale to them is saving waits, then refuses (the sale and its lines are kept)", async () => {
    as("sales");
    const race = await addPackage({ name: `Race ${n}`, price: "5000", lines: "Logo on lanyards" });
    const racer = await addSponsor(`Racing Co ${n}`);
    // A sale in flight: it holds the sponsor's row lock (as sellPackageTx
    // does) while removeSponsor starts from the row read before it.
    const holder = postgres(url!, { max: 1, prepare: false, onnotice: () => {} });
    let removal!: Promise<Awaited<ReturnType<typeof sponsorsActions.removeSponsor>>>;
    try {
      await holder.begin(async (sql) => {
        await sql`SELECT id FROM sponsors WHERE id = ${racer} FOR UPDATE`;
        removal = sponsorsActions.removeSponsor({ sponsorId: racer });
        await new Promise((r) => setTimeout(r, 500));
        await sql`UPDATE sponsors SET package_id = ${race}, package_name = ${`Race ${n}`},
          package_price = 5000, package_sold_at = now() WHERE id = ${racer}`;
        await sql`INSERT INTO sponsor_entitlements (sponsor_id, description, quantity, from_package_id)
          VALUES (${racer}, 'Logo on lanyards', 1, ${race})`;
      });
    } finally {
      await holder.end();
    }
    expect(await removal).toMatchObject({
      ok: false,
      error: `Racing Co ${n} has the Race ${n} package — remove it from their card first`,
    });
    expect((await sponsorRow(racer)).packageId).toBe(race);
    expect(await entitlementsOf(racer)).toHaveLength(1);
  });

  it("saveSponsor dedupes by lineKey, as package sales do", async () => {
    as("sales");
    const id = await addSponsor(`Dedupe ${n}`, "Logo on banners\n  logo   ON banners\n3 x Flags");
    expect((await entitlementsOf(id)).map((e) => e.description).sort()).toEqual([
      "Flags",
      "Logo on banners",
    ]);
    const again = await sponsorsActions.saveSponsor({
      editionId,
      id,
      companyName: `Dedupe ${n}`,
      entitlements: "LOGO ON  BANNERS\nNew line",
      // An older client still sends the package name: it is ignored.
      packageName: "Should not stick",
    });
    expect(again.ok).toBe(true);
    expect((await entitlementsOf(id)).map((e) => e.description).sort()).toEqual([
      "Flags",
      "Logo on banners",
      "New line",
    ]);
    expect((await sponsorRow(id)).packageName).toBeNull();
  });

  it("copying an event brings live packages and their lines, not sales or package lines on sponsors", async () => {
    as("admin");
    const archived = await packageNamed("Bronze");
    await pkgs.setPackageArchived({ packageId: archived.id, archived: true });
    const livePkgs = await db
      .select()
      .from(schema.sponsorshipPackages)
      .where(
        and(
          eq(schema.sponsorshipPackages.editionId, editionId),
          eq(schema.sponsorshipPackages.isArchived, false),
        ),
      )
      .orderBy(schema.sponsorshipPackages.sortOrder);
    const code = `PKC${n}`;
    const res = await editionsActions.cloneEdition({
      sourceEditionId: editionId,
      name: `Packages copy ${n}`,
      code,
      openStart: "2028-10-05",
      openEnd: "2028-10-07",
      include: {
        halls: false,
        deadlines: false,
        packages: true,
        sponsors: true,
        items: false,
        access: false,
        people: false,
      },
    });
    if (!res.ok) throw new Error(res.error);
    expect(res.data!.counts.packages).toBe(livePkgs.length);
    const [copy] = await db.select().from(schema.editions).where(eq(schema.editions.code, code));
    editionsMade.push(copy.id);
    const copied = await db
      .select()
      .from(schema.sponsorshipPackages)
      .where(eq(schema.sponsorshipPackages.editionId, copy.id))
      .orderBy(schema.sponsorshipPackages.sortOrder);
    expect(copied.map((p) => [p.sortOrder, p.name, p.price, p.places, p.isArchived])).toEqual(
      livePkgs.map((p, i) => [i + 1, p.name, p.price, p.places, false]),
    );
    expect(copied.some((p) => p.name === "Bronze")).toBe(false);
    const copiedGold = copied.find((p) => p.name === "Gold")!;
    const goldLines = await db
      .select()
      .from(schema.sponsorshipPackageLines)
      .where(eq(schema.sponsorshipPackageLines.packageId, copiedGold.id))
      .orderBy(schema.sponsorshipPackageLines.sortOrder);
    expect(goldLines.map((l) => [l.quantity, l.description])).toEqual([
      [2, "Banners"],
      [1, "Logo in the event guide"],
    ]);
    // Sponsors come across without a package, and only with their own lines.
    const copiedSponsors = await db
      .select()
      .from(schema.sponsors)
      .where(eq(schema.sponsors.editionId, copy.id));
    expect(copiedSponsors.length).toBeGreaterThan(0);
    expect(copiedSponsors.every((s) => s.packageId === null && s.packageName === null)).toBe(true);
    const copiedEnts = await db
      .select()
      .from(schema.sponsorEntitlements)
      .where(
        inArray(
          schema.sponsorEntitlements.sponsorId,
          copiedSponsors.map((s) => s.id),
        ),
      );
    expect(copiedEnts.every((e) => e.fromPackageId === null)).toBe(true);
    const buildCo = copiedSponsors.find((s) => s.companyName === `BuildCo ${n}`)!;
    expect(copiedEnts.filter((e) => e.sponsorId === buildCo.id).map((e) => e.description)).toEqual([
      "logo in the EVENT   guide",
    ]);

    // Unticked: no packages.
    const code2 = `PKD${n}`;
    const res2 = await editionsActions.cloneEdition({
      sourceEditionId: editionId,
      name: `Packages copy 2 ${n}`,
      code: code2,
      openStart: "2028-11-05",
      openEnd: "2028-11-07",
      include: {
        halls: false,
        deadlines: false,
        packages: false,
        sponsors: false,
        items: false,
        access: false,
        people: false,
      },
    });
    if (!res2.ok) throw new Error(res2.error);
    const [copy2] = await db.select().from(schema.editions).where(eq(schema.editions.code, code2));
    editionsMade.push(copy2.id);
    expect(res2.data!.counts.packages).toBe(0);
    await pkgs.setPackageArchived({ packageId: archived.id, archived: false });
  });

  it("the sponsor report has Package, Packages and Revenue only when packages exist, and no money without costs.view", async () => {
    const { buildSponsorWorkbook } = await import("@/lib/exports/excel");
    const read = async (id: string, costs: boolean) => {
      const { workbook } = await buildSponsorWorkbook(id, costs, "GBP");
      const wb = new ExcelJS.Workbook();
      await wb.xlsx.load(Buffer.from(await workbook.xlsx.writeBuffer()) as unknown as ArrayBuffer);
      return wb;
    };
    const headers = (ws: ExcelJS.Worksheet) =>
      (ws.getRow(1).values as unknown[]).filter((v) => typeof v === "string");

    const withCosts = await read(editionId, true);
    const names = withCosts.worksheets.map((w) => w.name);
    expect(names).toContain("Packages");
    expect(names).toContain("Revenue");
    expect(headers(withCosts.getWorksheet("All sponsors")!)).toContain("Package");
    expect(headers(withCosts.getWorksheet("Packages")!)).toEqual([
      "Package",
      "Price £",
      "Places",
      "Sold",
      "Left",
      "Sponsor",
      "Agreed £",
      "Difference £",
      "Why",
      "Sold on",
      "Archived",
    ]);
    const revenue = withCosts.getWorksheet("Revenue")!;
    expect(headers(revenue)).toEqual(["Figure", "Count", "Value £"]);
    const figures = (revenue.getColumn(1).values as unknown[]).filter((v) => typeof v === "string");
    expect(figures).toEqual(
      expect.arrayContaining([
        "Packages sold",
        "Items sold",
        "Total sponsorship revenue",
        "Still to sell in packages",
      ]),
    );

    const noCosts = await read(editionId, false);
    expect(headers(noCosts.getWorksheet("Packages")!)).not.toContain("Price £");
    expect(headers(noCosts.getWorksheet("Packages")!)).not.toContain("Agreed £");
    expect(headers(noCosts.getWorksheet("Revenue")!)).toEqual(["Figure", "Count"]);
    const agreedValues = noCosts.getWorksheet("Packages")!.getSheetValues().flat();
    expect(agreedValues).not.toContain(8500);

    // An event without packages: the workbook is as it always was.
    const plain = await read(otherEditionId, true);
    expect(plain.worksheets.map((w) => w.name)).not.toContain("Packages");
    expect(headers(plain.getWorksheet("All sponsors")!)).not.toContain("Package");
  });

  it("dashboard data adds package revenue only when the event has packages", async () => {
    const { dashboardData } = await import("@/lib/queries/dashboard");
    const session = as("sales");
    const actor = session.actor as Extract<Session["actor"], { kind: "staff" }>;
    const [ed] = await db.select().from(schema.editions).where(eq(schema.editions.id, editionId));
    const data = await dashboardData({ edition: ed, actor, today: "2027-09-01" });
    expect(data.sponsorshipPackages).not.toBeNull();
    expect(data.sponsorshipRevenue).not.toBeNull();
    const sold = await db
      .select()
      .from(schema.sponsors)
      .where(eq(schema.sponsors.editionId, editionId));
    const withPackage = sold.filter((s) => s.packageId !== null);
    expect(data.sponsorshipRevenue!.packages.sold).toBe(withPackage.length);
    expect(data.sponsorshipRevenue!.packages.value).toBe(
      withPackage.reduce((n2, s) => n2 + Number(s.packagePrice ?? 0), 0),
    );
    expect(data.sponsorshipRevenue!.total).toBe(
      data.sponsorshipRevenue!.packages.value + data.sponsorshipRevenue!.items.value,
    );

    const [plain] = await db
      .select()
      .from(schema.editions)
      .where(eq(schema.editions.id, archivedEditionId));
    as("admin");
    const none = await dashboardData({
      edition: plain,
      actor: (state.session as Session).actor as typeof actor,
      today: "2027-09-01",
    });
    expect(none.sponsorshipPackages).toBeNull();
    expect(none.sponsorshipRevenue).toBeNull();
  });

  it("prices only reach people who see costs (packageCards over listPackages)", async () => {
    const { listPackages } = await import("@/lib/queries/sponsorship-packages");
    const { packageCards } = await import("@/lib/domain/sponsorship-packages");
    const rows = await listPackages(db, editionId);
    const gold = rows.find((r) => r.name === "Gold")!;
    expect(gold.price).toBe("10000.00");
    expect(gold.referenced).toBe(true);
    const hidden = packageCards(rows, { canSeeCosts: false });
    expect(hidden.every((c) => c.price === null && c.soldValue === null)).toBe(true);
    expect(hidden.flatMap((c) => c.sales).every((s) => s.agreedPrice === null)).toBe(true);
    // Live first by order, archived last.
    const archivedAt = rows.findIndex((r) => r.isArchived);
    if (archivedAt >= 0) expect(rows.slice(archivedAt).every((r) => r.isArchived)).toBe(true);
  });
});
