import type { ReviewVersion } from "@/lib/queries/artwork-approvals";

/** Another step of the same round, for "Operations: Approved · Venue: Waiting on NEC". */
export type QueueOther = {
  id: string;
  stepName: string;
  status: string;
  who: string | null;
};

/** One sign-off waiting on the viewer, as the review queue shows it. */
export type QueueRow = {
  instanceId: string;
  kind: "approval" | "confirmation";
  entity: "signage" | "stand";
  ref: string;
  /** "Main entrance arch banner", "Stand design: …". */
  title: string;
  /** The record's page (its Artwork & sign-off tab for signage). */
  href: string;
  eventCode: string;
  eventName: string;
  stepName: string;
  dueAt: string | null;
  /** Whole days overdue; null when not overdue. */
  overdueDays: number | null;
  expectedLockedVersionId: string | null;
  requiresPhoto: boolean;
  artwork: { current: ReviewVersion; previous: ReviewVersion | null } | null;
  others: QueueOther[];
};

/** Rows grouped by event, keeping the order rows arrive in (soonest due first). */
export function groupByEvent<T extends { eventCode: string; eventName: string }>(
  rows: T[],
): { eventCode: string; eventName: string; rows: T[] }[] {
  const groups = new Map<string, { eventCode: string; eventName: string; rows: T[] }>();
  for (const row of rows) {
    const g = groups.get(row.eventCode) ?? {
      eventCode: row.eventCode,
      eventName: row.eventName,
      rows: [],
    };
    g.rows.push(row);
    groups.set(row.eventCode, g);
  }
  return [...groups.values()];
}
