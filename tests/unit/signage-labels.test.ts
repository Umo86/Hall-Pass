import { describe, expect, it } from "vitest";
import { statusLabel, stepStatusLabel } from "@/lib/format";

describe("status words (one set for the whole app)", () => {
  it("names every item status", () => {
    expect(
      Object.fromEntries(
        [
          "draft",
          "awaiting_artwork",
          "in_review",
          "changes_requested",
          "approved",
          "approved_with_conditions",
          "in_production",
          "delivered",
          "installed",
          "snagged",
          "closed",
          "on_hold",
          "rejected",
        ].map((s) => [s, statusLabel(s)]),
      ),
    ).toEqual({
      draft: "Draft",
      awaiting_artwork: "Needs artwork",
      in_review: "In sign-off",
      changes_requested: "Changes requested",
      approved: "Approved",
      approved_with_conditions: "Approved (conditions)",
      in_production: "Sent to print",
      delivered: "Delivered",
      installed: "Installed",
      snagged: "Snagged",
      closed: "Complete",
      on_hold: "On hold",
      rejected: "Rejected",
    });
  });

  it("names every sign-off step state", () => {
    expect(statusLabel("pending")).toBe("Their turn");
    expect(statusLabel("waiting")).toBe("Not started");
    expect(statusLabel("invalidated")).toBe("Superseded");
    expect(statusLabel("skipped")).toBe("Skipped");
    expect(statusLabel("approved_with_conditions")).toBe("Approved (conditions)");
  });

  it("says who a pending step waits on when that is known", () => {
    expect(stepStatusLabel("pending", "Operations")).toBe("Waiting on Operations");
    expect(stepStatusLabel("pending", " ")).toBe("Their turn");
    expect(stepStatusLabel("pending")).toBe("Their turn");
    expect(stepStatusLabel("approved", "Operations")).toBe("Approved");
  });

  it("still tidies anything else", () => {
    expect(statusLabel("wall_mounted")).toBe("Wall mounted");
    expect(statusLabel("wont_fix")).toBe("Won't fix");
  });
});
