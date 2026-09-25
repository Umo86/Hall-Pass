import { describe, expect, it } from "vitest";
import {

  applyDecision,
  applyDelegation,
  applyHoldShift,
  ConflictError,
  createRun,
  defaultSignageSteps,
  defaultStandSteps,
  invalidateOnNewVersion,
  resubmitAfterChanges,
  WorkflowError,
  type EngineSettings,
  type Instance,
  type SignageEntityCtx,
  type StandEntityCtx,
} from "@/lib/workflow";
import { signageTransition, type SignageStatus } from "@/lib/status/signage";

const NOW = new Date("2027-03-01T09:00:00Z");
const settings: EngineSettings = { costThresholdForDirector: 5000 };

const plainSignage: SignageEntityCtx = {
  kind: "signage",
  sponsorId: null,
  requiresVenueApproval: false,
  requiresEventDirector: false,
  costEstimate: 1000,
  fixingMethod: "freestanding",
  supplierId: "sup-1",
  category: "organiser",
  // Two sign-offs, one after the other: Marketing (with the first group),
  // then Senior management.
  signoffs: [
    { stepId: "sig-marketing", userId: null },
    { stepId: "sig-senior", userId: null },
  ],
};

const richSignage: SignageEntityCtx = {
  kind: "signage",
  sponsorId: "spo-1",
  requiresVenueApproval: true,
  requiresEventDirector: false,
  costEstimate: 9000,
  fixingMethod: "rigged",
  supplierId: "sup-1",
  category: "sponsor",
  signoffs: null, // the sponsor defaults: Ops, Marketing, Sales, then Senior management
};

const simpleStand: StandEntityCtx = {
  kind: "stand",
  isComplex: false,
  venueRequiresStandApproval: true,
};

function byName(instances: Instance[], name: string): Instance {
  const found = instances.filter((i) => i.stepName === name && i.status !== "invalidated");
  if (found.length === 0) throw new Error(`no active instance named ${name}`);
  return found[found.length - 1];
}

function decideOk(
  instances: Instance[],
  name: string,
  type: "approve" | "confirm" = "approve",
  entity: SignageEntityCtx | StandEntityCtx = plainSignage,
  extras: Partial<Parameters<typeof applyDecision>[1]> = {},
) {
  const inst = byName(instances, name);
  return applyDecision(instances, {
    instanceId: inst.id,
    decision: type === "approve" ? { type: "approve" } : { type: "confirm" },
    decidedBy: "user-1",
    now: NOW,
    entity,
    expectedStatus: inst.status,
    expectedLockedVersionId: null,
    lockedVersionType: "artwork_version",
    lockedVersionId: null,
    lockedSha256: "abc",
    ...extras,
  });
}

