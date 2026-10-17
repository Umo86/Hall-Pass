/**
 * Users v2 against a real database (TEST_DATABASE_URL): suspending someone
 * hands over sign-offs waiting on them by name, takes them out of routing,
 * sign-in and notifications, and reactivating puts everything back; an
 * access end date stops access at read time with no job run; managers add
 * people only within their scope; the claim copies a manager scope and end
 * date; the daily job records "Access ended" once; access history finds a
 * person's rows.
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
let active: typeof import("@/lib/users/active");
let notifyMod: typeof import("@/lib/notify");
let accountLink: typeof import("@/lib/auth/account-link");
let actorMod: typeof import("@/lib/auth/actor");
let history: typeof import("@/lib/users/history");
let jobs: typeof import("@/lib/cron/jobs");
let claim: typeof import("@/lib/auth/claim-staff-invite");
let orgId: string;
let workflowId: string;
let adminId: string;
let mkt: typeof schema.departments.$inferSelect;
let sales: typeof schema.departments.$inferSelect;
const n = Date.now() % 1_000_000;

type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];
const run = <T>(fn: (tx: Tx) => Promise<T>) => db.transaction(fn);
const email = (name: string) => `${name.toLowerCase()}-${n}@access.test`;

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

const person = {
  jobTitle: null,
  newDepartmentName: null,
  features: null,
  abilities: {},
  signoffs: [],
};

d("users v2: access", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    manage = await import("@/lib/users/manage");
    departments = await import("@/lib/domain/departments");
    active = await import("@/lib/users/active");
    notifyMod = await import("@/lib/notify");
    accountLink = await import("@/lib/auth/account-link");
    actorMod = await import("@/lib/auth/actor");
    history = await import("@/lib/users/history");
    jobs = await import("@/lib/cron/jobs");
    claim = await import("@/lib/auth/claim-staff-invite");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Access Org", slug: `access-${n}` })
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
  });

  afterAll(async () => {
    await client?.end();
  });

  it("suspending hands over named sign-offs, drops them from routing, sign-in and messages; reactivating restores it", async () => {
    const ctx = { organisationId: orgId, actorUserId: adminId, actorName: "Alex" };
    const mia = await addMember("Mia", "marketing", { departmentId: mkt.id });
    await run((tx) =>
      manage.setSignoffs(
        tx,
        ctx,
        { userId: mia, email: email("Mia"), fullName: "Mia", jobTitle: null },
        [{ departmentId: mkt.id, isMain: true }],
      ),
    );
    await db.transaction((tx) => departments.syncDepartmentSteps(tx, orgId));
    expect((await deptStep(mkt.id)).approverUserId).toBe(mia);

    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Access Show", code: `AS${n % 10000}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Access Hall", code: `AH${n % 10000}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Access Show 2027",
        code: `AZ${n % 10000}`,
        buildStart: "2027-02-01",
        buildEnd: "2027-02-02",
        openStart: "2027-02-03",
        openEnd: "2027-02-04",
        breakdownEnd: "2027-02-05",
      })
      .returning();
    const [item] = await db
      .insert(schema.signageItems)
      .values({
        editionId: edition.id,
        ref: `SIG-AZ${n}-001`,
        seq: 1,
        name: "Welcome banner",
        ownerUserId: mia,
        status: "in_review",
        workflowId,
        currentRunNumber: 1,
        createdBy: adminId,
      })
      .returning();
    const [inst] = await db
      .insert(schema.approvalInstances)
      .values({
        entityType: "signage_item",
        entityId: item.id,
        runNumber: 1,
        workflowStepId: (await deptStep(mkt.id)).id,
        stepNameSnapshot: "Marketing sign-off",
        stepKindSnapshot: "approval",
        sortOrderSnapshot: 1,
        status: "pending",
        assignedUserId: mia,
        assignedDepartmentId: mkt.id,
      })
      .returning();

    // A sign-off waits on Mia: someone must take it over…
    const refused = await run((tx) => manage.suspendMemberTx(tx, ctx, { userId: mia })).catch(
      (e) => e,
    );
    expect(refused.message).toMatch(/A sign-off is waiting on Mia/);
    // …and not someone whose sign-off is paused, or a viewer.
    const paused = await addMember("Pat", "marketing", {
      permissionOverrides: { "approval.decide": false },
    });
    const viewer = await addMember("Vic", "viewer");
    for (const to of [paused, viewer]) {
      const bad = await run((tx) =>
        manage.suspendMemberTx(tx, ctx, { userId: mia, handToUserId: to }),
      ).catch((e) => e);
      expect(bad.message).toBe("Pick a team member who can sign off");
    }
    // Nobody can suspend themselves.
    const self = await run((tx) => manage.suspendMemberTx(tx, ctx, { userId: adminId })).catch(
      (e) => e,
    );
    expect(self.message).toMatch(/can't change your own access/);

    const ops = await addMember("Oscar", "ops");
    const out = await run((tx) =>
      manage.suspendMemberTx(tx, ctx, { userId: mia, handToUserId: ops }),
    );
    expect(out).toMatchObject({ name: "Mia", handedOver: 1 });
    const [moved] = await db
      .select()
      .from(schema.approvalInstances)
      .where(eq(schema.approvalInstances.id, inst.id));
    expect(moved.assignedUserId).toBe(ops);

    // Approver row, item and membership stay; routing and lists skip her.
    const rows = await db.select().from(schema.approvers).where(eq(schema.approvers.userId, mia));
    expect(rows).toHaveLength(1);
    expect((await deptStep(mkt.id)).approverUserId).toBeNull();
    expect(await departments.departmentSignerIds(db, orgId, mkt.id)).not.toContain(mia);
    expect((await active.activeMembers(db, orgId)).map((m) => m.userId)).not.toContain(mia);
    expect(await notifyMod.activeRecipientIds(db, [mia, ops])).toEqual(new Set([ops]));
    expect(await accountLink.emailIsInvited(email("Mia"))).toBe(false);
    expect(await actorMod.sessionForUserId(mia)).toBeNull();
    const [owned] = await db
      .select()
      .from(schema.signageItems)
      .where(eq(schema.signageItems.id, item.id));
    expect(owned.ownerUserId).toBe(mia);

    // Reactivated: everything as it was, main approver routing included.
    await run((tx) => manage.reactivateMemberTx(tx, ctx, { userId: mia }));
    expect((await deptStep(mkt.id)).approverUserId).toBe(mia);
    expect(await departments.departmentSignerIds(db, orgId, mkt.id)).toContain(mia);
    expect(await accountLink.emailIsInvited(email("Mia"))).toBe(true);
    const session = await actorMod.sessionForUserId(mia);
    expect(session?.actor.kind).toBe("staff");

    // Both changes are in her access history, by subject.
    const h = await history.accessHistory(db, orgId, { userId: mia, email: email("Mia") });
    expect(h.map((e) => e.summary)).toEqual(
      expect.arrayContaining([`Suspended ${email("Mia")}`, `Reactivated ${email("Mia")}`]),
    );
    expect(h.find((e) => e.summary.startsWith("Suspended"))?.actorName).toBe("Alex");
  });

  it("an access end date in the past takes effect at read time, with no job run", async () => {
    const gone = await addMember("Gail", "marketing", {
      accessEndsAt: new Date(Date.now() - 60_000),
    });
    expect((await active.activeMembers(db, orgId)).map((m) => m.userId)).not.toContain(gone);
    expect(await notifyMod.activeRecipientIds(db, [gone])).toEqual(new Set());
    expect(await accountLink.emailIsInvited(email("Gail"))).toBe(false);
    expect(await actorMod.sessionForUserId(gone)).toBeNull();
  });

  it("setting an end date: a London date, today or later, never on yourself", async () => {
    const ctx = { organisationId: orgId, actorUserId: adminId };
    const tess = await addMember("Tess", "sales");
    const out = await run((tx) =>
      manage.setAccessEndTx(tx, ctx, { userId: tess, date: "2099-06-30" }),
    );
    expect(out.endsAt?.toISOString()).toBe("2099-06-30T22:59:59.999Z");
    const past = await run((tx) =>
      manage.setAccessEndTx(tx, ctx, { userId: tess, date: "2001-01-01" }),
    ).catch((e) => e);
    expect(past.message).toMatch(/today or a later date/);
    const mine = await run((tx) =>
      manage.setAccessEndTx(tx, ctx, { userId: adminId, date: "2099-01-01" }),
    ).catch((e) => e);
    expect(mine.message).toMatch(/can't change your own access/);
    await run((tx) => manage.setAccessEndTx(tx, ctx, { userId: tess, date: null }));
    const [m] = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, tess));
    expect(m.accessEndsAt).toBeNull();
  });

  it("a department manager adds people to their own department only, never managers", async () => {
    const mgr = await addMember("Mona", "marketing", {
      departmentId: mkt.id,
      managerScope: "department",
    });
    const ctx = { organisationId: orgId, actorUserId: mgr };
    const out = await run((tx) =>
      manage.inviteUserTx(tx, ctx, {
        ...person,
        email: email("Newbie"),
        fullName: "Newbie",
        departmentId: mkt.id,
        role: "marketing",
        accessEndsOn: "2099-12-31",
      }),
    );
    const [invite] = await db
      .select()
      .from(schema.staffInvites)
      .where(eq(schema.staffInvites.id, out.inviteId));
    expect(invite).toMatchObject({ departmentId: mkt.id, managerScope: null });
    expect(invite.accessEndsAt?.toISOString()).toBe("2099-12-31T23:59:59.999Z");

    const otherDept = await run((tx) =>
      manage.inviteUserTx(tx, ctx, {
        ...person,
        email: email("Elsewhere"),
        fullName: "Elsewhere",
        departmentId: sales.id,
        role: "marketing",
      }),
    ).catch((e) => e);
    expect(otherDept.message).toMatch(/your own department/);
    const asManager = await run((tx) =>
      manage.inviteUserTx(tx, ctx, {
        ...person,
        email: email("Boss"),
        fullName: "Boss",
        departmentId: mkt.id,
        role: "marketing",
        managerScope: "department",
      }),
    ).catch((e) => e);
    expect(asManager.message).toMatch(/manager/);
    const tooMuch = await run((tx) =>
      manage.inviteUserTx(tx, ctx, {
        ...person,
        email: email("Costly"),
        fullName: "Costly",
        departmentId: mkt.id,
        role: "marketing",
        abilities: { "costs.edit": true },
      }),
    ).catch((e) => e);
    expect(tooMuch.message).toMatch(/Edit costs/);
    // Someone outside her department can't be changed or suspended by her.
    const salesPerson = await addMember("Sid", "sales", { departmentId: sales.id });
    const edit = await run((tx) =>
      manage.updateMemberTx(tx, ctx, {
        ...person,
        userId: salesPerson,
        fullName: "Sid",
        departmentId: sales.id,
        role: "sales",
        signoffPaused: false,
      }),
    ).catch((e) => e);
    expect(edit.message).toMatch(/can't change this person's access/);
    const suspend = await run((tx) =>
      manage.suspendMemberTx(tx, { ...ctx, actorName: "Mona" }, { userId: salesPerson }),
    ).catch((e) => e);
    expect(suspend.message).toMatch(/can't change this person's access/);

    // Accepting copies the end date (and a manager scope when a super admin set one).
    const userId = randomUUID();
    await db
      .insert(schema.users)
      .values({ id: userId, email: email("Newbie"), fullName: "Newbie" });
    await claim.claimStaffInvite(invite, userId);
    const [m] = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, userId));
    expect(m.accessEndsAt?.toISOString()).toBe("2099-12-31T23:59:59.999Z");
  });

  it("a super admin's manager invitation carries the scope through the claim", async () => {
    const ctx = { organisationId: orgId, actorUserId: adminId };
    const out = await run((tx) =>
      manage.inviteUserTx(tx, ctx, {
        ...person,
        email: email("Lead"),
        fullName: "Lead",
        departmentId: sales.id,
        role: "sales",
        managerScope: "department",
      }),
    );
    const [invite] = await db
      .select()
      .from(schema.staffInvites)
      .where(eq(schema.staffInvites.id, out.inviteId));
    const userId = randomUUID();
    await db.insert(schema.users).values({ id: userId, email: email("Lead"), fullName: "Lead" });
    await claim.claimStaffInvite(invite, userId);
    const [m] = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, userId));
    expect(m.managerScope).toBe("department");
    // A super admin never carries a scope (database check).
    const bad = await db
      .insert(schema.memberships)
      .values({
        userId: await addMember("Zed", "viewer"),
        organisationId: orgId,
        role: "admin",
        managerScope: "everyone",
      })
      .catch((e) => e);
    expect(bad).toBeInstanceOf(Error);
  });

  it("the daily job records Access ended once, and tells super admins about waiting sign-offs", async () => {
    const ended = await addMember("Eve", "marketing", {
      accessEndsAt: new Date(Date.now() - 3_600_000),
    });
    const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/London" }).format(
      new Date(),
    );
    const first = await jobs.endExpiredAccess(today);
    expect(first.sent).toBeGreaterThanOrEqual(1);
    const audits = await db
      .select()
      .from(schema.auditLog)
      .where(
        and(eq(schema.auditLog.entityType, "membership"), eq(schema.auditLog.subjectUserId, ended)),
      );
    expect(audits.map((a) => a.summary)).toEqual([`Access ended for ${email("Eve")}`]);
    expect(audits[0].actorType).toBe("cron");
    await jobs.endExpiredAccess(today);
    const again = await db
      .select()
      .from(schema.auditLog)
      .where(
        and(eq(schema.auditLog.entityType, "membership"), eq(schema.auditLog.subjectUserId, ended)),
      );
    expect(again).toHaveLength(1);
  });

  it("when access ends, the daily job hands named sign-offs back where someone else can sign", async () => {
    const ella = await addMember("Ella", "marketing", {
      departmentId: mkt.id,
      accessEndsAt: new Date(Date.now() - 3_600_000),
    });
    // Ella signs for Marketing (others can too) and Sales (nobody else can).
    await db.insert(schema.approvers).values([
      {
        organisationId: orgId,
        departmentId: mkt.id,
        fullName: "Ella",
        email: email("Ella"),
        userId: ella,
      },
      {
        organisationId: orgId,
        departmentId: sales.id,
        fullName: "Ella",
        email: email("Ella"),
        userId: ella,
      },
    ]);
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Ended Show", code: `ES${n % 10000}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Ended Hall", code: `EH${n % 10000}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Ended Show 2027",
        code: `EZ${n % 10000}`,
        buildStart: "2027-03-01",
        buildEnd: "2027-03-02",
        openStart: "2027-03-03",
        openEnd: "2027-03-04",
        breakdownEnd: "2027-03-05",
      })
      .returning();
    const mktStep = await deptStep(mkt.id);
    const salesStep = await deptStep(sales.id);
    const [item] = await db
      .insert(schema.signageItems)
      .values({
        editionId: edition.id,
        ref: `SIG-EZ${n}-001`,
        seq: 1,
        name: "Hall banner",
        ownerUserId: adminId,
        status: "in_review",
        workflowId,
        currentRunNumber: 1,
        createdBy: adminId,
        signoffs: [
          { stepId: mktStep.id, userId: ella },
          { stepId: salesStep.id, userId: ella },
        ],
      })
      .returning();
    const step = (id: string, name: string, departmentId: string) => ({
      entityType: "signage_item" as const,
      entityId: item.id,
      runNumber: 1,
      workflowStepId: id,
      stepNameSnapshot: name,
      stepKindSnapshot: "approval" as const,
      sortOrderSnapshot: 1,
      status: "pending" as const,
      assignedUserId: ella,
      assignedDepartmentId: departmentId,
    });
    const [mktInst, salesInst] = await db
      .insert(schema.approvalInstances)
      .values([
        step(mktStep.id, "Marketing sign-off", mkt.id),
        step(salesStep.id, "Sales sign-off", sales.id),
      ])
      .returning();
    const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/London" }).format(
      new Date(),
    );
    await jobs.endExpiredAccess(today);
    const now = async (id: string) =>
      (
        await db.select().from(schema.approvalInstances).where(eq(schema.approvalInstances.id, id))
      )[0];
    // Marketing has other signers: back to the department (or its main approver).
    expect((await now(mktInst.id)).assignedUserId).not.toBe(ella);
    // Nobody else signs for Sales: it stays named, and the super admin hears about it.
    expect((await now(salesInst.id)).assignedUserId).toBe(ella);
    const told = await db
      .select()
      .from(schema.notifications)
      .where(
        and(
          eq(schema.notifications.userId, adminId),
          eq(schema.notifications.kind, "access_ended"),
        ),
      );
    expect(told.map((t) => t.title)).toContain(
      "Ella's access has ended — a sign-off still waits on them",
    );
    // The hand-back is audited as the daily job, about Ella; her item plan names nobody now.
    const [handed] = await db
      .select()
      .from(schema.auditLog)
      .where(and(eq(schema.auditLog.entityId, item.id), eq(schema.auditLog.action, "delegate")))
      .orderBy(schema.auditLog.createdAt);
    expect(handed).toMatchObject({ actorType: "cron", actorUserId: null, subjectUserId: ella });
    expect(handed.summary).toContain("Ella no longer has access");
    const [plan] = await db
      .select({ signoffs: schema.signageItems.signoffs })
      .from(schema.signageItems)
      .where(eq(schema.signageItems.id, item.id));
    expect(JSON.stringify(plan.signoffs)).not.toContain(ella);
  });
});
