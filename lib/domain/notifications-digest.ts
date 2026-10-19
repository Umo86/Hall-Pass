/**
 * Pure wording and grouping for sign-off reminders: the daily overdue
 * digest (one message per person instead of one per item per day) and
 * manual reminders sent from Approvals. Unit tested.
 */
import { diffDaysIso } from "@/lib/deadlines";

export type OverdueRow = {
  instanceId: string;
  ref: string;
  /** The due date (YYYY-MM-DD, London). */
  dueIso: string;
  assigneeIds: string[];
  /** The event the sign-off is in. */
  editionId?: string | null;
};

export type DigestLine = {
  userId: string;
  count: number;
  /** Days the oldest of them is overdue. */
  oldestDays: number;
  /** Refs, oldest first. */
  refs: string[];
  instanceIds: string[];
  /** The one event all of them are in, else null (see soleEditionId). */
  editionId: string | null;
};

/**
 * The event a message is about when everything it names is in that one
 * event; null when they span events (or one has none). Stored on the
 * notification, so the bell and late emails hide it from someone later
 * taken off that event (Users → Events) — without splitting messages, so
 * nobody gets more or fewer of them.
 */
export function soleEditionId(ids: readonly (string | null | undefined)[]): string | null {
  if (ids.length === 0) return null;
  const first = ids[0] ?? null;
  return first && ids.every((id) => id === first) ? first : null;
}

/** One line per person: how many of their sign-offs are overdue, oldest first. */
export function overdueDigestLines(rows: OverdueRow[], today: string): DigestLine[] {
  const byUser = new Map<string, OverdueRow[]>();
  for (const row of rows) {
    if (diffDaysIso(today, row.dueIso) <= 0) continue; // not overdue yet
    for (const userId of new Set(row.assigneeIds)) {
      byUser.set(userId, [...(byUser.get(userId) ?? []), row]);
    }
  }
  return [...byUser.entries()]
    .map(([userId, list]) => {
      const sorted = [...list].sort(
        (a, b) => a.dueIso.localeCompare(b.dueIso) || a.ref.localeCompare(b.ref),
      );
      const seen = new Set<string>();
      const unique = sorted.filter((r) => !seen.has(r.instanceId) && seen.add(r.instanceId));
      return {
        userId,
        count: unique.length,
        oldestDays: diffDaysIso(today, unique[0].dueIso),
        refs: unique.map((r) => r.ref),
        instanceIds: unique.map((r) => r.instanceId),
        editionId: soleEditionId(unique.map((r) => r.editionId)),
      };
    })
    .sort((a, b) => a.userId.localeCompare(b.userId));
}

const days = (n: number) => `${n} day${n === 1 ? "" : "s"}`;

/** "SIG-1, SIG-2, SIG-3 and 2 more." */
export function refList(refs: string[], max = 3): string {
  const shown = refs.slice(0, max).join(", ");
  const more = refs.length - max;
  return more > 0 ? `${shown} and ${more} more` : shown;
}

/** "You have 5 sign-offs overdue (oldest 21 days)". */
export function overdueDigestText(line: Pick<DigestLine, "count" | "oldestDays" | "refs">): {
  title: string;
  body: string;
} {
  const title =
    line.count === 1
      ? `You have 1 sign-off overdue (${days(line.oldestDays)})`
      : `You have ${line.count} sign-offs overdue (oldest ${days(line.oldestDays)})`;
  return { title, body: `${refList(line.refs)}. Open Approvals to clear them.` };
}

/** The reminders before a step is due: a week, two days and on the day. */
export function dueReminderTitle(kind: "minus7" | "minus2" | "due", step: string, ref: string) {
  const when = kind === "due" ? "today" : kind === "minus2" ? "in 2 days" : "in 7 days";
  return `Reminder: ${step} on ${ref} is due ${when}`;
}

export type ManualReminder = {
  instanceId: string;
  ref: string;
  stepName: string;
  /** Days overdue (0 when due today or not overdue). */
  overdueDays: number;
  link: string;
  entityType: "signage_item" | "stand_submission";
  entityId: string;
  assigneeIds: string[];
  /** The event the item is in. */
  editionId?: string | null;
};

export type ReminderMessage = {
  userId: string;
  title: string;
  body: string;
  link: string;
  entity: { type: "signage_item" | "stand_submission"; id: string } | null;
  /** The one event the message is about, else null (see soleEditionId). */
  editionId: string | null;
};

/**
 * Manual reminders ("Remind" / "Remind all"): one message per person — about
 * the item when it is one, a summary when it is several.
 */
export function reminderMessages(
  from: string,
  reminders: ManualReminder[],
  opts: { listLink: string },
): ReminderMessage[] {
  const byUser = new Map<string, ManualReminder[]>();
  for (const r of reminders) {
    for (const id of new Set(r.assigneeIds)) byUser.set(id, [...(byUser.get(id) ?? []), r]);
  }
  return [...byUser.entries()].map(([userId, list]) => {
    if (list.length === 1) {
      const r = list[0];
      return {
        userId,
        title: `Reminder from ${from}: ${r.stepName} on ${r.ref}`,
        body:
          r.overdueDays > 0
            ? `It is ${days(r.overdueDays)} overdue. Open it to review and decide.`
            : "Open it to review and decide.",
        link: r.link,
        entity: { type: r.entityType, id: r.entityId },
        editionId: r.editionId ?? null,
      };
    }
    const overdue = list.filter((r) => r.overdueDays > 0).length;
    return {
      userId,
      title: `${from} asks you to sign off ${list.length} items${overdue ? ` (${overdue} overdue)` : ""}`,
      body: `${refList(list.map((r) => r.ref))}.`,
      link: opts.listLink,
      entity: null,
      editionId: soleEditionId(list.map((r) => r.editionId)),
    };
  });
}
