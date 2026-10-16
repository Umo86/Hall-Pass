/**
 * Handing work to people, against a real database (TEST_DATABASE_URL) with
 * the session stubbed: owners are checked by item kind and told the item is
 * theirs; bulk "Change owner" checks each item; a stand's panels follow its
 * owner; snags record who raised them and tell the raiser and owner when
 * fixed; delegation and deciding on someone's behalf name the person in the
 * audit log and tell them; supplier and venue steps nobody can sign in for
 * tell the people who can act; open department sign-offs follow a new main
 * approver; tasks moved to someone else take their subtasks along; the
 * morning task reminder counts what My Work counts.
 */
import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";
import type { Session } from "@/lib/auth/actor";
import type { PermissionOverrides, StaffRole } from "@/lib/authz";

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
let signageActions: typeof import("@/app/actions/signage");
let bulkActions: typeof import("@/app/actions/signage-bulk");
let snagActions: typeof import("@/app/actions/snags");
let approvalActions: typeof import("@/app/actions/approvals");
let taskActions: typeof import("@/app/actions/tasks");
let signageDomain: typeof import("@/lib/domain/signage");
let people: typeof import("@/lib/people");
let taskQueries: typeof import("@/lib/queries/tasks");
let cron: typeof import("@/lib/cron/jobs");

const n = Date.now() % 1_000_000;
let orgId: string;
let editionId: string;
let editionCode: string;
let sponsorId: string;
let supplierId: string;
let workflowId: string;
let mktStepId: string;
let mktDeptId: string;
const team: Record<string, { id: string; role: StaffRole; name: string }> = {};

async function addUser(
  key: string,
  role: StaffRole,
  extra: Partial<typeof schema.memberships.$inferInsert> = {},
) {
  const id = randomUUID();
  const name = `${key[0].toUpperCase()}${key.slice(1)} ${n}`;
  await db.insert(schema.users).values({ id, email: `${key}-${n}@people.test`, fullName: name });
  await db.insert(schema.memberships).values({ userId: id, organisationId: orgId, role, ...extra });
  team[key] = { id, role, name };
}

function as(key: string, overrides: PermissionOverrides = {}) {
  const p = team[key];
  const session: Session = {
    actor: {
      kind: "staff",
      userId: p.id,
      organisationId: orgId,
      role: p.role,
      overrides,
      signoffDepartmentIds: key === "mia" || key === "max" ? [mktDeptId] : [],
    },
    user: { id: p.id, email: `${key}-${n}@people.test`, fullName: p.name, isExternal: false },
    organisation: {
      id: orgId,
      brandName: "Hall Pass",
      settings: {} as Session["organisation"]["settings"],
    },
  };
  state.session = session;
}

let seq = 0;
async function addItem(values: Partial<typeof schema.signageItems.$inferInsert> = {}) {
  seq++;
  const [item] = await db
    .insert(schema.signageItems)
    .values({
      editionId,
      ref: `SIG-PPX${n}-${String(seq).padStart(3, "0")}`,
      seq: 500 + seq,
      name: `People sign ${seq}`,
      createdBy: team.ops.id,
      ownerUserId: team.ops.id,
      workflowId,
      ...values,
    })
    .returning();
  return item;
}

const notesFor = async (key: string, entityId?: string) =>
  db
    .select()
    .from(schema.notifications)
    .where(
      and(
        eq(schema.notifications.userId, team[key].id),
        entityId ? eq(schema.notifications.entityId, entityId) : undefined,
      ),
    );

const itemNow = async (id: string) =>
  (await db.select().from(schema.signageItems).where(eq(schema.signageItems.id, id)))[0];

const auditFor = async (entityId: string) =>
  db.select().from(schema.auditLog).where(eq(schema.auditLog.entityId, entityId));