describe("run creation (6.1)", () => {
  it("creates one instance per step with snapshots; departments not chosen are skipped but visible", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    expect(run).toHaveLength(8);
    expect(byName(run, "Operations sign-off").status).toBe("skipped"); // not chosen
    expect(byName(run, "Sales sign-off").status).toBe("skipped"); // not chosen
    expect(byName(run, "Venue approval").status).toBe("skipped"); // no venue flag
    expect(byName(run, "Marketing sign-off").status).toBe("pending");
    expect(byName(run, "Senior management sign-off").status).toBe("waiting");
  });

  it("organiser signage defaults to Operations, Marketing and Senior management", () => {
    const entity = { ...plainSignage, signoffs: null };
    const run = createRun({ steps: defaultSignageSteps, entity, settings, runNumber: 1, now: NOW });
    expect(byName(run, "Operations sign-off").status).toBe("pending");
    expect(byName(run, "Marketing sign-off").status).toBe("pending");
    expect(byName(run, "Sales sign-off").status).toBe("skipped");
    expect(byName(run, "Senior management sign-off").status).toBe("waiting");
  });

  it("sponsor signage adds Sales to the first group", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: richSignage, settings, runNumber: 1, now: NOW });
    for (const name of ["Operations sign-off", "Marketing sign-off", "Sales sign-off"]) {
      expect(byName(run, name).status).toBe("pending");
    }
    expect(byName(run, "Venue approval").status).toBe("waiting"); // condition applies
    expect(byName(run, "Senior management sign-off").status).toBe("waiting");
  });

  it("an item can need Marketing only, and one approval then signs it off", () => {
    const entity = { ...plainSignage, signoffs: [{ stepId: "sig-marketing", userId: null }] };
    let run = createRun({ steps: defaultSignageSteps, entity, settings, runNumber: 1, now: NOW });
    expect(run.filter((i) => i.stepKind === "approval" && i.status !== "skipped")).toHaveLength(1);
    const res = decideOk(run, "Marketing sign-off", "approve", entity);
    expect(res.entityEvent.type).toBe("run_approved");
    run = res.instances;
    expect(byName(run, "Sent to print").status).toBe("pending");
  });

  it("a named person on the item gets the step; 'anyone' goes to the department", () => {
    const entity = {
      ...plainSignage,
      signoffs: [
        { stepId: "sig-marketing", userId: "marcus" },
        { stepId: "sig-senior", userId: null },
      ],
    };
    const steps = defaultSignageSteps.map((s) =>
      s.id === "sig-senior" ? { ...s, approverType: "user" as const, approverUserId: "dana" } : s,
    );
    const run = createRun({ steps, entity, settings, runNumber: 1, now: NOW });
    expect(byName(run, "Marketing sign-off").assignedUserId).toBe("marcus");
    expect(byName(run, "Marketing sign-off").assignedRole).toBeNull();
    // An explicit "anyone in Senior management" overrides the default person.
    expect(byName(run, "Senior management sign-off").assignedUserId).toBeNull();
    expect(byName(run, "Senior management sign-off").assignedRole).toBe("event_director");
  });

  it("with the defaults, a step's default person is used", () => {
    const steps = defaultSignageSteps.map((s) =>
      s.id === "sig-marketing"
        ? { ...s, approverType: "user" as const, approverUserId: "user-42" }
        : s,
    );
    const run = createRun({ steps, entity: { ...plainSignage, signoffs: null }, settings, runNumber: 1, now: NOW });
    const inst = byName(run, "Marketing sign-off");
    expect(inst.assignedUserId).toBe("user-42");
    expect(inst.assignedRole).toBeNull();
  });

  it("stand run: engineer step only when complex; venue only when the venue requires it", () => {
    const simple = createRun({ steps: defaultStandSteps, entity: simpleStand, settings, runNumber: 1, now: NOW });
    expect(byName(simple, "Structural engineer review").status).toBe("skipped");
    expect(byName(simple, "Venue approval").status).toBe("waiting");

    const complex = createRun({
      steps: defaultStandSteps,
      entity: { kind: "stand", isComplex: true, venueRequiresStandApproval: false },
      settings,
      runNumber: 1,
      now: NOW,
    });
    expect(byName(complex, "Structural engineer review").status).toBe("waiting");
    expect(byName(complex, "Venue approval").status).toBe("skipped");
  });
});

describe("activation (6.2)", () => {
  it("parallel group activates together with due dates from SLA", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: richSignage, settings, runNumber: 1, now: NOW });
    const marketing = byName(run, "Marketing sign-off");
    const sponsor = byName(run, "Sales sign-off");
    expect(marketing.status).toBe("pending");
    expect(sponsor.status).toBe("pending");
    expect(marketing.pendingSince).toEqual(NOW);
    expect(marketing.dueAt).toEqual(new Date("2027-03-04T09:00:00Z")); // +3 days
    expect(sponsor.dueAt).toEqual(new Date("2027-03-06T09:00:00Z")); // +5 days
  });

  it("next stage activates only when every instance in the group is settled", () => {
    let run = createRun({ steps: defaultSignageSteps, entity: richSignage, settings, runNumber: 1, now: NOW });
    run = decideOk(run, "Marketing sign-off", "approve", richSignage).instances;
    run = decideOk(run, "Sales sign-off", "approve", richSignage).instances;
    expect(byName(run, "Venue approval").status).toBe("waiting"); // Operations still pending
    run = decideOk(run, "Operations sign-off", "approve", richSignage).instances;
    expect(byName(run, "Venue approval").status).toBe("pending");
  });

  it("skipped steps do not block activation", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const afterMarketing = decideOk(run, "Marketing sign-off").instances;
    // Operations and Sales (same group) were not chosen, so the next step activates.
    expect(byName(afterMarketing, "Senior management sign-off").status).toBe("pending");
  });
});

