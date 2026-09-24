/**
 * Cron jobs against a real database (TEST_DATABASE_URL): the expected sends
 * happen once, and a second run the same day sends nothing (idempotency via
 * reminder_log). Skips when no test database is configured.
 */
import { randomUUID } from "node:crypto";
import { and, count, eq, gte } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "@/lib/db/schema";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);

// The jobs module imports lib/db/client which reads DATABASE_URL, so point
// it at the test database before importing.
if (url) process.env.DATABASE_URL = url;
// Stands are hidden in the product for now; this suite still covers their chasers.
process.env.STANDS_ENABLED = "1";

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let jobs: typeof import("@/lib/cron/jobs");

const TODAY = "2027-08-25";

let opsUserId: string;
const EXHIBITOR_EMAIL = `exhibitor-${Date.now()}@cron.test`;
let instanceId: string;
let exhibitorId: string;

d("daily cron jobs", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 5, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    await migrate(db, { migrationsFolder: "lib/db/migrations" });
    jobs = await import("@/lib/cron/jobs");

    const suffix = Date.now() % 100000;
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Cron Org", slug: `cron-${suffix}` })
      .returning();
    opsUserId = randomUUID();
    await db.insert(schema.users).values({ id: opsUserId, email: `cron-ops-${suffix}@test.dev` });
    await db
      .insert(schema.memberships)
      .values({ userId: opsUserId, organisationId: org.id, role: "ops" });
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: org.id, name: "Cron Event", code: `CE${suffix}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: org.id, name: "Cron Venue", code: `CV${suffix}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Cron Edition",
        code: `CRN${suffix}`,
        buildStart: "2027-10-01",
        buildEnd: "2027-10-04",
        openStart: "2027-10-05",
        openEnd: "2027-10-07",
        breakdownEnd: "2027-10-08",
      })
      .returning();
    await db.insert(schema.editionDeadlines).values([
      { editionId: edition.id, key: "stand_design_due", label: "Designs due", daysBeforeBuildStart: 42 },
      { editionId: edition.id, key: "artwork_due", label: "Artwork due", daysBeforeBuildStart: 21 },
    ]);
    // stand_design_due = 2027-08-20 → 5 days overdue on TODAY? diff = -5, not
    // a weekly multiple; use an exhibitor whose chase lands exactly on TODAY:
    // overdue by 7 (due 2027-08-18) is impossible per edition; instead the
    // "due in 14 days" window is not today either, so create a second edition
    // deadline override to hit due-0 exactly.
    await db
      .update(schema.editionDeadlines)
      .set({ overrideDate: TODAY })
      .where(
        and(
          eq(schema.editionDeadlines.editionId, edition.id),
          eq(schema.editionDeadlines.key, "stand_design_due"),
        ),
      );

    // A workflow step to satisfy the FK on approval instances.
    const [wf] = await db
      .insert(schema.workflows)
      .values({ organisationId: org.id, name: `Cron WF ${suffix}`, appliesTo: "signage" })
      .returning();
    const [step] = await db
      .insert(schema.workflowSteps)
      .values({
        workflowId: wf.id,
        sortOrder: 1,
        name: "Ops technical check",
        kind: "approval",
        approverType: "role",
        approverRole: "ops",
        conditions: ["always"],
        slaDays: 3,
      })
      .returning();

    // An overdue pending instance on a signage item (due 4 days ago →
    // overdue reminder AND escalation at the default 2-day threshold).
    const [item] = await db
      .insert(schema.signageItems)
      .values({
        editionId: edition.id,
        ref: `SIG-CRN${suffix}-001`,
        seq: 1,
        name: "Cron item",
        ownerUserId: opsUserId,
        status: "in_review",
        workflowId: wf.id,
        currentRunNumber: 1,
        createdBy: opsUserId,
      })
      .returning();
    const [inst] = await db
      .insert(schema.approvalInstances)
      .values({
        entityType: "signage_item",
        entityId: item.id,
        runNumber: 1,
        workflowStepId: step.id,
        stepNameSnapshot: "Ops technical check",
        stepKindSnapshot: "approval",
        sortOrderSnapshot: 1,
        status: "pending",
        assignedRole: "ops",
        pendingSince: new Date("2027-08-18T09:00:00Z"),
        dueAt: new Date("2027-08-21T09:00:00Z"),
      })
      .returning();
    instanceId = inst.id;

    // A space-only exhibitor with nothing submitted (chased at due-0 = TODAY).
    const [exhibitor] = await db
      .insert(schema.exhibitors)
      .values({
        editionId: edition.id,
        companyName: "Cron Exhibitor",
        standNumber: `Z${suffix}`,
        standType: "space_only",
        contactEmail: EXHIBITOR_EMAIL,
      })
      .returning();
    exhibitorId = exhibitor.id;

    // An insurance document expiring before build end.
    await db.insert(schema.documents).values({
      organisationId: org.id,
      editionId: edition.id,
      entityType: "stand_submission",
      entityId: randomUUID(),
      docType: "insurance_pl",
      filePath: "cron/insurance.pdf",
      fileName: "insurance.pdf",
      mimeType: "application/pdf",
      fileSize: 10,
      sha256: "0".repeat(64),
      expiresAt: "2027-09-15",
    });
  });

  afterAll(async () => {
    await client?.end();
  });

  it("first run sends the expected reminders, chasers, escalation and expiry flags", async () => {
    const results = await jobs.runDailyJobs(TODAY);
    const byJob = Object.fromEntries(results.map((r) => [r.job, r]));

    expect(byJob.approval_reminders.sent).toBeGreaterThanOrEqual(1); // our overdue instance
    expect(byJob.escalation.sent).toBeGreaterThanOrEqual(1);
    expect(byJob.stand_chasers.sent).toBeGreaterThanOrEqual(1);
    expect(byJob.document_expiry.sent).toBeGreaterThanOrEqual(1);

    // Escalation is recorded on the instance.
    const [inst] = await db
      .select()
      .from(schema.approvalInstances)
      .where(eq(schema.approvalInstances.id, instanceId));
    expect(inst.escalatedAt).not.toBeNull();

    // The chaser email hit email_log for the exhibitor contact.
    const [{ n }] = await db
      .select({ n: count() })
      .from(schema.emailLog)
      .where(eq(schema.emailLog.toEmail, EXHIBITOR_EMAIL));
    expect(Number(n)).toBe(1);
  });

  it("a second run the same day sends nothing new", async () => {
    const before = await db.select({ n: count() }).from(schema.reminderLog);
    const results = await jobs.runDailyJobs(TODAY);
    const after = await db.select({ n: count() }).from(schema.reminderLog);
    expect(Number(after[0].n)).toBe(Number(before[0].n));
    const relevant = results.filter((r) =>
      ["approval_reminders", "escalation", "stand_chasers", "document_expiry"].includes(r.job),
    );
    for (const r of relevant) {
      expect(r.sent, r.job).toBe(0);
    }
    // Still exactly one chaser email in the log.
    const [{ n }] = await db
      .select({ n: count() })
      .from(schema.emailLog)
      .where(eq(schema.emailLog.toEmail, EXHIBITOR_EMAIL));
    expect(Number(n)).toBe(1);
  });

  it("reminder_log rows exist for the instance and exhibitor", async () => {
    const rows = await db
      .select()
      .from(schema.reminderLog)
      .where(gte(schema.reminderLog.sentOn, TODAY));
    const targets = rows.map((r) => `${r.targetType}:${r.kind}`);
    expect(targets).toContain("approval_instance:overdue");
    expect(targets).toContain("approval_instance:escalation");
    expect(targets).toContain("exhibitor:chaser");
    expect(targets).toContain("document:expiry");
    void exhibitorId;
  });
});
