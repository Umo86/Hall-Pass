import type { MutableKind } from "@/lib/notification-kinds";

/**
 * How My account groups the notifications a person can switch off. Every
 * mutable kind is in exactly one group (tests/unit/settings-sections.test.ts).
 */
export const NOTIFICATION_GROUPS: { id: string; label: string; kinds: MutableKind[] }[] = [
  {
    id: "signoffs",
    label: "Sign-offs",
    kinds: [
      "approval_requested",
      "approval_reminder",
      "delegation",
      "approval_invalidated",
      "decision_made",
    ],
  },
  {
    id: "items",
    label: "Items I own or follow",
    kinds: [
      "artwork_uploaded",
      "comment",
      "snag",
      "item_created",
      "item_assigned",
      "supplier_needed",
    ],
  },
  {
    id: "tasks",
    label: "Tasks and dates",
    kinds: ["task_assigned", "task_reminder", "date_reminder"],
  },
  { id: "digest", label: "Digest", kinds: ["daily_digest"] },
];
