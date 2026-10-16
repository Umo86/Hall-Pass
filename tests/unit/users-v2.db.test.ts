/**
 * Users v2 pages against a real database (TEST_DATABASE_URL): add several
 * people (per-row results), bulk changes checked per person, sign-offs
 * handed to someone who can sign for each department on suspension —
 * including steps that haven't started yet — the Suspend dialog's data,
 * removal handing tasks and items to the person picked, taking someone off
 * a department sending its sign-offs back, and an invitation never taking
 * "main approver" from someone who can sign.
 */
import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "@/lib/db/schema";
import type { StaffRole } from "@/lib/authz";
import { defaultSignageSteps } from "@/lib/workflow";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let manage: typeof import("@/lib/users/manage");
let departments: typeof import("@/lib/domain/departments");
let orgId: string;
let workflowId: string;
let adminId: string;
let editionId: string;
let archivedEditionId: string;
let mkt: typeof schema.departments.$inferSelect;
let sales: typeof schema.departments.$inferSelect;
const n = Date.now() % 1_000_000;
let seq = 0;

type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];
const run = <T>(fn: (tx: Tx) => Promise<T>) => db.transaction(fn);
const email = (name: string) => `${name.toLowerCase()}-${n}@v2.test`;
const admin = () => ({ organisationId: orgId, actorUserId: adminId, actorName: "Alex" });

async function addMember(
  name: string,
  role: StaffRole,
  extra: Partial<typeof schema.memberships.$inferInsert> = {},
) {
  const id = randomUUID();
  await db.insert(schema.users).values({ id, email: email(name), fullName: name });
  await db.insert(schema.memberships).values({ userId: id, organisationId: orgId, role, ...extra });
  return id;
}

async function approve(userId: string, name: string, departmentId: string, isMain = false) {
  await db.insert(schema.approvers).values({
    organisationId: orgId,
    departmentId,
    fullName: name,
    email: email(name),
    userId,
    isMain,
  });
}

async function deptStep(departmentId: string) {
  const [step] = await db
    .select()
    .from(schema.workflowSteps)
    .where(
      and(
        eq(schema.workflowSteps.workflowId, workflowId),
        eq(schema.workflowSteps.departmentId, departmentId),
      ),
    );
  return step;
}

/** A sign that is in sign-off, with these steps in its current round. */
async function itemWith(
  ownerUserId: string,
  steps: {
    departmentId: string | null;
    assignedUserId: string;
    status: "pending" | "waiting" | "approved" | "changes_requested";
  }[],
  opts: { editionId?: string; kind?: "signage" | "sponsorship_item"; status?: "closed" } = {},
) {
  seq++;
  const [item] = await db
    .insert(schema.signageItems)
    .values({
      editionId: opts.editionId ?? editionId,
      ref: `SIG-V2${n}-${seq}`,
      seq,
      name: `Sign ${seq}`,
      kind: opts.kind ?? "signage",
      ownerUserId,
      status: opts.status ?? "in_review",
      workflowId,
      currentRunNumber: 1,
      createdBy: adminId,
      signoffs: steps
        .filter((s) => s.departmentId)
        .map(() => ({ stepId: randomUUID(), userId: ownerUserId })),
    })
    .returning();
  const instances = [];
  for (const [i, s] of steps.entries()) {
    const wf = s.departmentId ? await deptStep(s.departmentId) : null;
    const [inst] = await db
      .insert(schema.approvalInstances)
      .values({
        entityType: "signage_item",
        entityId: item.id,
        runNumber: 1,
        workflowStepId: wf?.id ?? (await deptStep(mkt.id)).id,
        stepNameSnapshot: wf?.name ?? "Named sign-off",
        stepKindSnapshot: "approval",
        sortOrderSnapshot: i + 1,
        status: s.status,
        assignedUserId: s.assignedUserId,
        assignedDepartmentId: s.departmentId,
        decidedBy: s.status === "approved" ? s.assignedUserId : null,
      })
      .returning();
    instances.push(inst);
  }
  return { item, instances };
}

async function instance(id: string) {
  const [row] = await db
    .select()
    .from(schema.approvalInstances)
    .where(eq(schema.approvalInstances.id, id));
  return row;
}

const person = { jobTitle: null, newDepartmentName: null, features: null, abilities: {} };

