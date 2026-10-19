/**
 * Users: abilities stored as differences from the role, the sections
 * picker, sign-off changes and the words shown in the list.
 */
import { describe, expect, it } from "vitest";
import { FEATURES } from "@/lib/authz";
import {
  abilityChanged,
  abilityChoices,
  abilityGroups,
  defaultAbilities,
  departmentFallbackText,
  EDITABLE_ABILITY_KEYS,
  effectiveAbilities,
  effectiveAbility,
  eventsSummary,
  eventsTitle,
  featuresSummary,
  firstName,
  inviteStatusText,
  mainApproverNote,
  mainOnAcceptOutcome,
  mainTakeover,
  normaliseEditionIds,
  normaliseFeatures,
  overridesFor,
  removedEditions,
  roleForDepartment,
  sameEditions,
  sameFeatures,
  signoffChanges,
  signoffPaused,
  sortPeople,
  visibleFeatures,
} from "@/lib/users/rules";

describe("abilities", () => {
  it("start from the role's defaults: nothing chosen", () => {
    expect(defaultAbilities("ops")).toEqual({});
    const ops = effectiveAbilities("ops", {});
    expect(ops["costs.edit"]).toBe("yes");
    expect(ops["halls.manage"]).toBe("yes");
    const viewer = effectiveAbilities("viewer", {});
    expect(viewer["signage.create"]).toBe("no");
    expect(viewer["costs.view"]).toBe("yes");
    expect(effectiveAbilities("marketing", {})["signage.create"]).toBe("yes");
    expect(effectiveAbilities("sales", {})["sponsorship.create"]).toBe("yes");
    expect(effectiveAbilities("sales", {})["reports.download"]).toBe("partial");
  });

  it("apply stored differences", () => {
    expect(effectiveAbilities("sales", { "costs.edit": true })["costs.edit"]).toBe("yes");
    expect(effectiveAbilities("ops", { "costs.edit": false })["costs.edit"]).toBe("no");
    expect(effectiveAbility("sales", { "reports.download": true }, "reports.download")).toBe("yes");
  });

  it("store only what differs from the role", () => {
    expect(overridesFor("ops", {})).toEqual({});
    expect(overridesFor("ops", { "costs.edit": true, "halls.manage": true })).toEqual({});
    expect(overridesFor("sales", { "costs.edit": true })).toEqual({ "costs.edit": true });
    expect(overridesFor("ops", { "halls.manage": false })).toEqual({ "halls.manage": false });
    // A partial default is a difference either way.
    expect(overridesFor("sales", { "reports.download": true })).toEqual({
      "reports.download": true,
    });
    expect(overridesFor("sales", { "reports.download": false })).toEqual({
      "reports.download": false,
    });
  });

  it("an ability that follows another stores only a real difference", () => {
    // Bulk follows "Add signage": with it taken away, bulk goes too.
    expect(overridesFor("marketing", { "signage.create": false, "signage.bulk": false })).toEqual({
      "signage.create": false,
    });
    expect(overridesFor("sales", { "signage.create": true, "signage.bulk": true })).toEqual({
      "signage.create": true,
    });
    expect(overridesFor("marketing", { "signage.bulk": false })).toEqual({ "signage.bulk": false });
    expect(
      abilityChanged(
        "marketing",
        { "signage.create": false, "signage.bulk": false },
        "signage.bulk",
      ),
    ).toBe(false);
  });

  it("older stored keys are read through and written out as the new ones", () => {
    const choices = abilityChoices({ "settings.manage": true });
    expect(choices["halls.manage"]).toBe(true);
    expect(choices["organisation.manage"]).toBe(true);
    const o = overridesFor("marketing", choices);
    expect(o).not.toHaveProperty("settings.manage");
    expect(o["events.create"]).toBe(true);
    expect(o["lists.manage"]).toBe(true);
    // Operations with settings.manage off keep all six off.
    expect(overridesFor("ops", abilityChoices({ "settings.manage": false }))).toEqual({
      "events.create": false,
      "events.edit": false,
      "halls.manage": false,
      "suppliers.manage": false,
      "lists.manage": false,
      "organisation.manage": false,
    });
    expect(abilityChoices({ "sponsorship.create": true })["sponsorship.sell"]).toBe(true);
  });

  it("never store anything for admins", () => {
    expect(overridesFor("admin", { "costs.edit": false }, { signoffPaused: true })).toEqual({});
  });

  it("keep a paused sign-off, and only that one approval key", () => {
    const o = overridesFor("marketing", {}, { signoffPaused: true });
    expect(o).toEqual({ "approval.decide": false });
    expect(signoffPaused(o)).toBe(true);
    expect(signoffPaused({})).toBe(false);
    expect(signoffPaused(null)).toBe(false);
    expect(EDITABLE_ABILITY_KEYS).not.toContain("approval.decide");
  });

  it("group the form's abilities, every editable one once", () => {
    const groups = abilityGroups();
    expect(groups.map((g) => g.label)[0]).toBe("Signage and artwork");
    expect(groups.flatMap((g) => g.keys).sort()).toEqual([...EDITABLE_ABILITY_KEYS].sort());
    expect(abilityGroups(["costs.edit"]).map((g) => g.group)).toEqual(["money"]);
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

describe("main approver when they accept", () => {
  it("mainTakeover: an invitee waits while the main can sign; otherwise, and for members, it is now", () => {
    expect(mainTakeover({ hasAccount: false, currentMainCanSign: true })).toBe("on_accept");
    expect(mainTakeover({ hasAccount: false, currentMainCanSign: false })).toBe("now");
    expect(mainTakeover({ hasAccount: true, currentMainCanSign: true })).toBe("now");
    expect(mainTakeover({ hasAccount: true, currentMainCanSign: false })).toBe("now");
  });

  it("mainOnAcceptOutcome: promotes; an archived or non-signing department comes first; someone who can't sign isn't promoted", () => {
    const at = (departmentArchived: boolean, signsOff: boolean, canSign: boolean) =>
      mainOnAcceptOutcome({ departmentArchived, signsOff, canSign });
    expect(at(false, true, true)).toBe("promote");
    expect(at(false, true, false)).toBe("cant_sign");
    expect(at(true, true, true)).toBe("department_off");
    expect(at(false, false, true)).toBe("department_off");
    expect(at(true, false, false)).toBe("department_off");
    expect(at(false, false, false)).toBe("department_off");
  });

  it("mainApproverNote: no main, a main who can't sign, a main who can (invited and member), and someone else's pending ask", () => {
    const base = { person: "Sam", department: "Marketing", pending: null };
    expect(mainApproverNote({ ...base, invited: true, current: null })).toBe(
      "Marketing has no main approver yet.",
    );
    expect(mainApproverNote({ ...base, invited: false, current: null })).toBe(
      "Marketing has no main approver yet.",
    );
    expect(
      mainApproverNote({ ...base, invited: true, current: { name: "Jo", canSign: false } }),
    ).toBe("Replaces Jo, who can't sign off at the moment.");
    expect(
      mainApproverNote({ ...base, invited: false, current: { name: "Jo", canSign: false } }),
    ).toBe("Replaces Jo, who can't sign off at the moment.");
    expect(
      mainApproverNote({ ...base, invited: true, current: { name: "Jo", canSign: true } }),
    ).toBe("Jo stays main approver until Sam accepts, then Sam takes over.");
    expect(
      mainApproverNote({ ...base, invited: false, current: { name: "Jo", canSign: true } }),
    ).toBe("Replaces Jo as main approver.");
    // Someone else's ask: the newest choice wins.
    expect(
      mainApproverNote({
        ...base,
        pending: "Alex",
        invited: true,
        current: { name: "Jo", canSign: true },
      }),
    ).toBe(
      "Jo stays main approver until Sam accepts, then Sam takes over. Alex was going to take over when they accept — Sam will instead.",
    );
    expect(
      mainApproverNote({
        ...base,
        pending: "Alex",
        invited: false,
        current: { name: "Jo", canSign: true },
      }),
    ).toBe("Replaces Jo as main approver. Alex won't take over when they accept.");
    expect(
      mainApproverNote({
        ...base,
        pending: "Alex",
        invited: true,
        current: { name: "Jo", canSign: false },
      }),
    ).toBe("Replaces Jo, who can't sign off at the moment. Alex won't take over when they accept.");
    expect(mainApproverNote({ ...base, pending: "Alex", invited: true, current: null })).toBe(
      "Marketing has no main approver yet. Alex won't take over when they accept.",
    );
  });
});

describe("events per person", () => {
  const codes: Record<string, string> = { a: "BIRM27", b: "LOND27", c: "BIRM28" };
  const all = (id: string) => codes[id] ?? null;
  const onlyA = (id: string) => (id === "a" ? "BIRM27" : null);

  it("normaliseEditionIds: null stays null; lists are de-duplicated and sorted; empty stays empty", () => {
    expect(normaliseEditionIds(null)).toBeNull();
    expect(normaliseEditionIds(undefined)).toBeNull();
    expect(normaliseEditionIds(["b", "a", "b"])).toEqual(["a", "b"]);
    expect(normaliseEditionIds([])).toEqual([]);
  });

  it("sameEditions: order and repeats don't matter; null is only the same as null", () => {
    expect(sameEditions(null, null)).toBe(true);
    expect(sameEditions(["a", "b"], ["b", "a", "a"])).toBe(true);
    expect(sameEditions(["a"], ["a", "b"])).toBe(false);
    expect(sameEditions(null, ["a"])).toBe(false);
    expect(sameEditions(["a"], null)).toBe(false);
  });

  it("eventsSummary: All events, one event by code when the viewer can open it, else a count", () => {
    expect(eventsSummary(null, all)).toBe("All events");
    expect(eventsSummary(["a"], all)).toBe("BIRM27 only");
    expect(eventsSummary(["b"], onlyA)).toBe("1 event");
    expect(eventsSummary(["a", "b", "c"], all)).toBe("3 events");
    expect(eventsSummary(["a", "b"], onlyA)).toBe("2 events");
  });

  it("eventsTitle names only the codes the viewer can open", () => {
    expect(eventsTitle(null, all)).toBe("All events");
    expect(eventsTitle(["a"], all)).toBe("Only BIRM27");
    expect(eventsTitle(["b"], onlyA)).toBe("Only 1 event");
    expect(eventsTitle(["a", "b", "c"], all)).toBe("Only 3 events: BIRM27, LOND27 and BIRM28");
    expect(eventsTitle(["a", "b", "c"], onlyA)).toBe("Only 3 events: BIRM27 and 2 others");
    expect(eventsTitle(["a", "b"], onlyA)).toBe("Only 2 events: BIRM27 and 1 other");
    expect(eventsTitle(["b", "c"], onlyA)).toBe("Only 2 events");
  });

  it("removedEditions: what someone loses (All = every event; to All loses nothing)", () => {
    const every = ["a", "b", "c"];
    expect(removedEditions(null, ["a"], every)).toEqual(["b", "c"]);
    expect(removedEditions(["a", "b"], ["a"], every)).toEqual(["b"]);
    expect(removedEditions(["a", "b"], null, every)).toEqual([]);
    expect(removedEditions(null, null, every)).toEqual([]);
    expect(removedEditions(["a"], ["a", "b"], every)).toEqual([]);
  });

  it("mainApproverNote adds where a limited new main's sign-offs go in other events", () => {
    const base = { person: "Sam", department: "Marketing", pending: null };
    expect(
      mainApproverNote({ ...base, invited: false, current: null, newMainEvents: "BIRM27 only" }),
    ).toBe(
      "Marketing has no main approver yet. Sam only works on BIRM27, so Marketing sign-offs in other events go to everyone in Marketing.",
    );
    expect(
      mainApproverNote({
        ...base,
        invited: true,
        current: { name: "Jo", canSign: true },
        pending: "Alex",
        newMainEvents: "3 events",
      }),
    ).toBe(
      "Jo stays main approver until Sam accepts, then Sam takes over. Alex was going to take over when they accept — Sam will instead. Sam only works on 3 events, so Marketing sign-offs in other events go to everyone in Marketing.",
    );
    expect(mainApproverNote({ ...base, invited: false, current: null, newMainEvents: null })).toBe(
      "Marketing has no main approver yet.",
    );
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
