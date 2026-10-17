/**
 * Users v2 review fixes against a real database (TEST_DATABASE_URL). Each
 * test sets up its own organisation and drives lib/users/manage.ts:
 * - a manager can't renew an invitation that gives more than they could
 *   (escalation-1), nor hand a suspended colleague's sign-offs to
 *   themselves or a non-approver (escalation-2);
 * - there is always a super admin with no end date (lifecycle-1);
 * - suspending a department's last signer hands over its department-wide
 *   sign-offs too, and the daily job's notice names them (lifecycle-2);
 * - clearing item plans writes a row per item (lifecycle-3);
 * - team members hold no live partner access: renew re-checks it, partner
 *   access isn't extended for them, removal revokes it (lifecycle-4);
 * - two suspensions at once can't each hand over to the other (lifecycle-5);
 * - a main approver demoted by someone else becoming main has a row in
 *   their access history (lifecycle-6).
 */
import { randomUUID } from "node:crypto";
import { and, eq, inArray } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "@/lib/db/schema";
import {
  can,
  parseFeatures,
  type ApprovalStepCtx,
  type PermissionOverrides,
  type StaffActor,
  type StaffRole,
} from "@/lib/authz";
import { defaultSignageSteps } from "@/lib/workflow";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let manage: typeof import("@/lib/users/manage");
let external: typeof import("@/lib/users/external");
let departments: typeof import("@/lib/domain/departments");
let history: typeof import("@/lib/users/history");
let actorMod: typeof import("@/lib/auth/actor");
let jobs: typeof import("@/lib/cron/jobs");
let today: typeof import("@/lib/today");
const n = Date.now() % 1_000_000;
let k = 0;

type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];
const run = <T>(fn: (tx: Tx) => Promise<T>) => db.transaction(fn);
const person = { jobTitle: null, newDepartmentName: null, features: null, abilities: {} };

/** A fresh organisation with the default workflow, Marketing and Sales, a super admin and an event. */
async function newOrg() {
  const tag = `r${k++}`;
  const [org] = await db
    .insert(schema.organisations)
    .values({ name: `Review ${tag}`, slug: `review-${tag}-${n}` })
    .returning();
  const orgId = org.id;
  const [wf] = await db
    .insert(schema.workflows)
    .values({ organisationId: orgId, name: "Signage", appliesTo: "signage", isDefault: true })
    .returning();
  for (const s of defaultSignageSteps.filter((s) => !s.defaultFor?.length)) {
    await db.insert(schema.workflowSteps).values({
      workflowId: wf.id,
      sortOrder: s.sortOrder,
      name: s.name,
      kind: s.kind,
      approverType: s.approverType,
      approverRole: s.approverRole,
      conditions: s.conditions,
    });
  }
  const [mkt, sales] = await db
    .insert(schema.departments)
    .values([
      { organisationId: orgId, name: "Marketing", sortOrder: 1, defaultFor: ["organiser"] },
      { organisationId: orgId, name: "Sales", sortOrder: 2, defaultFor: ["sponsor"] },
    ])
    .returning();
  await run((tx) => departments.syncDepartmentSteps(tx, orgId));
  const email = (name: string) => `${name.toLowerCase()}-${tag}-${n}@review.test`;
  const add = async (
    name: string,
    role: StaffRole,
    extra: Partial<typeof schema.memberships.$inferInsert> = {},
  ) => {
    const id = randomUUID();
    await db.insert(schema.users).values({ id, email: email(name), fullName: name });
    await db
      .insert(schema.memberships)
      .values({ userId: id, organisationId: orgId, role, ...extra });
    return id;
  };
  const admin = await add("Alex", "admin");
  const [event] = await db
    .insert(schema.events)
    .values({ organisationId: orgId, name: `Review ${tag}`, code: `V${tag}${n % 1000}` })
    .returning();
  const [venue] = await db
    .insert(schema.venues)
    .values({ organisationId: orgId, name: `Review Hall ${tag}`, code: `VH${tag}${n % 1000}` })
    .returning();
  const [edition] = await db
    .insert(schema.editions)
    .values({
      eventId: event.id,
      venueId: venue.id,
      name: `Review ${tag} 2027`,
      code: `RV${tag}${n % 1000}`,
      buildStart: "2027-02-01",
      buildEnd: "2027-02-02",
      openStart: "2027-02-03",
      openEnd: "2027-02-04",
      breakdownEnd: "2027-02-05",
    })
    .returning();
  const ctx = { organisationId: orgId, actorUserId: admin, actorName: "Alex" };
  let seq = 0;
  const deptStep = async (departmentId: string) => {
    const [step] = await db
      .select()
      .from(schema.workflowSteps)
      .where(
        and(
          eq(schema.workflowSteps.workflowId, wf.id),
          eq(schema.workflowSteps.departmentId, departmentId),
        ),
      );
    return step;
  };
  /** An item in review with one pending step for the department (naming someone, or nobody). */
  const pendingItem = async (departmentId: string, assignedUserId: string | null) => {
    seq++;
    const [item] = await db
      .insert(schema.signageItems)
      .values({
        editionId: edition.id,
        ref: `SIG-RV${tag}${n}-${String(seq).padStart(3, "0")}`,
        seq,
        name: `Sign ${seq}`,
        ownerUserId: admin,
        status: "in_review",
        workflowId: wf.id,
        currentRunNumber: 1,
        createdBy: admin,
      })
      .returning();
    const step = await deptStep(departmentId);
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
        assignedUserId,
        assignedDepartmentId: departmentId,
      })
      .returning();
    return { item, inst };
  };
  const signsFor = (userId: string, name: string, departmentId: string, isMain = false) =>
    run((tx) =>
      manage.setSignoffs(tx, ctx, { userId, email: email(name), fullName: name, jobTitle: null }, [
        { departmentId, isMain },
      ]),
    );
  return {
    orgId,
    workflowId: wf.id,
    editionId: edition.id,
    mkt,
    sales,
    admin,
    ctx,
    email,
    add,
    deptStep,
    pendingItem,
    signsFor,
  };
}

