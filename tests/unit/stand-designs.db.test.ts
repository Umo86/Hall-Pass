/**
 * The stand-design sign-off workflow against a real database: created once
 * per organisation with one step per department, kept in step when
 * departments change, and never picked as a sign's default workflow.
 */
import { and, eq } from "drizzle-orm";
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
let stands: typeof import("@/lib/domain/stand-designs");
let departments: typeof import("@/lib/domain/departments");
let signage: typeof import("@/lib/domain/signage");
let orgId: string;
let signageWfId: string;
const suffix = Date.now() % 1_000_000;

const stepsOf = (workflowId: string) =>
  db
    .select()
    .from(schema.workflowSteps)
    .where(eq(schema.workflowSteps.workflowId, workflowId))
    .orderBy(schema.workflowSteps.sortOrder);

d("stand design workflow", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    await migrate(db, { migrationsFolder: "lib/db/migrations" });
    stands = await import("@/lib/domain/stand-designs");
    departments = await import("@/lib/domain/departments");
    signage = await import("@/lib/domain/signage");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Stand Org", slug: `stand-${suffix}` })
      .returning();
    orgId = org.id;
    const [wf] = await db
      .insert(schema.workflows)
      .values({ organisationId: orgId, name: "Signage", appliesTo: "signage" })
      .returning();
    signageWfId = wf.id;
    await db.insert(schema.workflowSteps).values({
      workflowId: signageWfId,
      sortOrder: 10,
      name: "Sent to print",
      kind: "confirmation",
      approverType: "role",
      approverRole: "ops",
    });
    await db.insert(schema.departments).values([
      { organisationId: orgId, name: "Operations", sortOrder: 1, defaultFor: ["organiser"] },
      { organisationId: orgId, name: "Marketing", sortOrder: 2, defaultFor: ["organiser"] },
    ]);
  });

  afterAll(async () => {
    await client?.end();
  });

  it("is created once, with one sign-off step per department and nothing else", async () => {
    const first = await db.transaction((tx) => stands.ensureStandDesignWorkflow(tx, orgId));
    const again = await db.transaction((tx) => stands.ensureStandDesignWorkflow(tx, orgId));
    expect(again).toBe(first);
    const steps = await stepsOf(first);
    expect(steps.map((s) => s.name)).toEqual(["Operations sign-off", "Marketing sign-off"]);
    expect(steps.every((s) => s.kind === "approval" && s.departmentId)).toBe(true);
    // The signage workflow keeps its print step and gains the departments too.
    expect((await stepsOf(signageWfId)).map((s) => s.name)).toEqual([
      "Operations sign-off",
      "Marketing sign-off",
      "Sent to print",
    ]);
  });

  it("follows department changes", async () => {
    await db
      .insert(schema.departments)
      .values({ organisationId: orgId, name: "Sales", sortOrder: 3, defaultFor: ["sponsor"] });
    await db.transaction((tx) => departments.syncDepartmentSteps(tx, orgId));
    const wfId = await stands.ensureStandDesignWorkflow(db, orgId);
    expect((await stepsOf(wfId)).map((s) => s.name)).toContain("Sales sign-off");
  });

  it("is never a sign's default workflow", async () => {
    await db
      .update(schema.workflows)
      .set({ isDefault: true })
      .where(
        and(
          eq(schema.workflows.organisationId, orgId),
          eq(schema.workflows.forKind, "stand_design"),
        ),
      );
    expect(await signage.defaultSignageWorkflowId(db, orgId, null)).toBe(signageWfId);
  });
});
