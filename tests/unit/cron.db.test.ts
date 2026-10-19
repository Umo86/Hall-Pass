/**
 * Cron jobs against a real database (TEST_DATABASE_URL): the expected sends
 * happen once, and a second run the same day sends nothing (idempotency via
 * reminder_log). Skips when no test database is configured.
 */
import { randomUUID } from "node:crypto";
import { and, count, eq, gte, ne, sql } from "drizzle-orm";
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
let editionId: string;
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
    editionId = edition.id;
    await db.insert(schema.editionDeadlines).values([
      {
        editionId: edition.id,
        key: "stand_design_due",
        label: "Designs due",
        daysBeforeBuildStart: 42,
      },
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
    // Only this event's sends: other test files add (overdue) work in parallel.
    const sentToday = async () => {
      const rows = await db.execute<{ n: number }>(sql`
        select count(*)::int as n from reminder_log where sent_on = ${TODAY} and target_id in (
          select ai.id from approval_instances ai
            join signage_items si on si.id = ai.entity_id where si.edition_id = ${editionId}
          union select id from signage_items where edition_id = ${editionId}
          union select id from exhibitors where edition_id = ${editionId}
          union select id from documents where edition_id = ${editionId})`);
      return Number(rows[0].n);
    };
    const toOps = async () =>
      (
        await db
          .select({ n: count() })
          .from(schema.notifications)
          .where(
            and(
              eq(schema.notifications.userId, opsUserId),
              // The ops digest goes out on every run by design.
              ne(schema.notifications.kind, "daily_digest"),
            ),
          )
      )[0].n;
    const before = await sentToday();
    const notesBefore = await toOps();
    await jobs.runDailyJobs(TODAY);
    expect(await sentToday()).toBe(before);
    // Nobody here is told anything twice (reminders, overdue digest, escalation).
    expect(await toOps()).toBe(notesBefore);
    // Still exactly one chaser email in the log.
    const [{ n }] = await db
      .select({ n: count() })
      .from(schema.emailLog)
      .where(eq(schema.emailLog.toEmail, EXHIBITOR_EMAIL));
    expect(Number(n)).toBe(1);
  });

  it("chases artwork a week and two days ahead, on the day, then weekly", () => {
    const days = Array.from({ length: 30 }, (_, i) => 10 - i).filter(jobs.artworkChaseDay);
    expect(days).toEqual([7, 2, 0, -7, -14]);
  });

  it("date reminders: install date today → owner and ops told once", async () => {
    const [item] = await db
      .insert(schema.signageItems)
      .values({
        editionId,
        ref: `SIG-DATE-${Date.now() % 100000}`,
        seq: 900,
        name: "Install today",
        ownerUserId: opsUserId,
        status: "delivered",
        installDate: TODAY,
        createdBy: opsUserId,
      })
      .returning();
    const first = await jobs.dateReminders(TODAY);
    expect(first.sent).toBeGreaterThanOrEqual(1);
    const logged = await db
      .select()
      .from(schema.reminderLog)
      .where(
        and(eq(schema.reminderLog.targetId, item.id), eq(schema.reminderLog.kind, "install_due")),
      );
    expect(logged).toHaveLength(1);
    const notes = await db
      .select()
      .from(schema.notifications)
      .where(
        and(
          eq(schema.notifications.entityId, item.id),
          eq(schema.notifications.kind, "date_reminder"),
        ),
      );
    expect(notes.length).toBeGreaterThanOrEqual(1);
    expect(notes[0].title).toMatch(/^Install today: /);
    const second = await jobs.dateReminders(TODAY);
    expect(second.sent).toBe(0);
  });

  it("task reminders go out once per person per day", async () => {
    await db.insert(schema.tasks).values({
      organisationId: (await db.select().from(schema.organisations).limit(1))[0].id,
      title: "Cron test task",
      dueDate: TODAY,
      assignedToUserId: opsUserId,
      createdByUserId: opsUserId,
    });
    const first = await jobs.taskReminders(TODAY);
    expect(first.sent).toBeGreaterThanOrEqual(1);
    const second = await jobs.taskReminders(TODAY);
    expect(second.sent).toBe(0);
  });

  it("overdue sign-offs come as one digest per person a day, not one per item", async () => {
    const day = "2027-08-26";
    const digests = () =>
      db
        .select()
        .from(schema.notifications)
        .where(
          and(
            eq(schema.notifications.userId, opsUserId),
            eq(schema.notifications.kind, "approval_reminder"),
          ),
        );
    const before = await digests();
    await jobs.approvalReminders(day);
    const after = await digests();
    const added = after.filter((a) => !before.some((b) => b.id === a.id));
    expect(added.map((a) => a.title)).toEqual(["You have 1 sign-off overdue (5 days)"]);
    expect(added[0].link).toBe("/approvals?overdue=1");
    expect(added[0].body).toMatch(/^SIG-CRN\d+-001\. Open Approvals/);
    // The old per-item "Overdue: …" message is gone.
    expect(after.some((a) => a.title.startsWith("Overdue:"))).toBe(false);
    // Again the same day: nothing new.
    await jobs.approvalReminders(day);
    expect((await digests()).length).toBe(after.length);
  });

  it("reminders before a step is due point at the item", async () => {
    const [inst] = await db
      .select()
      .from(schema.approvalInstances)
      .where(eq(schema.approvalInstances.id, instanceId));
    const [item] = await db
      .insert(schema.signageItems)
      .values({
        editionId,
        ref: `SIG-REM-${Date.now() % 100000}`,
        seq: 901,
        name: "Due in a week",
        ownerUserId: opsUserId,
        status: "in_review",
        currentRunNumber: 1,
        createdBy: opsUserId,
      })
      .returning();
    await db.insert(schema.approvalInstances).values({
      entityType: "signage_item",
      entityId: item.id,
      runNumber: 1,
      workflowStepId: inst.workflowStepId,
      stepNameSnapshot: "Ops technical check",
      stepKindSnapshot: "approval",
      sortOrderSnapshot: 1,
      status: "pending",
      assignedRole: "ops",
      pendingSince: new Date("2027-08-20T09:00:00Z"),
      dueAt: new Date("2027-09-03T09:00:00Z"),
    });
    await jobs.approvalReminders("2027-08-27");
    const [note] = await db
      .select()
      .from(schema.notifications)
      .where(
        and(
          eq(schema.notifications.userId, opsUserId),
          eq(schema.notifications.entityId, item.id),
          eq(schema.notifications.kind, "approval_reminder"),
        ),
      );
    expect(note.title).toBe(`Reminder: Ops technical check on ${item.ref} is due in 7 days`);
    expect(note.entityType).toBe("signage_item");
  });

  it("settles sign-off requests whose step has ended", async () => {
    const [item] = await db
      .insert(schema.signageItems)
      .values({
        editionId,
        ref: `SIG-STALE-${Date.now() % 100000}`,
        seq: 902,
        name: "Already decided",
        ownerUserId: opsUserId,
        status: "approved",
        createdBy: opsUserId,
      })
      .returning();
    const [note] = await db
      .insert(schema.notifications)
      .values({
        userId: opsUserId,
        kind: "approval_requested",
        title: `Please sign off: ${item.ref}`,
        entityType: "signage_item",
        entityId: item.id,
      })
      .returning();
    const res = await jobs.staleApprovalNotifications(TODAY);
    expect(res.sent).toBeGreaterThanOrEqual(1);
    const [after] = await db
      .select()
      .from(schema.notifications)
      .where(eq(schema.notifications.id, note.id));
    expect(after.readAt).not.toBeNull();
    // The overdue step still waiting on ops keeps its requests.
    const [stillOpen] = await db
      .insert(schema.notifications)
      .values({
        userId: opsUserId,
        kind: "approval_requested",
        title: "Please sign off: the overdue one",
        entityType: "signage_item",
        entityId: (
          await db
            .select()
            .from(schema.approvalInstances)
            .where(eq(schema.approvalInstances.id, instanceId))
        )[0].entityId,
      })
      .returning();
    await jobs.staleApprovalNotifications(TODAY);
    const [kept] = await db
      .select()
      .from(schema.notifications)
      .where(eq(schema.notifications.id, stillOpen.id));
    expect(kept.readAt).toBeNull();
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

d("daily cron jobs — events per person", () => {
  // Their own organisation: two events, a limited ops user (Lena, A only) and
  // one without a list (Omar), both asked by role for sign-offs in A and B.
  const DAY = "2027-12-01";
  const sfx = (Date.now() % 100000) + 7;
  let org: string;
  let lena: string;
  let omar: string;
  let refA: string;
  let refB: string;

  beforeAll(async () => {
    client = postgres(url!, { max: 5, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    jobs = await import("@/lib/cron/jobs");
    const [o] = await db
      .insert(schema.organisations)
      .values({ name: "Cron Scope Org", slug: `cron-scope-${sfx}` })
      .returning();
    org = o.id;
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: org, name: "Cron Scope", code: `CSE${sfx}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: org, name: "Cron Scope Venue", code: `CSV${sfx}` })
      .returning();
    const [a, b] = await db
      .insert(schema.editions)
      .values(
        ["A", "B"].map((x) => ({
          eventId: event.id,
          venueId: venue.id,
          name: `Cron Scope ${x}`,
          code: `CS${x}${sfx}`,
          buildStart: "2028-01-10",
          buildEnd: "2028-01-11",
          openStart: "2028-01-12",
          openEnd: "2028-01-13",
          breakdownEnd: "2028-01-14",
        })),
      )
      .returning();
    const person = async (key: string, editionIds: string[] | null) => {
      const id = randomUUID();
      await db.insert(schema.users).values({ id, email: `${key}-${sfx}@cron-scope.test` });
      await db
        .insert(schema.memberships)
        .values({ userId: id, organisationId: org, role: "ops", editionIds });
      return id;
    };
    lena = await person("lena", [a.id]);
    omar = await person("omar", null);
    const [wf] = await db
      .insert(schema.workflows)
      .values({ organisationId: org, name: "Cron Scope WF", appliesTo: "signage" })
      .returning();
    const [step] = await db
      .insert(schema.workflowSteps)
      .values({
        workflowId: wf.id,
        sortOrder: 1,
        name: "Ops check",
        kind: "approval",
        approverType: "role",
        approverRole: "ops",
        conditions: ["always"],
      })
      .returning();
    const refs: string[] = [];
    for (const [i, ed] of [a, b].entries()) {
      const [item] = await db
        .insert(schema.signageItems)
        .values({
          editionId: ed.id,
          ref: `SIG-CS${sfx}-${i + 1}`,
          seq: i + 1,
          name: `Scope sign ${i + 1}`,
          status: "in_review",
          currentRunNumber: 1,
          workflowId: wf.id,
          createdBy: omar,
          ownerUserId: omar,
        })
        .returning();
      refs.push(item.ref);
      await db.insert(schema.approvalInstances).values({
        entityType: "signage_item",
        entityId: item.id,
        runNumber: 1,
        workflowStepId: step.id,
        stepNameSnapshot: "Ops check",
        stepKindSnapshot: "approval",
        sortOrderSnapshot: 1,
        status: "pending",
        assignedRole: "ops",
        pendingSince: new Date("2027-11-20T09:00:00Z"),
        dueAt: new Date("2027-11-25T09:00:00Z"),
      });
      await db.insert(schema.tasks).values({
        organisationId: org,
        editionId: ed.id,
        title: `Scope task ${i + 1}`,
        dueDate: "2027-11-30",
        assignedToUserId: lena,
        createdByUserId: omar,
      });
    }
    await db.insert(schema.tasks).values({
      organisationId: org,
      title: "Scope task, no event",
      dueDate: "2027-11-30",
      assignedToUserId: lena,
      createdByUserId: omar,
    });
    [refA, refB] = refs;
  });

  afterAll(async () => {
    await client?.end();
  });

  const notes = (userId: string, kind: string) =>
    db
      .select()
      .from(schema.notifications)
      .where(and(eq(schema.notifications.userId, userId), eq(schema.notifications.kind, kind)));

  it("approval reminders and the overdue digest skip a limited approver for B", async () => {
    await jobs.approvalReminders(DAY);
    const mine = await notes(lena, "approval_reminder");
    expect(mine.map((r) => r.title)).toEqual(["You have 1 sign-off overdue (6 days)"]);
    expect(mine[0].body).toContain(refA);
    expect(mine[0].body).not.toContain(refB);
    const his = await notes(omar, "approval_reminder");
    expect(his).toHaveLength(1);
    expect(his[0].body).toContain(refB);
  });

  it("dailyDigest per scope: one digest per set of events, about those events only", async () => {
    await jobs.dailyDigest(DAY);
    const mine = await notes(lena, "daily_digest");
    expect(mine.map((r) => r.title)).toEqual(["Daily digest — 1 open sign-offs, 1 overdue"]);
    expect(mine[0].body).not.toContain(refB);
    const his = await notes(omar, "daily_digest");
    expect(his.map((r) => r.title)).toEqual(["Daily digest — 2 open sign-offs, 2 overdue"]);
  });

  it("taskReminders counts only visible tasks", async () => {
    await jobs.taskReminders(DAY);
    const mine = await notes(lena, "task_reminder");
    expect(mine.map((r) => r.title)).toEqual(["You have 2 tasks due or overdue"]);
  });
});
