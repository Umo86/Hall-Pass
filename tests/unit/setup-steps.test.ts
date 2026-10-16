/**
 * The event setup checklist: how the facts about an event and its
 * organisation become steps, and how progress is counted. Pure.
 */
import { describe, expect, it } from "vitest";
import {
  buildSetupSteps,
  signoffState,
  summariseSetup,
  type EditionSetupFacts,
  type OrgSetupFacts,
  type SetupPermissions,
} from "@/lib/queries/setup";

const everyone: SetupPermissions = { canSetup: true, canUsers: true, canAddSigns: true };

function facts(over: Partial<EditionSetupFacts> = {}): EditionSetupFacts {
  return {
    setupChecked: [],
    dates: {
      buildStart: "2027-10-03",
      openStart: "2027-10-05",
      openEnd: "2027-10-07",
      breakdownEnd: "2027-10-08",
    },
    copied: false,
    halls: [],
    signCount: 0,
    draftSignCount: 0,
    sponsorCount: 0,
    sponsorshipItemCount: 0,
    deadlines: [
      { key: "artwork_due", label: "Artwork due", date: "2027-09-12" },
      { key: "print_deadline", label: "Print deadline", date: "2027-09-19" },
    ],
    ...over,
  };
}

const marketing = (over: Partial<OrgSetupFacts["signoffDepartments"][number]> = {}) => ({
  name: "Marketing",
  forOrganiser: true,
  approvers: [{ name: "Marcus", email: "marcus@x.test", isMain: true, active: true }],
  ...over,
});

function org(over: Partial<OrgSetupFacts> = {}): OrgSetupFacts {
  return {
    signageWorkflow: true,
    signoffDepartments: [marketing()],
    memberCount: 1,
    openInviteCount: 0,
    signTypeCount: 12,
    supplierCount: 0,
    ...over,
  };
}

const byKey = (steps: ReturnType<typeof buildSetupSteps>) =>
  Object.fromEntries(steps.map((s) => [s.key, s]));

describe("a brand-new event", () => {
  const steps = buildSetupSteps({ code: "LON27" }, facts(), org(), everyone);
  const s = byKey(steps);

  it("lists the nine steps in order", () => {
    expect(steps.map((x) => x.key)).toEqual([
      "details",
      "halls",
      "deadlines",
      "signoff",
      "people",
      "types",
      "suppliers",
      "signs",
      "sponsorship",
    ]);
  });

  it("has six essentials; people is recommended, suppliers and sponsorship optional", () => {
    expect(steps.filter((x) => x.required).map((x) => x.key)).toEqual([
      "details",
      "halls",
      "deadlines",
      "signoff",
      "types",
      "signs",
    ]);
    expect(s.people.level).toBe("recommended");
    expect(s.suppliers.state).toBe("optional");
    expect(s.sponsorship.state).toBe("optional");
  });

  it("dates and deadlines wait for someone to confirm them", () => {
    expect(s.details.state).toBe("todo");
    expect(s.details.detail).toMatch(/assumed/);
    expect(s.deadlines.state).toBe("todo");
    expect(s.deadlines.detail).toMatch(/Artwork due .*Print/);
  });

  it("counts what is done from the data", () => {
    expect(s.signoff.state).toBe("done");
    expect(s.types.state).toBe("done");
    expect(s.halls.state).toBe("todo");
    expect(s.halls.detail).toBe("No halls yet");
    expect(s.signs.state).toBe("todo");
    expect(s.people.state).toBe("todo");
    expect(summariseSetup(steps)).toMatchObject({ done: 2, total: 6, complete: false });
    expect(summariseSetup(steps).next?.key).toBe("details");
  });

  it("links each step to where it's done", () => {
    expect(s.details.href).toBe("/LON27/setup#details");
    expect(s.halls.href).toBe("/LON27/halls");
    expect(s.signoff.href).toBe("/users?tab=departments");
    expect(s.people.href).toBe("/users/new");
    expect(s.signs.href).toBe("/LON27/signage/new");
  });
});

describe("finishing setup", () => {
  it("is complete once every essential is done, whatever the optional steps say", () => {
    const steps = buildSetupSteps(
      { code: "LON27" },
      facts({
        setupChecked: ["details", "deadlines"],
        halls: [{ name: "Hall 1", locations: 3 }],
        signCount: 1,
      }),
      org(),
      everyone,
    );
    const summary = summariseSetup(steps);
    expect(summary).toMatchObject({ done: 6, total: 6, complete: true, next: null });
    expect(byKey(steps).suppliers.state).toBe("optional");
  });

  it("'dismissed' only hides the dashboard card; it confirms nothing", () => {
    const steps = buildSetupSteps(
      { code: "X" },
      facts({ setupChecked: ["dismissed"] }),
      org(),
      everyone,
    );
    expect(byKey(steps).details.state).toBe("todo");
  });
});

