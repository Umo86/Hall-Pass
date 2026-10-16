/**
 * Feature stands and their panels against a real database
 * (TEST_DATABASE_URL), with the session stubbed: panels can be listed
 * before the design is approved (not once the stand is complete); a change
 * to the stand's place reaches its panels until they are installed, and a
 * change to who signs off reaches the panels still in draft; a panel's own
 * edit can't move it away from its stand.
 */
import { randomUUID } from "node:crypto";
import { asc, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";
import type { Session } from "@/lib/auth/actor";

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
let standActions: typeof import("@/app/actions/stand-designs");
let signageActions: typeof import("@/app/actions/signage");
const n = Date.now() % 1_000_000;
let orgId: string;
let editionId: string;
let opsId: string;
const hall: Record<string, string> = {};
let standWfId: string;
let signageWfId: string;

const item = async (id: string) =>
  (await db.select().from(schema.signageItems).where(eq(schema.signageItems.id, id)))[0];
const byRef = async (ref: string) =>
  (await db.select().from(schema.signageItems).where(eq(schema.signageItems.ref, ref)))[0];
const deptStep = async (workflowId: string, name: string) =>
  (
    await db
      .select()
      .from(schema.workflowSteps)
      .where(eq(schema.workflowSteps.workflowId, workflowId))
      .orderBy(asc(schema.workflowSteps.sortOrder))
  ).find((s) => s.name === name)!;

d("feature stands and their panels", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    standActions = await import("@/app/actions/stand-designs");
    signageActions = await import("@/app/actions/signage");
    const standDomain = await import("@/lib/domain/stand-designs");
    const departments = await import("@/lib/domain/departments");

    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Panels Org", slug: `panels-${n}` })
      .returning();
    orgId = org.id;
    opsId = randomUUID();
    await db
      .insert(schema.users)
      .values({ id: opsId, email: `ops-${n}@panels.test`, fullName: "Olive Ops" });
    await db
      .insert(schema.memberships)
      .values({ userId: opsId, organisationId: orgId, role: "ops" });
    const session: Session = {
      actor: {
        kind: "staff",
        userId: opsId,
        organisationId: orgId,
        role: "ops",
        signoffDepartmentIds: [],
      },
      user: { id: opsId, email: `ops-${n}@panels.test`, fullName: "Olive Ops", isExternal: false },
      organisation: {
        id: orgId,
        brandName: "Hall Pass",
        settings: {} as Session["organisation"]["settings"],
      },
    };
    state.session = session;

    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Panels Event", code: `PE${n}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Panels Venue", code: `PV${n}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Panels Edition",
        code: `PNL${n}`,
        buildStart: "2027-10-01",
        buildEnd: "2027-10-04",
        openStart: "2027-10-05",
        openEnd: "2027-10-07",
        breakdownEnd: "2027-10-08",
      })
      .returning();
    editionId = edition.id;
    for (const name of ["Hall 1", "Hall 2"]) {
      const [h] = await db.insert(schema.halls).values({ editionId, name }).returning();
      hall[name] = h.id;
    }
    const [wf] = await db
      .insert(schema.workflows)
      .values({ organisationId: orgId, name: "Signage", appliesTo: "signage", isDefault: true })
      .returning();
    signageWfId = wf.id;
    await db.insert(schema.departments).values([
      { organisationId: orgId, name: "Operations", sortOrder: 1, defaultFor: ["organiser"] },
      { organisationId: orgId, name: "Marketing", sortOrder: 2, defaultFor: ["organiser"] },
    ]);
    await db.transaction((tx) => departments.syncDepartmentSteps(tx, orgId));
    standWfId = await standDomain.ensureStandDesignWorkflow(db, orgId);
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

  it("panels can be listed on a draft stand, not on a complete one; stand changes reach them", async () => {
    const ops = await deptStep(standWfId, "Operations sign-off");
    const mkt = await deptStep(standWfId, "Marketing sign-off");
    const created = await standActions.createStandDesign({
      editionId,
      name: "Feature stand — entrance",
      standNumber: "A01",
      hallId: hall["Hall 1"],
      category: "organiser",
      signoffs: [
        { stepId: ops.id, userId: null },
        { stepId: mkt.id, userId: null },
      ],
    });
    expect(created).toMatchObject({ ok: true });
    const stand = await byRef(created.ok ? created.data!.ref : "");
    expect(stand.status).toBe("draft");

    // Listed before the design is approved (printers can quote early).
    const p1 = await standActions.addStandPanel({
      standId: stand.id,
      name: "Back wall",
      widthMm: 3000,
      heightMm: 2500,
    });
    const p2 = await standActions.addStandPanel({
      standId: stand.id,
      name: "Side wall",
      widthMm: 2000,
      heightMm: 2500,
    });
    expect(p1).toMatchObject({ ok: true });
    expect(p2).toMatchObject({ ok: true });
    const draftPanel = await byRef(p1.ok ? p1.data!.ref : "");
    const reviewPanel = await byRef(p2.ok ? p2.data!.ref : "");
    expect(draftPanel).toMatchObject({
      hallId: hall["Hall 1"],
      standNumber: "A01",
      status: "draft",
    });
    // The second panel is already in sign-off: its approvers stay as they are.
    await db
      .update(schema.signageItems)
      .set({ status: "in_review" })
      .where(eq(schema.signageItems.id, reviewPanel.id));

    // Move the stand and leave its sign-off to Marketing only.
    const saved = await standActions.updateStandDesign({
      id: stand.id,
      name: stand.name,
      hallId: hall["Hall 2"],
      locationId: null,
      standNumber: "B10",
      category: "organiser",
      signoffs: JSON.stringify([{ stepId: mkt.id, userId: null }]),
    });
    expect(saved).toMatchObject({ ok: true });
    expect(saved.ok ? saved.message : "").toMatch(/2 panels updated to match/);

    const draftAfter = await item(draftPanel.id);
    const panelMkt = await deptStep(signageWfId, "Marketing sign-off");
    expect(draftAfter).toMatchObject({ hallId: hall["Hall 2"], standNumber: "B10" });
    expect(draftAfter.signoffs).toEqual([{ stepId: panelMkt.id, userId: null }]);
    const reviewAfter = await item(reviewPanel.id);
    expect(reviewAfter).toMatchObject({ hallId: hall["Hall 2"], standNumber: "B10" });
    expect(reviewAfter.signoffs).toEqual(reviewPanel.signoffs);
    const audit = await db
      .select()
      .from(schema.auditLog)
      .where(eq(schema.auditLog.entityId, draftPanel.id));
    expect(audit.some((a) => a.summary.includes(`to match its stand ${stand.ref}`))).toBe(true);

    // Saving again changes nothing more.
    const again = await standActions.updateStandDesign({ id: stand.id, name: stand.name });
    expect(again.ok ? again.message : "").not.toMatch(/updated to match/);

    // A panel's own edit can't move it off its stand; its own fields change.
    const edited = await signageActions.updateSignageItem({
      id: draftPanel.id,
      name: "Back wall (left)",
      hallId: hall["Hall 1"],
      standNumber: "Z99",
      signoffs: null,
    });
    expect(edited).toMatchObject({ ok: true });
    expect(await item(draftPanel.id)).toMatchObject({
      name: "Back wall (left)",
      hallId: hall["Hall 2"],
      standNumber: "B10",
    });

    // Once the stand is complete, no more panels.
    await db
      .update(schema.signageItems)
      .set({ status: "closed" })
      .where(eq(schema.signageItems.id, stand.id));
    const late = await standActions.addStandPanel({
      standId: stand.id,
      name: "Late panel",
      widthMm: 100,
      heightMm: 100,
    });
    expect(late).toMatchObject({ ok: false });
    expect(late.ok ? "" : late.error).toMatch(/complete/);
  });
});
