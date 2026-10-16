/**
 * Users: abilities stored as differences from the role, the sections
 * picker, sign-off changes and the words shown in the list.
 */
import { describe, expect, it } from "vitest";
import { FEATURES } from "@/lib/authz";
import {
  ABILITY_KEYS,
  defaultAbilities,
  departmentFallbackText,
  effectiveAbilities,
  featuresSummary,
  firstName,
  inviteStatusText,
  normaliseFeatures,
  overridesFor,
  roleForDepartment,
  sameFeatures,
  signoffChanges,
  signoffPaused,
  sortPeople,
  visibleFeatures,
} from "@/lib/users/rules";

describe("abilities", () => {
  it("start from the role's defaults", () => {
    expect(defaultAbilities("ops")).toEqual({
      "signage.create": true,
      "sponsorship.create": true,
      "costs.edit": true,
      "settings.manage": true,
    });
    expect(defaultAbilities("viewer")).toEqual({
      "signage.create": false,
      "sponsorship.create": false,
      "costs.edit": false,
      "settings.manage": false,
    });
    expect(defaultAbilities("marketing")["signage.create"]).toBe(true);
    expect(defaultAbilities("sales")["sponsorship.create"]).toBe(true);
  });

  it("apply stored differences", () => {
    expect(effectiveAbilities("sales", { "costs.edit": true })["costs.edit"]).toBe(true);
    expect(effectiveAbilities("ops", { "costs.edit": false })["costs.edit"]).toBe(false);
  });

  it("store only what differs from the role", () => {
    expect(overridesFor("ops", defaultAbilities("ops"))).toEqual({});
    expect(overridesFor("sales", { ...defaultAbilities("sales"), "costs.edit": true })).toEqual({
      "costs.edit": true,
    });
    expect(overridesFor("ops", { "settings.manage": false })).toEqual({
      "settings.manage": false,
    });
  });

  it("never store anything for admins", () => {
    expect(overridesFor("admin", { "costs.edit": false }, { signoffPaused: true })).toEqual({});
  });

  it("keep a paused sign-off, and only that one approval key", () => {
    const o = overridesFor("marketing", defaultAbilities("marketing"), { signoffPaused: true });
    expect(o).toEqual({ "approval.decide": false });
    expect(signoffPaused(o)).toBe(true);
    expect(signoffPaused({})).toBe(false);
    expect(signoffPaused(null)).toBe(false);
    expect(ABILITY_KEYS).not.toContain("approval.decide");
  });
});

describe("sections", () => {
  it("hide Exhibitor stands while stands are off", () => {
    expect(visibleFeatures(false)).not.toContain("stands");
    expect(visibleFeatures(true)).toEqual([...FEATURES]);
  });

  it("normalise to known keys in order, and every section to null", () => {
    expect(normaliseFeatures(null)).toBeNull();
    expect(normaliseFeatures(["reports", "signage", "signage", "nonsense"])).toEqual([
      "signage",
      "reports",
    ]);
    expect(normaliseFeatures([...FEATURES].reverse())).toBeNull();
    expect(normaliseFeatures([])).toEqual([]);
  });

  it("compare lists regardless of order", () => {
    expect(sameFeatures(["reports", "signage"], ["signage", "reports"])).toBe(true);
    expect(sameFeatures(null, [...FEATURES])).toBe(true);
    expect(sameFeatures(null, ["signage"])).toBe(false);
    expect(sameFeatures(["signage"], ["reports"])).toBe(false);
  });

  it("summarise for the list", () => {
    const visible = visibleFeatures(false);
    expect(featuresSummary(null, visible)).toBe("All sections");
    expect(featuresSummary(["signage", "reports", "calendar", "onsite"], visible)).toBe("4 of 8");
    expect(featuresSummary([], visible)).toBe("No sections");
    // A hidden section doesn't count.
    expect(featuresSummary(["stands", "signage"], visible)).toBe("1 of 8");
    expect(featuresSummary(visible, visible)).toBe("All sections");
  });
});

describe("role for a department", () => {
  it("matches the role with the department's name", () => {
    expect(roleForDepartment("Marketing")).toBe("marketing");
    expect(roleForDepartment(" senior management ")).toBe("event_director");
    expect(roleForDepartment("Operations")).toBe("ops");
    expect(roleForDepartment("Viewer")).toBe("viewer");
  });

  it("never suggests admin and leaves other names alone", () => {
    expect(roleForDepartment("Admin")).toBeNull();
    expect(roleForDepartment("Legal")).toBeNull();
    expect(roleForDepartment(null)).toBeNull();
  });
});

describe("sign-off changes", () => {
  it("lists additions, removals and main-approver changes", () => {
    const current = [
      { departmentId: "a", isMain: true },
      { departmentId: "b", isMain: false },
      { departmentId: "c", isMain: false },
    ];
    const desired = [
      { departmentId: "a", isMain: false },
      { departmentId: "c", isMain: false },
      { departmentId: "d", isMain: true },
    ];
    expect(signoffChanges(current, desired)).toEqual({
      add: [{ departmentId: "d", isMain: true }],
      remove: ["b"],
      update: [{ departmentId: "a", isMain: false }],
    });
  });

  it("is empty when nothing changed", () => {
    const same = [{ departmentId: "a", isMain: true }];
    expect(signoffChanges(same, same)).toEqual({ add: [], remove: [], update: [] });
  });
});

describe("list words", () => {
  const now = new Date("2026-10-14T12:00:00Z");

  it("says when and by whom someone was invited, or that it expired", () => {
    expect(
      inviteStatusText(
        {
          createdAt: new Date("2026-10-03T09:00:00Z"),
          expiresAt: new Date("2026-10-17T09:00:00Z"),
          inviterName: "Alex Admin",
        },
        now,
      ),
    ).toBe("Invited 3 Oct by Alex");
    expect(
      inviteStatusText(
        { createdAt: new Date("2026-09-01T09:00:00Z"), expiresAt: null, inviterName: null },
        now,
      ),
    ).toBe("Invited 1 Sept");
    expect(
      inviteStatusText(
        {
          createdAt: new Date("2026-09-01T09:00:00Z"),
          expiresAt: new Date("2026-09-15T09:00:00Z"),
        },
        now,
      ),
    ).toBe("Invite expired");
  });

  it("sorts by name with you first", () => {
    const rows = sortPeople([
      { name: "zoe", email: "z@x.test" },
      { name: "", email: "bob@x.test" },
      { name: "Amy", email: "a@x.test" },
      { name: "Mia", email: "m@x.test", isSelf: true },
    ]);
    expect(rows.map((r) => r.email)).toEqual(["m@x.test", "a@x.test", "bob@x.test", "z@x.test"]);
  });

  it("uses first names", () => {
    expect(firstName("Sam Smith")).toBe("Sam");
    expect(firstName("", "sam@x.test")).toBe("sam");
  });

  it("says where a department's sign-offs go when someone leaves it", () => {
    expect(departmentFallbackText({ name: "Marketing", isMain: true, others: ["Priya"] })).toBe(
      "Sign-offs for Marketing will go to Priya.",
    );
    expect(
      departmentFallbackText({ name: "Sales", isMain: false, others: ["A", "B", "C", "D"] }),
    ).toBe("Sign-offs for Sales will go to A, B and 2 more.");
    expect(departmentFallbackText({ name: "Legal", isMain: true, others: [] })).toBe(
      "Legal will have no approvers — add one first or its sign-offs will wait.",
    );
  });
});