describe("halls and locations", () => {
  it("needs at least one hall, each with a location", () => {
    const one = buildSetupSteps(
      { code: "X" },
      facts({
        halls: [
          { name: "Hall 1", locations: 2 },
          { name: "Hall 3", locations: 0 },
        ],
      }),
      org(),
      everyone,
    );
    expect(byKey(one).halls.state).toBe("todo");
    expect(byKey(one).halls.detail).toBe("Hall 3 has no locations yet");
    const ok = buildSetupSteps(
      { code: "X" },
      facts({
        halls: [
          { name: "Hall 1", locations: 2 },
          { name: "Hall 2", locations: 10 },
        ],
      }),
      org(),
      everyone,
    );
    expect(byKey(ok).halls.state).toBe("done");
    expect(byKey(ok).halls.detail).toBe("2 halls · 12 locations");
  });
});

describe("first signs after a copy", () => {
  it("says the copied signs are drafts to review", () => {
    const steps = buildSetupSteps(
      { code: "X" },
      facts({ copied: true, signCount: 124, draftSignCount: 124 }),
      org(),
      everyone,
    );
    expect(byKey(steps).signs.state).toBe("done");
    expect(byKey(steps).signs.detail).toBe("124 signs copied as drafts — review them");
  });
});

describe("people", () => {
  it("is done with a second person or an open invitation", () => {
    expect(
      byKey(buildSetupSteps({ code: "X" }, facts(), org({ memberCount: 2 }), everyone)).people
        .state,
    ).toBe("done");
    const invited = byKey(
      buildSetupSteps({ code: "X" }, facts(), org({ openInviteCount: 1 }), everyone),
    ).people;
    expect(invited.state).toBe("done");
    expect(invited.detail).toBe("1 person · 1 invitation open");
  });
});

describe("who can act on each step", () => {
  it("follows the permissions: setup, users and signs separately", () => {
    const ops = byKey(
      buildSetupSteps({ code: "X" }, facts(), org(), {
        canSetup: true,
        canUsers: false,
        canAddSigns: true,
      }),
    );
    expect(ops.details.canAct).toBe(true);
    expect(ops.halls.canAct).toBe(true);
    expect(ops.signoff.canAct).toBe(false);
    expect(ops.people.canAct).toBe(false);
    const viewer = byKey(
      buildSetupSteps({ code: "X" }, facts(), org(), {
        canSetup: false,
        canUsers: false,
        canAddSigns: false,
      }),
    );
    expect(Object.values(viewer).every((s) => !s.canAct)).toBe(true);
  });
});

describe("who signs off", () => {
  it("needs the workflow and a department that signs off", () => {
    expect(signoffState(org({ signageWorkflow: false })).state).toBe("todo");
    expect(signoffState(org({ signoffDepartments: [] })).state).toBe("todo");
  });

  it("needs a department that signs organiser signage", () => {
    const res = signoffState(org({ signoffDepartments: [marketing({ forOrganiser: false })] }));
    expect(res.state).toBe("todo");
    expect(res.detail).toMatch(/organiser signage/);
  });

  it("each organiser department needs someone who can sign", () => {
    const res = signoffState(
      org({ signoffDepartments: [marketing(), marketing({ name: "Operations", approvers: [] })] }),
    );
    expect(res).toEqual({ state: "todo", detail: "Operations: nobody to sign off yet" });
  });

  it("waits for a main approver who hasn't accepted their invitation", () => {
    const res = signoffState(
      org({
        signoffDepartments: [
          marketing({
            approvers: [{ name: "Dana", email: "dana@x.test", isMain: true, active: false }],
          }),
        ],
      }),
    );
    expect(res.state).toBe("waiting");
    expect(res.detail).toBe("Waiting for dana@x.test to accept their invitation");
  });

  it("is ready when anyone in the department can sign (no main approver starred)", () => {
    const res = signoffState(
      org({
        signoffDepartments: [
          marketing({
            approvers: [
              { name: "A", email: "a@x.test", isMain: false, active: false },
              { name: "B", email: "b@x.test", isMain: false, active: true },
            ],
          }),
          { name: "Sales", forOrganiser: false, approvers: [] },
        ],
      }),
    );
    expect(res).toEqual({ state: "done", detail: "Marketing and Sales sign off" });
  });
});
