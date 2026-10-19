/**
 * Hand-over and events per person (lib/users/handover.ts): a group's signers
 * are only people who can open every one of its events; narrowing someone's
 * events sends their sign-offs back to the department when someone else
 * there can open them, else a person must be picked.
 */
import { describe, expect, it } from "vitest";
import {
  BACK_TO_DEPARTMENT,
  eventHandoverGroups,
  handoverGroups,
  resolveHandover,
  type HandoverSigner,
  type HandoverStep,
} from "@/lib/users/handover";
import { removedEditions } from "@/lib/users/rules";

const step = (over: Partial<HandoverStep>): HandoverStep => ({
  id: over.id ?? "s1",
  entityType: "signage_item",
  entityId: over.entityId ?? "item-1",
  runNumber: 1,
  status: "pending",
  stepName: "Marketing sign-off",
  ref: "SIG-1",
  departmentId: "mkt",
  href: "/BIRM27/signage/SIG-1",
  ...over,
});
const names = new Map([["mkt", "Marketing"]]);
const jo: HandoverSigner = { userId: "jo", name: "Jo", isMain: true, editionIds: ["a"] };
const mia: HandoverSigner = { userId: "mia", name: "Mia", isMain: false, editionIds: null };
const zed: HandoverSigner = { userId: "zed", name: "Zed", isMain: false, editionIds: ["b"] };

describe("handoverGroups with events", () => {
  it("unchanged when nobody is limited and steps carry no event", () => {
    const groups = handoverGroups([step({})], {
      departmentNames: names,
      signers: new Map([["mkt", [{ ...jo, editionIds: null }, mia]]]),
    });
    expect(groups[0].signers.map((s) => s.userId)).toEqual(["jo", "mia"]);
    expect(groups[0].defaultTo).toBe("jo");
    expect(groups[0].editionIds).toEqual([]);
  });

  it("keeps only signers who can open every event of the group", () => {
    const groups = handoverGroups(
      [step({ id: "1", editionId: "b" }), step({ id: "2", ref: "SIG-2", editionId: "b" })],
      { departmentNames: names, signers: new Map([["mkt", [jo, mia, zed]]]) },
    );
    expect(groups[0].editionIds).toEqual(["b"]);
    expect(groups[0].signers.map((s) => s.userId)).toEqual(["mia", "zed"]);
    expect(groups[0].defaultTo).toBe("mia");
    const both = handoverGroups(
      [step({ id: "1", editionId: "a" }), step({ id: "2", ref: "SIG-2", editionId: "b" })],
      { departmentNames: names, signers: new Map([["mkt", [jo, mia, zed]]]) },
    );
    expect(both[0].editionIds).toEqual(["a", "b"]);
    expect(both[0].signers.map((s) => s.userId)).toEqual(["mia"]);
  });

  it("a super admin signer sees every event, even with a stray list", () => {
    const groups = handoverGroups([step({ editionId: "b" })], {
      departmentNames: names,
      signers: new Map([["mkt", [{ ...jo, role: "admin" }]]]),
    });
    expect(groups[0].signers.map((s) => s.userId)).toEqual(["jo"]);
  });
});

describe("eventHandoverGroups", () => {
  it("back to the department when someone else there can open the events", () => {
    const [g] = eventHandoverGroups([step({ editionId: "b" })], {
      departmentNames: names,
      signers: new Map([["mkt", [jo, zed]]]),
    });
    expect(g.signers.map((s) => s.userId)).toEqual(["zed"]);
    expect(g.defaultTo).toBe(BACK_TO_DEPARTMENT);
  });

  it("a person must be picked when nobody else there can, or outside a department", () => {
    const [g] = eventHandoverGroups([step({ editionId: "b" })], {
      departmentNames: names,
      signers: new Map([["mkt", [jo]]]),
    });
    expect(g.signers).toEqual([]);
    expect(g.defaultTo).toBeNull();
    const [other] = eventHandoverGroups([step({ departmentId: null, editionId: "b" })], {
      departmentNames: names,
      signers: new Map(),
    });
    expect(other.defaultTo).toBeNull();
    const res = resolveHandover([g], null, {
      personId: "sam",
      who: "Sam",
      canReceive: () => true,
    });
    expect(res).toEqual({
      ok: false,
      error: "A sign-off is waiting on Sam (Marketing) — choose who takes it over",
    });
  });
});

describe("resolveHandover canReceive(userId, group)", () => {
  it("passes the group, so a pick who can't open its events is refused", () => {
    const groups = handoverGroups([step({ editionId: "b" })], {
      departmentNames: names,
      signers: new Map([["mkt", [jo, mia]]]),
    });
    const editionsOf = new Map([
      ["jo", ["a"]],
      ["mia", null],
    ]);
    const canReceive = (id: string, g: { editionIds: string[] }) => {
      const list = editionsOf.get(id);
      return list === null || (list ?? []).length === 0
        ? true
        : g.editionIds.every((e) => list!.includes(e));
    };
    expect(
      resolveHandover(groups, { mkt: "jo" }, { personId: "sam", who: "Sam", canReceive }),
    ).toEqual({ ok: false, error: "Pick a team member who can sign off" });
    const ok = resolveHandover(groups, { mkt: "mia" }, { personId: "sam", who: "Sam", canReceive });
    expect(ok.ok && ok.targets.get("mkt")).toBe("mia");
  });
});

describe("removedEditions", () => {
  it("null → list, list → list, list → null", () => {
    expect(removedEditions(null, ["a"], ["a", "b"])).toEqual(["b"]);
    expect(removedEditions(["a", "b"], ["b"], ["a", "b"])).toEqual(["a"]);
    expect(removedEditions(["a"], null, ["a", "b"])).toEqual([]);
  });
});
