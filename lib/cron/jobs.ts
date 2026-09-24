import { appUrl } from "@/lib/app-url";
import "server-only";
import { and, count, eq, gte, inArray, isNull, sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  approvalInstances,
  auditLog,
  documents,
  editions,
  exhibitors,
  memberships,
  organisations,
  reminderLog,
  signageItems,
  standSubmissions,
} from "@/lib/db/schema";
import { artworkDue, diffDaysIso, standDesignDue } from "@/lib/deadlines";
import { editionForDeadlines } from "@/lib/queries/editions";
import { notify } from "@/lib/notify";
import { sendEmail } from "@/lib/email/send";
import { renderNotificationEmail } from "@/lib/email/template";
import { brandName, standsEnabled } from "@/lib/config";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { writeAudit } from "@/lib/audit";

export type JobResult = { job: string; sent: number; skipped: number };

type ReminderTarget = "approval_instance" | "signage_item" | "exhibitor" | "document";
type ReminderKind = "minus7" | "minus2" | "due" | "overdue" | "escalation" | "chaser" | "expiry";

/** Record a send; returns false when it already happened (idempotency). */
async function recordSend(
  targetType: ReminderTarget,
  targetId: string,
  kind: ReminderKind,
  today: string,
): Promise<boolean> {
  const rows = await db
    .insert(reminderLog)
    .values({ targetType, targetId, kind, sentOn: today })
    .onConflictDoNothing()
    .returning();
  return rows.length > 0;
}

async function staffUserIdsByRoles(organisationId: string, roles: ("admin" | "ops")[]) {
  const rows = await db
    .select({ userId: memberships.userId })
    .from(memberships)
    .where(and(eq(memberships.organisationId, organisationId), inArray(memberships.role, roles)));
  return rows.map((r) => r.userId);
}

type PendingRow = {
  instance: typeof approvalInstances.$inferSelect;
  ref: string;
  link: string;
  editionId: string;
  organisationId: string;
  ownerUserId: string | null;
  assigneeIds: string[];
};

/** Pending instances joined to their entity, with resolved assignees. */
async function pendingWithContext(): Promise<PendingRow[]> {
  const pending = await db
    .select()
    .from(approvalInstances)
    .where(eq(approvalInstances.status, "pending"));
  const out: PendingRow[] = [];
  for (const instance of pending) {
    if (instance.entityType === "signage_item") {
      const { loadItemBundle, resolveAssigneeUserIds } = await import("@/lib/domain/signage");
      const bundle = await loadItemBundle(db, instance.entityId);
      if (!bundle) continue;
      // Deleted, held and archived items take no reminders or escalations.
      if (bundle.item.deletedAt || bundle.item.status === "on_hold") continue;
      if (editionIsReadOnly(bundle.edition.status)) continue;
      out.push({
        instance,
        ref: bundle.item.ref,
        link: `/${bundle.edition.code}/signage/${bundle.item.ref}?tab=approvals`,
        editionId: bundle.edition.id,
        organisationId: bundle.organisation.id,
        ownerUserId: bundle.item.ownerUserId,
        assigneeIds: await resolveAssigneeUserIds(
          db,
          bundle.organisation.id,
          bundle.edition.id,
          bundle.venue.id,
          bundle.item,
          instance,
        ),
      });
    } else {
      if (!standsEnabled) continue;
      const { loadStandBundle } = await import("@/lib/domain/stand");
      const { resolveAssigneeUserIds } = await import("@/lib/domain/signage");
      const bundle = await loadStandBundle(db, instance.entityId);
      if (!bundle) continue;
      out.push({
        instance,
        ref: bundle.sub.ref,
        link: `/${bundle.edition.code}/stands/${bundle.sub.ref}`,
        editionId: bundle.edition.id,
        organisationId: bundle.organisation.id,
        ownerUserId: bundle.sub.createdBy,
        assigneeIds: await resolveAssigneeUserIds(
          db,
          bundle.organisation.id,
          bundle.edition.id,
          bundle.venue.id,
          null,
          instance,
        ),
      });
    }
  }
  return out;
}

