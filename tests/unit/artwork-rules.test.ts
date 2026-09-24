import { describe, expect, it } from "vitest";
import { artworkBlockedReason, artworkTypeAllowed } from "@/lib/artwork-rules";

describe("artwork rules", () => {
  it("accepts print formats, including AI/EPS with a generic type", () => {
    expect(artworkTypeAllowed("application/pdf", "a.pdf")).toBe(true);
    expect(artworkTypeAllowed("application/octet-stream", "logo.ai")).toBe(true);
    expect(artworkTypeAllowed("", "logo.eps")).toBe(true);
  });
  it("refuses other files", () => {
    expect(artworkTypeAllowed("text/html", "page.html")).toBe(false);
    expect(artworkTypeAllowed("application/x-msdownload", "setup.exe")).toBe(false);
  });
  it("blocks new artwork once an item is installed", () => {
    expect(artworkBlockedReason("installed")).toMatch(/reopen/);
    expect(artworkBlockedReason("closed")).toMatch(/reopen/);
    expect(artworkBlockedReason("in_review")).toBeNull();
  });
});
