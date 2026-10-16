/**
 * Who hears about a new item ("New items in my area"): the owner's
 * department (people with the item's section and access), falling back to
 * the owning team when the owner has no department. The owner is told
 * separately (item_assigned). Pure.
 */
import { describe, expect, it } from "vitest";
import { itemCreationRecipients } from "@/lib/domain/signage";

describe("new-item notifications", () => {
  const people = [
    { userId: "admin", role: "admin", departmentId: null, features: null, active: true },
    { userId: "mia", role: "marketing", departmentId: "d-mkt", features: null, active: true },
    { userId: "max", role: "marketing", departmentId: "d-mkt", features: null, active: true },
    { userId: "mo", role: "ops", departmentId: "d-mkt", features: ["sponsorship"], active: true },
    { userId: "mags", role: "marketing", departmentId: "d-mkt", features: null, active: false },
    { userId: "olly", role: "ops", departmentId: "d-ops", features: null, active: true },
    { userId: "oz", role: "ops", departmentId: null, features: null, active: true },
    { userId: "sam", role: "sales", departmentId: "d-sales", features: null, active: true },
  ];
  const sign = (over: Partial<Parameters<typeof itemCreationRecipients>[1]> = {}) => ({
    kind: "signage" as const,
    category: "organiser",
    ownerUserId: "mia",
    ownerRole: "ops" as const,
    ...over,
  });

  it("go to the owner's department, with the section and access, never the owner or creator", () => {
    // mo lacks Signage; mags is suspended; mia owns it (told separately).
    expect(itemCreationRecipients(people, sign(), "admin")).toEqual(["max"]);
    expect(itemCreationRecipients(people, sign(), "max")).toEqual([]);
    // A sponsorship item reaches mo, who has Sponsorship.
    expect(
      itemCreationRecipients(people, sign({ kind: "sponsorship_item", category: "sponsor" }), "x"),
    ).toEqual(["max", "mo"]);
  });

  it("fall back to the owning team (and Sales for sponsor items) when the owner has no department", () => {
    expect(
      itemCreationRecipients(people, sign({ ownerUserId: "oz", ownerRole: "ops" }), "admin"),
    ).toEqual(["olly"]);
    expect(
      itemCreationRecipients(
        people,
        sign({ ownerUserId: "oz", ownerRole: "ops", category: "sponsor" }),
        "admin",
      ),
    ).toEqual(["olly", "sam"]);
  });

  it("deduplicates", () => {
    const dupes = [...people, { ...people[2] }];
    expect(itemCreationRecipients(dupes, sign(), "admin")).toEqual(["max"]);
  });
});