/** Job 1 — approval reminders at due−7, due−2, due, then daily overdue (cap 10). */
export async function approvalReminders(today: string): Promise<JobResult> {
  let sent = 0;
  let skipped = 0;
  const rows = await pendingWithContext();
  for (const row of rows) {
    const { instance } = row;
    if (!instance.dueAt) continue;
    const dueIso = instance.dueAt.toISOString().slice(0, 10);
    const diff = diffDaysIso(dueIso, today); // positive = due in the future
    let kind: ReminderKind | null = null;
    if (diff === 7) kind = "minus7";
    else if (diff === 2) kind = "minus2";
    else if (diff === 0) kind = "due";
    else if (diff < 0) kind = "overdue";
    if (!kind) continue;

    if (kind === "overdue") {
      const [{ n }] = await db
        .select({ n: count() })
        .from(reminderLog)
        .where(
          and(
            eq(reminderLog.targetType, "approval_instance"),
            eq(reminderLog.targetId, instance.id),
            eq(reminderLog.kind, "overdue"),
          ),
        );
      if (Number(n) >= 10) {
        skipped++;
        continue;
      }
    }
    if (!(await recordSend("approval_instance", instance.id, kind, today))) {
      skipped++;
      continue;
    }
    await db.transaction(async (tx) => {
      await notify(tx, {
        userIds: row.assigneeIds,
        kind: "approval_reminder",
        title:
          kind === "overdue"
            ? `Overdue: ${instance.stepNameSnapshot} on ${row.ref}`
            : `Reminder: ${instance.stepNameSnapshot} on ${row.ref} is due ${
                kind === "due" ? "today" : kind === "minus2" ? "in 2 days" : "in 7 days"
              }`,
        body: `The ${instance.stepNameSnapshot} step is waiting on you.`,
        link: row.link,
      });
    });
    sent++;
  }
  return { job: "approval_reminders", sent, skipped };
}

/** Job 2 — escalation of instances overdue by escalate_after_days. */
export async function escalation(today: string): Promise<JobResult> {
  let sent = 0;
  let skipped = 0;
  const rows = await pendingWithContext();
  for (const row of rows) {
    const { instance } = row;
    if (!instance.dueAt || instance.escalatedAt) continue;
    const dueIso = instance.dueAt.toISOString().slice(0, 10);
    const overdueDays = -diffDaysIso(dueIso, today);
    const [org] = await db
      .select()
      .from(organisations)
      .where(eq(organisations.id, row.organisationId));
    const threshold = org?.settings.escalate_after_days ?? 2;
    if (overdueDays < threshold) continue;
    if (!(await recordSend("approval_instance", instance.id, "escalation", today))) {
      skipped++;
      continue;
    }
    const admins = await staffUserIdsByRoles(row.organisationId, ["admin"]);
    const recipients = [...new Set([...admins, ...(row.ownerUserId ? [row.ownerUserId] : [])])];
    await db.transaction(async (tx) => {
      await tx
        .update(approvalInstances)
        .set({ escalatedAt: new Date(), escalatedTo: recipients })
        .where(eq(approvalInstances.id, instance.id));
      await notify(tx, {
        userIds: recipients,
        kind: "escalation",
        title: `Escalated: ${instance.stepNameSnapshot} on ${row.ref} is ${overdueDays} days overdue`,
        body: `Assigned to ${instance.assignedRole ?? "a named user"}; no decision since ${dueIso}.`,
        link: row.link,
      });
      await writeAudit(tx, {
        organisationId: row.organisationId,
        editionId: row.editionId,
        actorType: "cron",
        entityType: instance.entityType,
        entityId: instance.entityId,
        action: "escalate",
        summary: `${instance.stepNameSnapshot} on ${row.ref} escalated after ${overdueDays} days overdue`,
      });
    });
    sent++;
  }
  return { job: "escalation", sent, skipped };
}

