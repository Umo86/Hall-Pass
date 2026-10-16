/**
 * Sign-off notifications against a real database (TEST_DATABASE_URL):
 * "Please sign off" is settled for everyone whose turn is over and kept for
 * whoever still holds a step; held items settle everyone; the cheap counts
 * behind the navigation and the bell's Done state agree with the queue.
 */
import { randomUUID } from "node:crypto";
import { eq, inArray } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "@/lib/db/schema";
import type { Session } from "@/lib/auth/actor";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let settle: typeof import("@/lib/domain/notifications");
let notifyMod: typeof import("@/lib/notify");
let queries: typeof import("@/lib/queries/approvals");
const n = Date.now() % 1_000_000;
let orgId: string;
let editionId: string;
let stepId: string;
let opsId: string;
let mktId: string;
let ops2Id: string;

async function addUser(name: string, role: "ops" | "marketing") {
  const id = randomUUID();
  await db.insert(schema.users).values({ id, email: `${name}-${n}@settle.test`, fullName: name });
  await db.insert(schema.memberships).values({ userId: id, organisationId: orgId, role });
  return id;
}

let seq = 0;
async function addItem(status: "in_review" | "on_hold" = "in_review") {
  seq++;
  const [item] = await db
    .insert(schema.signageItems)
    .values({
      editionId,
      ref: `SIG-STL${n}-${String(seq).padStart(3, "0")}`,
      seq,
      name: `Settle item ${seq}`,
      status,
      currentRunNumber: 1,
      createdBy: opsId,
    })
    .returning();
  return item;
}

async function addStep(itemId: string, opts: { role?: string; userId?: string; due?: Date }) {
  const [inst] = await db
    .insert(schema.approvalInstances)
    .values({
      entityType: "signage_item",
      entityId: itemId,
      runNumber: 1,
      workflowStepId: stepId,
      stepNameSnapshot: "Operations sign-off",
      stepKindSnapshot: "approval",
      sortOrderSnapshot: 1,
      status: "pending",
      assignedRole: opts.role ?? null,
      assignedUserId: opts.userId ?? null,
      pendingSince: new Date(),
      dueAt: opts.due ?? new Date(Date.now() + 5 * 86_400_000),
    })
    .returning();
  return inst;
}

async function ask(userIds: string[], itemId: string, kind = "approval_requested") {
  await db.insert(schema.notifications).values(
    userIds.map((userId) => ({
      userId,
      kind,
      title: "Please sign off",
      entityType: "signage_item" as const,
      entityId: itemId,
    })),
  );
}

async function unreadFor(itemId: string) {
  const rows = await db
    .select({ userId: schema.notifications.userId, readAt: schema.notifications.readAt })
    .from(schema.notifications)
    .where(eq(schema.notifications.entityId, itemId));
  return rows.filter((r) => !r.readAt).map((r) => r.userId);
}

function sessionFor(userId: string, role: "ops" | "marketing"): Session {
  return {
    actor: { kind: "staff", userId, organisationId: orgId, role, signoffDepartmentIds: [] },
    user: { id: userId, email: "x@settle.test", fullName: "X", isExternal: false },
    organisation: {
      id: orgId,
      brandName: "Hall Pass",
      settings: {} as Session["organisation"]["settings"],
    },
  };
}

