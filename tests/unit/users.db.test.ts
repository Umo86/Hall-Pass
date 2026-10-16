/**
 * Users against a real database (TEST_DATABASE_URL): inviting someone with
 * a department, sections and sign-off; editing a member; removing a main
 * approver (department steps don't block it, waiting sign-offs are handed
 * over, the step falls back); cancelling an invitation.
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
let claim: typeof import("@/lib/auth/claim-staff-invite");
let orgId: string;
let workflowId: string;
let adminId: string;
let mkt: typeof schema.departments.$inferSelect;
let sales: typeof schema.departments.$inferSelect;
const n = Date.now() % 1_000_000;

type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];
const run = <T>(fn: (tx: Tx) => Promise<T>) => db.transaction(fn);

async function addMember(name: string, role: StaffRole, departmentId?: string) {
  const id = randomUUID();
  await db
    .insert(schema.users)
    .values({ id, email: `${name.toLowerCase()}-${n}@users.test`, fullName: name });
  await db
    .insert(schema.memberships)
    .values({ userId: id, organisationId: orgId, role, departmentId: departmentId ?? null });
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

d("users", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    manage = await import("@/lib/users/manage");
    claim = await import("@/lib/auth/claim-staff-invite");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Users Org", slug: `users-${n}` })
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
    const { syncDepartmentSteps } = await import("@/lib/domain/departments");
    await db.transaction((tx) => syncDepartmentSteps(tx, orgId));
    adminId = await addMember("Alex", "admin");
  });

  afterAll(async () => {
    await client?.end();
  });

  it("invites someone with a department, sections and sign-off; accepting links it all", async () => {
    const email = `sam-${n}@users.test`;
    const out = await run((tx) =>
      manage.inviteUserTx(
        tx,
        { organisationId: orgId, actorUserId: adminId },
        {
          ...person,
          email: ` ${email.toUpperCase()} `,
          fullName: "Sam Smith",
          jobTitle: "Designer",
          departmentId: mkt.id,
          role: "marketing",
          features: ["signage", "signage", "calendar"],
          abilities: { "signage.create": true, "costs.edit": true },
          signoffs: [{ departmentId: mkt.id, isMain: true }],
        },
      ),
    );
    expect(out.departmentName).toBe("Marketing");
    const [invite] = await db
      .select()
      .from(schema.staffInvites)
      .where(eq(schema.staffInvites.id, out.inviteId));
    expect(invite.invitedEmail).toBe(email);
    expect(invite.fullName).toBe("Sam Smith");
    expect(invite.jobTitle).toBe("Designer");
    expect(invite.departmentId).toBe(mkt.id);
    expect(invite.features).toEqual(["signage", "calendar"]);
    // Only the difference from Marketing's defaults is stored.
    expect(invite.permissionOverrides).toEqual({ "costs.edit": true });
    expect(invite.expiresAt).not.toBeNull();

    const [row] = await db
      .select()
      .from(schema.approvers)
      .where(and(eq(schema.approvers.email, email), eq(schema.approvers.departmentId, mkt.id)));
    expect(row.userId).toBeNull();
    expect(row.isMain).toBe(true);
    // No account yet: the step still goes to the whole department.
    expect((await deptStep(mkt.id)).approverUserId).toBeNull();

    const userId = randomUUID();
    await db.insert(schema.users).values({ id: userId, email });
    await claim.claimStaffInvite(invite, userId);
    const [m] = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, userId));
    expect(m.departmentId).toBe(mkt.id);
    expect(m.features).toEqual(["signage", "calendar"]);
    expect(m.jobTitle).toBe("Designer");
    expect((await deptStep(mkt.id)).approverUserId).toBe(userId);
  });

  it("refuses people already on the team and portal accounts", async () => {
    const memberId = await addMember("Olive", "ops");
    const err = await run((tx) =>
      manage.inviteUserTx(
        tx,
        { organisationId: orgId, actorUserId: adminId },
        {
          ...person,
          email: `olive-${n}@users.test`,
          fullName: "Olive",
          departmentId: null,
          role: "ops",
        },
      ),
    ).catch((e) => e);
    expect(err).toBeInstanceOf(manage.UserError);
    expect(err.message).toMatch(/already on the team/);
    expect(err.detail).toEqual({ existingUserId: memberId });

    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Users Show", code: `US${n % 10000}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Users Hall", code: `UH${n % 10000}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Users Show 2027",
        code: `UZ${n % 10000}`,
        buildStart: "2027-01-01",
        buildEnd: "2027-01-02",
        openStart: "2027-01-03",
        openEnd: "2027-01-04",
        breakdownEnd: "2027-01-05",
      })
      .returning();
    await db.insert(schema.externalGrants).values({
      invitedEmail: `venue-${n}@users.test`,
      organisationId: orgId,
      editionId: edition.id,
      role: "venue",
      scopeType: "venue",
      scopeId: venue.id,
      inviteTokenHash: `grant-${n}`,
    });
    const ext = await run((tx) =>
      manage.inviteUserTx(
        tx,
        { organisationId: orgId, actorUserId: adminId },
        {
          ...person,
          email: `venue-${n}@users.test`,
          fullName: "Vee",
          departmentId: null,
          role: "viewer",
        },
      ),
    ).catch((e) => e);
    expect(ext.message).toBe(
      "This email is used by an external portal account (Venue – Users Hall). Use a different email.",
    );
  });

  it("creates a new department as a team with no sign-off step", async () => {
    await run((tx) =>
      manage.inviteUserTx(
        tx,
        { organisationId: orgId, actorUserId: adminId },
        {
          ...person,
          email: `lee-${n}@users.test`,
          fullName: "Lee",
          departmentId: null,
          newDepartmentName: "Events",
          role: "viewer",
        },
      ),
    );
    const [events] = await db
      .select()
      .from(schema.departments)
      .where(
        and(eq(schema.departments.organisationId, orgId), eq(schema.departments.name, "Events")),
      );
    expect(events.signsOff).toBe(false);
    expect(await deptStep(events.id)).toBeUndefined();
    // Signing off for it is refused until sign-off is switched on.
    const err = await run((tx) =>
      manage.inviteUserTx(
        tx,
        { organisationId: orgId, actorUserId: adminId },
        {
          ...person,
          email: `lou-${n}@users.test`,
          fullName: "Lou",
          departmentId: events.id,
          role: "viewer",
          signoffs: [{ departmentId: events.id, isMain: false }],
        },
      ),
    ).catch((e) => e);
    expect(err.message).toMatch(/doesn't sign off artwork/);
  });

  it("edits a member in one audited change and keeps at least one admin", async () => {
    const userId = await addMember("Priya", "sales", sales.id);
    const ctx = { organisationId: orgId, actorUserId: adminId };
    const out = await run((tx) =>
      manage.updateMemberTx(tx, ctx, {
        ...person,
        userId,
        fullName: "Priya Patel",
        jobTitle: "Account manager",
        departmentId: mkt.id,
        role: "marketing",
        features: ["signage", "reports"],
        // Add signage is a Marketing default (not stored); halls is a real difference.
        abilities: { "signage.create": true, "halls.manage": true },
        signoffs: [
          { departmentId: mkt.id, isMain: false },
          { departmentId: sales.id, isMain: true },
        ],
        signoffPaused: false,
      }),
    );
    expect(out.changed).toEqual(
      expect.arrayContaining(["fullName", "jobTitle", "departmentId", "role", "features"]),
    );
    const [m] = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, userId));
    expect(m).toMatchObject({
      role: "marketing",
      departmentId: mkt.id,
      features: ["signage", "reports"],
      jobTitle: "Account manager",
      permissionOverrides: { "halls.manage": true },
    });
    expect((await deptStep(sales.id)).approverUserId).toBe(userId);
    const audits = await db
      .select()
      .from(schema.auditLog)
      .where(and(eq(schema.auditLog.entityType, "membership"), eq(schema.auditLog.entityId, m.id)));
    expect(audits).toHaveLength(1);

    // Taking away sign-off for Sales sends Sales back to the department.
    await run((tx) =>
      manage.updateMemberTx(tx, ctx, {
        ...person,
        userId,
        fullName: "Priya Patel",
        departmentId: mkt.id,
        role: "marketing",
        features: ["signage", "reports"],
        signoffs: [{ departmentId: mkt.id, isMain: false }],
        signoffPaused: true,
      }),
    );
    expect((await deptStep(sales.id)).approverUserId).toBeNull();
    const [after] = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, userId));
    expect(after.permissionOverrides).toEqual({ "approval.decide": false });

    // Someone who isn't a super admin or manager can't change a super admin;
    // a super admin can't change their own role.
    const last = await run((tx) =>
      manage.updateMemberTx(
        tx,
        { organisationId: orgId, actorUserId: userId },
        {
          ...person,
          userId: adminId,
          fullName: "Alex",
          departmentId: null,
          role: "ops",
          signoffPaused: false,
        },
      ),
    ).catch((e) => e);
    expect(last.message).toBe("You can't change this person's access");
    const self = await run((tx) =>
      manage.updateMemberTx(tx, ctx, {
        ...person,
        userId: adminId,
        fullName: "Alex",
        departmentId: null,
        role: "ops",
        signoffPaused: false,
      }),
    ).catch((e) => e);
    expect(self.message).toMatch(/can't change your own role/);
  });

  it("removes a main approver: hands over waiting sign-offs and the step falls back", async () => {
    const dana = await addMember("Dana", "event_director", sales.id);
    const ctx = { organisationId: orgId, actorUserId: adminId, actorName: "Alex" };
    await run((tx) =>
      manage.setSignoffs(
        tx,
        ctx,
        {
          userId: dana,
          email: `dana-${n}@users.test`,
          fullName: "Dana",
          jobTitle: null,
        },
        [{ departmentId: sales.id, isMain: true }],
      ),
    );
    const { syncDepartmentSteps } = await import("@/lib/domain/departments");
    await db.transaction((tx) => syncDepartmentSteps(tx, orgId));
    const step = await deptStep(sales.id);
    expect(step.approverUserId).toBe(dana);

    // A sign-off waiting on Dana by name.
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Removal Show", code: `RS${n % 10000}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Removal Hall", code: `RH${n % 10000}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Removal Show 2027",
        code: `RZ${n % 10000}`,
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
        ref: `SIG-RZ${n}-001`,
        seq: 1,
        name: "Welcome banner",
        ownerUserId: dana,
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
        workflowStepId: step.id,
        stepNameSnapshot: "Sales sign-off",
        stepKindSnapshot: "approval",
        sortOrderSnapshot: 1,
        status: "pending",
        assignedUserId: dana,
        assignedDepartmentId: sales.id,
      })
      .returning();

    const impact = await manage.getRemovalImpact(db, orgId, dana);
    expect(impact).toMatchObject({
      ownedItems: 1,
      waiting: { count: 1, refs: [item.ref] },
      namedSteps: [],
    });
    expect(impact!.departments).toEqual([expect.objectContaining({ name: "Sales", isMain: true })]);

    // Waiting sign-offs need someone to take them over.
    const refused = await run((tx) => manage.removeMemberTx(tx, ctx, { userId: dana })).catch(
      (e) => e,
    );
    expect(refused.message).toMatch(/A sign-off is waiting on Dana/);

    const ops = await addMember("Oscar", "ops");
    const out = await run((tx) =>
      manage.removeMemberTx(tx, ctx, { userId: dana, handToUserId: ops }),
    );
    expect(out).toMatchObject({ items: 1, handedOver: 1 });

    const [moved] = await db
      .select()
      .from(schema.approvalInstances)
      .where(eq(schema.approvalInstances.id, inst.id));
    expect(moved.assignedUserId).toBe(ops);
    expect(moved.delegatedFromUserId).toBe(dana);
    const rows = await db.select().from(schema.approvers).where(eq(schema.approvers.userId, dana));
    expect(rows).toHaveLength(0);
    const fallback = await deptStep(sales.id);
    expect(fallback.approverUserId).toBeNull();
    expect(fallback.approverType).toBe("role");
    const [owner] = await db
      .select()
      .from(schema.signageItems)
      .where(eq(schema.signageItems.id, item.id));
    expect(owner.ownerUserId).toBe(adminId);
    const membership = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, dana));
    expect(membership).toHaveLength(0);
  });

  it("cancelling an invitation drops the sign-offs it would have given", async () => {
    const email = `kai-${n}@users.test`;
    const ctx = { organisationId: orgId, actorUserId: adminId };
    const out = await run((tx) =>
      manage.inviteUserTx(tx, ctx, {
        ...person,
        email,
        fullName: "Kai",
        departmentId: mkt.id,
        role: "marketing",
        signoffs: [{ departmentId: mkt.id, isMain: false }],
      }),
    );
    const before = await db
      .select()
      .from(schema.approvers)
      .where(eq(schema.approvers.email, email));
    expect(before).toHaveLength(1);
    await run((tx) => manage.cancelInviteTx(tx, ctx, out.inviteId));
    const after = await db.select().from(schema.approvers).where(eq(schema.approvers.email, email));
    expect(after).toHaveLength(0);
    const [invite] = await db
      .select()
      .from(schema.staffInvites)
      .where(eq(schema.staffInvites.id, out.inviteId));
    expect(invite.revokedAt).not.toBeNull();
    // A cancelled invitation can't be cancelled or renewed again.
    const again = await run((tx) => manage.renewInviteLinkTx(tx, ctx, out.inviteId)).catch(
      (e) => e,
    );
    expect(again).toBeInstanceOf(manage.UserError);
  });

  it("a fresh link replaces the old one and pushes the expiry out", async () => {
    const ctx = { organisationId: orgId, actorUserId: adminId };
    const out = await run((tx) =>
      manage.inviteUserTx(tx, ctx, {
        ...person,
        email: `rio-${n}@users.test`,
        fullName: "Rio",
        departmentId: null,
        role: "viewer",
      }),
    );
    await db
      .update(schema.staffInvites)
      .set({ expiresAt: new Date(Date.now() - 1000) })
      .where(eq(schema.staffInvites.id, out.inviteId));
    const [old] = await db
      .select()
      .from(schema.staffInvites)
      .where(eq(schema.staffInvites.id, out.inviteId));
    const renewed = await run((tx) => manage.renewInviteLinkTx(tx, ctx, out.inviteId));
    const [now] = await db
      .select()
      .from(schema.staffInvites)
      .where(eq(schema.staffInvites.id, out.inviteId));
    expect(now.inviteTokenHash).not.toBe(old.inviteTokenHash);
    expect(now.expiresAt!.getTime()).toBeGreaterThan(Date.now());
    expect(renewed.inviteUrl).toMatch(/\/invite\//);
  });
});