describe("decisions (6.3)", () => {
  it("the run is approved when the last approval step settles, before production", () => {
    let run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    run = decideOk(run, "Marketing sign-off").instances;
    const approved = decideOk(run, "Senior management sign-off");
    expect(approved.entityEvent.type).toBe("run_approved");
    // Production tracking starts straight away.
    expect(byName(approved.instances, "Sent to print").status).toBe("pending");
    run = approved.instances;
    for (const step of ["Sent to print", "Delivered", "Installed"]) {
      const res = decideOk(run, step, "confirm");
      // Confirmations never re-approve; the action maps them to their own events.
      expect(res.entityEvent.type).toBe("none");
      run = res.instances;
    }
    expect(run.every((i) => ["approved", "confirmed", "skipped"].includes(i.status))).toBe(true);
  });

  it("an item walks from review to installed through legal transitions only", () => {
    let run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    let status: SignageStatus = "in_review";
    const CONFIRMATION_EVENTS = {
      "Sent to print": "sent_to_print",
      Delivered: "delivered",
      Installed: "installed",
    } as const;
    const steps: Array<[string, "approve" | "confirm"]> = [
      ["Marketing sign-off", "approve"],
      ["Senior management sign-off", "approve"],
      ["Sent to print", "confirm"],
      ["Delivered", "confirm"],
      ["Installed", "confirm"],
    ];
    for (const [name, type] of steps) {
      const res = decideOk(run, name, type);
      run = res.instances;
      if (res.entityEvent.type === "run_approved") status = signageTransition(status, "run_approved");
      else if (type === "confirm") {
        status = signageTransition(status, CONFIRMATION_EVENTS[name as keyof typeof CONFIRMATION_EVENTS]);
      }
    }
    expect(status).toBe("installed");
  });

  it("any conditions anywhere make the run approved_with_conditions", () => {
    let run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const marketing = byName(run, "Marketing sign-off");
    run = applyDecision(run, {
      instanceId: marketing.id,
      decision: { type: "approve_with_conditions", conditionsText: "Use the 2027 logo" },
      decidedBy: "user-1",
      now: NOW,
      entity: plainSignage,
      expectedStatus: "pending",
      expectedLockedVersionId: null,
      lockedVersionType: "artwork_version",
      lockedVersionId: null,
      lockedSha256: null,
    }).instances;
    const final = decideOk(run, "Senior management sign-off");
    expect(final.entityEvent.type).toBe("run_approved_with_conditions");
  });

  it("request_changes and reject need a comment; approve_with_conditions needs text", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const inst = byName(run, "Marketing sign-off");
    const base = {
      instanceId: inst.id,
      decidedBy: "u",
      now: NOW,
      entity: plainSignage,
      expectedStatus: "pending",
      expectedLockedVersionId: null,
      lockedVersionType: "artwork_version" as const,
      lockedVersionId: null,
      lockedSha256: null,
    };
    expect(() =>
      applyDecision(run, { ...base, decision: { type: "request_changes", comment: " " } }),
    ).toThrow(WorkflowError);
    expect(() => applyDecision(run, { ...base, decision: { type: "reject", comment: "" } })).toThrow(
      WorkflowError,
    );
    expect(() =>
      applyDecision(run, {
        ...base,
        decision: { type: "approve_with_conditions", conditionsText: " " },
      }),
    ).toThrow(WorkflowError);
  });

  it("confirmation steps cannot be approved; approval steps cannot be confirmed", () => {
    let run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const marketing = byName(run, "Marketing sign-off");
    expect(() =>
      applyDecision(run, {
        instanceId: marketing.id,
        decision: { type: "confirm" },
        decidedBy: "u",
        now: NOW,
        entity: plainSignage,
        expectedStatus: "pending",
        expectedLockedVersionId: null,
        lockedVersionType: null,
        lockedVersionId: null,
        lockedSha256: null,
      }),
    ).toThrow(WorkflowError);
    run = decideOk(run, "Marketing sign-off").instances;
    run = decideOk(run, "Senior management sign-off").instances;
    const print = byName(run, "Sent to print");
    expect(() =>
      applyDecision(run, {
        instanceId: print.id,
        decision: { type: "approve" },
        decidedBy: "u",
        now: NOW,
        entity: plainSignage,
        expectedStatus: "pending",
        expectedLockedVersionId: null,
        lockedVersionType: null,
        lockedVersionId: null,
        lockedSha256: null,
      }),
    ).toThrow(WorkflowError);
  });

  it("optimistic lock: stale expected status or version conflicts", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const inst = byName(run, "Marketing sign-off");
    // Two clients open the same step. First decides fine.
    const first = decideOk(run, "Marketing sign-off");
    expect(first.decided.status).toBe("approved");
    // Second still believes it is pending → conflict against the updated set.
    expect(() =>
      applyDecision(first.instances, {
        instanceId: inst.id,
        decision: { type: "approve" },
        decidedBy: "user-2",
        now: NOW,
        entity: plainSignage,
        expectedStatus: "pending",
        expectedLockedVersionId: null,
        lockedVersionType: "artwork_version",
        lockedVersionId: null,
        lockedSha256: null,
      }),
    ).toThrow(ConflictError);
    // A stale locked version also conflicts.
    expect(() =>
      applyDecision(run, {
        instanceId: inst.id,
        decision: { type: "approve" },
        decidedBy: "user-2",
        now: NOW,
        entity: plainSignage,
        expectedStatus: "pending",
        expectedLockedVersionId: "v1",
        lockedVersionType: "artwork_version",
        lockedVersionId: "v2",
        lockedSha256: null,
      }),
    ).toThrow(ConflictError);
  });

  it("supplier step with no supplier falls back to ops and is flagged", () => {
    const noSupplier = { ...plainSignage, supplierId: null };
    let run = createRun({ steps: defaultSignageSteps, entity: noSupplier, settings, runNumber: 1, now: NOW });
    run = decideOk(run, "Marketing sign-off", "approve", noSupplier).instances;
    run = decideOk(run, "Senior management sign-off", "approve", noSupplier).instances;
    const print = byName(run, "Sent to print");
    expect(print.status).toBe("pending");
    expect(print.assignedRole).toBe("ops");
    expect(print.noSupplierFallback).toBe(true);
  });
});

