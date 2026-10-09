import { describe, expect, it } from "vitest";
import { artworkBlockedReason, artworkTypeAllowed, isVideoArtwork } from "@/lib/artwork-rules";

describe("artwork rules", () => {
  it("accepts print formats, including AI/EPS with a generic type", () => {
    expect(artworkTypeAllowed("application/pdf", "a.pdf")).toBe(true);
    expect(artworkTypeAllowed("application/octet-stream", "logo.ai")).toBe(true);
    expect(artworkTypeAllowed("", "logo.eps")).toBe(true);
  });
  it("accepts video for screens, even with a generic type from a phone", () => {
    expect(artworkTypeAllowed("video/mp4", "promo.mp4")).toBe(true);
    expect(artworkTypeAllowed("video/quicktime", "promo.mov")).toBe(true);
    expect(artworkTypeAllowed("application/octet-stream", "promo.MOV")).toBe(true);
    expect(isVideoArtwork("video/webm", "clip.webm")).toBe(true);
    expect(isVideoArtwork(null, "clip.m4v")).toBe(true);
    expect(isVideoArtwork("image/png", "still.png")).toBe(false);
  });
  it("refuses other files", () => {
    expect(artworkTypeAllowed("text/html", "page.html")).toBe(false);
    expect(artworkTypeAllowed("application/x-msdownload", "setup.exe")).toBe(false);
  });
  it("blocks new artwork once an item is installed", () => {
    expect(artworkBlockedReason("installed")).toMatch(/reopen/i);
    expect(artworkBlockedReason("closed")).toMatch(/reopen/i);
    expect(artworkBlockedReason("in_review")).toBeNull();
  });
});
