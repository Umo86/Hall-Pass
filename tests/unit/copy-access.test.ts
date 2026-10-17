import { describe, expect, it } from "vitest";
import { copiedAccessCount, type CopyableGrant } from "@/lib/copy-access";

/** The copy form's partner-access count (partners-2): what cloneEdition brings across. */
describe("copiedAccessCount", () => {
  const today = "2026-10-17";
  const grants: CopyableGrant[] = [
    { venue: true, endOffsetDays: 0 }, // the venue, ended with the old event
    { venue: false, endOffsetDays: 0 }, // a supplier, ended with the old event
    { venue: false, endOffsetDays: null }, // an engineer with no end date
    { venue: false, endOffsetDays: -30 }, // ended a month before the old event's breakdown
  ];

  it("counts ended access whose moved end date is still ahead", () => {
    expect(copiedAccessCount(grants, { breakdownEnd: "2027-06-05", sameVenue: true, today })).toBe(
      4,
    );
  });

  it("leaves the venue's access behind for a different venue", () => {
    expect(copiedAccessCount(grants, { breakdownEnd: "2027-06-05", sameVenue: false, today })).toBe(
      3,
    );
  });

  it("drops access whose moved end date has passed; an end today still counts", () => {
    expect(copiedAccessCount(grants, { breakdownEnd: "2026-10-17", sameVenue: true, today })).toBe(
      3,
    );
    expect(copiedAccessCount(grants, { breakdownEnd: "2026-10-16", sameVenue: true, today })).toBe(
      1,
    );
  });

  it("counts every grant while the new dates aren't valid yet", () => {
    expect(copiedAccessCount(grants, { breakdownEnd: null, sameVenue: true, today })).toBe(4);
    expect(copiedAccessCount([], { breakdownEnd: "2027-06-05", sameVenue: true, today })).toBe(0);
  });
});