describe("delegation (6.3)", () => {
  it("stores the delegator and reassigns to the named user", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const inst = byName(run, "Marketing sign-off");
    const after = applyDelegation(run, { instanceId: inst.id, toUserId: "kate", fromUserId: "mark" });
    const delegated = byName(after, "Marketing sign-off");
    expect(delegated.assignedUserId).toBe("kate");
    expect(delegated.delegatedFromUserId).toBe("mark");
  });

  it("only pending steps can be delegated", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const waiting = byName(run, "Senior management sign-off");
    expect(() =>
      applyDelegation(run, { instanceId: waiting.id, toUserId: "a", fromUserId: "b" }),
    ).toThrow(WorkflowError);
  });
});

describe("changes-requested restart (6.3)", () => {
  function runToOpsChangesRequested() {
    let run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    run = decideOk(run, "Marketing sign-off").instances;
    const ops = byName(run, "Senior management sign-off");
    const res = applyDecision(run, {
      instanceId: ops.id,
      decision: { type: "request_changes", comment: "Wrong size" },
      decidedBy: "ops-user",
      now: NOW,
      entity: plainSignage,
      expectedStatus: "pending",
      expectedLockedVersionId: null,
      lockedVersionType: "artwork_version",
      lockedVersionId: null,
      lockedSha256: null,
    });
    expect(res.entityEvent.type).toBe("changes_requested");
    return res.instances;
  }

  it("restart_from_here=true resets from the requesting step; earlier approvals stand", () => {
    const run = runToOpsChangesRequested();
    const result = resubmitAfterChanges(run, { entity: plainSignage, now: NOW });
    expect(result.mode).toBe("restart_from_step");
    if (result.mode !== "restart_from_step") return;
    expect(byName(result.instances, "Marketing sign-off").status).toBe("approved"); // stands
    expect(byName(result.instances, "Senior management sign-off").status).toBe("pending"); // reset
    expect(byName(result.instances, "Sent to print").status).toBe("waiting");
  });

  it("restart_from_here=false demands a whole new run", () => {
    const steps = defaultSignageSteps.map((s) =>
      s.id === "sig-senior" ? { ...s, restartFromHereOnChanges: false } : s,
    );
    let run = createRun({ steps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    run = decideOk(run, "Marketing sign-off").instances;
    const ops = byName(run, "Senior management sign-off");
    const res = applyDecision(run, {
      instanceId: ops.id,
      decision: { type: "request_changes", comment: "Redo" },
      decidedBy: "ops-user",
      now: NOW,
      entity: plainSignage,
      expectedStatus: "pending",
      expectedLockedVersionId: null,
      lockedVersionType: "artwork_version",
      lockedVersionId: null,
      lockedSha256: null,
    });
    const result = resubmitAfterChanges(res.instances, { entity: plainSignage, now: NOW });
    expect(result.mode).toBe("new_run");
  });
});

describe("invalidation on new version (6.4)", () => {
  it("invalidates exactly the configured decided steps and re-creates them in position", () => {
    let run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    run = decideOk(run, "Marketing sign-off").instances;
    run = decideOk(run, "Senior management sign-off").instances;
    run = decideOk(run, "Sent to print", "confirm").instances;
    run = decideOk(run, "Delivered", "confirm").instances; // invalidate_on_new_version = false

    const { instances, invalidated } = invalidateOnNewVersion(run, { entity: plainSignage, now: NOW });
    const invalidatedNames = invalidated.map((i) => i.stepName).sort();
    // Delivered has invalidate=false so its confirmation stands.
    expect(invalidatedNames).toEqual(["Marketing sign-off", "Senior management sign-off", "Sent to print"].sort());
    expect(byName(instances, "Delivered").status).toBe("confirmed");
    // Fresh instances exist and the earliest re-created step is pending again.
    expect(byName(instances, "Marketing sign-off").status).toBe("pending");
    expect(byName(instances, "Senior management sign-off").status).toBe("waiting");
    expect(byName(instances, "Sent to print").status).toBe("waiting");
    // Superseded rows are kept for history.
    expect(instances.filter((i) => i.status === "invalidated")).toHaveLength(3);
  });

  it("no decided invalidatable steps → nothing changes", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const { instances, invalidated } = invalidateOnNewVersion(run, { entity: plainSignage, now: NOW });
    expect(invalidated).toHaveLength(0);
    expect(instances.filter((i) => i.status === "invalidated")).toHaveLength(0);
  });
});

describe("hold shifting (5.1)", () => {
  it("shifts due dates of pending instances by the hold duration", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const shifted = applyHoldShift(run, 4);
    const marketing = byName(shifted, "Marketing sign-off");
    expect(marketing.dueAt).toEqual(new Date("2027-03-08T09:00:00Z")); // +3 SLA +4 hold
    expect(marketing.holdShiftDays).toBe(4);
    // Waiting instances untouched.
    expect(byName(shifted, "Senior management sign-off").dueAt).toBeNull();
  });
});
