/**
 * The sign-off actions against a real database (TEST_DATABASE_URL), with the
 * session stubbed: deciding settles everyone's "Please sign off", tells
 * Operations when an approved item has no supplier, tells the step's people
 * when an admin decides for them; Remind chases once a day and is audited.
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
let actions: typeof import("@/app/actions/approvals");
const n = Date.now() % 1_000_000;
let orgId: string;
let editionId: string;
let editionCode: string;
let approvalStepId: string;
let printStepId: string;
const people: Record<string, { id: string; role: StaffRole; name: string }> = {};

async function addUser(key: string, name: string, role: StaffRole) {
  const id = randomUUID();
  await db.insert(schema.users).values({ id, email: `${key}-${n}@actions.test`, fullName: name });
  await db.insert(schema.memberships).values({ userId: id, organisationId: orgId, role });
  people[key] = { id, role, name };
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
    user: { id: p.id, email: `${key}@actions.test`, fullName: p.name, isExternal: false },
    organisation: {
      id: orgId,
      brandName: "Hall Pass",
      settings: {} as Session["organisation"]["settings"],
    },
  };
  state.session = session;
}

let seq = 0;
/** A sign in sign-off: one approval step (as given) then Sent to print waiting. */
async function itemInSignoff(step: { role?: string; userId?: string }) {
  seq++;
  const [item] = await db
    .insert(schema.signageItems)
    .values({
      editionId,
      ref: `SIG-ACT${n}-${String(seq).padStart(3, "0")}`,
      seq,
      name: `Action sign ${seq}`,
      status: "in_review",
      currentRunNumber: 1,
      createdBy: people.ops.id,
      ownerUserId: people.mkt.id,
    })
    .returning();
  const [approval] = await db
    .insert(schema.approvalInstances)
    .values({
      entityType: "signage_item",
      entityId: item.id,
      runNumber: 1,
      workflowStepId: approvalStepId,
      stepNameSnapshot: "Operations sign-off",
      stepKindSnapshot: "approval",
      sortOrderSnapshot: 1,
      status: "pending",
      assignedRole: step.role ?? null,
      assignedUserId: step.userId ?? null,
      pendingSince: new Date(),
      dueAt: new Date(Date.now() - 3 * 86_400_000),
    })
    .returning();
  await db.insert(schema.approvalInstances).values({
    entityType: "signage_item",
    entityId: item.id,
    runNumber: 1,
    workflowStepId: printStepId,
    stepNameSnapshot: "Sent to print",
    stepKindSnapshot: "confirmation",
    sortOrderSnapshot: 2,
    status: "waiting",
    assignedRole: "supplier",
  });
  return { item, approval };
}

async function notes(userKey: string, itemId: string) {
  return db
    .select()
    .from(schema.notifications)
    .where(
      and(
        eq(schema.notifications.userId, people[userKey].id),
        eq(schema.notifications.entityId, itemId),
      ),
    );
}

