/** The notification kinds a person can mute; anything not listed always sends. */
export const MUTABLE_KINDS = [
  "approval_requested",
  "approval_reminder",
  "approval_invalidated",
  "decision_made",
  "artwork_uploaded",
  "comment",
  "change_request",
  "delegation",
  "item_created",
  "task_assigned",
  "task_reminder",
  "daily_digest",
] as const;

export type MutableKind = (typeof MUTABLE_KINDS)[number];

export const KIND_LABELS: Record<MutableKind, string> = {
  approval_requested: "A sign-off lands with me",
  approval_reminder: "Deadline reminders for my sign-offs",
  approval_invalidated: "My approval is superseded by a new version",
  decision_made: "Decisions on items I own",
  artwork_uploaded: "New artwork on items I follow",
  comment: "Comments and mentions",
  change_request: "Change requests",
  delegation: "A sign-off is delegated to me",
  item_created: "New items in my area",
  task_assigned: "A task is assigned to me (or one I gave out is done)",
  task_reminder: "Morning reminder of my tasks due",
  daily_digest: "Daily digest",
};
