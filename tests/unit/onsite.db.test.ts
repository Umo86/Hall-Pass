/**
 * The floor against a real database (TEST_DATABASE_URL), with the session
 * stubbed: damage is reported on a delivered item without moving it, a
 * damage snag can be worked on before install, "Done – close" can be
 * undone straight after (keeping the install), holding and deleting settle
 * "Please sign off", and a supplier step tells Operations only when there
 * is a supplier to invite.
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
let snagActions: typeof import("@/app/actions/snags");
let signageActions: typeof import("@/app/actions/signage");
let signageDomain: typeof import("@/lib/domain/signage");
const n = Date.now() % 1_000_000;
let orgId: string;
let editionId: string;
let supplierId: string;
let stepId: string;
const people: Record<string, { id: string; role: StaffRole }> = {};

async function addUser(key: string, role: StaffRole) {
  const id = randomUUID();
  await db.insert(schema.users).values({ id, email: `${key}-${n}@onsite.test`, fullName: key });
  await db.insert(schema.memberships).values({ userId: id, organisationId: orgId, role });
  people[key] = { id, role };
}

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
    user: { id: p.id, email: `${key}@onsite.test`, fullName: key, isExternal: false },
    organisation: {
      id: orgId,
      brandName: "Hall Pass",
      settings: {} as Session["organisation"]["settings"],
    },
  };
  state.session = session;
}

let seq = 0;
async function addItem(values: Partial<typeof schema.signageItems.$inferInsert>) {
  seq++;
  const [item] = await db
    .insert(schema.signageItems)
    .values({
      editionId,
      ref: `SIG-ONS${n}-${String(seq).padStart(3, "0")}`,
      seq,
      name: `Onsite sign ${seq}`,
      createdBy: people.ops.id,
      ...values,
    })
    .returning();
  return item;
}

const itemNow = async (id: string) =>
  (await db.select().from(schema.signageItems).where(eq(schema.signageItems.id, id)))[0];

d("onsite on a real database", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    snagActions = await import("@/app/actions/snags");
    signageActions = await import("@/app/actions/signage");
    signageDomain = await import("@/lib/domain/signage");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Onsite Org", slug: `onsite-${n}` })
      .returning();
    orgId = org.id;
    await addUser("ops", "ops");
    await addUser("mkt", "marketing");
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Onsite Event", code: `OE${n}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Onsite Venue", code: `OV${n}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Onsite Edition",
        code: `ONS${n}`,
        buildStart: "2027-10-01",
        buildEnd: "2027-10-04",
        openStart: "2027-10-05",
        openEnd: "2027-10-07",
        breakdownEnd: "2027-10-08",
      })
      .returning();
    editionId = edition.id;
    const [supplier] = await db
      .insert(schema.suppliers)
      .values({ organisationId: orgId, name: `Print Shop ${n}` })
      .returning();
    supplierId = supplier.id;
    const [wf] = await db
      .insert(schema.workflows)
      .values({ organisationId: orgId, name: `Onsite WF ${n}`, appliesTo: "signage" })
      .returning();
    const [step] = await db
      .insert(schema.workflowSteps)
      .values({
        workflowId: wf.id,
        sortOrder: 1,
        name: "Marketing sign-off",
        kind: "approval",
        approverType: "role",
        approverRole: "marketing",
        conditions: ["always"],
      })
      .returning();
    stepId = step.id;
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

  it("reports damage on a delivered item without moving it, and works on it before install", async () => {
    as("mkt");
    const item = await addItem({ status: "delivered" });
    const fd = new FormData();
    fd.set("itemId", item.id);
    fd.set("description", "Corner crushed in transit");
    fd.set("severity", "high");
    const res = await snagActions.raiseSnag(fd);
    expect(res).toMatchObject({ ok: true, message: `Damage reported on ${item.ref}` });
    expect((await itemNow(item.id)).status).toBe("delivered");
    const [snag] = await db
      .select()
      .from(schema.snags)
      .where(eq(schema.snags.signageItemId, item.id));
    expect(snag).toMatchObject({ status: "open", severity: "high" });

    const progress = new FormData();
    progress.set("snagId", snag.id);
    progress.set("status", "in_progress");
    expect(await snagActions.updateSnag(progress)).toMatchObject({ ok: true });

    // Still refused before delivery.
    const early = await addItem({ status: "in_production" });
    const tooEarly = new FormData();
    tooEarly.set("itemId", early.id);
    tooEarly.set("description", "x");
    expect(await snagActions.raiseSnag(tooEarly)).toMatchObject({ ok: false });
  });

  it("undoes Done – close straight after, keeping the install record", async () => {
    as("ops");
    const installedAt = new Date("2026-10-01T10:00:00Z");
    const item = await addItem({ status: "installed", installedAt, installedBy: people.ops.id });
    expect(await signageActions.closeSignageItem({ id: item.id })).toMatchObject({ ok: true });
    expect((await itemNow(item.id)).status).toBe("closed");

    // Marketing can't; Operations can.
    as("mkt");
    expect(await snagActions.undoMarkComplete({ id: item.id })).toMatchObject({ ok: false });
    as("ops");
    expect(await snagActions.undoMarkComplete({ id: item.id })).toMatchObject({
      ok: true,
      message: `${item.ref} is back under Ready to close`,
    });
    const after = await itemNow(item.id);
    expect(after.status).toBe("installed");
    expect(after.installedAt?.toISOString()).toBe(installedAt.toISOString());
    const audit = await db
      .select()
      .from(schema.auditLog)
      .where(eq(schema.auditLog.entityId, item.id));
    expect(
      audit.some((a) => a.summary === `${item.ref} back to Installed (Mark complete undone)`),
    ).toBe(true);
    // Only from closed.
    expect(await snagActions.undoMarkComplete({ id: item.id })).toMatchObject({ ok: false });
  });

  it("holding or deleting an item settles its sign-off requests", async () => {
    as("ops");
    for (const action of ["hold", "delete"] as const) {
      const item = await addItem({ status: "in_review", currentRunNumber: 1 });
      await db.insert(schema.approvalInstances).values({
        entityType: "signage_item",
        entityId: item.id,
        runNumber: 1,
        workflowStepId: stepId,
        stepNameSnapshot: "Marketing sign-off",
        stepKindSnapshot: "approval",
        sortOrderSnapshot: 1,
        status: "pending",
        assignedRole: "marketing",
        pendingSince: new Date(),
      });
      const [note] = await db
        .insert(schema.notifications)
        .values({
          userId: people.mkt.id,
          kind: "approval_requested",
          title: `Please sign off: ${item.ref}`,
          entityType: "signage_item",
          entityId: item.id,
        })
        .returning();
      const res =
        action === "hold"
          ? await signageActions.holdSignageItem({ id: item.id, reason: "Waiting for logo" })
          : await signageActions.softDeleteSignageItem({ id: item.id });
      expect(res).toMatchObject({ ok: true });
      const [after] = await db
        .select()
        .from(schema.notifications)
        .where(eq(schema.notifications.id, note.id));
      expect(after.readAt, action).not.toBeNull();
    }
  });

  it("tells Operations about a supplier step only when there is a supplier without access", async () => {
    const run = async (withSupplier: boolean) => {
      const item = await addItem({
        status: "approved",
        supplierId: withSupplier ? supplierId : null,
      });
      const bundle = (await signageDomain.loadItemBundle(db, item.id))!;
      await db.transaction((tx) =>
        signageDomain.notifyPendingAssignees(tx, bundle, [
          {
            status: "pending",
            stepName: "Sent to print",
            stepKind: "confirmation",
            assignedRole: "supplier",
            assignedUserId: null,
          },
        ]),
      );
      return db
        .select()
        .from(schema.notifications)
        .where(
          and(
            eq(schema.notifications.entityId, item.id),
            eq(schema.notifications.userId, people.ops.id),
          ),
        );
    };
    // No supplier at all: nothing here (the approval already said so).
    expect(await run(false)).toHaveLength(0);
    // A supplier with nobody on the portal: Operations hear, pointed at the
    // item to confirm it themselves, and told who can invite the supplier
    // (nobody here can, so "a super admin").
    const [note] = await run(true);
    expect(note.body).toContain(`Nobody at Print Shop ${n} can sign in to Hall Pass yet`);
    expect(note.body).toContain("— or ask a super admin to invite them.");
    expect(note.link).toMatch(new RegExp(`^/ONS${n}/signage/SIG-ONS${n}-\\d{3}$`));
  });
});