type Org = Awaited<ReturnType<typeof newOrg>>;

async function actorFor(o: Org, userId: string): Promise<StaffActor> {
  const m = await db.query.memberships.findFirst({
    where: eq(schema.memberships.userId, userId),
  });
  return {
    kind: "staff",
    userId,
    organisationId: o.orgId,
    role: m!.role,
    overrides: m!.permissionOverrides as PermissionOverrides,
    departmentId: m!.departmentId,
    features: parseFeatures(m!.features),
    managerScope: m!.role === "admin" ? null : m!.managerScope,
    signoffDepartmentIds: await departments.departmentIdsForUser(db, o.orgId, userId),
  };
}

function stepCtx(o: Org, inst: typeof schema.approvalInstances.$inferSelect): ApprovalStepCtx {
  return {
    assignedRole: inst.assignedRole,
    assignedDepartmentId: inst.assignedDepartmentId,
    assignedUserId: inst.assignedUserId,
    stepKind: inst.stepKindSnapshot,
    entity: {
      type: "signage_item",
      item: { organisationId: o.orgId, editionId: o.editionId, venueId: "v", kind: "signage" },
    },
  };
}

async function instance(id: string) {
  const [row] = await db
    .select()
    .from(schema.approvalInstances)
    .where(eq(schema.approvalInstances.id, id));
  return row;
}

const refused = <T>(p: Promise<T>) => p.then(() => null).catch((e: Error) => e.message);

