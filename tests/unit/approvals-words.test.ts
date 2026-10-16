import { describe, expect, it } from "vitest";
import {
  bulkConfirmSummary,
  daysOverdue,
  decisionToast,
  overdueLabel,
  stepKindLabel,
  stepStateLabel,
  waitingOnLabel,
} from "@/components/approvals/step-words";

describe("sign-off step words", () => {
  it.each([
    ["pending", "Marketing", "Waiting on Marketing"],
    ["pending", null, "Their turn"],
    ["waiting", null, "Not started"],
    ["approved", null, "Approved"],
    ["approved_with_conditions", null, "Approved (conditions)"],
    ["changes_requested", null, "Changes requested"],
    ["rejected", null, "Rejected"],
    ["invalidated", null, "Superseded"],
    ["skipped", null, "Skipped"],
    ["confirmed", null, "Confirmed"],
  ])("%s (%s) → %s", (status, who, label) => {
    expect(stepStateLabel(status, who)).toBe(label);
  });

  it("names the step kind", () => {
    expect(stepKindLabel("approval")).toBe("Sign-off");
    expect(stepKindLabel("confirmation")).toBe("Confirmation");
  });

  it("says who a step is with: person, then department, then role", () => {
    expect(
      waitingOnLabel({ assignedUserId: "u", assigneeName: "Dana Director", departmentName: "X" }),
    ).toBe("Dana Director");
    expect(waitingOnLabel({ assignedUserId: "u" })).toBe("a named person");
    expect(waitingOnLabel({ departmentName: "Marketing", roleName: "Venue" })).toBe("Marketing");
    expect(waitingOnLabel({ roleName: "Venue" })).toBe("Venue");
    expect(waitingOnLabel({})).toBeNull();
  });

  it("counts whole days overdue in London", () => {
    expect(daysOverdue(new Date("2026-09-25T14:10:00Z"), "2026-10-16")).toBe(21);
    // Due earlier today: overdue, but not by a day.
    expect(daysOverdue(new Date("2026-10-16T08:00:00Z"), "2026-10-16")).toBe(0);
    // Late evening UTC is already the next day in London during BST.
    expect(daysOverdue("2026-10-15T23:30:00Z", "2026-10-16")).toBe(0);
    expect(daysOverdue(new Date("2026-10-20T08:00:00Z"), "2026-10-16")).toBe(0);
  });

  it("labels overdue pills", () => {
    expect(overdueLabel(0)).toBe("Overdue");
    expect(overdueLabel(1)).toBe("Overdue 1 day");
    expect(overdueLabel(21)).toBe("Overdue 21 days");
  });

  it("words the toast after each decision", () => {
    expect(decisionToast("approve", "Marketing sign-off")).toBe("Approved — Marketing sign-off");
    expect(decisionToast("request_changes", "Venue approval")).toBe(
      "Changes requested — Venue approval",
    );
    expect(decisionToast("confirm", "Delivered")).toBe("Delivered confirmed");
  });

  it("sums up a bulk confirmation", () => {
    expect(
      bulkConfirmSummary([
        { ref: "A", ok: true },
        { ref: "B", ok: true },
        { ref: "C", ok: false, needsPhoto: true },
      ]),
    ).toBe("2 confirmed, 1 needs a photo");
    expect(
      bulkConfirmSummary([
        { ref: "A", ok: false, error: "x" },
        { ref: "B", ok: false, needsPhoto: true },
        { ref: "C", ok: false, needsPhoto: true },
      ]),
    ).toBe("0 confirmed, 2 need a photo, 1 couldn't be confirmed");
  });
});
