import { describe, expect, it } from "vitest";
import { PORTAL_HOME, STAFF_HOME, safeNext } from "@/lib/edition-path";
import { todayInLondon } from "@/lib/today";

describe("safeNext", () => {
  it("keeps same-site paths", () => {
    expect(safeNext("/BIRM27/signage/SIG-1?tab=artwork")).toBe("/BIRM27/signage/SIG-1?tab=artwork");
    expect(safeNext("/approvals")).toBe("/approvals");
  });
  it("refuses other sites, sign-in loops and junk", () => {
    for (const bad of ["//evil.test", "/\\evil.test", "https://evil.test", "evil", "/login?next=/x", "/auth/callback", null, undefined, 42]) {
      expect(safeNext(bad)).toBeNull();
    }
  });
  it("sends staff to My Work and partners to their sign-offs", () => {
    expect(STAFF_HOME).toBe("/approvals");
    expect(PORTAL_HOME).toBe("/portal/approvals");
  });
});

describe("todayInLondon", () => {
  it("uses the London date, not UTC", () => {
    // 23:30 UTC on 30 June is 00:30 on 1 July in London (BST).
    expect(todayInLondon(new Date("2027-06-30T23:30:00Z"))).toBe("2027-07-01");
    // In winter London is on UTC.
    expect(todayInLondon(new Date("2027-01-15T23:30:00Z"))).toBe("2027-01-15");
  });
});

import { formatDate } from "@/lib/format";

describe("formatDate", () => {
  it("formats plain dates and full timestamps, and never throws", () => {
    expect(formatDate("2027-03-12")).toBe("12 Mar 2027");
    expect(formatDate("2027-03-12T09:30:00.000Z")).toBe("12 Mar 2027");
    expect(formatDate("not a date")).toBe("—");
    expect(formatDate(null)).toBe("—");
  });
});
