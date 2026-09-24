import { describe, expect, it } from "vitest";
import { itemCreationRecipients } from "@/lib/domain/signage";

const members = [
  { userId: "u-admin", role: "admin" },
  { userId: "u-ops", role: "ops" },
  { userId: "u-ops2", role: "ops" },
  { userId: "u-marketing", role: "marketing" },
  { userId: "u-sales", role: "sales" },
  { userId: "u-viewer", role: "viewer" },
];

describe("itemCreationRecipients", () => {
  it("notifies the owning role's members", () => {
    expect(
      itemCreationRecipients(members, { kind: "signage", category: "venue", ownerRole: "ops" }, "x"),
    ).toEqual(["u-ops", "u-ops2"]);
  });

  it("adds sales for sponsorship-category signage", () => {
    expect(
      itemCreationRecipients(
        members,
        { kind: "signage", category: "sponsorship", ownerRole: "marketing" },
        "x",
      ),
    ).toEqual(["u-marketing", "u-sales"]);
  });

  it("adds sales for sponsorship items regardless of category", () => {
    expect(
      itemCreationRecipients(
        members,
        { kind: "sponsorship_item", category: null, ownerRole: "marketing" },
        "x",
      ),
    ).toEqual(["u-marketing", "u-sales"]);
  });

  it("never notifies the creator", () => {
    expect(
      itemCreationRecipients(members, { kind: "signage", category: "venue", ownerRole: "ops" }, "u-ops"),
    ).toEqual(["u-ops2"]);
  });

  it("deduplicates users holding the role twice", () => {
    const dupes = [...members, { userId: "u-ops", role: "ops" }];
    expect(
      itemCreationRecipients(dupes, { kind: "signage", category: "venue", ownerRole: "ops" }, "x"),
    ).toEqual(["u-ops", "u-ops2"]);
  });

  it("directional and venue signage never pull in sales", () => {
    for (const category of ["directional", "venue"]) {
      const got = itemCreationRecipients(members, { kind: "signage", category, ownerRole: "ops" }, "x");
      expect(got).not.toContain("u-sales");
    }
  });
});