d("handing work to people", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    signageActions = await import("@/app/actions/signage");
    bulkActions = await import("@/app/actions/signage-bulk");
    snagActions = await import("@/app/actions/snags");
    approvalActions = await import("@/app/actions/approvals");
    taskActions = await import("@/app/actions/tasks");
    signageDomain = await import("@/lib/domain/signage");
    people = await import("@/lib/people");
    taskQueries = await import("@/lib/queries/tasks");
    cron = await import("@/lib/cron/jobs");

    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "People Org", slug: `people-${n}` })
      .returning();
    orgId = org.id;
    const [dept] = await db
      .insert(schema.departments)
      .values({ organisationId: orgId, name: `Marketing ${n}`, defaultFor: ["organiser"] })
      .returning();
    mktDeptId = dept.id;
    const [opsDept] = await db
      .insert(schema.departments)
      .values({ organisationId: orgId, name: `Operations ${n}`, signsOff: false })
      .returning();
    await addUser("admin", "admin");
    await addUser("ops", "ops", { departmentId: opsDept.id });
    await addUser("ops2", "ops", { departmentId: opsDept.id });
    await addUser("mia", "marketing", { departmentId: mktDeptId, jobTitle: "Marketing Manager" });
    await addUser("max", "marketing", { departmentId: mktDeptId });
    await addUser("sales", "sales");
    await addUser("director", "event_director");
    await addUser("gone", "marketing", { departmentId: mktDeptId, suspendedAt: new Date() });
    await addUser("inviter", "ops", { permissionOverrides: { "partners.invite": true } });
    await db.insert(schema.approvers).values([
      {
        organisationId: orgId,
        departmentId: mktDeptId,
        fullName: team.mia.name,
        email: `mia-${n}@people.test`,
        userId: team.mia.id,
        isMain: true,
      },
      {
        organisationId: orgId,
        departmentId: mktDeptId,
        fullName: team.max.name,
        email: `max-${n}@people.test`,
        userId: team.max.id,
      },
    ]);

    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "People Event", code: `PE${n}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: `People Venue ${n}`, code: `PV${n}` })
      .returning();
    editionCode = `PPL${n}`;
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "People Edition",
        code: editionCode,
        buildStart: "2027-10-01",
        buildEnd: "2027-10-04",
        openStart: "2027-10-05",
        openEnd: "2027-10-07",
        breakdownEnd: "2027-10-08",
      })
      .returning();
    editionId = edition.id;
    const [sponsor] = await db
      .insert(schema.sponsors)
      .values({ editionId, companyName: `Sponsor ${n}` })
      .returning();
    sponsorId = sponsor.id;
    const [supplier] = await db
      .insert(schema.suppliers)
      .values({ organisationId: orgId, name: `Big Print ${n}` })
      .returning();
    supplierId = supplier.id;
    const [wf] = await db
      .insert(schema.workflows)
      .values({ organisationId: orgId, name: `People WF ${n}`, appliesTo: "signage" })
      .returning();
    workflowId = wf.id;
    const [step] = await db
      .insert(schema.workflowSteps)
      .values({
        workflowId,
        sortOrder: 1,
        name: "Marketing sign-off",
        kind: "approval",
        approverType: "user",
        approverUserId: team.mia.id,
        departmentId: mktDeptId,
        defaultFor: ["organiser"],
        conditions: ["always"],
      })
      .returning();
    mktStepId = step.id;
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

  it("refuses an owner who can't work on that kind of item, and tells the one who can", async () => {
    as("ops");
    const sales = await signageActions.createSignageItem({
      editionId,
      name: "Entrance arch",
      kind: "signage",
      category: "organiser",
      ownerUserId: team.sales.id,
      workflowId,
    });
    expect(sales).toMatchObject({
      ok: false,
      error: `${team.sales.name} can't work on signage — pick someone else`,
    });
    const suspended = await signageActions.createSignageItem({
      editionId,
      name: "Entrance arch",
      kind: "signage",
      ownerUserId: team.gone.id,
      workflowId,
    });
    expect(suspended).toMatchObject({
      ok: false,
      error: `${team.gone.name}'s access is suspended — pick someone else`,
    });
    // Sales may own sponsor signage.
    const sponsorSign = await signageActions.createSignageItem({
      editionId,
      name: "Sponsor banner",
      kind: "signage",
      category: "sponsor",
      sponsorId,
      ownerUserId: team.sales.id,
      workflowId,
    });
    expect(sponsorSign).toMatchObject({ ok: true });

    const created = await signageActions.createSignageItem({
      editionId,
      name: "Hall sign",
      kind: "signage",
      category: "organiser",
      ownerUserId: team.mia.id,
      workflowId,
    });
    expect(created.ok).toBe(true);
    const ref = created.ok ? created.data!.ref : "";
    const [item] = await db
      .select()
      .from(schema.signageItems)
      .where(eq(schema.signageItems.ref, ref));
    expect(item).toMatchObject({ ownerUserId: team.mia.id, ownerRole: "marketing" });
    // The owner is told it's theirs; their department hears it's new; the
    // suspended colleague and the creator hear nothing.
    expect((await notesFor("mia", item.id)).map((x) => [x.kind, x.title])).toEqual([
      ["item_assigned", `${team.ops.name} gave you ${ref} — Hall sign`],
    ]);
    expect((await notesFor("max", item.id)).map((x) => x.kind)).toEqual(["item_created"]);
    expect(await notesFor("gone", item.id)).toHaveLength(0);
    expect(await notesFor("ops", item.id)).toHaveLength(0);
  });

  it("changing the owner tells the new owner and the previous one", async () => {
    as("ops2");
    const item = await addItem({ ownerUserId: team.mia.id, ownerRole: "marketing" });
    const res = await signageActions.updateSignageItem({ id: item.id, ownerUserId: team.max.id });
    expect(res).toMatchObject({ ok: true });
    expect((await itemNow(item.id)).ownerUserId).toBe(team.max.id);
    expect((await notesFor("max", item.id)).map((x) => x.title)).toEqual([
      `${team.ops2.name} gave you ${item.ref} — ${item.name}`,
    ]);
    expect((await notesFor("mia", item.id)).map((x) => x.title)).toEqual([
      `${item.ref} is now ${team.max.name}'s`,
    ]);
    const audit = await auditFor(item.id);
    expect(audit.some((a) => a.summary.includes(`owner changed to ${team.max.name}`))).toBe(true);
    // The director can't own signage; an unchanged owner is always kept.
    expect(
      await signageActions.updateSignageItem({ id: item.id, ownerUserId: team.director.id }),
    ).toMatchObject({ ok: false });
    await db
      .update(schema.memberships)
      .set({ suspendedAt: new Date() })
      .where(eq(schema.memberships.userId, team.max.id));
    try {
      expect(
        await signageActions.updateSignageItem({
          id: item.id,
          ownerUserId: team.max.id,
          name: "Renamed",
        }),
      ).toMatchObject({ ok: true });
    } finally {
      await db
        .update(schema.memberships)
        .set({ suspendedAt: null })
        .where(eq(schema.memberships.userId, team.max.id));
    }
  });

  it("bulk Change owner checks each item and reports why some were left", async () => {
    as("ops");
    const organiser = await addItem({ category: "organiser" });
    const sponsorSign = await addItem({ category: "sponsor", sponsorId });
    const theirs = await addItem({ category: "sponsor", sponsorId, ownerUserId: team.sales.id });
    const res = await bulkActions.bulkSignageAction({
      ids: [organiser.id, sponsorSign.id, theirs.id],
      action: "set_owner",
      ownerUserId: team.sales.id,
    });
    expect(res).toMatchObject({ ok: true, data: { done: 1, failed: 2 } });
    const reasons = res.ok ? res.data!.failures.map((f) => [f.ref, f.reason]) : [];
    expect(reasons).toEqual([
      [organiser.ref, `${team.sales.name} can't work on signage`],
      [theirs.ref, `already ${team.sales.name}'s`],
    ]);
    expect((await itemNow(sponsorSign.id)).ownerUserId).toBe(team.sales.id);
    expect((await itemNow(organiser.id)).ownerUserId).toBe(team.ops.id);
    const audit = await auditFor(sponsorSign.id);
    expect(audit.find((a) => a.summary.endsWith("(bulk)"))).toMatchObject({
      before: { ownerUserId: team.ops.id },
      after: { ownerUserId: team.sales.id },
    });
    // Nobody suspended can be given anything.
    expect(
      await bulkActions.bulkSignageAction({
        ids: [organiser.id],
        action: "set_owner",
        ownerUserId: team.gone.id,
      }),
    ).toMatchObject({ ok: false });
    // Without the bulk ability, nothing at all.
    as("ops", { "signage.bulk": false });
    expect(
      await bulkActions.bulkSignageAction({
        ids: [organiser.id],
        action: "set_owner",
        ownerUserId: team.mia.id,
      }),
    ).toMatchObject({ ok: false });
  });

  it("a stand's panels follow its owner, in bulk too", async () => {
    as("ops");
    const stand = await addItem({ kind: "stand_design", name: "Feature stand" });
    const panelA = await addItem({ kind: "stand_panel", parentItemId: stand.id });
    const panelB = await addItem({
      kind: "stand_panel",
      parentItemId: stand.id,
      status: "installed",
    });
    const res = await bulkActions.bulkSignageAction({
      ids: [stand.id, panelA.id],
      action: "set_owner",
      ownerUserId: team.ops2.id,
    });
    expect(res).toMatchObject({ ok: true, data: { done: 1, failed: 1 } });
    expect(res.ok && res.data!.failures[0].reason).toMatch(/goes with its stand/);
    for (const id of [stand.id, panelA.id, panelB.id]) {
      expect((await itemNow(id)).ownerUserId).toBe(team.ops2.id);
    }
    // Marketing can't run a feature stand.
    expect(
      await bulkActions.bulkSignageAction({
        ids: [stand.id],
        action: "set_owner",
        ownerUserId: team.mia.id,
      }),
    ).toMatchObject({ ok: true, data: { done: 0, failed: 1 } });
  });

  it("records who raised a snag and tells the raiser and owner — not the fixer — when fixed", async () => {
    const item = await addItem({ status: "installed", ownerUserId: team.ops2.id });
    as("mia");
    const raise = new FormData();
    raise.set("itemId", item.id);
    raise.set("description", "Edge peeling");
    expect(await snagActions.raiseSnag(raise)).toMatchObject({ ok: true });
    const [snag] = await db
      .select()
      .from(schema.snags)
      .where(eq(schema.snags.signageItemId, item.id));
    expect(snag).toMatchObject({ raisedByUserId: team.mia.id, assignedUserId: null });

    as("ops");
    const fix = new FormData();
    fix.set("snagId", snag.id);
    fix.set("status", "resolved");
    fix.set("note", "Re-stuck");
    expect(await snagActions.updateSnag(fix)).toMatchObject({ ok: true });
    const fixedFor = async (key: string) =>
      (await notesFor(key, item.id)).filter((x) => x.title.startsWith("Snag resolved"));
    expect(await fixedFor("mia")).toHaveLength(1);
    expect((await fixedFor("mia"))[0].body).toBe(`Fixed by ${team.ops.name}: Re-stuck`);
    expect(await fixedFor("ops2")).toHaveLength(1);
    expect(await fixedFor("ops")).toHaveLength(0);
    const views = await (await import("@/lib/queries/signage")).getItemSnagsWithPeople(item.id);
    expect(views[0]).toMatchObject({
      raisedByName: team.mia.name,
      resolvedByName: team.ops.name,
    });
  });

  /** An item in sign-off whose Marketing step is pending, named for `who` (or the department). */
  async function inSignoff(who: string | null, signoffs: unknown = null) {
    const item = await addItem({
      status: "in_review",
      currentRunNumber: 1,
      signoffs: signoffs as never,
    });
    const [inst] = await db
      .insert(schema.approvalInstances)
      .values({
        entityType: "signage_item",
        entityId: item.id,
        runNumber: 1,
        workflowStepId: mktStepId,
        stepNameSnapshot: "Marketing sign-off",
        stepKindSnapshot: "approval",
        sortOrderSnapshot: 1,
        status: "pending",
        assignedDepartmentId: mktDeptId,
        assignedUserId: who,
        pendingSince: new Date(),
      })
      .returning();
    return { item, inst };
  }

  it("delegating names who it was waiting on, in the audit log, and tells them", async () => {
    const { item, inst } = await inSignoff(team.mia.id);
    as("admin");
    expect(
      await approvalActions.delegateApproval({ instanceId: inst.id, toUserId: team.max.id }),
    ).toMatchObject({ ok: true });
    const [row] = (await auditFor(item.id)).filter((a) => a.action === "delegate");
    expect(row).toMatchObject({
      subjectUserId: team.mia.id,
      before: { assignedUserId: team.mia.id },
      after: { toUserId: team.max.id, fromUserId: team.mia.id },
    });
    expect(row.summary).toBe(
      `Marketing sign-off delegated to ${team.max.name} (was with ${team.mia.name})`,
    );
    expect((await notesFor("mia", item.id)).map((x) => x.title)).toContain(
      `Marketing sign-off on ${item.ref} is now with ${team.max.name}`,
    );
    // A department-wide step can be taken by one of its people for themselves.
    const open = await inSignoff(null);
    as("max");
    expect(
      await approvalActions.delegateApproval({ instanceId: open.inst.id, toUserId: team.max.id }),
    ).toMatchObject({ ok: true });
  });

  it("deciding for someone else names them in the audit log", async () => {
    const { item, inst } = await inSignoff(team.mia.id);
    as("admin");
    const res = await approvalActions.decideApproval({
      instanceId: inst.id,
      decision: "approve",
      expectedStatus: "pending",
      expectedLockedVersionId: null,
    });
    expect(res).toMatchObject({ ok: true });
    const [row] = (await auditFor(item.id)).filter((a) => a.action === "decide");
    expect(row.subjectUserId).toBe(team.mia.id);
    expect(row.after).toMatchObject({ onBehalfOf: [team.mia.id] });
    expect(row.summary).toContain(`— for ${team.mia.name}`);
  });

  it("tells who can act when nobody at a supplier or venue can sign in", async () => {
    // A supplier's confirmation: Operations hear; the one who can invite
    // partners gets the invitation link, the others are told who can.
    const item = await addItem({ status: "approved", supplierId, ownerUserId: team.mia.id });
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
    const [toOps] = await notesFor("ops", item.id);
    expect(toOps.body).toBe(
      `Nobody at Big Print ${n} can sign in to Hall Pass yet, so they can't confirm this. Confirm it on ${item.ref} yourself once it's done — or ask ${team.admin.name} or ${team.inviter.name} to invite them.`,
    );
    expect(toOps.link).toBe(`/${editionCode}/signage/${item.ref}`);
    const [toInviter] = await notesFor("inviter", item.id);
    expect(toInviter.body).toContain("Confirm it on");
    expect(toInviter.body).toContain(", or invite them.");
    expect(toInviter.link).toBe(
      `/users?tab=external&invite=1&role=supplier&scopeId=${supplierId}&edition=${editionId}`,
    );
    // Not the suspended, nor Marketing (they don't confirm production).
    expect(await notesFor("mia", item.id)).toHaveLength(0);

    // A venue sign-off: Operations and the item's owner.
    const venueItem = await addItem({ status: "in_review", ownerUserId: team.mia.id });
    const venueBundle = (await signageDomain.loadItemBundle(db, venueItem.id))!;
    await db.transaction((tx) =>
      signageDomain.notifyPendingAssignees(tx, venueBundle, [
        {
          status: "pending",
          stepName: "Venue approval",
          stepKind: "approval",
          assignedRole: "venue",
          assignedUserId: null,
        },
      ]),
    );
    const [toOwner] = await notesFor("mia", venueItem.id);
    expect(toOwner.title).toBe(
      `Nobody at People Venue ${n} can sign off ${venueItem.ref} — ${venueItem.name}`,
    );
    expect(toOwner.body).toContain(
      `Ask ${team.admin.name} or ${team.inviter.name} to invite them.`,
    );
    expect(await notesFor("ops", venueItem.id)).toHaveLength(1);
    expect((await notesFor("inviter", venueItem.id))[0].link).toContain("role=venue");

    // An invitation nobody has accepted yet is named instead.
    await db.insert(schema.externalGrants).values({
      invitedEmail: `print-${n}@supplier.test`,
      organisationId: orgId,
      editionId,
      role: "supplier",
      scopeType: "supplier",
      scopeId: supplierId,
      inviteTokenHash: `hash-${n}`,
    });
    const again = await addItem({ status: "approved", supplierId });
    const againBundle = (await signageDomain.loadItemBundle(db, again.id))!;
    await db.transaction((tx) =>
      signageDomain.notifyPendingAssignees(tx, againBundle, [
        {
          status: "pending",
          stepName: "Sent to print",
          stepKind: "confirmation",
          assignedRole: "supplier",
          assignedUserId: null,
        },
      ]),
    );
    const [invited] = await notesFor("ops", again.id);
    expect(invited.body).toContain(`print-${n}@supplier.test was invited on`);
    expect(invited.body).toContain("to resend the invitation.");
  });

  it("open department sign-offs follow a new main approver; chosen people stay", async () => {
    const byDefault = await inSignoff(team.mia.id, null);
    const chosen = await inSignoff(team.mia.id, [{ stepId: mktStepId, userId: team.mia.id }]);
    const leftDept = await inSignoff(team.ops.id, [{ stepId: mktStepId, userId: team.ops.id }]);
    // Max becomes Marketing's main approver.
    await db
      .update(schema.approvers)
      .set({ isMain: false })
      .where(eq(schema.approvers.userId, team.mia.id));
    await db
      .update(schema.approvers)
      .set({ isMain: true })
      .where(eq(schema.approvers.userId, team.max.id));
    try {
      const moved = await db.transaction((tx) => people.rerouteDepartmentSignoffs(tx, orgId));
      expect(moved).toBeGreaterThanOrEqual(2);
      const assigned = async (id: string) =>
        (
          await db
            .select()
            .from(schema.approvalInstances)
            .where(eq(schema.approvalInstances.id, id))
        )[0].assignedUserId;
      expect(await assigned(byDefault.inst.id)).toBe(team.max.id);
      expect(await assigned(chosen.inst.id)).toBe(team.mia.id);
      // Ops was never a Marketing approver: the step goes to the department's main.
      expect(await assigned(leftDept.inst.id)).toBe(team.max.id);
      const [row] = (await auditFor(byDefault.item.id)).filter((a) => a.action === "delegate");
      expect(row).toMatchObject({ subjectUserId: team.mia.id, actorType: "system" });
      expect(row.summary).toContain("main approver changed");
      expect((await notesFor("max", byDefault.item.id)).map((x) => x.kind)).toContain(
        "approval_requested",
      );
      // Running it again moves nothing.
      expect(await db.transaction((tx) => people.rerouteDepartmentSignoffs(tx, orgId))).toBe(0);
    } finally {
      await db
        .update(schema.approvers)
        .set({ isMain: false })
        .where(eq(schema.approvers.userId, team.max.id));
      await db
        .update(schema.approvers)
        .set({ isMain: true })
        .where(eq(schema.approvers.userId, team.mia.id));
    }
  });

  it("a new round never starts with someone who can't sign for the department", async () => {
    // A stored plan naming someone who has since been taken off Marketing.
    const item = await addItem({
      status: "draft",
      signoffs: [{ stepId: mktStepId, userId: team.ops.id }],
    });
    const bundle = (await signageDomain.loadItemBundle(db, item.id))!;
    const instances = await db.transaction((tx) =>
      signageDomain.startItemRun(tx, bundle, new Date()),
    );
    const mkt = instances.find((i) => i.stepName === "Marketing sign-off")!;
    expect(mkt.assignedUserId).toBe(team.mia.id);
  });

  it("moving a task takes its open subtasks with it and records who it moved from", async () => {
    as("ops");
    const created = await taskActions.createTask({
      title: `Check proofs ${n}`,
      assignedToUserId: team.mia.id,
    });
    expect(created.ok).toBe(true);
    const taskId = created.ok ? created.data!.id : "";
    as("mia");
    expect(await taskActions.createTask({ title: "Sub one", parentTaskId: taskId })).toMatchObject({
      ok: true,
    });
    as("ops");
    // Suspended people can't be given it.
    expect(
      await taskActions.updateTask({ id: taskId, assignedToUserId: team.gone.id }),
    ).toMatchObject({
      ok: false,
      error: `${team.gone.name}'s access is suspended — pick someone else`,
    });
    const res = await taskActions.updateTask({ id: taskId, assignedToUserId: team.max.id });
    expect(res).toMatchObject({
      ok: true,
      message: `Task moved to ${team.max.name} with 1 subtask`,
    });
    const subs = await db.select().from(schema.tasks).where(eq(schema.tasks.parentTaskId, taskId));
    expect(subs.map((s) => s.assignedToUserId)).toEqual([team.max.id]);
    const [row] = (await auditFor(taskId)).filter((a) => a.action === "update");
    expect(row).toMatchObject({
      before: { assignedToUserId: team.mia.id },
      after: { assignedToUserId: team.max.id, subtasksMoved: 1 },
      subjectUserId: team.mia.id,
    });
    const told = (await notesFor("mia")).filter((x) => x.title.startsWith("Task moved to"));
    expect(told).toHaveLength(1);
  });

  it("the morning reminder counts tasks the way My Work does", async () => {
    as("ops");
    const today = "2026-10-16";
    const late = await taskActions.createTask({
      title: `Late parent ${n}`,
      assignedToUserId: team.ops2.id,
      dueDate: "2026-10-20",
    });
    const lateId = late.ok ? late.data!.id : "";
    // A late subtask counts its task once; subtasks aren't counted themselves.
    await taskActions.createTask({
      title: "late sub",
      parentTaskId: lateId,
      dueDate: "2026-10-01",
    });
    await taskActions.createTask({
      title: "late sub 2",
      parentTaskId: lateId,
      dueDate: "2026-10-02",
    });
    await taskActions.createTask({
      title: `Due today ${n}`,
      assignedToUserId: team.ops2.id,
      dueDate: today,
    });
    const summary = await taskQueries.myTaskSummary({
      organisationId: orgId,
      userId: team.ops2.id,
      today,
    });
    expect(summary.overdue + summary.dueToday).toBe(2);
    await cron.taskReminders(today);
    const [reminder] = (await notesFor("ops2")).filter((x) => x.kind === "task_reminder");
    expect(reminder.title).toBe("You have 2 tasks due or overdue");
  });

  it("import sets owners from an Owner email column, or the importer, and says which", async () => {
    const ExcelJS = (await import("exceljs")).default;
    const { importSchedule } = await import("@/app/actions/import");
    const wb = new ExcelJS.Workbook();
    const { IMPORT_COLUMNS } = await import("@/lib/exports/import-columns");
    const ws = wb.addWorksheet("Schedule");
    // The template's columns, with "Owner email" added at the end.
    ws.addRow([...IMPORT_COLUMNS, "Owner email"]);
    const row = (name: string, owner: string) =>
      ws.addRow([
        ...IMPORT_COLUMNS.map((c) => (c === "Name" ? name : c === "Category" ? "Organiser" : "")),
        owner,
      ]);
    row(`Imported A ${n}`, `mia-${n}@people.test`);
    row(`Imported B ${n}`, `sales-${n}@people.test`);
    row(`Imported C ${n}`, "nobody@elsewhere.test");
    row(`Imported D ${n}`, "");
    const buf = Buffer.from(await wb.xlsx.writeBuffer());
    const form = (dryRun: boolean) => {
      const fd = new FormData();
      fd.set("editionId", editionId);
      fd.set("file", new File([buf], "schedule.xlsx"));
      if (dryRun) fd.set("dryRun", "on");
      return fd;
    };
    as("ops");
    const check = await importSchedule(form(true));
    expect(check).toMatchObject({
      ok: true,
      data: { dryRun: true, created: 4, owners: { fromSheet: 1, toYou: 3 } },
    });
    const notes = check.ok ? check.data!.owners!.notes : [];
    expect(notes).toEqual([
      { row: 3, message: `${team.sales.name} can't work on signage — given to you` },
      { row: 4, message: "nobody@elsewhere.test isn't on the team — given to you" },
    ]);
    const done = await importSchedule(form(false));
    expect(done).toMatchObject({ ok: true, data: { created: 4 } });
    const rows = await db
      .select()
      .from(schema.signageItems)
      .where(eq(schema.signageItems.editionId, editionId));
    const owner = (name: string) => rows.find((r) => r.name === name)?.ownerUserId;
    expect(owner(`Imported A ${n}`)).toBe(team.mia.id);
    expect(owner(`Imported B ${n}`)).toBe(team.ops.id);
    expect(owner(`Imported C ${n}`)).toBe(team.ops.id);
    expect(owner(`Imported D ${n}`)).toBe(team.ops.id);
    expect(rows.find((r) => r.name === `Imported A ${n}`)?.ownerRole).toBe("marketing");
    const given = (await notesFor("mia")).filter((x) => x.kind === "item_assigned");
    expect(given.some((x) => x.title.endsWith(`Imported A ${n}`))).toBe(true);
  });

  it("picker lists come from one place, with the current holder labelled", async () => {
    const owners = await people.peopleFor(
      db,
      orgId,
      { type: "owner", item: { kind: "signage", sponsored: false } },
      { include: [team.gone.id] },
    );
    const ids = owners.map((p) => p.id);
    expect(ids).toEqual(expect.arrayContaining([team.ops.id, team.mia.id, team.admin.id]));
    expect(ids).not.toContain(team.sales.id);
    expect(ids).not.toContain(team.director.id);
    expect(owners.find((p) => p.id === team.gone.id)?.unavailable).toBe("Suspended");
    expect(owners.find((p) => p.id === team.mia.id)).toMatchObject({
      jobTitle: "Marketing Manager",
      departmentName: `Marketing ${n}`,
    });
    const signers = await people.peopleFor(db, orgId, { type: "signoff", departmentId: mktDeptId });
    // Only Marketing's approvers who can sign now.
    expect(signers.map((p) => p.id).sort()).toEqual([team.max.id, team.mia.id].sort());
    // Viewers and suspended people never; everyone else with access for tasks.
    const tasksFor = await people.peopleFor(db, orgId, { type: "task" });
    expect(tasksFor.map((p) => p.id)).not.toContain(team.gone.id);
    const confirmers = people.eligibleIds(
      await people.loadTeam(db, orgId),
      { type: "confirm" },
      {
        organisationId: orgId,
      },
    );
    expect(confirmers).toEqual(
      expect.arrayContaining([team.ops.id, team.ops2.id, team.inviter.id, team.admin.id]),
    );
    expect(confirmers).not.toContain(team.mia.id);
  });
});
