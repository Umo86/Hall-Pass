import { describe, expect, it } from "vitest";
import {
  addDaysIso,
  artworkDue,
  diffDaysIso,
  effectiveDeadline,
  insuranceDue,
  printDeadline,
  shiftForHold,
  standDesignDue,
  type EditionForDeadlines,
} from "@/lib/deadlines";

const edition: EditionForDeadlines = {
  buildStart: "2027-10-01",
  deadlines: [
    { key: "stand_design_due", daysBeforeBuildStart: 42, overrideDate: null },
    { key: "insurance_due", daysBeforeBuildStart: 28, overrideDate: null },
    { key: "venue_rigging_submission", daysBeforeBuildStart: 28, overrideDate: null },
    { key: "artwork_due", daysBeforeBuildStart: 21, overrideDate: null },
    { key: "print_deadline", daysBeforeBuildStart: 14, overrideDate: null },
    { key: "delivery", daysBeforeBuildStart: 3, overrideDate: null },
  ],
};

describe("date arithmetic", () => {
  it("adds and subtracts days across month boundaries", () => {
    expect(addDaysIso("2027-10-01", -21)).toBe("2027-09-10");
    expect(addDaysIso("2027-10-01", -42)).toBe("2027-08-20");
    expect(addDaysIso("2027-12-30", 5)).toBe("2028-01-04");
  });
  it("is DST-agnostic (calendar days, not 24h blocks)", () => {
    // The clocks change on 2027-03-28 in Europe/London; day maths is unaffected.
    expect(addDaysIso("2027-03-27", 2)).toBe("2027-03-29");
    expect(diffDaysIso("2027-03-29", "2027-03-27")).toBe(2);
  });
});

describe("effective deadlines (7.1)", () => {
  it("computes offset-based dates from build start", () => {
    expect(effectiveDeadline(edition, "artwork_due")).toBe("2027-09-10");
    expect(standDesignDue(edition)).toBe("2027-08-20");
    expect(insuranceDue(edition)).toBe("2027-09-03");
  });

  it("override date wins over the offset", () => {
    const withOverride: EditionForDeadlines = {
      ...edition,
      deadlines: edition.deadlines.map((d) =>
        d.key === "artwork_due" ? { ...d, overrideDate: "2027-09-15" } : d,
      ),
    };
    expect(effectiveDeadline(withOverride, "artwork_due")).toBe("2027-09-15");
  });

  it("missing key returns null", () => {
    expect(effectiveDeadline({ buildStart: "2027-10-01", deadlines: [] }, "delivery")).toBeNull();
  });

  it("item artwork override wins over the edition value", () => {
    expect(artworkDue({ artworkDueOverride: "2027-09-20" }, edition)).toBe("2027-09-20");
    expect(artworkDue({ artworkDueOverride: null }, edition)).toBe("2027-09-10");
  });

  it("item print deadline wins over the edition value", () => {
    expect(printDeadline({ printDeadline: "2027-09-25" }, edition)).toBe("2027-09-25");
    expect(printDeadline({ printDeadline: null }, edition)).toBe("2027-09-17");
  });
});

describe("hold shifting", () => {
  it("shifts a deadline later by the hold duration", () => {
    expect(shiftForHold("2027-09-10", 4)).toBe("2027-09-14");
    expect(shiftForHold("2027-09-10", 0)).toBe("2027-09-10");
    expect(shiftForHold(null, 4)).toBeNull();
  });
});
