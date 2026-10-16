/**
 * Sponsors and sales against a real database (TEST_DATABASE_URL), with the
 * session stubbed: entitlements can be corrected and removed only while
 * nothing counts towards them, a sponsor is removed only when nothing points
 * at them, every change is audited, and sales toasts name the item.
 */
import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
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
let sponsorsActions: typeof import("@/app/actions/sponsors");
let sales: typeof import("@/app/actions/sponsorship");
const n = Date.now() % 1_000_000;
let orgId: string;
let otherOrgId: string;
let editionId: string;
let otherEditionId: string;
const people: Record<string, { id: string; role: StaffRole; org: string }> = {};

async function addUser(key: string, role: StaffRole, org: string) {
  const id = randomUUID();
  await db.insert(schema.users).values({ id, email: `${key}-${n}@sponsors.test`, fullName: key });
  await db.insert(schema.memberships).values({ userId: id, organisationId: org, role });
  people[key] = { id, role, org };
}

function as(key: string) {
  const p = people[key];
  const session: Session = {
    actor: {
      kind: "staff",
      userId: p.id,
      organisationId: p.org,
      role: p.role,
      signoffDepartmentIds: [],
    },
    user: { id: p.id, email: `${key}@sponsors.test`, fullName: key, isExternal: false },
    organisation: {
      id: p.org,
      brandName: "Hall Pass",
      settings: {} as Session["organisation"]["settings"],
    },
  };
  state.session = session;
}

async function makeEdition(org: string, tag: string) {
  const [event] = await db
    .insert(schema.events)
    .values({ organisationId: org, name: `Sponsors ${tag}`, code: `SE${tag}${n}` })
    .returning();
  const [venue] = await db
    .insert(schema.venues)
    .values({ organisationId: org, name: `Venue ${tag}`, code: `SV${tag}${n}` })
    .returning();
  const [edition] = await db
    .insert(schema.editions)
    .values({
      eventId: event.id,
      venueId: venue.id,
      name: `Sponsors ${tag}`,
      code: `SPN${tag}${n}`,
      buildStart: "2027-10-01",
      buildEnd: "2027-10-04",
      openStart: "2027-10-05",
      openEnd: "2027-10-07",
      breakdownEnd: "2027-10-08",
    })
    .returning();
  return edition.id;
}

let seq = 0;
async function addItem(values: Partial<typeof schema.signageItems.$inferInsert>) {
  seq++;
  const [item] = await db
    .insert(schema.signageItems)
    .values({
      editionId,
      ref: `SIG-SPN${n}-${String(seq).padStart(3, "0")}`,
      seq,
      name: `Sponsorship thing ${seq}`,
      kind: "sponsorship_item",
      ...values,
    })
    .returning();
  return item;
}

const auditFor = (entityId: string) =>
  db.select().from(schema.auditLog).where(eq(schema.auditLog.entityId, entityId));

