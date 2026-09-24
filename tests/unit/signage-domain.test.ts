import { describe, expect, it } from "vitest";
import {
  changedSpecKeys,
  commentRecipients,
  missingSubmitFields,
  newlyPending,
} from "@/lib/domain/signage";

const complete = {
  kind: "signage" as const,
  hallId: "h",
  locationId: "l",
  itemTypeId: "t",
  widthMm: 1000,
  heightMm: 500,
  quantity: 1,
  fixingMethod: "rigged",
};

describe("missingSubmitFields", () => {
  it("a complete sign is ready", () => {
    expect(missingSubmitFields(complete)).toEqual([]);
  });

  it("a sign needs hall, location, size and fixing", () => {
    expect(
      missingSubmitFields({ ...complete, hallId: null, locationId: null, widthMm: null, fixingMethod: null }),
    ).toEqual(["hall", "location", "width", "fixing method"]);
  });

  it("a sponsorship item only needs a type and quantity", () => {
    const bag = {
      kind: "sponsorship_item" as const,
      hallId: null,
      locationId: null,
      itemTypeId: "bags",
      widthMm: null,
      heightMm: null,
      quantity: 500,
      fixingMethod: null,
    };
    expect(missingSubmitFields(bag)).toEqual([]);
    expect(missingSubmitFields({ ...bag, itemTypeId: null })).toEqual(["item type"]);
  });
});

describe("changedSpecKeys", () => {
  const stored = { widthMm: 3000, material: "Fabric", installDate: "2027-10-01", depthMm: null };

  it("ignores unchanged values and non-spec fields", () => {
    expect(changedSpecKeys(stored, { widthMm: "3000", installDate: "2027-10-05" })).toEqual([]);
  });

  it("treats null and empty as the same", () => {
    expect(changedSpecKeys(stored, { depthMm: "" })).toEqual([]);
  });

  it("reports real spec changes", () => {
    expect(changedSpecKeys(stored, { widthMm: 5000, material: "Foamex" })).toEqual([
      "widthMm",
      "material",
    ]);
  });
});

describe("commentRecipients", () => {
  it("tells the owner and earlier commenters, never the author", () => {
    expect(
      commentRecipients({
        authorId: "me",
        ownerId: "owner",
        createdBy: "creator",
        priorAuthors: [
          { id: "me", isExternal: false },
          { id: "colleague", isExternal: false },
        ],
        isInternal: true,
      }),
    ).toEqual(["owner", "colleague"]);
  });

  it("falls back to the creator when an imported item has no owner", () => {
    expect(
      commentRecipients({ authorId: "me", ownerId: null, createdBy: "creator", priorAuthors: [], isInternal: true }),
    ).toEqual(["creator"]);
  });

  it("keeps external people out of staff-only comments", () => {
    expect(
      commentRecipients({
        authorId: "me",
        ownerId: null,
        createdBy: null,
        priorAuthors: [{ id: "sponsor", isExternal: true }],
        isInternal: true,
      }),
    ).toEqual([]);
  });
});

describe("newlyPending", () => {
  it("returns only steps that just became pending", () => {
    const before = [
      { id: "a", status: "pending" },
      { id: "b", status: "waiting" },
    ];
    const after = [
      { id: "a", status: "pending" },
      { id: "b", status: "pending" },
    ];
    expect(newlyPending(before, after).map((i) => i.id)).toEqual(["b"]);
  });
});