d("sign-off actions", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    actions = await import("@/app/actions/approvals");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Actions Org", slug: `actions-${n}` })
      .returning();
    orgId = org.id;
    await addUser("admin", "Alex Admin", "admin");
    await addUser("ops", "Olive Ops", "ops");
    await addUser("ops2", "Oscar Ops", "ops");
    await addUser("mkt", "Mia Marketing", "marketing");
    await addUser("viewer", "Vic Viewer", "viewer");
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Actions Event", code: `AE${n}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Actions Venue", code: `AV${n}` })
      .returning();
    editionCode = `ACT${n}`;
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Actions Edition",
        code: editionCode,
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
      .values({ organisationId: orgId, name: `Actions WF ${n}`, appliesTo: "signage" })
      .returning();
    const [a, p] = await db
      .insert(schema.workflowSteps)
      .values([
        {
          workflowId: wf.id,
          sortOrder: 1,
          name: "Operations sign-off",
          kind: "approval",
          approverType: "role",
          approverRole: "ops",
          conditions: ["always"],
          slaDays: 3,
        },
        {
          workflowId: wf.id,
          sortOrder: 2,
          name: "Sent to print",
          kind: "confirmation",
          approverType: "role",
          approverRole: "supplier",
          conditions: ["always"],
          slaDays: 3,
        },
      ])
      .returning();
    approvalStepId = a.id;
    printStepId = p.id;
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

  it("deciding settles everyone's request and flags a missing supplier to Operations", async () => {
    const { item, approval } = await itemInSignoff({ role: "ops" });
    await db.insert(schema.notifications).values(
      ["ops", "ops2"].map((k) => ({
        userId: people[k].id,
        kind: "approval_requested",
        title: `Please sign off: ${item.ref}`,
        entityType: "signage_item" as const,
        entityId: item.id,
      })),
    );
    as("ops");
    const res = await actions.decideApproval({
      instanceId: approval.id,
      decision: "approve",
      expectedStatus: "pending",
      expectedLockedVersionId: null,
    });
    expect(res).toMatchObject({ ok: true });

    // Oscar's "Please sign off" is settled; the decision is done.
    const oscar = await notes("ops2", item.id);
    const request = oscar.find((x) => x.kind === "approval_requested")!;
    expect(request.readAt).not.toBeNull();
    // Operations hear the sign is approved with no supplier.
    const flag = oscar.find((x) => x.kind === "supplier_needed");
    expect(flag?.title).toBe(
      `${item.ref} is approved but has no supplier — set one before it can go to print`,
    );
    expect(flag?.link).toBe(`/${editionCode}/signage/${item.ref}`);
    // The owner hears the decision in plain words.
    const owner = await notes("mkt", item.id);
    expect(owner.find((x) => x.kind === "decision_made")?.title).toBe(
      `Operations sign-off: approved — ${item.ref}`,
    );
    // Deciding your own step tells nobody it was decided "for them".
    expect(oscar.some((x) => x.title.includes("for you"))).toBe(false);
  });

  it("an admin deciding someone else's step tells them", async () => {
    const { item, approval } = await itemInSignoff({ userId: people.mkt.id });
    as("admin");
    const res = await actions.decideApproval({
      instanceId: approval.id,
      decision: "request_changes",
      comment: "Logo too small",
      expectedStatus: "pending",
      expectedLockedVersionId: null,
    });
    expect(res).toMatchObject({ ok: true });
    const mia = await notes("mkt", item.id);
    expect(
      mia.find((x) => x.title.startsWith("Alex Admin decided Operations sign-off on"))?.title,
    ).toBe(`Alex Admin decided Operations sign-off on ${item.ref} for you: changes requested`);
  });

  it("Remind tells whoever the step waits on, once a day, and is in the History", async () => {
    const { item, approval } = await itemInSignoff({ userId: people.mkt.id });
    as("ops");
    const first = await actions.remindApproval({ instanceId: approval.id });
    expect(first).toMatchObject({ ok: true, data: { reminded: 1, alreadyToday: 0 } });
    const mia = (await notes("mkt", item.id)).filter((x) => x.kind === "approval_reminder");
    expect(mia).toHaveLength(1);
    expect(mia[0].title).toBe(`Reminder from Olive Ops: Operations sign-off on ${item.ref}`);
    expect(mia[0].body).toBe("It is 3 days overdue. Open it to review and decide.");
    const [audit] = await db
      .select()
      .from(schema.auditLog)
      .where(and(eq(schema.auditLog.entityId, item.id), eq(schema.auditLog.action, "escalate")));
    expect(audit.actorUserId).toBe(people.ops.id);
    expect(audit.summary).toBe("Reminder sent for Operations sign-off (1 person)");

    // Again today, by anyone: not sent twice.
    as("admin");
    const again = await actions.remindApproval({ instanceIds: [approval.id] });
    expect(again).toMatchObject({ ok: true, data: { reminded: 0, alreadyToday: 1 } });
    expect(
      (await notes("mkt", item.id)).filter((x) => x.kind === "approval_reminder"),
    ).toHaveLength(1);
  });

  it("viewers cannot chase, and decided steps cannot be chased", async () => {
    const { approval } = await itemInSignoff({ role: "ops" });
    as("viewer");
    expect(await actions.remindApproval({ instanceId: approval.id })).toMatchObject({
      ok: false,
      error: "You cannot chase this sign-off",
    });
    await db
      .update(schema.approvalInstances)
      .set({ status: "approved" })
      .where(eq(schema.approvalInstances.id, approval.id));
    as("ops");
    expect(await actions.remindApproval({ instanceId: approval.id })).toMatchObject({
      ok: false,
    });
  });

  it("delegating settles the request of whoever the step was with", async () => {
    const { item, approval } = await itemInSignoff({ role: "ops" });
    await db.insert(schema.notifications).values({
      userId: people.ops2.id,
      kind: "approval_requested",
      title: `Please sign off: ${item.ref}`,
      entityType: "signage_item",
      entityId: item.id,
    });
    as("ops");
    const res = await actions.delegateApproval({
      instanceId: approval.id,
      toUserId: people.mkt.id,
    });
    expect(res).toMatchObject({ ok: true });
    const oscar = await notes("ops2", item.id);
    expect(oscar.find((x) => x.kind === "approval_requested")?.readAt).not.toBeNull();
    const mia = await notes("mkt", item.id);
    const delegated = mia.find((x) => x.kind === "delegation")!;
    expect(delegated.readAt).toBeNull();
    expect(delegated.link).toBe(`/${editionCode}/signage/${item.ref}?tab=artwork`);
  });
});
