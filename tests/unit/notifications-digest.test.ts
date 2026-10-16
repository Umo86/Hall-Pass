import { describe, expect, it } from "vitest";
import {
  dueReminderTitle,
  overdueDigestLines,
  overdueDigestText,
  refList,
  reminderMessages,
} from "@/lib/domain/notifications-digest";
import { isApprovalRequestKind, notificationGroup } from "@/lib/notification-kinds";

const TODAY = "2026-10-16";

describe("overdue digest", () => {
  it("gives each person one line, oldest first, ignoring steps not yet overdue", () => {
    const lines = overdueDigestLines(
      [
        { instanceId: "i1", ref: "SIG-3", dueIso: "2026-10-10", assigneeIds: ["ana", "ben"] },
        { instanceId: "i2", ref: "SIG-1", dueIso: "2026-09-25", assigneeIds: ["ana"] },
        { instanceId: "i3", ref: "SIG-2", dueIso: "2026-10-16", assigneeIds: ["ana"] }, // due today
        { instanceId: "i4", ref: "SIG-4", dueIso: "2026-10-20", assigneeIds: ["ben"] }, // future
      ],
      TODAY,
    );
    expect(lines).toEqual([
      {
        userId: "ana",
        count: 2,
        oldestDays: 21,
        refs: ["SIG-1", "SIG-3"],
        instanceIds: ["i2", "i1"],
      },
      { userId: "ben", count: 1, oldestDays: 6, refs: ["SIG-3"], instanceIds: ["i1"] },
    ]);
  });

  it("counts a person once per step even when listed twice", () => {
    const [line] = overdueDigestLines(
      [{ instanceId: "i1", ref: "SIG-1", dueIso: "2026-10-01", assigneeIds: ["ana", "ana"] }],
      TODAY,
    );
    expect(line.count).toBe(1);
  });

  it("words the digest", () => {
    expect(
      overdueDigestText({ count: 5, oldestDays: 21, refs: ["A", "B", "C", "D", "E"] }),
    ).toEqual({
      title: "You have 5 sign-offs overdue (oldest 21 days)",
      body: "A, B, C and 2 more. Open Approvals to clear them.",
    });
    expect(overdueDigestText({ count: 1, oldestDays: 1, refs: ["A"] }).title).toBe(
      "You have 1 sign-off overdue (1 day)",
    );
    expect(refList(["A", "B"])).toBe("A, B");
  });

  it("words the reminders before the due date", () => {
    expect(dueReminderTitle("minus7", "Marketing sign-off", "SIG-1")).toBe(
      "Reminder: Marketing sign-off on SIG-1 is due in 7 days",
    );
    expect(dueReminderTitle("due", "Delivered", "SIG-1")).toBe(
      "Reminder: Delivered on SIG-1 is due today",
    );
  });
});

describe("manual reminders", () => {
  const base = {
    stepName: "Marketing sign-off",
    link: "/X/signage/SIG-1?tab=artwork",
    entityType: "signage_item" as const,
  };
  it("sends one message about the item when a person has one", () => {
    const [msg] = reminderMessages(
      "Olivia Ops",
      [
        {
          ...base,
          instanceId: "i1",
          ref: "SIG-1",
          overdueDays: 3,
          entityId: "e1",
          assigneeIds: ["ana"],
        },
      ],
      { listLink: "/approvals" },
    );
    expect(msg).toEqual({
      userId: "ana",
      title: "Reminder from Olivia Ops: Marketing sign-off on SIG-1",
      body: "It is 3 days overdue. Open it to review and decide.",
      link: base.link,
      entity: { type: "signage_item", id: "e1" },
    });
  });

  it("sums several up into one message per person", () => {
    const msgs = reminderMessages(
      "Olivia Ops",
      [
        {
          ...base,
          instanceId: "i1",
          ref: "SIG-1",
          overdueDays: 3,
          entityId: "e1",
          assigneeIds: ["ana", "ben"],
        },
        {
          ...base,
          instanceId: "i2",
          ref: "SIG-2",
          overdueDays: 0,
          entityId: "e2",
          assigneeIds: ["ana"],
        },
      ],
      { listLink: "/approvals" },
    );
    expect(msgs.find((m) => m.userId === "ana")).toMatchObject({
      title: "Olivia Ops asks you to sign off 2 items (1 overdue)",
      body: "SIG-1, SIG-2.",
      link: "/approvals",
      entity: null,
    });
    expect(msgs.find((m) => m.userId === "ben")?.entity).toEqual({
      type: "signage_item",
      id: "e1",
    });
  });
});

describe("notification kinds", () => {
  it("knows which ask for a sign-off", () => {
    expect(isApprovalRequestKind("approval_requested")).toBe(true);
    expect(isApprovalRequestKind("approval_reminder")).toBe(true);
    expect(isApprovalRequestKind("delegation")).toBe(true);
    expect(isApprovalRequestKind("decision_made")).toBe(false);
  });

  it("groups kinds for their icon", () => {
    expect(notificationGroup("approval_requested")).toBe("approval");
    expect(notificationGroup("decision_made")).toBe("approval");
    expect(notificationGroup("task_assigned")).toBe("task");
    expect(notificationGroup("date_reminder")).toBe("date");
    expect(notificationGroup("supplier_needed")).toBe("item");
    expect(notificationGroup("daily_digest")).toBe("other");
  });
});
