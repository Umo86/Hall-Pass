import { describe, expect, it } from "vitest";
import { IllegalTransitionError } from "@/lib/status/signage";
import {
  computeIsComplex,
  standTransition,
  type StandContext,
  type StandEvent,
  type StandStatus,
} from "@/lib/status/stand";

const ALL_STATUSES: StandStatus[] = [
  "not_submitted",
  "submitted",
  "in_review",
  "changes_requested",
  "approved",
  "approved_with_conditions",
  "rejected",
  "build_checked",
  "closed",
  "on_hold",
];

const ALL_EVENTS: StandEvent[] = [
  "submit",
  "changes_requested",
  "outcome_approved",
  "outcome_approved_with_conditions",
  "outcome_rejected",
  "resubmit",
  "build_check",
  "close",
  "hold",
  "resume",
];

const ok: StandContext = {
  requiredDocsPresent: true,
  maxHeightSet: true,
  buildCheckNotes: "checked",
  hadConditions: false,
  previousStatus: "in_review",
};

const LEGAL: Array<[StandStatus, StandEvent, StandContext, StandStatus]> = [
  ["not_submitted", "submit", ok, "in_review"],
  ["submitted", "changes_requested", ok, "changes_requested"],
  ["in_review", "changes_requested", ok, "changes_requested"],
  ["in_review", "outcome_approved", ok, "approved"],
  ["in_review", "outcome_approved_with_conditions", ok, "approved_with_conditions"],
  ["in_review", "outcome_rejected", ok, "rejected"],
  ["changes_requested", "resubmit", ok, "in_review"],
  ["rejected", "resubmit", ok, "in_review"],
  ["approved", "build_check", ok, "build_checked"],
  ["approved_with_conditions", "build_check", ok, "build_checked"],
  ["build_checked", "close", ok, "closed"],
  ...ALL_STATUSES.filter((s) => s !== "closed" && s !== "on_hold").map(
    (s): [StandStatus, StandEvent, StandContext, StandStatus] => [s, "hold", ok, "on_hold"],
  ),
  ["on_hold", "resume", ok, "in_review"],
];

describe("stand status machine — legal transitions", () => {
  it.each(LEGAL)("%s --%s--> %s", (from, event, ctx, expected) => {
    expect(standTransition(from, event, ctx)).toBe(expected);
  });
});

describe("stand status machine — guards", () => {
  it("cannot submit with required documents missing", () => {
    expect(() =>
      standTransition("not_submitted", "submit", { ...ok, requiredDocsPresent: false }),
    ).toThrow(IllegalTransitionError);
  });
  it("cannot submit without max height", () => {
    expect(() => standTransition("not_submitted", "submit", { ...ok, maxHeightSet: false })).toThrow(
      IllegalTransitionError,
    );
  });
  it("resubmit requires documents present", () => {
    expect(() =>
      standTransition("changes_requested", "resubmit", { ...ok, requiredDocsPresent: false }),
    ).toThrow(IllegalTransitionError);
  });
  it("build check notes are mandatory when conditions existed", () => {
    expect(() =>
      standTransition("approved_with_conditions", "build_check", {
        ...ok,
        hadConditions: true,
        buildCheckNotes: null,
      }),
    ).toThrow(IllegalTransitionError);
    expect(
      standTransition("approved_with_conditions", "build_check", {
        ...ok,
        hadConditions: true,
        buildCheckNotes: "conditions verified onsite",
      }),
    ).toBe("build_checked");
  });
});

describe("stand status machine — every other transition throws", () => {
  const legalKeys = new Set(LEGAL.map(([from, event]) => `${from}|${event}`));
  for (const from of ALL_STATUSES) {
    for (const event of ALL_EVENTS) {
      if (legalKeys.has(`${from}|${event}`)) continue;
      it(`${from} --${event}--> throws`, () => {
        expect(() => standTransition(from, event, ok)).toThrow(IllegalTransitionError);
      });
    }
  }
});

describe("complexity computation", () => {
  const base = {
    isDoubleDeck: false,
    hasPlatformOver600mm: false,
    hasRampedRaisedFloor: false,
    hasRigging: false,
    hasCeilingOrRoof: false,
    hasTieredSeating: false,
    maxHeightMm: 3000 as number | null,
  };
  it("simple stand is not complex", () => {
    expect(computeIsComplex(base)).toBe(false);
  });
  it("any single trigger makes it complex", () => {
    for (const key of [
      "isDoubleDeck",
      "hasPlatformOver600mm",
      "hasRampedRaisedFloor",
      "hasRigging",
      "hasCeilingOrRoof",
      "hasTieredSeating",
    ] as const) {
      expect(computeIsComplex({ ...base, [key]: true }), key).toBe(true);
    }
  });
  it("height over 4000 mm is complex; exactly 4000 is not; null height is not", () => {
    expect(computeIsComplex({ ...base, maxHeightMm: 4001 })).toBe(true);
    expect(computeIsComplex({ ...base, maxHeightMm: 4000 })).toBe(false);
    expect(computeIsComplex({ ...base, maxHeightMm: null })).toBe(false);
  });
});
