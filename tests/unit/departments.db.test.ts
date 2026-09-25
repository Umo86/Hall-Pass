/**
 * Departments and approvers against a real database (TEST_DATABASE_URL):
 * each department gets its sign-off step in the right place, the main
 * approver becomes the step's default person once they have an account,
 * and an invited approver is linked when they accept.
 */
import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "@/lib/db/schema";
import { defaultSignageSteps } from "@/lib/workflow";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let departments: typeof import("@/lib/domain/departments");
let invites: typeof import("@/lib/auth/claim-staff-invite");
let orgId: string;
let workflowId: string;
const suffix = Date.now() % 1_000_000;

async function signageSteps() {
  return db
    .select()
    .from(schema.workflowSteps)
    .where(eq(schema.workflowSteps.workflowId, workflowId))
    .orderBy(schema.workflowSteps.sortOrder);
}

d("departments and approvers", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    await migrate(db, { migrationsFolder: "lib/db/migrations" });
    departments = await import("@/lib/domain/departments");
    invites = await import("@/lib/auth/claim-staff-invite");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Dept Org", slug: `dept-${suffix}` })
      .returning();
    orgId = org.id;
    const [wf] = await db
      .insert(schema.workflows)
      .values({ organisationId: orgId, name: "Signage", appliesTo: "signage", isDefault: true })
      .returning();
    workflowId = wf.id;
    // Venue approval and the confirmations; departments are added below.
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
  });

  afterAll(async () => {
    await client?.end();
  });

  it("adds a step per department, in order, named after it", async () => {
    await db.insert(schema.departments).values([
      { organisationId: orgId, name: "Marketing", sortOrder: 1, defaultFor: ["organiser", "sponsor"] },
      { organisationId: orgId, name: "Legal", sortOrder: 2, defaultFor: [] },
      { organisationId: orgId, name: "Directors", sortOrder: 3, signsLast: true, defaultFor: ["sponsor"] },
    ]);
    await db.transaction((tx) => departments.syncDepartmentSteps(tx, orgId));

    const steps = await signageSteps();
    expect(steps.map((s) => s.name)).toEqual([
      "Marketing sign-off",
      "Legal sign-off",
      "Venue approval",
      "Directors sign-off",
      "Sent to print",
      "Delivered",
      "Installed",
    ]);
    const marketing = steps.find((s) => s.name === "Marketing sign-off")!;
    expect(marketing.parallelGroup).toBe(1);
    expect(marketing.defaultFor).toEqual(["organiser", "sponsor"]);
    expect(marketing.approverType).toBe("role");
    expect(marketing.approverRole).toBeNull();
  });

  it("the main approver becomes the default person once they join", async () => {
    const [mkt] = await db
      .select()
      .from(schema.departments)
      .where(and(eq(schema.departments.organisationId, orgId), eq(schema.departments.name, "Marketing")));
    const email = `maya-${suffix}@dept.test`;
    await db.insert(schema.approvers).values({
      organisationId: orgId,
      departmentId: mkt.id,
      fullName: "Maya Marketing",
      jobTitle: "Head of Marketing",
      email,
      isMain: true,
    });
    await db.insert(schema.staffInvites).values({
      organisationId: orgId,
      invitedEmail: email,
      role: "viewer",
      inviteTokenHash: `dept-${suffix}`,
    });
    await db.transaction((tx) => departments.syncDepartmentSteps(tx, orgId));
    // Not joined yet: the step still goes to anyone in Marketing.
    let step = (await signageSteps()).find((s) => s.departmentId === mkt.id)!;
    expect(step.approverUserId).toBeNull();

    const userId = randomUUID();
    await db.insert(schema.users).values({ id: userId, email });
    const invite = await invites.openStaffInviteFor(email);
    await invites.claimStaffInvite(invite!, userId, "Maya Marketing");

    const [approver] = await db
      .select()
      .from(schema.approvers)
      .where(eq(schema.approvers.email, email));
    expect(approver.userId).toBe(userId);
    step = (await signageSteps()).find((s) => s.departmentId === mkt.id)!;
    expect(step.approverType).toBe("user");
    expect(step.approverUserId).toBe(userId);

    expect(await departments.departmentIdsForUser(db, orgId, userId)).toEqual([mkt.id]);
    expect(await departments.departmentSignerIds(db, orgId, mkt.id)).toEqual([userId]);
  });

  it("removing a department archives its step", async () => {
    const [legal] = await db
      .update(schema.departments)
      .set({ isArchived: true })
      .where(and(eq(schema.departments.organisationId, orgId), eq(schema.departments.name, "Legal")))
      .returning();
    await db.transaction((tx) => departments.syncDepartmentSteps(tx, orgId));
    const all = await signageSteps();
    expect(all.find((s) => s.departmentId === legal.id)!.isArchived).toBe(true);
    const live = all.filter((s) => !s.isArchived).map((s) => s.name);
    expect(live[0]).toBe("Marketing sign-off");
    expect(live).not.toContain("Legal sign-off");
  });
});
