import { describe, expect, it } from "vitest";
import { PORTAL_HOME, STAFF_HOME, safeNext } from "@/lib/edition-path";
import { todayInLondon } from "@/lib/today";

describe("safeNext", () => {
  it("keeps same-site paths", () => {
    expect(safeNext("/BIRM27/signage/SIG-1?tab=artwork")).toBe("/BIRM27/signage/SIG-1?tab=artwork");
    expect(safeNext("/approvals")).toBe("/approvals");
  });
  it("keeps queries and fragments, and normalises the path as the browser would", () => {
    expect(safeNext("/my-work?tab=mine#top")).toBe("/my-work?tab=mine#top");
    expect(safeNext("/BIRM27/./signage")).toBe("/BIRM27/signage");
    // An encoded tab stays an encoded tab: a path on this site, not a host.
    expect(safeNext("/%09/evil.test")).toBe("/%09/evil.test");
  });
  it("refuses other sites, sign-in loops and junk", () => {
    for (const bad of [
      "//evil.test",
      "/\\evil.test",
      "/\t/evil.test",
      "/\n/evil.test",
      "/\r/evil.test",
      "/\t/evil.test/phish?x=1",
      "/x\\y",
      "/\u007f/evil.test",
      "https://evil.test",
      "evil",
      "/login?next=/x",
      "/auth/callback",
      "/api/auth/magic-link/verify?token=x",
      "/api/files/x",
      "/x/../login",
      "/x/%2e%2e/api/files/y",
      "/x/../auth/callback",
      null,
      undefined,
      42,
    ]) {
      expect(safeNext(bad)).toBeNull();
    }
  });
  it("sends staff to My Work and partners to their sign-offs", () => {
    expect(STAFF_HOME).toBe("/my-work");
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