d("settling sign-off notifications", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    settle = await import("@/lib/domain/notifications");
    notifyMod = await import("@/lib/notify");
    queries = await import("@/lib/queries/approvals");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Settle Org", slug: `settle-${n}` })
      .returning();
    orgId = org.id;
    opsId = await addUser("Olive", "ops");
    ops2Id = await addUser("Oscar", "ops");
    mktId = await addUser("Mia", "marketing");
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Settle Event", code: `SE${n}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Settle Venue", code: `SV${n}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Settle Edition",
        code: `STL${n}`,
        buildStart: "2027-10-01",
        buildEnd: "2027-10-04",
        openStart: "2027-10-05",
        openEnd: "2027-10-07",
        breakdownEnd: "2027-10-08",
      })
      .returning();
    editionId = edition.id;
    const [wf] = await db
      .insert(schema.workflows)
      .values({ organisationId: orgId, name: `Settle WF ${n}`, appliesTo: "signage" })
      .returning();
    const [step] = await db
      .insert(schema.workflowSteps)
      .values({
        workflowId: wf.id,
        sortOrder: 1,
        name: "Operations sign-off",
        kind: "approval",
        approverType: "role",
        approverRole: "ops",
        conditions: ["always"],
        slaDays: 3,
      })
      .returning();
    stepId = step.id;
  });

  afterAll(async () => {
    // Leave nothing open for other suites' daily jobs to pick up.
    if (editionId) {
      await db
        .update(schema.signageItems)
        .set({ deletedAt: new Date() })
        .where(eq(schema.signageItems.editionId, editionId));
    }
    await client?.end();
  });

  it("keeps the request for whoever still holds a step and settles everyone else's", async () => {
    const item = await addItem();
    const inst = await addStep(item.id, { role: "ops" });
    await ask([opsId, ops2Id, mktId], item.id);
    // A decision notification is not a request: never touched.
    await ask([mktId], item.id, "decision_made");

    const settled = await db.transaction((tx) =>
      settle.settleApprovalNotifications(tx, "signage_item", item.id),
    );
    expect(settled).toBe(1); // Mia's request: the step is Operations'.
    expect((await unreadFor(item.id)).sort()).toEqual([opsId, ops2Id, mktId].sort());

    // Olive decides: nobody holds a step any more.
    await db
      .update(schema.approvalInstances)
      .set({ status: "approved", decidedBy: opsId, decidedAt: new Date() })
      .where(eq(schema.approvalInstances.id, inst.id));
    await db.transaction((tx) => settle.settleApprovalNotifications(tx, "signage_item", item.id));
    expect(await unreadFor(item.id)).toEqual([mktId]); // only the decision_made one
  });

  it("settles everyone when the item is put on hold", async () => {
    const item = await addItem("on_hold");
    await addStep(item.id, { role: "ops" });
    await ask([opsId, ops2Id], item.id);
    await db.transaction((tx) => settle.settleApprovalNotifications(tx, "signage_item", item.id));
    expect(await unreadFor(item.id)).toEqual([]);
  });

  it("a delegated step keeps only the delegate's request", async () => {
    const item = await addItem();
    await addStep(item.id, { userId: ops2Id });
    await ask([opsId, ops2Id], item.id, "approval_reminder");
    await db.transaction((tx) => settle.settleApprovalNotifications(tx, "signage_item", item.id));
    expect(await unreadFor(item.id)).toEqual([ops2Id]);
  });

  it("the daily safety net settles requests left behind", async () => {
    const item = await addItem();
    await ask([opsId], item.id); // no pending step at all
    const { settled } = await settle.settleStaleApprovalNotifications(db);
    expect(settled).toBeGreaterThanOrEqual(1);
    expect(await unreadFor(item.id)).toEqual([]);
  });

  it("resolveNotifications only touches the given kinds and record", async () => {
    const a = await addItem();
    const b = await addItem();
    await ask([opsId], a.id);
    await ask([opsId], b.id);
    const count = await db.transaction((tx) =>
      notifyMod.resolveNotifications(tx, {
        entityType: "signage_item",
        entityId: a.id,
        kinds: ["approval_requested"],
      }),
    );
    expect(count).toBe(1);
    expect(await unreadFor(a.id)).toEqual([]);
    expect(await unreadFor(b.id)).toEqual([opsId]);
  });

  it("counts what is waiting on me without loading bundles, leaving out held items", async () => {
    const live = await addItem();
    await addStep(live.id, { role: "ops", due: new Date(Date.now() - 2 * 86_400_000) });
    const held = await addItem("on_hold");
    await addStep(held.id, { role: "ops" });
    const deleted = await addItem();
    await addStep(deleted.id, { role: "ops" });
    await db
      .update(schema.signageItems)
      .set({ deletedAt: new Date() })
      .where(eq(schema.signageItems.id, deleted.id));

    const ops = sessionFor(opsId, "ops");
    const counts = await queries.countPendingForUser(ops);
    const queue = await queries.pendingInstancesForUser(ops);
    expect(counts.total).toBe(queue.length);
    expect(counts.overdue).toBe(queue.filter((q) => q.isOverdue).length);
    expect(counts.overdue).toBeGreaterThanOrEqual(1);
    const ids = queue.map((q) => q.raw.entityId);
    expect(ids).toContain(live.id);
    expect(ids).not.toContain(held.id);
    expect(ids).not.toContain(deleted.id);

    // Marketing holds none of these Operations steps.
    expect((await queries.countPendingForUser(sessionFor(mktId, "marketing"))).total).toBe(0);

    // The bell's Done state: still mine for the live item only.
    const mine = await queries.pendingEntityIdsForUser(ops, [live.id, held.id, deleted.id]);
    expect([...mine]).toEqual([live.id]);

    // Paused sign-off counts nothing.
    const paused = sessionFor(opsId, "ops");
    (paused.actor as { overrides?: Record<string, boolean> }).overrides = {
      "approval.decide": false,
    };
    expect((await queries.countPendingForUser(paused)).total).toBe(0);
  });

  it("the oldest waiting come first for My Work", async () => {
    const rows = await queries.oldestPendingForUser(sessionFor(opsId, "ops"), 2);
    expect(rows.length).toBeGreaterThan(0);
    const dues = rows.map((r) => r.dueAt?.getTime() ?? Infinity);
    expect([...dues].sort((x, y) => x - y)).toEqual(dues);
    expect(rows[0].href).toMatch(/^\/STL\d+\/signage\/SIG-STL/);
  });

  it("the team view says who each sign-off waits on", async () => {
    const item = await addItem();
    const inst = await addStep(item.id, { userId: mktId });
    const rows = await queries.openSignoffsForTeam(sessionFor(opsId, "ops"), { search: item.ref });
    const row = rows.find((r) => r.instanceId === inst.id)!;
    expect(row.waitingOn).toBe("Mia");
    expect(row.people).toEqual(["Mia"]);
    expect(row.isMine).toBe(false);
    // Operations can chase signage (they can send it for sign-off) but not decide Mia's step.
    expect(row.canRemind).toBe(true);
    expect(row.canDecide).toBe(false);
    await db
      .delete(schema.approvalInstances)
      .where(inArray(schema.approvalInstances.id, [inst.id]));
  });
});
