/**
 * Which event a notification is about, from its link (lib/edition-path.ts):
 * notify() stores it so the bell and late emails leave out events someone
 * can no longer open (Users → Events).
 */
import { describe, expect, it } from "vitest";
import { linkEditionCode } from "@/lib/edition-path";

describe("linkEditionCode", () => {
  it("reads the event code at the start of the link", () => {
    expect(linkEditionCode("/BIRM27/signage/SIG-BIRM27-001")).toBe("BIRM27");
    expect(linkEditionCode("/BIRM27/signage/SIG-BIRM27-001?tab=artwork")).toBe("BIRM27");
    expect(linkEditionCode("/BIRM27?x=1")).toBe("BIRM27");
    expect(linkEditionCode("/BIRM27")).toBe("BIRM27");
    expect(linkEditionCode("/BIRM27#top")).toBe("BIRM27");
  });

  it("is null for pages about no one event, and for no link", () => {
    expect(linkEditionCode("/approvals")).toBeNull();
    expect(linkEditionCode("/approvals?tab=team")).toBeNull();
    expect(linkEditionCode("/users/abc")).toBeNull();
    expect(linkEditionCode("/my-work")).toBeNull();
    expect(linkEditionCode("/q/SIG-1")).toBeNull();
    expect(linkEditionCode("/")).toBeNull();
    expect(linkEditionCode(null)).toBeNull();
    expect(linkEditionCode(undefined)).toBeNull();
    expect(linkEditionCode("https://example.test/BIRM27")).toBeNull();
    expect(linkEditionCode("//evil.test/BIRM27")).toBeNull();
  });
});
