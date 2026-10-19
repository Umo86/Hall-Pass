/** The notification kinds a person can mute; anything not listed always sends. */
export const MUTABLE_KINDS = [
  "approval_requested",
  "approval_reminder",
  "approval_invalidated",
  "decision_made",
  "artwork_uploaded",
  "comment",
  "snag",
  "delegation",
  "item_created",
  "item_assigned",
  "supplier_needed",
  "task_assigned",
  "task_reminder",
  "date_reminder",
  "daily_digest",
] as const;

export type MutableKind = (typeof MUTABLE_KINDS)[number];

export const KIND_LABELS: Record<MutableKind, string> = {
  approval_requested: "A sign-off lands with me",
  approval_reminder: "Reminders for my sign-offs (overdue ones in one message a day)",
  approval_invalidated: "My approval is superseded by a new version",
  decision_made: "Decisions on items I own, or taken for me",
  artwork_uploaded: "New artwork on items I follow",
  comment: "Comments and mentions",
  snag: "Snags raised or resolved on items I own",
  delegation: "A sign-off is delegated to me",
  item_created: "New items in my area",
  item_assigned: "An item is given to me",
  supplier_needed: "An approved item still has no supplier (Operations)",
  task_assigned: "A task is assigned to me (or one I gave out is done)",
  task_reminder: "Morning reminder of my tasks due",
  date_reminder: "Print, delivery, install and order-by dates coming up",
  daily_digest: "Daily digest",
};

/**
 * Notifications that ask someone to act on a sign-off. They are settled
 * (marked read) once the person no longer has a step waiting on that record,
 * and show as "Done" in the bell.
 */
export const APPROVAL_REQUEST_KINDS = [
  "approval_requested",
  "approval_reminder",
  "delegation",
] as const;

export function isApprovalRequestKind(kind: string): boolean {
  return (APPROVAL_REQUEST_KINDS as readonly string[]).includes(kind);
}

export type NotificationGroup = "approval" | "task" | "date" | "item" | "other";

/** Which icon a notification gets in the bell and on the notifications page. */
export function notificationGroup(kind: string): NotificationGroup {
  if (
    kind.startsWith("approval_") ||
    kind === "delegation" ||
    kind === "decision_made" ||
    kind === "escalation" ||
    // Who signs off changed (always sent: not in MUTABLE_KINDS).
    kind === "main_approver" ||
    // Nobody who signs off for a department can open the item's event
    // (Users → Events); always sent, never shown as Done.
    kind === "signoff_stuck"
  ) {
    return "approval";
  }
  if (kind.startsWith("task_")) return "task";
  if (kind === "date_reminder" || kind === "document_expiry") return "date";
  if (
    kind === "artwork_uploaded" ||
    kind === "item_created" ||
    kind === "item_assigned" ||
    kind === "comment" ||
    kind === "snag" ||
    kind === "supplier_needed" ||
    kind === "artwork_chaser"
  ) {
    return "item";
  }
  return "other";
}
