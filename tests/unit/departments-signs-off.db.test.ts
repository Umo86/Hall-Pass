/**
 * Departments that don't sign off, and the signage workflow a brand-new
 * organisation gets, against a real database (TEST_DATABASE_URL).
 */
import { and, eq, isNull } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "@/lib/db/schema";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let departments: typeof import("@/lib/domain/departments");
const suffix = Date.now() % 1_000_000;

async function newOrg(name: string) {
  const [org] = await db
    .insert(schema.organisations)
    .values({ name, slug: `${name.toLowerCase().replace(/\W+/g, "-")}-${suffix}` })
    .returning();
  return org.id;
}

async function liveSteps(orgId: string) {
  const [flow] = await db
    .select()
    .from(schema.workflows)
    .where(
      and(
        eq(schema.workflows.organisationId, orgId),
        eq(schema.workflows.appliesTo, "signage"),
        isNull(schema.workflows.forKind),
      ),
    );
  const steps = await db
    .select()
    .from(schema.workflowSteps)
    .where(eq(schema.workflowSteps.workflowId, flow.id))
    .orderBy(schema.workflowSteps.sortOrder);
  return steps.filter((s) => !s.isArchived);
}

d("departments that sign off, and the starter workflow", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    await migrate(db, { migrationsFolder: "lib/db/migrations" });
    departments = await import("@/lib/domain/departments");
  });

  afterAll(async () => {
    await client?.end();
  });

  it("a new organisation gets a signage workflow with confirmations and its departments", async () => {
    const orgId = await newOrg("Starter Org");
    await db
      .insert(schema.departments)
      .values([
        { organisationId: orgId, name: "Marketing", sortOrder: 1, defaultFor: ["organiser"] },
      ]);
    const id1 = await db.transaction((tx) => departments.ensureSignageWorkflow(tx, orgId));
    const id2 = await db.transaction((tx) => departments.ensureSignageWorkflow(tx, orgId));
    expect(id2).toBe(id1); // only ever one
    const names = (await liveSteps(orgId)).map((s) => s.name);
    expect(names).toEqual([
      "Marketing sign-off",
      "Venue approval",
      "Sent to print",
      "Delivered",
      "Installed",
    ]);
  });

  it("a department that doesn't sign off has no live step, and gets one when switched on", async () => {
    const orgId = await newOrg("Teams Org");
    const [finance] = await db
      .insert(schema.departments)
      .values({ organisationId: orgId, name: "Finance", sortOrder: 1, signsOff: false })
      .returning();
    await db.insert(schema.departments).values({
      organisationId: orgId,
      name: "Marketing",
      sortOrder: 2,
      defaultFor: ["organiser"],
    });
    await db.transaction((tx) => departments.ensureSignageWorkflow(tx, orgId));
    expect((await liveSteps(orgId)).map((s) => s.name)).not.toContain("Finance sign-off");

    await db
      .update(schema.departments)
      .set({ signsOff: true })
      .where(eq(schema.departments.id, finance.id));
    await db.transaction((tx) => departments.syncDepartmentSteps(tx, orgId));
    expect((await liveSteps(orgId)).map((s) => s.name)).toContain("Finance sign-off");

    await db
      .update(schema.departments)
      .set({ signsOff: false })
      .where(eq(schema.departments.id, finance.id));
    await db.transaction((tx) => departments.syncDepartmentSteps(tx, orgId));
    expect((await liveSteps(orgId)).map((s) => s.name)).not.toContain("Finance sign-off");
  });
});