d("users v2: pages and hand-over", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    manage = await import("@/lib/users/manage");
    departments = await import("@/lib/domain/departments");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "V2 Org", slug: `v2-${n}` })
      .returning();
    orgId = org.id;
    const [wf] = await db
      .insert(schema.workflows)
      .values({ organisationId: orgId, name: "Signage", appliesTo: "signage", isDefault: true })
      .returning();
    workflowId = wf.id;
    for (const s of defaultSignageSteps.filter((s) => !s.defaultFor?.length)) {
      await db.insert(schema.workflowSteps).values({
        workflowId,
        sortOrder: s.sortOrder,
        name: s.name,
        kind: s.kind,
        approverType: s.approverType,
        approverRole: s.approverRole,
        conditions: s.conditions,
      });
    }
    [mkt, sales] = await db
      .insert(schema.departments)
      .values([
        { organisationId: orgId, name: "Marketing", sortOrder: 1, defaultFor: ["organiser"] },
        { organisationId: orgId, name: "Sales", sortOrder: 2, defaultFor: ["sponsor"] },
      ])
      .returning();
    await db.transaction((tx) => departments.syncDepartmentSteps(tx, orgId));
    adminId = await addMember("Alex", "admin");
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "V2 Show", code: `V${n % 100000}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "V2 Hall", code: `VH${n % 10000}` })
      .returning();
    const dates = {
      buildStart: "2027-02-01",
      buildEnd: "2027-02-02",
      openStart: "2027-02-03",
      openEnd: "2027-02-04",
      breakdownEnd: "2027-02-05",
    };
    const [edition] = await db
      .insert(schema.editions)
      .values({ eventId: event.id, venueId: venue.id, name: "V2 2027", code: `VZ${n}`, ...dates })
      .returning();
    editionId = edition.id;
    const [old] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "V2 2025",
        code: `VY${n}`,
        status: "archived",
        ...dates,
      })
      .returning();
    archivedEditionId = old.id;
  });

  afterAll(async () => {
    await client?.end();
  });

  it("invites several people: each row invited or left out with its reason", async () => {
    const onTeam = await addMember("Tia", "marketing");
    void onTeam;
    // An invitation still open for Ivy.
    await run((tx) =>
      manage.inviteUserTx(tx, admin(), {
        ...person,
        signoffs: [],
        email: email("Ivy"),
        fullName: "Ivy",
        departmentId: null,
        role: "viewer",
      }),
    );
    const rows = [
      { line: 1, name: "Pam", email: email("Pam"), jobTitle: "Designer" },
      { line: 2, name: "Tia", email: email("Tia").toUpperCase(), jobTitle: null },
      { line: 3, name: "Ivy", email: email("Ivy"), jobTitle: null },
      { line: 4, name: "Bad", email: "not-an-email", jobTitle: null },
      { line: 5, name: "Pam again", email: email("Pam"), jobTitle: null },
      { line: 6, name: "Quin", email: email("Quin"), jobTitle: null },
    ];
    const preview = await manage.previewInviteRows(db, orgId, rows);
    expect(preview.map((r) => r.reason)).toEqual([
      "ready",
      "on_team",
      "invited",
      "bad_email",
      "duplicate",
      "ready",
    ]);
    expect(preview[1].existingId).toBe(onTeam);
    const out = await run((tx) =>
      manage.inviteRowsTx(tx, admin(), rows, {
        departmentId: mkt.id,
        role: "marketing",
        features: ["signage", "calendar"],
        abilities: {},
        accessEndsOn: "2099-01-29",
      }),
    );
    expect(out.results.map((r) => [r.line, r.ok])).toEqual([
      [1, true],
      [2, false],
      [3, false],
      [4, false],
      [5, false],
      [6, true],
    ]);
    expect(out.results[0].inviteUrl).toMatch(/\/invite\//);
    const [pam] = await db
      .select()
      .from(schema.staffInvites)
      .where(eq(schema.staffInvites.invitedEmail, email("Pam")));
    expect(pam).toMatchObject({
      fullName: "Pam",
      jobTitle: "Designer",
      departmentId: mkt.id,
      role: "marketing",
      features: ["signage", "calendar"],
    });
    expect(pam.accessEndsAt?.toISOString()).toBe("2099-01-29T23:59:59.999Z");

    // A department manager can't give a role above theirs: every ready row says so.
    const mona = await addMember("Mona", "marketing", {
      departmentId: mkt.id,
      managerScope: "department",
    });
    const refused = await run((tx) =>
      manage.inviteRowsTx(
        tx,
        { organisationId: orgId, actorUserId: mona, actorName: "Mona" },
        [{ line: 1, name: "Rex", email: email("Rex"), jobTitle: null }],
        { departmentId: mkt.id, role: "ops", features: null, abilities: {} },
      ),
    );
    expect(refused.results[0]).toMatchObject({ ok: false, reason: "ready" });
    expect(refused.results[0].error).toMatch(/can't make someone Operations/);
    const rex = await db
      .select()
      .from(schema.staffInvites)
      .where(eq(schema.staffInvites.invitedEmail, email("Rex")));
    expect(rex).toHaveLength(0);
  });

  it("an open invitation is never replaced by inviting the same email", async () => {
    const err = await run((tx) =>
      manage.inviteUserTx(tx, admin(), {
        ...person,
        signoffs: [],
        email: email("Ivy"),
        fullName: "Ivy",
        departmentId: null,
        role: "viewer",
      }),
    ).catch((e) => e);
    expect(err.message).toBe("Ivy is already invited — open their page to send it again");
    expect(err.detail.existingInviteId).toBeTruthy();
  });

  it("bulk changes check each person: a department manager changes only their own people", async () => {
    const mona = await addMember("Moira", "marketing", {
      departmentId: mkt.id,
      managerScope: "department",
    });
    const inDept = await addMember("Ian", "marketing", { departmentId: mkt.id });
    const otherDept = await addMember("Sid", "sales", { departmentId: sales.id });
    const otherManager = await addMember("Max", "marketing", {
      departmentId: mkt.id,
      managerScope: "department",
    });
    const ctx = { organisationId: orgId, actorUserId: mona, actorName: "Moira" };
    const suspended = await manage.bulkPeople(db, ctx, {
      ids: [inDept, otherDept, adminId, mona, otherManager, randomUUID()],
      action: "suspend",
    });
    expect(suspended.map((r) => [r.name, r.ok, r.reason])).toEqual([
      ["Ian", true, undefined],
      ["Sid", false, "You can't change this person's access"],
      ["Alex", false, "You can't change this person's access"],
      ["Moira", false, "You can't change your own access — ask another super admin"],
      ["Max", false, "You can't change this person's access"],
      ["Someone", false, "No longer on the list — reload"],
    ]);
    const [ian] = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, inDept));
    expect(ian.suspendedAt).not.toBeNull();
    expect(ian.suspendedBy).toBe(mona);
    // Each change is audited on its own, about the person.
    const audits = await db
      .select()
      .from(schema.auditLog)
      .where(eq(schema.auditLog.subjectUserId, inDept));
    expect(audits.map((a) => a.summary)).toContain(`Suspended ${email("Ian")}`);

    const again = await manage.bulkPeople(db, ctx, {
      ids: [inDept, otherDept],
      action: "reactivate",
    });
    expect(again.map((r) => r.ok)).toEqual([true, false]);
    const ended = await manage.bulkPeople(db, ctx, {
      ids: [inDept],
      action: "end_date",
      date: "2099-01-31",
    });
    expect(ended[0].ok).toBe(true);
    const [after] = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, inDept));
    expect(after.suspendedAt).toBeNull();
    expect(after.accessEndsAt?.toISOString()).toBe("2099-01-31T23:59:59.999Z");
    const notInvites = await manage.bulkPeople(db, ctx, { ids: [inDept], action: "resend" });
    expect(notInvites[0]).toMatchObject({ ok: false, reason: "Already on the team" });
  });

  it("suspending hands each department's sign-offs to someone who signs for it, steps not started yet included", async () => {
    const dana = await addMember("Dana", "event_director", { departmentId: mkt.id });
    const mia = await addMember("Mia", "marketing", { departmentId: mkt.id });
    const oscar = await addMember("Oscar", "ops");
    await approve(dana, "Dana", mkt.id);
    await approve(mia, "Mia", mkt.id, true);
    await approve(dana, "Dana", sales.id);
    await db.transaction((tx) => departments.syncDepartmentSteps(tx, orgId));
    const pendingMkt = await itemWith(adminId, [
      { departmentId: mkt.id, assignedUserId: dana, status: "pending" },
    ]);
    // Not started yet, sent back, and approved (redone after new artwork): all name Dana.
    const later = await itemWith(adminId, [
      { departmentId: mkt.id, assignedUserId: dana, status: "waiting" },
      { departmentId: sales.id, assignedUserId: dana, status: "changes_requested" },
      { departmentId: mkt.id, assignedUserId: dana, status: "approved" },
    ]);

    // The dialog's data: Marketing defaults to Mia (main approver); Sales has nobody else.
    const plan = await manage.handoverPlan(db, orgId, dana);
    expect(
      plan.groups.map((g) => [g.departmentName, g.steps.length, g.waitingNow, g.defaultTo]),
    ).toEqual([
      ["Marketing", 3, 1, mia],
      ["Sales", 1, 0, null],
    ]);
    expect(plan.candidates.map((c) => c.userId)).toEqual(expect.arrayContaining([mia, oscar]));
    expect(plan.candidates.map((c) => c.userId)).not.toContain(dana);

    const ctx = admin();
    const refused = await run((tx) => manage.suspendMemberTx(tx, ctx, { userId: dana })).catch(
      (e) => e,
    );
    expect(refused.message).toBe(
      "A sign-off is waiting on Dana (Sales) — choose who takes it over",
    );
    const noOne = await run((tx) =>
      manage.suspendMemberTx(tx, ctx, { userId: dana, handTo: { [sales.id]: "department" } }),
    ).catch((e) => e);
    expect(noOne.message).toBe("Nobody else can sign off for Sales — choose a person");

    const out = await run((tx) =>
      manage.suspendMemberTx(tx, ctx, { userId: dana, handTo: { [sales.id]: oscar } }),
    );
    expect(out.handedOver).toBe(4);
    const now = await instance(pendingMkt.instances[0].id);
    expect(now).toMatchObject({ assignedUserId: mia, delegatedFromUserId: dana });
    expect(await instance(later.instances[0].id)).toMatchObject({
      assignedUserId: mia,
      status: "waiting",
    });
    expect(await instance(later.instances[1].id)).toMatchObject({
      assignedUserId: oscar,
      status: "changes_requested",
    });
    // A decided step keeps who decided; only who a redo goes to changes.
    expect(await instance(later.instances[2].id)).toMatchObject({
      assignedUserId: mia,
      decidedBy: dana,
      status: "approved",
    });
    // One audit row per item; Mia is told about the one waiting now.
    const audits = await db
      .select()
      .from(schema.auditLog)
      .where(and(eq(schema.auditLog.action, "delegate"), eq(schema.auditLog.subjectUserId, dana)));
    // One per item and department: the first item once, the second for Marketing and Sales.
    expect(audits).toHaveLength(3);
    const told = await db
      .select()
      .from(schema.notifications)
      .where(eq(schema.notifications.userId, mia));
    expect(told.map((t) => t.title)).toContain(`A sign-off is now yours: ${pendingMkt.item.ref}`);
    // The item plans stop naming her.
    const [plans] = await db
      .select()
      .from(schema.signageItems)
      .where(eq(schema.signageItems.id, later.item.id));
    void plans;
    const named = await db.execute(
      `select count(*)::int as n from signage_items where signoffs @> '[{"userId":"${dana}"}]'::jsonb`,
    );
    expect((named as unknown as { n: number }[])[0].n).toBe(0);
    // Nothing is left naming her.
    expect(await manage.signoffsNaming(db, orgId, dana)).toEqual([]);
  });

  it("taking someone off a department sends its sign-offs naming them back to it", async () => {
    const pia = await addMember("Pia", "marketing", { departmentId: mkt.id });
    const ned = await addMember("Ned", "marketing", { departmentId: mkt.id });
    await approve(pia, "Pia", mkt.id);
    await approve(ned, "Ned", mkt.id);
    await db.transaction((tx) => departments.syncDepartmentSteps(tx, orgId));
    const { instances } = await itemWith(adminId, [
      { departmentId: mkt.id, assignedUserId: pia, status: "pending" },
    ]);
    const out = await run((tx) =>
      manage.updateMemberTx(tx, admin(), {
        ...person,
        userId: pia,
        fullName: "Pia",
        departmentId: mkt.id,
        role: "marketing",
        signoffs: [],
        signoffPaused: false,
      }),
    );
    expect(out).toMatchObject({ signoffsMoved: 1, signoffsKept: 0 });
    expect(await instance(instances[0].id)).toMatchObject({
      assignedUserId: null,
      assignedDepartmentId: mkt.id,
      delegatedFromUserId: pia,
    });
    // Ned (still a Marketing approver) is told it's back with the department.
    const told = await db
      .select()
      .from(schema.notifications)
      .where(eq(schema.notifications.userId, ned));
    expect(told.some((t) => t.title.includes("back with your department"))).toBe(true);
  });

  it("removing someone hands tasks and live items to the person picked, the rest to the remover", async () => {
    const leo = await addMember("Leo", "marketing", { departmentId: mkt.id });
    const sara = await addMember("Sara", "sales", { departmentId: sales.id });
    const sign = await itemWith(leo, []);
    const sponsorship = await itemWith(leo, [], { kind: "sponsorship_item" });
    const finished = await itemWith(leo, [], { status: "closed" });
    const archived = await itemWith(leo, [], { editionId: archivedEditionId });
    const [task] = await db
      .insert(schema.tasks)
      .values({
        organisationId: orgId,
        title: "Order lanyards",
        assignedToUserId: leo,
        createdByUserId: adminId,
      })
      .returning();
    const impact = await manage.getRemovalImpact(db, orgId, leo);
    expect(impact).toMatchObject({
      openTasks: 1,
      ownedItems: 2,
      ownedByKind: { signage: 1, sponsorship_item: 1 },
    });
    expect(impact!.workCandidates.map((c) => c.userId)).toContain(sara);

    const out = await run((tx) =>
      manage.removeMemberTx(tx, admin(), { userId: leo, workToUserId: sara }),
    );
    expect(out).toMatchObject({ tasks: 1, items: 2, itemsToYou: 1, workToName: "Sara" });
    const owner = async (id: string) =>
      (await db.select().from(schema.signageItems).where(eq(schema.signageItems.id, id)))[0]
        .ownerUserId;
    // Sales can work on sponsorship items, not organiser signage: that comes to the remover.
    expect(await owner(sponsorship.item.id)).toBe(sara);
    expect(await owner(sign.item.id)).toBe(adminId);
    // Finished items and archived events keep their owner.
    expect(await owner(finished.item.id)).toBe(leo);
    expect(await owner(archived.item.id)).toBe(leo);
    const [moved] = await db.select().from(schema.tasks).where(eq(schema.tasks.id, task.id));
    expect(moved.assignedToUserId).toBe(sara);
    const taskAudit = await db
      .select()
      .from(schema.auditLog)
      .where(and(eq(schema.auditLog.entityType, "task"), eq(schema.auditLog.entityId, task.id)));
    expect(taskAudit).toHaveLength(1);
    expect(taskAudit[0].after).toEqual({ assignedToUserId: sara });

    // Someone who can't take work (a viewer) is refused.
    const vic = await addMember("Vic", "viewer");
    const kim = await addMember("Kim", "marketing");
    const bad = await run((tx) =>
      manage.removeMemberTx(tx, admin(), { userId: kim, workToUserId: vic }),
    ).catch((e) => e);
    expect(bad.message).toMatch(/isn't a viewer/);
  });

  it("an invitation doesn't take main approver from someone who can sign", async () => {
    const mel = await addMember("Mel", "sales", { departmentId: sales.id });
    await db
      .update(schema.approvers)
      .set({ isMain: false })
      .where(eq(schema.approvers.departmentId, sales.id));
    await approve(mel, "Mel", sales.id, true);
    await db.transaction((tx) => departments.syncDepartmentSteps(tx, orgId));
    const out = await run((tx) =>
      manage.inviteUserTx(tx, admin(), {
        ...person,
        email: email("Newt"),
        fullName: "Newt",
        departmentId: sales.id,
        role: "sales",
        signoffs: [{ departmentId: sales.id, isMain: true }],
      }),
    );
    expect(out.mainKept).toEqual([{ departmentId: sales.id, name: "Mel" }]);
    const rows = await db
      .select()
      .from(schema.approvers)
      .where(eq(schema.approvers.departmentId, sales.id));
    expect(rows.find((r) => r.email === email("Mel"))?.isMain).toBe(true);
    expect(rows.find((r) => r.email === email("Newt"))?.isMain).toBe(false);
    expect((await deptStep(sales.id)).approverUserId).toBe(mel);
  });
});