d("users v2 review fixes", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 4, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    manage = await import("@/lib/users/manage");
    external = await import("@/lib/users/external");
    departments = await import("@/lib/domain/departments");
    history = await import("@/lib/users/history");
    actorMod = await import("@/lib/auth/actor");
    jobs = await import("@/lib/cron/jobs");
    today = await import("@/lib/today");
  });

  afterAll(async () => {
    await client?.end();
  });

  it("escalation-1: a manager can't renew an invitation that gives more than they could", async () => {
    const o = await newOrg();
    const mona = await o.add("Mona", "marketing", {
      departmentId: o.mkt.id,
      managerScope: "department",
    });
    const monaCtx = { organisationId: o.orgId, actorUserId: mona, actorName: "Mona" };
    // A super admin invites Pia into Mona's department with abilities only
    // super admins give, and as Sales' main approver.
    const rich = await run((tx) =>
      manage.inviteUserTx(tx, o.ctx, {
        ...person,
        email: o.email("Pia"),
        fullName: "Pia",
        departmentId: o.mkt.id,
        role: "marketing",
        abilities: { "departments.manage": true, "partners.invite": true },
        signoffs: [{ departmentId: o.sales.id, isMain: true }],
      }),
    );
    const before = await db.query.staffInvites.findFirst({
      where: eq(schema.staffInvites.id, rich.inviteId),
    });
    expect(await refused(run((tx) => manage.renewInviteLinkTx(tx, monaCtx, rich.inviteId)))).toBe(
      manage.RENEW_NOT_YOURS,
    );
    // Nothing changed: the old link still stands, no new one was made.
    const after = await db.query.staffInvites.findFirst({
      where: eq(schema.staffInvites.id, rich.inviteId),
    });
    expect(after!.inviteTokenHash).toBe(before!.inviteTokenHash);
    // The bulk bar's Resend goes through the same check.
    const [row] = await manage.bulkPeople(
      db,
      { ...monaCtx, actorName: "Mona" },
      { ids: [rich.inviteId], action: "resend" },
    );
    expect(row).toMatchObject({ ok: false, reason: manage.RENEW_NOT_YOURS });
    expect(row.inviteUrl).toBeUndefined();

    // A super admin can; and Mona can renew one she could have made herself.
    await run((tx) => manage.renewInviteLinkTx(tx, o.ctx, rich.inviteId));
    const own = await run((tx) =>
      manage.inviteUserTx(tx, monaCtx, {
        ...person,
        email: o.email("Quin"),
        fullName: "Quin",
        departmentId: o.mkt.id,
        role: "marketing",
        signoffs: [],
      }),
    );
    const renewed = await run((tx) => manage.renewInviteLinkTx(tx, monaCtx, own.inviteId));
    expect(renewed.inviteUrl).toMatch(/\/invite\//);
  });

  it("escalation-2: a manager hands a suspended colleague's sign-offs only to that department's approvers", async () => {
    const o = await newOrg();
    const mira = await o.add("Mira", "marketing", {
      departmentId: o.mkt.id,
      managerScope: "department",
    });
    const ian = await o.add("Ian", "marketing", { departmentId: o.mkt.id });
    const tom = await o.add("Tom", "marketing", { departmentId: o.mkt.id });
    const sid = await o.add("Sid", "sales", { departmentId: o.sales.id });
    await o.signsFor(ian, "Ian", o.sales.id);
    await o.signsFor(sid, "Sid", o.sales.id);
    await run((tx) => departments.syncDepartmentSteps(tx, o.orgId));
    const { inst } = await o.pendingItem(o.sales.id, ian);
    const miraCtx = { organisationId: o.orgId, actorUserId: mira, actorName: "Mira" };
    expect(can(await actorFor(o, mira), { type: "approval.decide", step: stepCtx(o, inst) })).toBe(
      false,
    );

    // Not to herself, nor to someone who doesn't sign off for Sales.
    for (const to of [mira, tom]) {
      expect(
        await refused(
          run((tx) =>
            manage.suspendMemberTx(tx, miraCtx, { userId: ian, handTo: { [o.sales.id]: to } }),
          ),
        ),
      ).toMatch(/Hand these Sales sign-offs to one of its approvers/);
      expect((await instance(inst.id)).assignedUserId).toBe(ian);
    }
    // The dialog offers her nobody but Sales' own approvers for them.
    const plan = await manage.handoverPlan(db, o.orgId, ian, { viewer: await actorFor(o, mira) });
    expect(plan.signersOnly).toBe(true);
    expect(plan.candidates.map((c) => c.userId)).not.toContain(mira);
    expect(plan.groups[0].signers.map((s) => s.userId)).toEqual([sid]);

    // One of Sales' approvers, or back to the department, is fine.
    await run((tx) =>
      manage.suspendMemberTx(tx, miraCtx, { userId: ian, handTo: { [o.sales.id]: sid } }),
    );
    expect((await instance(inst.id)).assignedUserId).toBe(sid);

    // A super admin may still pick anyone who can sign.
    await run((tx) => manage.reactivateMemberTx(tx, o.ctx, { userId: ian }));
    const second = await o.pendingItem(o.sales.id, ian);
    await run((tx) =>
      manage.suspendMemberTx(tx, o.ctx, { userId: ian, handTo: { [o.sales.id]: tom } }),
    );
    expect((await instance(second.inst.id)).assignedUserId).toBe(tom);
  });

  it("escalation-2: with nobody else in the department, a manager is told to ask a super admin", async () => {
    const o = await newOrg();
    const mira = await o.add("Mira", "marketing", {
      departmentId: o.mkt.id,
      managerScope: "department",
    });
    const ian = await o.add("Ian", "marketing", { departmentId: o.mkt.id });
    await o.signsFor(ian, "Ian", o.sales.id);
    await o.pendingItem(o.sales.id, ian);
    const message = await refused(
      run((tx) =>
        manage.suspendMemberTx(
          tx,
          { organisationId: o.orgId, actorUserId: mira, actorName: "Mira" },
          { userId: ian, handToUserId: mira },
        ),
      ),
    );
    expect(message).toMatch(/Nobody else can sign off for Sales — ask a super admin/);
  });

  it("lifecycle-1: there is always a super admin with no end date", async () => {
    const o = await newOrg();
    const bea = await o.add("Bea", "admin");
    const beaCtx = { organisationId: o.orgId, actorUserId: bea, actorName: "Bea" };
    const date = today.todayInLondon();
    // Alex gives Bea an end date: Alex has none, so that's fine…
    await run((tx) => manage.setAccessEndTx(tx, o.ctx, { userId: bea, date }));
    // …but Bea can't give Alex one back: nobody would be left once both pass.
    expect(
      await refused(run((tx) => manage.setAccessEndTx(tx, beaCtx, { userId: o.admin, date }))),
    ).toMatch(/always be a super admin whose access doesn't end/);
    // Nor suspend, demote or remove Alex while her own access ends.
    expect(
      await refused(run((tx) => manage.suspendMemberTx(tx, beaCtx, { userId: o.admin }))),
    ).toMatch(/always be a super admin/);
    expect(
      await refused(
        run((tx) =>
          manage.updateMemberTx(tx, beaCtx, {
            ...person,
            userId: o.admin,
            fullName: "Alex",
            departmentId: null,
            role: "ops",
            signoffs: [],
            signoffPaused: false,
          }),
        ),
      ),
    ).toMatch(/always be a super admin/);
    expect(
      await refused(run((tx) => manage.removeMemberTx(tx, beaCtx, { userId: o.admin }))),
    ).toMatch(/always be a super admin/);
    // A new end date through the person page is refused the same way.
    expect(
      await refused(
        run((tx) =>
          manage.updateMemberTx(tx, beaCtx, {
            ...person,
            userId: o.admin,
            fullName: "Alex",
            departmentId: null,
            role: "admin",
            signoffs: [],
            signoffPaused: false,
            accessEndsOn: "2099-01-01",
          }),
        ),
      ),
    ).toMatch(/always be a super admin/);
    const [alex] = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, o.admin));
    expect(alex).toMatchObject({ role: "admin", suspendedAt: null, accessEndsAt: null });

    // Once Bea's end date is cleared, either may give the other one.
    await run((tx) => manage.setAccessEndTx(tx, o.ctx, { userId: bea, date: null }));
    await run((tx) => manage.setAccessEndTx(tx, beaCtx, { userId: o.admin, date: "2099-01-01" }));
  });

  it("lifecycle-2: suspending a department's last signer hands over its department-wide sign-offs", async () => {
    const o = await newOrg();
    const dana = await o.add("Dana", "marketing", { departmentId: o.mkt.id });
    const oscar = await o.add("Oscar", "ops");
    await o.signsFor(dana, "Dana", o.mkt.id);
    await run((tx) => departments.syncDepartmentSteps(tx, o.orgId));
    expect((await o.deptStep(o.mkt.id)).approverUserId).toBeNull();
    const { inst } = await o.pendingItem(o.mkt.id, null);

    // The Suspend dialog shows it, with nobody else to give it to.
    const impact = await manage.getRemovalImpact(db, o.orgId, dana);
    expect(impact!.handover.groups).toHaveLength(1);
    expect(impact!.handover.groups[0]).toMatchObject({
      departmentId: o.mkt.id,
      signers: [],
      defaultTo: null,
    });
    expect(impact!.handover.groups[0].steps.map((s) => s.id)).toEqual([inst.id]);

    // Suspending needs someone picked, and they get it.
    expect(await refused(run((tx) => manage.suspendMemberTx(tx, o.ctx, { userId: dana })))).toMatch(
      /A sign-off is waiting on Dana \(Marketing\)/,
    );
    const out = await run((tx) =>
      manage.suspendMemberTx(tx, o.ctx, { userId: dana, handTo: { [o.mkt.id]: oscar } }),
    );
    expect(out.handedOver).toBe(1);
    expect(await instance(inst.id)).toMatchObject({
      status: "pending",
      assignedUserId: oscar,
      delegatedFromUserId: dana,
    });
    const told = await db
      .select()
      .from(schema.notifications)
      .where(
        and(eq(schema.notifications.userId, oscar), eq(schema.notifications.kind, "delegation")),
      );
    expect(told).toHaveLength(1);
    const [audit] = await db
      .select()
      .from(schema.auditLog)
      .where(
        and(eq(schema.auditLog.entityId, inst.entityId), eq(schema.auditLog.action, "delegate")),
      );
    expect(audit.before).toEqual({ assignedUserId: null, assignedDepartmentId: o.mkt.id });
  });

  it("lifecycle-2: when the last signer's access ends, the notice names the department-wide sign-offs", async () => {
    const o = await newOrg();
    const erin = await o.add("Erin", "marketing", { departmentId: o.mkt.id });
    await o.signsFor(erin, "Erin", o.mkt.id);
    const { item } = await o.pendingItem(o.mkt.id, null);
    await db
      .update(schema.memberships)
      .set({ accessEndsAt: new Date(Date.now() - 60_000) })
      .where(eq(schema.memberships.userId, erin));
    await jobs.endExpiredAccess(today.todayInLondon());
    const notices = await db
      .select()
      .from(schema.notifications)
      .where(
        and(
          eq(schema.notifications.userId, o.admin),
          eq(schema.notifications.kind, "access_ended"),
        ),
      );
    expect(notices).toHaveLength(1);
    expect(notices[0].title).toMatch(/Erin's access has ended — a sign-off still waits/);
    expect(notices[0].body).toContain(item.ref);
    expect(notices[0].body).toMatch(/Nobody else signs off for Marketing/);
  });

  it("lifecycle-3: clearing item sign-off plans writes an audit row per item", async () => {
    const o = await newOrg();
    const mia = await o.add("Mia", "marketing", { departmentId: o.mkt.id });
    const max = await o.add("Max", "marketing", { departmentId: o.mkt.id });
    await o.signsFor(mia, "Mia", o.mkt.id);
    await o.signsFor(max, "Max", o.mkt.id);
    const step = await o.deptStep(o.mkt.id);
    const [item] = await db
      .insert(schema.signageItems)
      .values({
        editionId: o.editionId,
        ref: `SIG-PLAN${n}-${k}`,
        seq: 900,
        name: "Hall sign",
        ownerUserId: o.admin,
        status: "draft",
        workflowId: o.workflowId,
        currentRunNumber: 0,
        createdBy: o.admin,
        signoffs: [{ stepId: step.id, userId: mia }],
      })
      .returning();
    await run((tx) => manage.suspendMemberTx(tx, o.ctx, { userId: mia }));
    const [afterItem] = await db
      .select()
      .from(schema.signageItems)
      .where(eq(schema.signageItems.id, item.id));
    expect(afterItem.signoffs).toEqual([{ stepId: step.id, userId: null }]);
    const rows = await db
      .select()
      .from(schema.auditLog)
      .where(
        and(eq(schema.auditLog.entityType, "signage_item"), eq(schema.auditLog.entityId, item.id)),
      );
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({
      action: "update",
      actorUserId: o.admin,
      subjectUserId: mia,
      before: { signoffs: [{ stepId: step.id, userId: mia }] },
      after: { signoffs: [{ stepId: step.id, userId: null }] },
    });
    expect(rows[0].summary).toMatch(/no longer names Mia, who is suspended/);
  });

  it("lifecycle-4: renewing a team invitation re-checks partner access; removal revokes partner access", async () => {
    const o = await newOrg();
    const jo = o.email("Jo");
    const inv = await run((tx) =>
      manage.inviteUserTx(tx, o.ctx, {
        ...person,
        email: jo,
        fullName: "Jo",
        departmentId: null,
        role: "marketing",
        signoffs: [],
      }),
    );
    await db
      .update(schema.staffInvites)
      .set({ expiresAt: new Date(Date.now() - 60_000) })
      .where(eq(schema.staffInvites.id, inv.inviteId));
    // Meanwhile Jo became a partner here.
    const joId = randomUUID();
    await db.insert(schema.users).values({ id: joId, email: jo, fullName: "Jo", isExternal: true });
    const [grant] = await db
      .insert(schema.externalGrants)
      .values({
        userId: joId,
        invitedEmail: jo,
        organisationId: o.orgId,
        editionId: o.editionId,
        role: "structural_engineer",
        invitedBy: o.admin,
        inviteTokenHash: `h-${randomUUID()}`,
        acceptedAt: new Date(),
      })
      .returning();
    expect(await refused(run((tx) => manage.renewInviteLinkTx(tx, o.ctx, inv.inviteId)))).toMatch(
      /portal access here/,
    );
    expect((await actorMod.sessionForUserId(joId))?.actor.kind).toBe("external");

    // Pat: a partner whose access ended, now on the team.
    const pat = await o.add("Pat", "ops");
    const [ended] = await db
      .insert(schema.externalGrants)
      .values({
        userId: pat,
        invitedEmail: o.email("Pat"),
        organisationId: o.orgId,
        editionId: o.editionId,
        role: "hs",
        invitedBy: o.admin,
        inviteTokenHash: `h-${randomUUID()}`,
        acceptedAt: new Date(Date.now() - 86_400_000),
        expiresAt: new Date(Date.now() - 60_000),
      })
      .returning();
    // Their old partner access can't be extended (only ended)…
    const extend = await refused(
      run((tx) =>
        external.setGrantEndTx(tx, {
          organisationId: o.orgId,
          actorUserId: o.admin,
          grantId: ended.id,
          expiresAt: new Date(Date.now() + 30 * 86_400_000),
        }),
      ),
    );
    expect(extend).toMatch(/on your team now/);
    // …and if they hold live partner access anyway, removal revokes it.
    await db
      .update(schema.externalGrants)
      .set({ expiresAt: null })
      .where(eq(schema.externalGrants.id, ended.id));
    const impact = await manage.getRemovalImpact(db, o.orgId, pat);
    expect(impact!.partnerAccess).toEqual(["Health & safety"]);
    const out = await run((tx) => manage.removeMemberTx(tx, o.ctx, { userId: pat }));
    expect(out.partnerAccessRevoked).toBe(1);
    expect(await actorMod.sessionForUserId(pat)).toBeNull();
    const [g] = await db
      .select()
      .from(schema.externalGrants)
      .where(eq(schema.externalGrants.id, ended.id));
    expect(g.revokedAt).not.toBeNull();
    const audits = await db
      .select()
      .from(schema.auditLog)
      .where(
        and(
          eq(schema.auditLog.entityType, "external_grant"),
          eq(schema.auditLog.entityId, ended.id),
        ),
      );
    expect(audits.map((a) => a.action)).toEqual(["grant_revoke"]);
    void grant;
  });

  it("lifecycle-5: two suspensions at once can't each hand their sign-offs to the other", async () => {
    let concurrentOk = 0;
    for (let i = 0; i < 3; i++) {
      const o = await newOrg();
      const bea = await o.add("Bea", "admin");
      const ali = await o.add("Ali", "ops", { departmentId: o.mkt.id });
      const bob = await o.add("Bob", "ops", { departmentId: o.mkt.id });
      await o.signsFor(ali, "Ali", o.mkt.id, true);
      await o.signsFor(bob, "Bob", o.mkt.id);
      const a = await o.pendingItem(o.mkt.id, ali);
      const b = await o.pendingItem(o.mkt.id, bob);
      const res = await Promise.allSettled([
        run((tx) => manage.suspendMemberTx(tx, o.ctx, { userId: ali })),
        run((tx) =>
          manage.suspendMemberTx(
            tx,
            { organisationId: o.orgId, actorUserId: bea, actorName: "Bea" },
            { userId: bob },
          ),
        ),
      ]);
      // Exactly one goes through; the other is told who must take them over.
      expect(res.filter((r) => r.status === "fulfilled")).toHaveLength(1);
      const rejected = res.find((r) => r.status === "rejected") as PromiseRejectedResult;
      expect(String(rejected.reason.message)).toMatch(/waiting on (Ali|Bob)/);
      const mem = await db
        .select()
        .from(schema.memberships)
        .where(inArray(schema.memberships.userId, [ali, bob]));
      expect(mem.filter((m) => m.suspendedAt != null)).toHaveLength(1);
      // Nobody suspended holds a sign-off.
      const suspended = mem.find((m) => m.suspendedAt != null)!.userId;
      for (const inst of [a.inst, b.inst]) {
        expect((await instance(inst.id)).assignedUserId).not.toBe(suspended);
      }
      concurrentOk++;
    }
    expect(concurrentOk).toBe(3);
  });

  it("regressions-7: who to ask about events is someone with access who holds the ability", async () => {
    const o = await newOrg();
    const { setupContacts } = await import("@/lib/queries/setup");
    await o.add("Sam Suspended", "admin", { suspendedAt: new Date() });
    await o.add("Eve Ended", "ops", { accessEndsAt: new Date(Date.now() - 60_000) });
    await o.add("Olive Ops", "ops");
    await o.add("Nora NoCreate", "ops", { permissionOverrides: { "events.create": false } });
    await o.add("Mark Granted", "marketing", { permissionOverrides: { "events.create": true } });
    await o.add("Max Marketing", "marketing");
    const names = (await setupContacts(o.orgId)).map((c) => c.name);
    // Super admins first; never suspended or ended people; by ability, not role.
    expect(names).toEqual(["Alex", "Mark Granted", "Olive Ops"]);
    // Setting up an event: anyone with one of the setup abilities.
    const setup = (await setupContacts(o.orgId, "event.setup")).map((c) => c.name);
    expect(setup).toContain("Alex");
    expect(setup).toContain("Olive Ops");
    expect(setup).not.toContain("Sam Suspended");
    expect(setup).not.toContain("Eve Ended");
  });

  it("lifecycle-6: the main approver someone else replaces has a row in their access history", async () => {
    const o = await newOrg();
    const mia = await o.add("Mia", "marketing", { departmentId: o.mkt.id });
    const max = await o.add("Max", "marketing", { departmentId: o.mkt.id });
    const edit = (userId: string, fullName: string, isMain: boolean) =>
      run((tx) =>
        manage.updateMemberTx(tx, o.ctx, {
          ...person,
          userId,
          fullName,
          departmentId: o.mkt.id,
          role: "marketing",
          signoffs: [{ departmentId: o.mkt.id, isMain }],
          signoffPaused: false,
        }),
      );
    await edit(mia, "Mia", true);
    await edit(max, "Max", false);
    const before = await history.accessHistory(db, o.orgId, { userId: mia, email: o.email("Mia") });
    await edit(max, "Max", true);
    const [miaRow] = await db
      .select()
      .from(schema.approvers)
      .where(eq(schema.approvers.userId, mia));
    expect(miaRow.isMain).toBe(false);
    const after = await history.accessHistory(db, o.orgId, { userId: mia, email: o.email("Mia") });
    expect(after.length).toBe(before.length + 1);
    expect(after[0]).toMatchObject({
      summary: "Mia is no longer the main approver for Marketing — Max is",
      actorName: "Alex",
    });
  });
});
