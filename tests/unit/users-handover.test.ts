/**
 * Who takes over sign-offs, items and tasks (lib/users/handover.ts): steps
 * grouped by department, the main approver (else another approver) as each
 * group's default, "back to the department" only where someone else signs,
 * refusals in words; and which owned items someone could no longer work
 * on after a change of role or sections.
 */
import { describe, expect, it } from "vitest";
import {
  BACK_TO_DEPARTMENT,
  canStillSign,
  canWorkOwnItem,
  handoverGroups,
  itemsLostByChange,
  OTHER_GROUP,
  resolveHandover,
  type HandoverStep,
} from "@/lib/users/handover";

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

const names = new Map([
  ["mkt", "Marketing"],
  ["sales", "Sales"],
]);

describe("handoverGroups", () => {
  const steps = [
    step({ id: "a", ref: "SIG-2", departmentId: "sales", stepName: "Sales sign-off" }),
    step({ id: "b", ref: "SIG-1" }),
    step({ id: "c", ref: "SIG-3", status: "waiting" }),
    step({ id: "d", ref: "STD-1", departmentId: null, entityType: "stand_submission" }),
  ];

  it("groups by department in name order, then the rest", () => {
    const groups = handoverGroups(steps, {
      departmentNames: names,
      signers: new Map([
        [
          "mkt",
          [
            { userId: "u2", name: "Zoe", isMain: false },
            { userId: "u1", name: "Mia", isMain: true },
          ],
        ],
      ]),
    });
    expect(groups.map((g) => g.key)).toEqual(["mkt", "sales", OTHER_GROUP]);
    const mkt = groups[0];
    expect(mkt.steps.map((s) => s.ref)).toEqual(["SIG-1", "SIG-3"]);
    expect(mkt.waitingNow).toBe(1);
    // Main approver first, and the default.
    expect(mkt.signers.map((s) => s.userId)).toEqual(["u1", "u2"]);
    expect(mkt.defaultTo).toBe("u1");
    // Nobody else signs for Sales, and stands outside departments: someone must be picked.
    expect(groups[1].defaultTo).toBeNull();
    expect(groups[2]).toMatchObject({ departmentId: null, departmentName: null, defaultTo: null });
  });

  it("defaults to another approver when there's no main one", () => {
    const [g] = handoverGroups([step({})], {
      departmentNames: names,
      signers: new Map([["mkt", [{ userId: "u9", name: "Ali", isMain: false }]]]),
    });
    expect(g.defaultTo).toBe("u9");
  });

  it("puts steps of an unknown department with the rest", () => {
    const [g] = handoverGroups([step({ departmentId: "gone" })], {
      departmentNames: names,
      signers: new Map(),
    });
    expect(g.key).toBe(OTHER_GROUP);
  });
});

describe("resolveHandover", () => {
  const groups = handoverGroups(
    [step({ id: "a" }), step({ id: "b", departmentId: "sales", ref: "SIG-9" })],
    {
      departmentNames: names,
      signers: new Map([["mkt", [{ userId: "main", name: "Mia", isMain: true }]]]),
    },
  );
  const ok = new Set(["main", "oscar"]);
  const opts = { personId: "dana", who: "Dana", canReceive: (id: string) => ok.has(id) };

  it("refuses until every group without a default has someone", () => {
    expect(resolveHandover(groups, {}, opts)).toEqual({
      ok: false,
      error: "A sign-off is waiting on Dana (Sales) — choose who takes it over",
    });
  });

  it("uses defaults, choices and back-to-department", () => {
    const res = resolveHandover(groups, { sales: "oscar" }, opts);
    expect(res).toEqual({
      ok: true,
      targets: new Map([
        ["mkt", "main"],
        ["sales", "oscar"],
      ]),
    });
    const back = resolveHandover(groups, { mkt: BACK_TO_DEPARTMENT, sales: "oscar" }, opts);
    expect(back.ok && back.targets.get("mkt")).toBeNull();
  });

  it("refuses back-to-department where nobody else signs, the person themselves, and people who can't sign", () => {
    expect(resolveHandover(groups, { sales: BACK_TO_DEPARTMENT }, opts)).toEqual({
      ok: false,
      error: "Nobody else can sign off for Sales — choose a person",
    });
    expect(resolveHandover(groups, { sales: "dana" }, opts)).toEqual({
      ok: false,
      error: "Pick a team member who can sign off",
    });
    expect(resolveHandover(groups, { sales: "paused-pat" }, opts)).toEqual({
      ok: false,
      error: "Pick a team member who can sign off",
    });
  });

  it("takes one person for everything from older callers", () => {
    const res = resolveHandover(groups, null, { ...opts, fallback: "oscar" });
    expect(res.ok && [...res.targets.values()]).toEqual(["oscar", "oscar"]);
  });

  it("counts several sign-offs in the refusal", () => {
    const many = handoverGroups([step({ id: "x" }), step({ id: "y", ref: "SIG-4" })], {
      departmentNames: names,
      signers: new Map(),
    });
    const res = resolveHandover(many, {}, opts);
    expect(!res.ok && res.error).toBe(
      "2 sign-offs are waiting on Dana (Marketing) — choose who takes them over",
    );
  });
});

describe("items and signing after a change", () => {
  it("knows who can work on their own items of each kind", () => {
    expect(canWorkOwnItem({ role: "marketing", features: null }, "signage")).toBe(true);
    expect(canWorkOwnItem({ role: "marketing", features: ["calendar"] }, "signage")).toBe(false);
    expect(canWorkOwnItem({ role: "viewer", features: null }, "signage")).toBe(false);
    expect(canWorkOwnItem({ role: "event_director", features: null }, "signage")).toBe(false);
    expect(canWorkOwnItem({ role: "sales", features: null }, "sponsorship_item")).toBe(true);
    expect(canWorkOwnItem({ role: "sales", features: null }, "signage")).toBe(false);
    expect(canWorkOwnItem({ role: "ops", features: null }, "stand_design")).toBe(true);
    expect(canWorkOwnItem({ role: "marketing", features: null }, "stand_design")).toBe(false);
    expect(canWorkOwnItem({ role: "admin", features: [] }, "stand_panel")).toBe(true);
  });

  it("lists the items lost by turning off a section or changing role", () => {
    const items = [
      { ref: "SIG-1", kind: "signage" as const },
      { ref: "SPO-1", kind: "sponsorship_item" as const },
    ];
    const before = { role: "marketing" as const, features: null };
    expect(itemsLostByChange(items, before, before)).toEqual([]);
    expect(
      itemsLostByChange(items, before, { role: "marketing", features: ["sponsorship"] }).map(
        (i) => i.ref,
      ),
    ).toEqual(["SIG-1"]);
    expect(itemsLostByChange(items, before, { role: "viewer", features: null })).toEqual(items);
  });

  it("knows who can still decide sign-offs", () => {
    expect(canStillSign({ role: "marketing", features: null })).toBe(true);
    expect(canStillSign({ role: "viewer", features: null })).toBe(false);
    expect(
      canStillSign({ role: "ops", features: null, overrides: { "approval.decide": false } }),
    ).toBe(false);
  });
});
