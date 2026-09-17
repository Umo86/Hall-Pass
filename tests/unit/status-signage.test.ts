import { describe, expect, it } from "vitest";
import {
  IllegalTransitionError,
  signageTransition,
  type SignageContext,
  type SignageEvent,
  type SignageStatus,
} from "@/lib/status/signage";

const ALL_STATUSES: SignageStatus[] = [
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
  "rejected",
  "on_hold",
];

const ALL_EVENTS: SignageEvent[] = [
  "submit_for_review",
  "artwork_uploaded",
  "changes_requested",
  "rejected",
  "run_approved",
  "run_approved_with_conditions",
  "resubmit",
  "sent_to_print",
  "delivered",
  "installed",
  "snag_opened",
  "snags_cleared",
  "close",
  "reopen",
  "new_version_after_approval",
  "hold",
  "resume",
];

// Every legal transition: [from, event, context, expected]
const LEGAL: Array<[SignageStatus, SignageEvent, SignageContext, SignageStatus]> = [
  ["draft", "submit_for_review", { hasArtwork: false }, "awaiting_artwork"],
  ["draft", "submit_for_review", { hasArtwork: true }, "in_review"],
  ["awaiting_artwork", "artwork_uploaded", {}, "in_review"],
  ["in_review", "changes_requested", {}, "changes_requested"],
  ["in_review", "rejected", {}, "rejected"],
  ["in_review", "run_approved", {}, "approved"],
  ["in_review", "run_approved_with_conditions", {}, "approved_with_conditions"],
  ["changes_requested", "resubmit", {}, "in_review"],
  ["approved", "sent_to_print", {}, "in_production"],
  ["approved_with_conditions", "sent_to_print", {}, "in_production"],
  ["approved", "new_version_after_approval", {}, "in_review"],
  ["approved_with_conditions", "new_version_after_approval", {}, "in_review"],
  ["in_production", "delivered", {}, "delivered"],
  ["in_production", "new_version_after_approval", {}, "in_review"],
  ["delivered", "installed", {}, "installed"],
  ["delivered", "new_version_after_approval", {}, "in_review"],
  ["installed", "snag_opened", {}, "snagged"],
  ["installed", "close", {}, "closed"],
  ["snagged", "snags_cleared", {}, "installed"],
  ["rejected", "reopen", {}, "draft"],
  // hold from every non-terminal status, resume returns to previous
  ...ALL_STATUSES.filter((s) => s !== "closed" && s !== "on_hold").map(
    (s): [SignageStatus, SignageEvent, SignageContext, SignageStatus] => [s, "hold", {}, "on_hold"],
  ),
  ["on_hold", "resume", { previousStatus: "in_review" }, "in_review"],
  ["on_hold", "resume", { previousStatus: "draft" }, "draft"],
];

describe("signage status machine — legal transitions", () => {
  it.each(LEGAL)("%s --%s--> %s", (from, event, ctx, expected) => {
    expect(signageTransition(from, event, ctx)).toBe(expected);
  });
});

describe("signage status machine — every other transition throws", () => {
  const legalKeys = new Set(LEGAL.map(([from, event]) => `${from}|${event}`));
  const context: SignageContext = { hasArtwork: true, previousStatus: "in_review" };

  for (const from of ALL_STATUSES) {
    for (const event of ALL_EVENTS) {
      if (legalKeys.has(`${from}|${event}`)) continue;
      it(`${from} --${event}--> throws`, () => {
        expect(() => signageTransition(from, event, context)).toThrow(IllegalTransitionError);
      });
    }
  }

  it("hold from closed throws; hold while on hold throws", () => {
    expect(() => signageTransition("closed", "hold")).toThrow(IllegalTransitionError);
    expect(() => signageTransition("on_hold", "hold")).toThrow(IllegalTransitionError);
  });

  it("resume without a stored previous status throws", () => {
    expect(() => signageTransition("on_hold", "resume", {})).toThrow(IllegalTransitionError);
  });
});
