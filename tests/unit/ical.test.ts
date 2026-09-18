import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { buildCalendar, icalToken, verifyIcalToken } from "@/lib/ical";

describe("ical tokens", () => {
  beforeEach(() => {
    process.env.CRON_SECRET = "test-secret";
  });
  afterEach(() => {
    delete process.env.CRON_SECRET;
  });

  it("round-trips a signed token", () => {
    const token = icalToken("user-123");
    expect(verifyIcalToken(token)).toBe("user-123");
  });

  it("rejects a tampered token", () => {
    const token = icalToken("user-123");
    expect(verifyIcalToken(token.replace("user-123", "user-456"))).toBeNull();
    expect(verifyIcalToken(token.slice(0, -1) + "0")).toBeNull();
    expect(verifyIcalToken("garbage")).toBeNull();
  });

  it("returns null when no secret configured", () => {
    delete process.env.CRON_SECRET;
    expect(verifyIcalToken("user-123.abc")).toBeNull();
  });
});

describe("buildCalendar", () => {
  it("emits valid all-day VEVENTs with escaping and CRLF", () => {
    const ics = buildCalendar(
      "Hall Pass deadlines",
      [
        {
          uid: "deadline-1@hallpass",
          date: "2027-09-01",
          title: "BIRM27: Artwork due; final, no extensions",
          url: "https://example.test/BIRM27/dashboard",
        },
      ],
      new Date("2027-01-01T00:00:00Z"),
    );
    expect(ics).toContain("BEGIN:VCALENDAR");
    expect(ics).toContain("DTSTART;VALUE=DATE:20270901");
    expect(ics).toContain("SUMMARY:BIRM27: Artwork due\\; final\\, no extensions");
    expect(ics).toContain("DTSTAMP:20270101T000000Z");
    expect(ics.endsWith("END:VCALENDAR\r\n")).toBe(true);
    for (const line of ics.split("\r\n")) {
      expect(line.length).toBeLessThanOrEqual(75);
    }
  });
});
