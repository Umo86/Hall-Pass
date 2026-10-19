/**
 * "Main approver when they accept" against a real database
 * (TEST_DATABASE_URL), with the session stubbed for the Departments
 * actions: someone invited as a department's main approver while the main
 * can sign takes over when they accept — the ask lives on their approver
 * row, the newest choice wins, a choice made now cancels it, it goes with
 * the invitation, survives resends and expiry, and at acceptance it is
 * carried out only if the department still signs off and they can sign
 * (whoever asked is told otherwise). Default sign-offs follow the new main.
 */
import { randomUUID } from "node:crypto";
import { and, eq, isNull } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";
import type { Session } from "@/lib/auth/actor";
import type { StaffRole } from "@/lib/authz";
import { defaultSignageSteps } from "@/lib/workflow";

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
let manage: typeof import("@/lib/users/manage");
let queries: typeof import("@/lib/users/queries");
let history: typeof import("@/lib/users/history");
let lookup: typeof import("@/lib/users/invite-lookup");
let departments: typeof import("@/lib/domain/departments");
let claim: typeof import("@/lib/auth/claim-staff-invite");
let approverActions: typeof import("@/app/actions/approvers");
let orgId: string;
let workflowId: string;
let editionId: string;
let adminId: string;
const n = Date.now() % 1_000_000;
let deptSeq = 0;
let itemSeq = 0;

type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];
const run = <T>(fn: (tx: Tx) => Promise<T>) => db.transaction(fn);
const email = (name: string) => `${name.toLowerCase().replace(/\s+/g, ".")}-${n}@moa.test`;
const admin = () => ({ organisationId: orgId, actorUserId: adminId, actorName: "Alex" });
const person = {
  jobTitle: null,
  newDepartmentName: null,
  features: null,
  abilities: {},
  departmentId: null,
  role: "marketing" as StaffRole,
};

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

/** A department that signs off (organiser signage by default), with its step. */
async function newDept(name: string, extra: Partial<typeof schema.departments.$inferInsert> = {}) {
  deptSeq++;
  const [dept] = await db
    .insert(schema.departments)
    .values({
      organisationId: orgId,
      name: `${name} ${n}`,
      sortOrder: deptSeq,
      defaultFor: ["organiser"],
      ...extra,
    })
    .returning();
  await run((tx) => departments.syncDepartmentSteps(tx, orgId));
  return dept;
}

async function approve(userId: string, name: string, departmentId: string, isMain = false) {
  const [row] = await db
    .insert(schema.approvers)
    .values({
      organisationId: orgId,
      departmentId,
      fullName: name,
      email: email(name),
      userId,
      isMain,
    })
    .returning();
  await run((tx) => departments.syncDepartmentSteps(tx, orgId));
  return row;
}

/** A department with a main approver who can sign. */
async function deptWithMain(label: string) {
  const dept = await newDept(label);
  const mainName = `Jo ${label}`;
  const mainId = await addMember(mainName, "marketing", { departmentId: dept.id });
  await approve(mainId, mainName, dept.id, true);
  return { dept, mainId, mainName };
}

async function invite(
  name: string,
  departmentId: string,
  isMain = true,
  ctx: { organisationId: string; actorUserId: string; actorName?: string } = admin(),
  extra: Partial<Parameters<typeof manage.inviteUserTx>[2]> = {},
) {
  return run((tx) =>
    manage.inviteUserTx(tx, ctx, {
      ...person,
      email: email(name),
      fullName: name,
      departmentId,
      signoffs: [{ departmentId, isMain }],
      ...extra,
    }),
  );
}

/** They accept their invitation (as the invitation page does). */
async function accept(name: string) {
  const [inv] = await db
    .select()
    .from(schema.staffInvites)
    .where(
      and(
        eq(schema.staffInvites.invitedEmail, email(name)),
        isNull(schema.staffInvites.acceptedAt),
        isNull(schema.staffInvites.revokedAt),
      ),
    );
  const userId = randomUUID();
  await db.insert(schema.users).values({ id: userId, email: email(name) });
  await claim.claimStaffInvite(inv, userId, name);
  return userId;
}