/** Job 3 — missing artwork chasers for draft/awaiting items near or past due. */
export async function missingArtwork(today: string): Promise<JobResult> {
  let sent = 0;
  let skipped = 0;
  const items = await db
    .select()
    .from(signageItems)
    .where(
      and(
        inArray(signageItems.status, ["draft", "awaiting_artwork"]),
        isNull(signageItems.deletedAt),
      ),
    );
  const deadlineCache = new Map<string, Awaited<ReturnType<typeof editionForDeadlines>>>();
  for (const item of items) {
    if (!item.ownerUserId) continue;
    if (!deadlineCache.has(item.editionId)) {
      deadlineCache.set(item.editionId, await editionForDeadlines(item.editionId));
    }
    const ed = deadlineCache.get(item.editionId);
    if (!ed) continue;
    const due = artworkDue({ artworkDueOverride: item.artworkDueOverride }, ed);
    if (!due) continue;
    const diff = diffDaysIso(due, today);
    if (diff > 7) continue; // not yet in the window
    if (!(await recordSend("signage_item", item.id, "chaser", today))) {
      skipped++;
      continue;
    }
    await db.transaction(async (tx) => {
      await notify(tx, {
        userIds: [item.ownerUserId!],
        kind: "artwork_chaser",
        title:
          diff < 0
            ? `Artwork overdue: ${item.ref} (due ${due})`
            : `Artwork due ${diff === 0 ? "today" : `in ${diff} days`}: ${item.ref}`,
        body: `${item.name} has no artwork yet.`,
        entityType: "signage_item",
        entityId: item.id,
      });
    });
    sent++;
  }
  return { job: "missing_artwork", sent, skipped };
}

/** Job 4 — stand design chasers for space-only exhibitors not yet submitted. */
export async function standChasers(today: string): Promise<JobResult> {
  let sent = 0;
  let skipped = 0;
  const rows = await db
    .select({ exhibitor: exhibitors, sub: standSubmissions, edition: editions })
    .from(exhibitors)
    .innerJoin(editions, eq(exhibitors.editionId, editions.id))
    .leftJoin(standSubmissions, eq(standSubmissions.exhibitorId, exhibitors.id))
    .where(eq(exhibitors.standType, "space_only"));

  const deadlineCache = new Map<string, Awaited<ReturnType<typeof editionForDeadlines>>>();
  for (const row of rows) {
    const status = row.sub?.status ?? "not_submitted";
    if (status !== "not_submitted") continue;
    if (!deadlineCache.has(row.edition.id)) {
      deadlineCache.set(row.edition.id, await editionForDeadlines(row.edition.id));
    }
    const ed = deadlineCache.get(row.edition.id);
    if (!ed) continue;
    const due = standDesignDue(ed);
    if (!due) continue;
    const diff = diffDaysIso(due, today);
    const shouldChase =
      diff === 14 || diff === 7 || diff === 2 || diff === 0 || (diff < 0 && -diff % 7 === 0);
    if (!shouldChase) continue;
    if (!(await recordSend("exhibitor", row.exhibitor.id, "chaser", today))) {
      skipped++;
      continue;
    }
    const subject =
      diff < 0
        ? `Stand design overdue — ${row.edition.name} (stand ${row.exhibitor.standNumber})`
        : `Stand design due ${diff === 0 ? "today" : `in ${diff} days`} — ${row.edition.name}`;
    const bodyText = `Your stand design for ${row.edition.name} (stand ${row.exhibitor.standNumber}) has not been submitted. Designs were due ${due}. Submit plans, elevations, RAMS and insurance through the portal.`;
    const base = appUrl();
    const { html, text } = await renderNotificationEmail({
      brandName,
      title: subject,
      bodyText,
      ctaLabel: "Open the exhibitor portal",
      ctaUrl: `${base}/portal/submission`,
    });
    const recipients = [row.exhibitor.contactEmail].filter((x): x is string => Boolean(x));
    if (row.exhibitor.contractorId) {
      const [contractor] = await db.execute<{ email: string | null }>(
        sql`SELECT email FROM contractors WHERE id = ${row.exhibitor.contractorId}`,
      );
      if (contractor?.email) recipients.push(contractor.email);
    }
    for (const to of recipients) {
      await sendEmail({
        to,
        subject,
        html,
        text,
        template: "stand_chaser",
        entityType: "exhibitor",
        entityId: row.exhibitor.id,
      });
    }
    // Copy ops in-app.
    const orgId = (
      await db.execute<{ organisation_id: string }>(
        sql`SELECT organisation_id FROM venues WHERE id = ${row.edition.venueId}`,
      )
    )[0]?.organisation_id;
    if (orgId) {
      const ops = await staffUserIdsByRoles(orgId, ["ops"]);
      await db.transaction(async (tx) => {
        await notify(tx, {
          userIds: ops,
          kind: "stand_chaser_copy",
          title: `Chased: ${row.exhibitor.companyName} (stand ${row.exhibitor.standNumber})`,
          body: subject,
          link: `/${row.edition.code}/stands`,
        });
      });
    }
    sent++;
  }
  return { job: "stand_chasers", sent, skipped };
}

