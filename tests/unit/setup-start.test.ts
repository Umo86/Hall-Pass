import { describe, expect, it } from "vitest";
import { noEventsStart } from "@/lib/setup-start";

/** regressions-8: My Work sends people to "Create your event" only when there are no events at all. */
describe("noEventsStart", () => {
  it("a brand-new organisation: creators go to Create your event, others are told who to ask", () => {
    expect(noEventsStart({ totalEvents: 0, activeEvents: 0, canCreate: true })).toBe("redirect");
    expect(noEventsStart({ totalEvents: 0, activeEvents: 0, canCreate: false })).toBe("ask");
  });

  it("between seasons (every event archived): My Work stays open with a card", () => {
    expect(noEventsStart({ totalEvents: 3, activeEvents: 0, canCreate: true })).toBe("create_next");
    expect(noEventsStart({ totalEvents: 3, activeEvents: 0, canCreate: false })).toBe("ask");
  });

  it("an event running: nothing extra", () => {
    expect(noEventsStart({ totalEvents: 3, activeEvents: 1, canCreate: true })).toBeNull();
    expect(noEventsStart({ totalEvents: 1, activeEvents: 1, canCreate: false })).toBeNull();
  });
});