async function rowOf(name: string, departmentId: string) {
  const [row] = await db
    .select()
    .from(schema.approvers)
    .where(
      and(eq(schema.approvers.departmentId, departmentId), eq(schema.approvers.email, email(name))),
    );
  return row;
}

async function stepOf(departmentId: string) {
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

const notesFor = async (userId: string, kind?: string) =>
  db
    .select()
    .from(schema.notifications)
    .where(
      and(
        eq(schema.notifications.userId, userId),
        kind ? eq(schema.notifications.kind, kind) : undefined,
      ),
    );

const auditAbout = async (emailAddress: string) =>
  db
    .select()
    .from(schema.auditLog)
    .where(
      and(
        eq(schema.auditLog.organisationId, orgId),
        eq(schema.auditLog.subjectEmail, emailAddress),
      ),
    );

function as(userId: string, role: StaffRole, name: string) {
  state.session = {
    actor: { kind: "staff", userId, organisationId: orgId, role },
    user: { id: userId, email: `${userId}@moa.test`, fullName: name, isExternal: false },
    organisation: {
      id: orgId,
      brandName: "Hall Pass",
      settings: {} as Session["organisation"]["settings"],
    },
  } satisfies Session;
}

const asAdmin = () => as(adminId, "admin", "Alex");

/** A sign waiting on the department's step for `who`; `planned` names them on the item. */
async function inSignoff(departmentId: string, who: string, planned = false) {
  itemSeq++;
  const step = await stepOf(departmentId);
  const [item] = await db
    .insert(schema.signageItems)
    .values({
      editionId,
      ref: `SIG-MOA${n}-${String(itemSeq).padStart(3, "0")}`,
      seq: itemSeq,
      name: `Accept sign ${itemSeq}`,
      createdBy: adminId,
      ownerUserId: adminId,
      workflowId,
      status: "in_review",
      currentRunNumber: 1,
      signoffs: (planned ? [{ stepId: step.id, userId: who }] : null) as never,
    })
    .returning();
  const [inst] = await db
    .insert(schema.approvalInstances)
    .values({
      entityType: "signage_item",
      entityId: item.id,
      runNumber: 1,
      workflowStepId: step.id,
      stepNameSnapshot: step.name,
      stepKindSnapshot: "approval",
      sortOrderSnapshot: 1,
      status: "pending",
      assignedDepartmentId: departmentId,
      assignedUserId: who,
      pendingSince: new Date(),
    })
    .returning();
  return { item, inst };
}

const assigned = async (id: string) =>
  (await db.select().from(schema.approvalInstances).where(eq(schema.approvalInstances.id, id)))[0]
    .assignedUserId;

d("main approver when they accept", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    manage = await import("@/lib/users/manage");
    queries = await import("@/lib/users/queries");
    history = await import("@/lib/users/history");
    lookup = await import("@/lib/users/invite-lookup");
    departments = await import("@/lib/domain/departments");
    claim = await import("@/lib/auth/claim-staff-invite");
    approverActions = await import("@/app/actions/approvers");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Accept Org", slug: `moa-${n}` })
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
    adminId = await addMember("Alex", "admin");
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Accept Show", code: `MOE${n}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Accept Hall", code: `MOV${n}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Accept 2027",
        code: `MOA${n}`,
        buildStart: "2027-02-01",
        buildEnd: "2027-02-02",
        openStart: "2027-02-03",
        openEnd: "2027-02-04",
        breakdownEnd: "2027-02-05",
      })
      .returning();
    editionId = edition.id;
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

  it("1. inviting someone as main approver while the main can sign stores the ask; the main keeps the step", async () => {
    const { dept, mainId, mainName } = await deptWithMain("Sales");
    const out = await invite("Newt One", dept.id);
    expect(out.mainOnAccept).toEqual([
      { departmentId: dept.id, departmentName: dept.name, currentMain: mainName },
    ]);
    expect(out.pendingDropped).toEqual([]);
    const newt = await rowOf("Newt One", dept.id);
    expect(newt).toMatchObject({ mainOnAccept: true, isMain: false, mainOnAcceptBy: adminId });
    expect((await rowOf(mainName, dept.id)).isMain).toBe(true);
    expect((await stepOf(dept.id)).approverUserId).toBe(mainId);
    // The form reads it as main approver (the people rules and renewals do too).
    expect(
      await manage.currentSignoffs(db, orgId, { userId: null, email: email("Newt One") }),
    ).toEqual([{ departmentId: dept.id, isMain: true }]);
    const audit = await auditAbout(email("Newt One"));
    expect(audit.map((a) => a.summary)).toContain(
      `Newt One will become the main approver for ${dept.name} when they accept — ${mainName} stays until then`,
    );
  });

  it("2. accepting makes them main: the old main loses it (in their history), default sign-offs move, both are told", async () => {
    const { dept, mainId, mainName } = await deptWithMain("Marketing");
    await invite("Sam Two", dept.id);
    const byDefault = await inSignoff(dept.id, mainId);
    const planned = await inSignoff(dept.id, mainId, true);
    const samId = await accept("Sam Two");

    const sam = await rowOf("Sam Two", dept.id);
    expect(sam).toMatchObject({ userId: samId, isMain: true, mainOnAccept: false });
    expect(sam.mainOnAcceptBy).toBeNull();
    expect((await rowOf(mainName, dept.id)).isMain).toBe(false);
    expect((await stepOf(dept.id)).approverUserId).toBe(samId);

    const joHistory = await history.accessHistory(db, orgId, { userId: mainId });
    expect(joHistory.map((h) => h.summary)).toContain(
      `${mainName} is no longer the main approver for ${dept.name} — Sam Two is (they accepted their invitation)`,
    );
    expect(joHistory.find((h) => h.summary.includes("is no longer the main"))?.actorName).toBe(
      "System",
    );
    const samHistory = await history.accessHistory(db, orgId, { userId: samId });
    expect(samHistory.map((h) => h.summary)).toContain(
      `Sam Two is now the main approver for ${dept.name} — they accepted their invitation, as Alex arranged`,
    );
    const [accepted] = await db
      .select()
      .from(schema.auditLog)
      .where(
        and(
          eq(schema.auditLog.subjectUserId, samId),
          eq(schema.auditLog.entityType, "staff_invite"),
          eq(schema.auditLog.action, "invite"),
        ),
      );
    expect(accepted).toMatchObject({ actorUserId: samId, after: { mainApproverFor: [dept.id] } });

    // The default sign-off moved to Sam; the one picked for Jo on the item stays.
    expect(await assigned(byDefault.inst.id)).toBe(samId);
    expect(await assigned(planned.inst.id)).toBe(mainId);
    const moves = await db
      .select()
      .from(schema.auditLog)
      .where(
        and(
          eq(schema.auditLog.entityId, byDefault.item.id),
          eq(schema.auditLog.action, "delegate"),
        ),
      );
    expect(moves).toHaveLength(1);
    expect(moves[0].summary).toContain("main approver changed");

    const joNotes = await notesFor(mainId, "main_approver");
    expect(joNotes.map((x) => x.title)).toEqual([
      `Sam Two is now the main approver for ${dept.name}`,
    ]);
    expect(joNotes[0].link).toBe("/users?tab=departments");
    expect((await notesFor(samId, "main_approver")).map((x) => x.title)).toEqual([
      `You're the main approver for ${dept.name}`,
    ]);
    expect(
      (await notesFor(samId, "approval_requested")).some((x) => x.entityId === byDefault.item.id),
    ).toBe(true);
  });

  it("3. the newest ask wins: a second invitation for the same department replaces the first", async () => {
    const { dept } = await deptWithMain("Finance");
    await invite("Sam Three", dept.id);
    const second = await invite("Alex Three", dept.id);
    expect(second.pendingDropped).toEqual([
      { departmentId: dept.id, departmentName: dept.name, name: "Sam Three" },
    ]);
    expect((await rowOf("Sam Three", dept.id)).mainOnAccept).toBe(false);
    expect((await rowOf("Alex Three", dept.id)).mainOnAccept).toBe(true);
    expect((await auditAbout(email("Sam Three"))).map((a) => a.summary)).toContain(
      `Sam Three will no longer become the main approver for ${dept.name} when they accept — Alex Three will instead`,
    );
  });

  it("4. choosing someone else as main now cancels a pending ask (Departments, Add approver, the person page)", async () => {
    const { dept, mainId, mainName } = await deptWithMain("Press");
    const maxId = await addMember("Max Four", "marketing", { departmentId: dept.id });
    const max = await approve(maxId, "Max Four", dept.id);
    const kimId = await addMember("Kim Four", "marketing", { departmentId: dept.id });
    await invite("Sam Four", dept.id);
    asAdmin();

    // Departments star.
    const made = await approverActions.setMainApprover({ id: max.id, isMain: true });
    expect(made).toMatchObject({ ok: true });
    expect(made.ok && made.message).toBe(
      `Max Four is now the main approver for ${dept.name}. Sam Four won't take over ${dept.name} when they accept`,
    );
    expect((await rowOf("Sam Four", dept.id)).mainOnAccept).toBe(false);

    // Asked again (Max can sign), then Add approver as main.
    const asked = await approverActions.setMainApprover({
      id: (await rowOf("Sam Four", dept.id)).id,
      isMain: true,
    });
    expect(asked).toMatchObject({
      ok: true,
      message: `Sam Four becomes the main approver for ${dept.name} when they accept — Max Four stays until then`,
    });
    const added = await approverActions.addApprover({
      departmentId: dept.id,
      userId: kimId,
      isMain: true,
    });
    expect(added).toMatchObject({
      ok: true,
      message: `Kim Four now signs off for ${dept.name}. Sam Four won't take over ${dept.name} when they accept`,
    });
    expect((await rowOf("Sam Four", dept.id)).mainOnAccept).toBe(false);
    expect((await rowOf("Kim Four", dept.id)).isMain).toBe(true);

    // Asked again, then Jo made main on their own page.
    await approverActions.setMainApprover({
      id: (await rowOf("Sam Four", dept.id)).id,
      isMain: true,
    });
    expect((await rowOf("Sam Four", dept.id)).mainOnAccept).toBe(true);
    const out = await run((tx) =>
      manage.updateMemberTx(tx, admin(), {
        ...person,
        userId: mainId,
        fullName: mainName,
        departmentId: dept.id,
        signoffPaused: false,
        signoffs: [{ departmentId: dept.id, isMain: true }],
      }),
    );
    expect(out.pendingDropped).toEqual([
      { departmentId: dept.id, departmentName: dept.name, name: "Sam Four" },
    ]);
    expect((await rowOf("Sam Four", dept.id)).mainOnAccept).toBe(false);
    expect((await rowOf(mainName, dept.id)).isMain).toBe(true);
  });

  it("5. the main being suspended or taken off the department meanwhile leaves the ask; on accept they become main", async () => {
    const a = await deptWithMain("Ops");
    await invite("Sam Five", a.dept.id);
    await db
      .update(schema.memberships)
      .set({ suspendedAt: new Date() })
      .where(eq(schema.memberships.userId, a.mainId));
    expect((await rowOf("Sam Five", a.dept.id)).mainOnAccept).toBe(true);
    const samId = await accept("Sam Five");
    expect((await rowOf("Sam Five", a.dept.id)).isMain).toBe(true);
    expect((await rowOf(a.mainName, a.dept.id)).isMain).toBe(false);
    expect((await stepOf(a.dept.id)).approverUserId).toBe(samId);

    const b = await deptWithMain("Legal");
    await invite("Pat Five", b.dept.id);
    asAdmin();
    const removed = await approverActions.removeApprover({
      id: (await rowOf(b.mainName, b.dept.id)).id,
    });
    expect(removed).toMatchObject({ ok: true });
    expect((await rowOf("Pat Five", b.dept.id)).mainOnAccept).toBe(true);
    await accept("Pat Five");
    expect((await rowOf("Pat Five", b.dept.id)).isMain).toBe(true);
  });

  it("6. cancelling the invitation drops the ask with its approver row", async () => {
    const { dept, mainName } = await deptWithMain("Venue");
    const out = await invite("Sam Six", dept.id);
    await run((tx) => manage.cancelInviteTx(tx, admin(), out.inviteId));
    expect(await rowOf("Sam Six", dept.id)).toBeUndefined();
    expect((await rowOf(mainName, dept.id)).isMain).toBe(true);
    const [cancelled] = await db
      .select()
      .from(schema.auditLog)
      .where(
        and(eq(schema.auditLog.entityId, out.inviteId), eq(schema.auditLog.action, "grant_revoke")),
      );
    expect(cancelled.before).toMatchObject({ mainOnAccept: [dept.id] });
  });

  it("7. renewing the link keeps the ask; a manager without departments.manage can't renew it", async () => {
    const { dept } = await deptWithMain("Comms");
    const mgrId = await addMember("Mona Seven", "marketing", {
      departmentId: dept.id,
      managerScope: "department",
    });
    await approve(mgrId, "Mona Seven", dept.id);
    const mgr = { organisationId: orgId, actorUserId: mgrId };
    const asked = await invite("Sam Seven", dept.id);
    await run((tx) => manage.renewInviteLinkTx(tx, admin(), asked.inviteId));
    expect((await rowOf("Sam Seven", dept.id)).mainOnAccept).toBe(true);
    await expect(run((tx) => manage.renewInviteLinkTx(tx, mgr, asked.inviteId))).rejects.toThrow(
      manage.RENEW_NOT_YOURS,
    );
    // Without an ask they could.
    const plain = await invite("Pip Seven", dept.id, false);
    await expect(
      run((tx) => manage.renewInviteLinkTx(tx, mgr, plain.inviteId)),
    ).resolves.toMatchObject({ inviteUrl: expect.any(String) });
  });

  it("8. an expired invitation keeps its ask and can't be claimed; renewed and accepted, they become main", async () => {
    const { dept, mainName } = await deptWithMain("Build");
    const out = await invite("Sam Eight", dept.id);
    await db
      .update(schema.staffInvites)
      .set({ expiresAt: new Date(Date.now() - 60_000) })
      .where(eq(schema.staffInvites.id, out.inviteId));
    const [inv] = await db
      .select()
      .from(schema.staffInvites)
      .where(eq(schema.staffInvites.id, out.inviteId));
    const early = randomUUID();
    await db.insert(schema.users).values({ id: early, email: `early-${n}@moa.test` });
    await claim.claimStaffInvite(inv, early);
    expect((await rowOf("Sam Eight", dept.id)).mainOnAccept).toBe(true);
    expect((await rowOf(mainName, dept.id)).isMain).toBe(true);
    // Departments says so.
    const card = (await queries.listDepartmentCards(db, orgId)).find((c) => c.id === dept.id)!;
    expect(card.approvers.find((a) => a.email === email("Sam Eight"))).toMatchObject({
      mainOnAccept: true,
      stateText: "Invitation expired — resend",
    });
    await run((tx) => manage.renewInviteLinkTx(tx, admin(), out.inviteId));
    await accept("Sam Eight");
    expect((await rowOf("Sam Eight", dept.id)).isMain).toBe(true);
    expect((await rowOf(mainName, dept.id)).isMain).toBe(false);
  });

  it("9. editing the invitation: unticking cancels the ask; another department moves it; a viewer has none", async () => {
    const a = await deptWithMain("Design");
    const b = await deptWithMain("Digital");
    const c = await newDept("Print");
    const out = await invite("Sam Nine", a.dept.id);
    const edit = (
      signoffs: { departmentId: string; isMain: boolean }[],
      role: StaffRole = "marketing",
    ) =>
      run((tx) =>
        manage.updateInviteTx(tx, admin(), {
          ...person,
          role,
          inviteId: out.inviteId,
          fullName: "Sam Nine",
          departmentId: a.dept.id,
          signoffs,
        }),
      );
    await edit([{ departmentId: a.dept.id, isMain: false }]);
    expect(await rowOf("Sam Nine", a.dept.id)).toMatchObject({
      mainOnAccept: false,
      isMain: false,
    });
    expect((await auditAbout(email("Sam Nine"))).map((x) => x.summary)).toContain(
      `Sam Nine will no longer become the main approver for ${a.dept.name} when they accept`,
    );
    const again = await edit([{ departmentId: a.dept.id, isMain: true }]);
    expect(again.mainOnAccept.map((m) => m.departmentId)).toEqual([a.dept.id]);
    // Moved to another department whose main can sign: asked there instead.
    const moved = await edit([{ departmentId: b.dept.id, isMain: true }]);
    expect(await rowOf("Sam Nine", a.dept.id)).toBeUndefined();
    expect(moved.mainOnAccept).toEqual([
      { departmentId: b.dept.id, departmentName: b.dept.name, currentMain: b.mainName },
    ]);
    expect((await rowOf("Sam Nine", b.dept.id)).mainOnAccept).toBe(true);
    // A department with no main: they are main straight away, as before.
    const now = await edit([{ departmentId: c.id, isMain: true }]);
    expect(now.mainOnAccept).toEqual([]);
    expect(await rowOf("Sam Nine", c.id)).toMatchObject({ isMain: true, mainOnAccept: false });
    // A viewer signs off for nothing.
    await edit([], "viewer");
    const left = await db
      .select()
      .from(schema.approvers)
      .where(eq(schema.approvers.email, email("Sam Nine")));
    expect(left).toEqual([]);
  });

  it("10. a manager without departments.manage can't ask, and saving an invitation with a super admin's ask keeps it", async () => {
    const { dept } = await deptWithMain("Events");
    const mgrId = await addMember("Mo Ten", "marketing", {
      departmentId: dept.id,
      managerScope: "department",
    });
    await approve(mgrId, "Mo Ten", dept.id);
    const mgr = { organisationId: orgId, actorUserId: mgrId };
    await expect(invite("Sam Ten", dept.id, true, mgr)).rejects.toThrow(
      "Only people who manage departments can choose a main approver",
    );
    const out = await invite("Pia Ten", dept.id);
    await run((tx) =>
      manage.updateInviteTx(tx, mgr, {
        ...person,
        inviteId: out.inviteId,
        fullName: "Pia Ten",
        jobTitle: "Designer",
        departmentId: dept.id,
        signoffs: [{ departmentId: dept.id, isMain: true }],
      }),
    );
    expect((await rowOf("Pia Ten", dept.id)).mainOnAccept).toBe(true);
    await expect(
      run((tx) =>
        manage.updateInviteTx(tx, mgr, {
          ...person,
          inviteId: out.inviteId,
          fullName: "Pia Ten",
          departmentId: dept.id,
          signoffs: [{ departmentId: dept.id, isMain: false }],
        }),
      ),
    ).rejects.toThrow("Only people who manage departments can choose a main approver");
  });

  it("11. a department that stopped signing off or was archived isn't taken over; the asker is told", async () => {
    for (const change of [{ signsOff: false }, { isArchived: true }]) {
      const label = change.isArchived ? "Archive" : "Quiet";
      const { dept, mainName } = await deptWithMain(label);
      const name = `Sam ${label}`;
      await invite(name, dept.id);
      await db.update(schema.departments).set(change).where(eq(schema.departments.id, dept.id));
      const samId = await accept(name);
      expect(await rowOf(name, dept.id)).toMatchObject({
        userId: samId,
        isMain: false,
        mainOnAccept: false,
      });
      expect((await rowOf(mainName, dept.id)).isMain).toBe(true);
      const told = (await notesFor(adminId, "main_approver")).filter((x) =>
        x.title.startsWith(name),
      );
      expect(told.map((x) => x.title)).toEqual([
        `${name} joined, but isn't the main approver for ${dept.name}`,
      ]);
      expect(told[0].body).toContain(`${dept.name} doesn't sign off artwork at the moment`);
      expect(told[0].link).toBe(`/users/${samId}`);
      expect((await notesFor(samId, "main_approver")).length).toBe(0);
    }
  });

  it("12. someone whose access has already ended when they accept isn't made main; the main stays and the asker is told", async () => {
    const { dept, mainId, mainName } = await deptWithMain("Hospitality");
    const out = await invite("Sam Twelve", dept.id);
    await db
      .update(schema.staffInvites)
      .set({ accessEndsAt: new Date(Date.now() - 60_000) })
      .where(eq(schema.staffInvites.id, out.inviteId));
    await accept("Sam Twelve");
    expect((await rowOf("Sam Twelve", dept.id)).isMain).toBe(false);
    expect((await rowOf(mainName, dept.id)).isMain).toBe(true);
    expect((await stepOf(dept.id)).approverUserId).toBe(mainId);
    const told = (await notesFor(adminId, "main_approver")).find((x) =>
      x.title.startsWith("Sam Twelve"),
    );
    expect(told?.body).toBe(
      `They can't sign off at the moment, so ${mainName} stays main approver. Make them main under Users → Departments once they can.`,
    );
    expect((await notesFor(mainId, "main_approver")).length).toBe(0);
  });

  it("13. Departments: making an invitee main asks instead of refusing; an email-only approver nobody invited is refused", async () => {
    const { dept, mainName } = await deptWithMain("Stands");
    await invite("Sam Thirteen", dept.id, false);
    const row = await rowOf("Sam Thirteen", dept.id);
    asAdmin();
    const words = `Sam Thirteen becomes the main approver for ${dept.name} when they accept — ${mainName} stays until then`;
    expect(await approverActions.setMainApprover({ id: row.id, isMain: true })).toMatchObject({
      ok: true,
      message: words,
    });
    expect(await rowOf("Sam Thirteen", dept.id)).toMatchObject({
      mainOnAccept: true,
      isMain: false,
      mainOnAcceptBy: adminId,
    });
    // Asking again changes nothing.
    expect(await approverActions.setMainApprover({ id: row.id, isMain: true })).toMatchObject({
      ok: true,
      message: words,
    });
    expect(
      (await auditAbout(email("Sam Thirteen"))).filter((a) =>
        a.summary.startsWith("Sam Thirteen will become"),
      ),
    ).toHaveLength(1);

    const [legacy] = await db
      .insert(schema.approvers)
      .values({
        organisationId: orgId,
        departmentId: dept.id,
        fullName: "Lee Legacy",
        email: email("Lee Legacy"),
      })
      .returning();
    expect(await approverActions.setMainApprover({ id: legacy.id, isMain: true })).toMatchObject({
      ok: false,
      error:
        "Lee Legacy hasn't been invited — add them under Users → Add person first, then make them main",
    });
    // With no main who can sign, they are main now (as before), and the ask goes.
    await db
      .update(schema.approvers)
      .set({ isMain: false })
      .where(eq(schema.approvers.email, email(mainName)));
    expect(await approverActions.setMainApprover({ id: legacy.id, isMain: true })).toMatchObject({
      ok: true,
      message: `Lee Legacy is now the main approver for ${dept.name}. Sam Thirteen won't take over ${dept.name} when they accept`,
    });
  });

  it("14. Don't make main clears the ask; after they have accepted it says to reload", async () => {
    const { dept, mainName } = await deptWithMain("Media");
    await invite("Sam Fourteen", dept.id);
    const row = await rowOf("Sam Fourteen", dept.id);
    asAdmin();
    expect(await approverActions.cancelMainOnAccept({ id: row.id })).toMatchObject({
      ok: true,
      message: `Sam Fourteen won't become the main approver for ${dept.name} — ${mainName} stays main approver`,
    });
    expect((await rowOf("Sam Fourteen", dept.id)).mainOnAccept).toBe(false);
    expect(await approverActions.cancelMainOnAccept({ id: row.id })).toMatchObject({
      ok: false,
      error: "Sam Fourteen isn't due to become main approver — reload the page",
    });
    // The outlined star (setMainApprover false) does the same.
    await approverActions.setMainApprover({ id: row.id, isMain: true });
    expect(await approverActions.setMainApprover({ id: row.id, isMain: false })).toMatchObject({
      ok: true,
      message: `Sam Fourteen won't become the main approver for ${dept.name} — ${mainName} stays main approver`,
    });
    await approverActions.setMainApprover({ id: row.id, isMain: true });
    await accept("Sam Fourteen");
    expect(await approverActions.cancelMainOnAccept({ id: row.id })).toMatchObject({
      ok: false,
      error: "Sam Fourteen has accepted their invitation — reload the page",
    });
    expect((await rowOf("Sam Fourteen", dept.id)).isMain).toBe(true);
    // Removing a pending approver says they won't become main.
    const other = await deptWithMain("Video");
    await invite("Pat Fourteen", other.dept.id);
    const removed = await approverActions.removeApprover({
      id: (await rowOf("Pat Fourteen", other.dept.id)).id,
    });
    expect(removed.ok && removed.message).toContain(
      `Pat Fourteen removed from ${other.dept.name} approvers — they won't become main approver when they accept`,
    );
  });

  it("15. the database refuses an ask on a linked or main row, and a second ask in one department", async () => {
    const { dept, mainName } = await deptWithMain("Guard");
    const pending = await invite("Sam Fifteen", dept.id);
    void pending;
    const refused = async (fn: () => Promise<unknown>) => {
      const err = (await fn().catch((e) => e)) as { cause?: { constraint_name?: string } };
      return err?.cause?.constraint_name;
    };
    expect(
      await refused(() =>
        db
          .update(schema.approvers)
          .set({ mainOnAccept: true })
          .where(eq(schema.approvers.email, email(mainName))),
      ),
    ).toBe("approvers_main_on_accept_invite_only");
    await invite("Pat Fifteen", dept.id, false);
    expect(
      await refused(() =>
        db
          .update(schema.approvers)
          .set({ mainOnAccept: true })
          .where(eq(schema.approvers.email, email("Pat Fifteen"))),
      ),
    ).toBe("approvers_one_main_on_accept");
    expect(
      await refused(() =>
        db
          .update(schema.approvers)
          .set({ isMain: true })
          .where(eq(schema.approvers.email, email("Sam Fifteen"))),
      ),
    ).toBeDefined();
  });

  it("17. the Users reads report the ask", async () => {
    const { dept, mainName } = await deptWithMain("Reads");
    const out = await invite("Sam Seventeen", dept.id);
    const cards = await queries.listDepartmentCards(db, orgId);
    const card = cards.find((c) => c.id === dept.id)!;
    expect(card.approvers.find((a) => a.email === email("Sam Seventeen"))).toMatchObject({
      isMain: false,
      mainOnAccept: true,
      stateText: "Invited — not set up yet",
    });
    expect(card.approvers.find((a) => a.email === email(mainName))).toMatchObject({
      isMain: true,
      mainOnAccept: false,
    });
    const loaded = await queries.loadPerson(db, orgId, out.inviteId, adminId);
    expect(loaded!.person.allSignoffs).toEqual([{ departmentId: dept.id, isMain: true }]);
    expect(loaded!.person.pendingMainFor).toEqual([dept.id]);
    expect(loaded!.person.signsOffFor).toEqual([
      { departmentId: dept.id, name: dept.name, isMain: false, mainOnAccept: true },
    ]);
    const forSam = (
      await queries.departmentOptions(db, orgId, { userId: null, email: email("Sam Seventeen") })
    ).find((o) => o.id === dept.id)!;
    expect(forSam).toMatchObject({
      mainApprover: mainName,
      mainIsThisPerson: false,
      mainCanSign: true,
      pendingMain: null,
      pendingIsThisPerson: true,
    });
    const forOthers = (await queries.departmentOptions(db, orgId)).find((o) => o.id === dept.id)!;
    expect(forOthers).toMatchObject({ pendingMain: "Sam Seventeen", pendingIsThisPerson: false });
    const team = await queries.listTeam(db, orgId, adminId);
    expect(team.rows.find((r) => r.id === out.inviteId)?.signsOffFor).toEqual([
      { departmentId: dept.id, name: dept.name, isMain: false, mainOnAccept: true },
    ]);
    // The invitation page names the department.
    const token = out.inviteUrl.split("/invite/")[1];
    const details = await lookup.inviteDetails(token);
    expect(details).toMatchObject({ ok: true, signsOff: true, mainFor: [dept.name] });
  });
});