d("sponsors and sales", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    sponsorsActions = await import("@/app/actions/sponsors");
    sales = await import("@/app/actions/sponsorship");
    const [org, other] = await db
      .insert(schema.organisations)
      .values([
        { name: "Sponsors Org", slug: `sponsors-${n}` },
        { name: "Other Org", slug: `sponsors-other-${n}` },
      ])
      .returning();
    orgId = org.id;
    otherOrgId = other.id;
    await addUser("sales", "sales", orgId);
    await addUser("viewer", "viewer", orgId);
    await addUser("outsider", "admin", otherOrgId);
    editionId = await makeEdition(orgId, "A");
    otherEditionId = await makeEdition(otherOrgId, "B");
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

  it("adds a sponsor, returning its id, and corrects an entitlement", async () => {
    as("sales");
    const res = await sponsorsActions.saveSponsor({
      editionId,
      companyName: "BuildCo",
      entitlements: "6 x Logo on banners\nShow bag insert",
    });
    expect(res).toMatchObject({ ok: true, message: "BuildCo added" });
    const sponsorId = res.ok ? res.data!.id : "";
    const ents = await db
      .select()
      .from(schema.sponsorEntitlements)
      .where(eq(schema.sponsorEntitlements.sponsorId, sponsorId));
    expect(ents.map((e) => [e.quantity, e.description]).sort()).toEqual([
      [1, "Show bag insert"],
      [6, "Logo on banners"],
    ]);
    const banners = ents.find((e) => e.quantity === 6)!;
    const fixed = await sponsorsActions.updateEntitlement({
      entitlementId: banners.id,
      description: "Logo on hanging banners",
      quantity: "8",
    });
    expect(fixed).toMatchObject({ ok: true });
    const [after] = await db
      .select()
      .from(schema.sponsorEntitlements)
      .where(eq(schema.sponsorEntitlements.id, banners.id));
    expect(after).toMatchObject({ description: "Logo on hanging banners", quantity: 8 });
    const audit = await auditFor(sponsorId);
    expect(audit.some((a) => a.summary.includes("8 × Logo on hanging banners"))).toBe(true);

    // Viewers can't, and another organisation can't even find it.
    as("viewer");
    expect(
      await sponsorsActions.updateEntitlement({
        entitlementId: banners.id,
        description: "x",
        quantity: 1,
      }),
    ).toMatchObject({ ok: false });
    as("outsider");
    expect(await sponsorsActions.removeEntitlement({ entitlementId: banners.id })).toEqual({
      ok: false,
      error: "Sponsor not found",
      fieldErrors: undefined,
    });
  });

  it("blocks removing an entitlement or sponsor while items point at them", async () => {
    as("sales");
    const res = await sponsorsActions.saveSponsor({
      editionId,
      companyName: "ToolMart",
      entitlements: "Lanyards\nBags",
    });
    const sponsorId = res.ok ? res.data!.id : "";
    const ents = await db
      .select()
      .from(schema.sponsorEntitlements)
      .where(eq(schema.sponsorEntitlements.sponsorId, sponsorId));
    const lanyards = ents.find((e) => e.description === "Lanyards")!;
    const bags = ents.find((e) => e.description === "Bags")!;
    // Even a deleted item still points at them.
    await addItem({ sponsorId, sponsorEntitlementId: lanyards.id, deletedAt: new Date() });

    const blocked = await sponsorsActions.removeEntitlement({ entitlementId: lanyards.id });
    expect(blocked).toMatchObject({ ok: false });
    expect(blocked.ok ? "" : blocked.error).toMatch(/1 item counts towards it/);
    expect(await sponsorsActions.removeEntitlement({ entitlementId: bags.id })).toMatchObject({
      ok: true,
    });
    const left = await db
      .select()
      .from(schema.sponsorEntitlements)
      .where(eq(schema.sponsorEntitlements.sponsorId, sponsorId));
    expect(left.map((e) => e.description)).toEqual(["Lanyards"]);

    const sponsorBlocked = await sponsorsActions.removeSponsor({ sponsorId });
    expect(sponsorBlocked.ok ? "" : sponsorBlocked.error).toMatch(/ToolMart has 1 item/);
  });

  it("removes a sponsor with nothing linked, and keeps a record in History", async () => {
    as("sales");
    const res = await sponsorsActions.saveSponsor({
      editionId,
      companyName: "Typo Ltd",
      entitlements: "Logo",
    });
    const sponsorId = res.ok ? res.data!.id : "";
    // Portal access blocks it too.
    const [grant] = await db
      .insert(schema.externalGrants)
      .values({
        invitedEmail: `typo-${n}@example.test`,
        organisationId: orgId,
        editionId,
        role: "sponsor",
        scopeType: "sponsor",
        scopeId: sponsorId,
        inviteTokenHash: `hash-${n}`,
      })
      .returning();
    const withGrant = await sponsorsActions.removeSponsor({ sponsorId });
    expect(withGrant.ok ? "" : withGrant.error).toMatch(/portal access/);
    await db
      .update(schema.externalGrants)
      .set({ revokedAt: new Date() })
      .where(eq(schema.externalGrants.id, grant.id));

    expect(await sponsorsActions.removeSponsor({ sponsorId })).toMatchObject({
      ok: true,
      message: "Removed Typo Ltd",
    });
    expect(
      await db.select().from(schema.sponsors).where(eq(schema.sponsors.id, sponsorId)),
    ).toHaveLength(0);
    const audit = await auditFor(sponsorId);
    expect(audit.find((a) => a.summary === "Removed sponsor Typo Ltd")?.before).toMatchObject({
      companyName: "Typo Ltd",
      entitlements: [{ description: "Logo", quantity: 1 }],
    });
  });

  it("a sale and its undo name the item", async () => {
    as("sales");
    const item = await addItem({ costEstimate: "100.00" });
    const sold = await sales.markSold({
      itemId: item.id,
      newSponsorName: `Pens ${n}`,
      salePrice: "250",
    });
    expect(sold).toMatchObject({ ok: true, message: `${item.ref} sold to Pens ${n}` });
    expect(await sales.markUnsold({ itemId: item.id })).toMatchObject({
      ok: true,
      message: `${item.ref} is for sale again`,
    });
    const [after] = await db
      .select()
      .from(schema.signageItems)
      .where(eq(schema.signageItems.id, item.id));
    expect(after).toMatchObject({ sponsorId: null, salePrice: null });
  });

  it("refuses a sponsor of another organisation's event", async () => {
    as("outsider");
    const res = await sponsorsActions.saveSponsor({
      editionId: otherEditionId,
      companyName: "Theirs",
    });
    const theirId = res.ok ? res.data!.id : "";
    as("sales");
    expect(await sponsorsActions.removeSponsor({ sponsorId: theirId })).toMatchObject({
      ok: false,
      error: "Sponsor not found",
    });
    const still = await db
      .select()
      .from(schema.sponsors)
      .where(and(eq(schema.sponsors.id, theirId), eq(schema.sponsors.editionId, otherEditionId)));
    expect(still).toHaveLength(1);
  });
});
