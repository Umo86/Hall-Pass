import { describe, expect, it } from "vitest";
import {
  DEADLINE_KEYS,
  DEFAULT_DEADLINE_OFFSETS,
  SAME_WEEKDAY_NEXT_YEAR,
  addDaysIso,
  artworkDue,
  assumedEventDates,
  datesLike,
  deadlineDate,
  defaultDeadlines,
  diffDaysIso,
  effectiveDeadline,
  firstDateOutOfOrder,
  isIsoDate,
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

describe("standard deadlines for a new event", () => {
  it("has an offset for every deadline, in the order they fall", () => {
    const rows = defaultDeadlines();
    expect(rows.map((r) => r.key)).toEqual(DEADLINE_KEYS);
    for (const r of rows) expect(r.daysBeforeBuildStart).toBe(DEFAULT_DEADLINE_OFFSETS[r.key]);
    expect(DEFAULT_DEADLINE_OFFSETS.artwork_due).toBe(21);
    expect(DEFAULT_DEADLINE_OFFSETS.print_deadline).toBe(14);
    expect(rows.find((r) => r.key === "delivery")?.label).toBe("Delivery to venue");
  });
});

describe("deadline dates while typing", () => {
  it("counts back from build-up start", () => {
    expect(deadlineDate("2027-10-01", 21)).toBe("2027-09-10");
    expect(deadlineDate("2027-10-01", "14")).toBe("2027-09-17");
    expect(deadlineDate("2027-10-01", 0)).toBe("2027-10-01");
  });
  it("a fixed date wins", () => {
    expect(deadlineDate("2027-10-01", 21, "2027-09-01")).toBe("2027-09-01");
  });
  it("is empty while the input isn't usable yet", () => {
    expect(deadlineDate("", 21)).toBeNull();
    expect(deadlineDate("2027-10-01", "")).toBeNull();
    expect(deadlineDate("2027-10-01", "abc")).toBeNull();
    expect(deadlineDate("2027-10-01", -3)).toBeNull();
    expect(deadlineDate("2027-10-01", 900)).toBeNull();
    expect(deadlineDate("2027-02-30", 3)).toBeNull();
    expect(deadlineDate("2027-10-01", 21, "not a date")).toBe("2027-09-10");
  });
  it("knows a real calendar date", () => {
    expect(isIsoDate("2028-02-29")).toBe(true);
    expect(isIsoDate("2027-02-29")).toBe(false);
    expect(isIsoDate("2027-13-01")).toBe(false);
    expect(isIsoDate("1/10/2027")).toBe(false);
    expect(isIsoDate(null)).toBe(false);
  });
});

describe("dates assumed for a new event", () => {
  it("build-up is the two days before it opens, breakdown ends the day after it closes", () => {
    expect(assumedEventDates("2027-10-05", "2027-10-07")).toEqual({
      buildStart: "2027-10-03",
      buildEnd: "2027-10-04",
      breakdownEnd: "2027-10-08",
    });
  });
  it("works across a month and year end", () => {
    expect(assumedEventDates("2028-01-01", "2028-01-01")).toEqual({
      buildStart: "2027-12-30",
      buildEnd: "2027-12-31",
      breakdownEnd: "2028-01-02",
    });
  });
  it("puts every date in order", () => {
    const open = { openStart: "2027-10-05", openEnd: "2027-10-07" };
    expect(
      firstDateOutOfOrder({ ...open, ...assumedEventDates(open.openStart, open.openEnd) }),
    ).toBeNull();
  });
});

describe("dates for a copied event", () => {
  const source = {
    buildStart: "2027-10-01",
    buildEnd: "2027-10-04",
    openStart: "2027-10-05",
    openEnd: "2027-10-07",
    breakdownEnd: "2027-10-08",
  };
  it("keeps the source's build-up and breakdown around the new open dates", () => {
    const open = addDaysIso(source.openStart, SAME_WEEKDAY_NEXT_YEAR);
    const close = addDaysIso(source.openEnd, SAME_WEEKDAY_NEXT_YEAR);
    expect(open).toBe("2028-10-03");
    expect(datesLike(source, open, close)).toEqual({
      buildStart: "2028-09-29",
      buildEnd: "2028-10-02",
      openStart: "2028-10-03",
      openEnd: "2028-10-05",
      breakdownEnd: "2028-10-06",
    });
  });
  it("next year's dates fall on the same weekday", () => {
    const day = (iso: string) => new Date(`${iso}T00:00:00Z`).getUTCDay();
    const next = addDaysIso("2027-10-05", SAME_WEEKDAY_NEXT_YEAR);
    expect(day(next)).toBe(day("2027-10-05"));
  });
});

describe("date order", () => {
  const ok = {
    buildStart: "2027-10-01",
    buildEnd: "2027-10-04",
    openStart: "2027-10-05",
    openEnd: "2027-10-07",
    breakdownEnd: "2027-10-08",
  };
  it("accepts the same day for neighbours", () => {
    expect(firstDateOutOfOrder(ok)).toBeNull();
    expect(firstDateOutOfOrder({ ...ok, openEnd: ok.openStart })).toBeNull();
  });
  it("names the first date that's out of order", () => {
    expect(firstDateOutOfOrder({ ...ok, buildEnd: "2027-09-01" })).toBe("buildEnd");
    expect(firstDateOutOfOrder({ ...ok, openStart: "2027-10-02" })).toBe("openStart");
    expect(firstDateOutOfOrder({ ...ok, breakdownEnd: "2027-10-06" })).toBe("breakdownEnd");
  });
});