/** Job 5 — insurance documents expiring before the edition's build end. */
export async function documentExpiry(today: string): Promise<JobResult> {
  let sent = 0;
  let skipped = 0;
  const docs = await db
    .select({ doc: documents, edition: editions })
    .from(documents)
    .innerJoin(editions, eq(documents.editionId, editions.id))
    .where(eq(documents.docType, "insurance_pl"));
  for (const { doc, edition } of docs) {
    if (!doc.expiresAt || doc.expiresAt >= edition.buildEnd) continue;
    // Once per document, ever.
    const existing = await db
      .select()
      .from(reminderLog)
      .where(
        and(
          eq(reminderLog.targetType, "document"),
          eq(reminderLog.targetId, doc.id),
          eq(reminderLog.kind, "expiry"),
        ),
      );
    if (existing.length > 0) {
      skipped++;
      continue;
    }
    await recordSend("document", doc.id, "expiry", today);
    const orgId = doc.organisationId;
    const ops = await staffUserIdsByRoles(orgId, ["ops", "admin"]);
    await db.transaction(async (tx) => {
      await notify(tx, {
        userIds: ops,
        kind: "document_expiry",
        title: `Insurance expires before the show: ${doc.fileName}`,
        body: `Expires ${doc.expiresAt} — build ends ${edition.buildEnd}.`,
        link: `/${edition.code}/stands`,
      });
    });
    sent++;
  }
  return { job: "document_expiry", sent, skipped };
}

/** Job 6 — daily digest to ops and admin; skipped when nothing is happening. */
export async function dailyDigest(today: string): Promise<JobResult> {
  let sent = 0;
  const orgs = await db.select().from(organisations);
  for (const org of orgs) {
    const pending = await pendingWithContext();
    const orgPending = pending.filter((p) => p.organisationId === org.id);
    const overdue = orgPending.filter(
      (p) => p.instance.dueAt && p.instance.dueAt.toISOString().slice(0, 10) < today,
    );
    const yesterday = new Date(new Date(`${today}T00:00:00Z`).getTime() - 86_400_000);
    const [{ n: activity }] = await db
      .select({ n: count() })
      .from(auditLog)
      .where(and(eq(auditLog.organisationId, org.id), gte(auditLog.createdAt, yesterday)));
    if (Number(activity) === 0 && overdue.length === 0) continue; // nothing to say

    const recipients = await staffUserIdsByRoles(org.id, ["ops", "admin"]);
    const title = `Daily digest — ${orgPending.length} open sign-offs, ${overdue.length} overdue`;
    const body = [
      `Open sign-offs: ${orgPending.length}`,
      `Overdue: ${overdue.length}`,
      overdue
        .slice(0, 5)
        .map((o) => ` · ${o.ref} — ${o.instance.stepNameSnapshot}`)
        .join("\n"),
      `Activity in the last day: ${activity} change(s)`,
    ]
      .filter(Boolean)
      .join("\n");
    await db.transaction(async (tx) => {
      await notify(tx, {
        userIds: recipients,
        kind: "daily_digest",
        title,
        body,
        link: "/approvals",
      });
    });
    sent++;
  }
  return { job: "daily_digest", sent, skipped: 0 };
}

export async function runDailyJobs(today: string): Promise<JobResult[]> {
  const results: JobResult[] = [];
  results.push(await approvalReminders(today));
  results.push(await escalation(today));
  results.push(await missingArtwork(today));
  // Stand chasers and stand-document expiry only run while Stands is on.
  if (standsEnabled) {
    results.push(await standChasers(today));
    results.push(await documentExpiry(today));
  }
  results.push(await dailyDigest(today));
  return results;
}
