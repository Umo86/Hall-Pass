import { describe, expect, it } from "vitest";
import { editionIsReadOnly } from "@/lib/edition-lock";

describe("editionIsReadOnly", () => {
  it("locks archived editions only", () => {
    expect(editionIsReadOnly("archived")).toBe(true);
    expect(editionIsReadOnly("planning")).toBe(false);
    expect(editionIsReadOnly("live")).toBe(false);
    expect(editionIsReadOnly("closed")).toBe(false);
  });
});
