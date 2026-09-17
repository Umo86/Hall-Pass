import { describe, expect, it } from "vitest";
import {
  activate,
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
};

const richSignage: SignageEntityCtx = {
  kind: "signage",
  sponsorId: "spo-1",
  requiresVenueApproval: true,
  requiresEventDirector: false,
  costEstimate: 9000,
  fixingMethod: "rigged",
  supplierId: "sup-1",
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
  it("creates one instance per step with snapshots; non-applicable steps are skipped but visible", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    expect(run).toHaveLength(8);
    expect(byName(run, "Sponsor approval").status).toBe("skipped"); // not sponsored
    expect(byName(run, "Venue approval").status).toBe("skipped"); // no venue flag
    expect(byName(run, "Event Director sign-off").status).toBe("skipped"); // no flag, under threshold
    expect(byName(run, "Marketing brand check").status).toBe("pending");
    expect(byName(run, "Ops technical check").status).toBe("waiting");
  });

  it("evaluates every condition with any-of semantics", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: richSignage, settings, runNumber: 1, now: NOW });
    expect(byName(run, "Sponsor approval").status).toBe("pending"); // if_sponsored, group A with marketing
    expect(byName(run, "Marketing brand check").status).toBe("pending");
    expect(byName(run, "Venue approval").status).toBe("waiting"); // applies
    expect(byName(run, "Event Director sign-off").status).toBe("waiting"); // cost over threshold
  });

  it("director step applies via if_requires_event_director alone", () => {
    const entity = { ...plainSignage, requiresEventDirector: true };
    const run = createRun({ steps: defaultSignageSteps, entity, settings, runNumber: 1, now: NOW });
    expect(byName(run, "Event Director sign-off").status).toBe("waiting");
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
    const marketing = byName(run, "Marketing brand check");
    const sponsor = byName(run, "Sponsor approval");
    expect(marketing.status).toBe("pending");
    expect(sponsor.status).toBe("pending");
    expect(marketing.pendingSince).toEqual(NOW);
    expect(marketing.dueAt).toEqual(new Date("2027-03-04T09:00:00Z")); // +3 days
    expect(sponsor.dueAt).toEqual(new Date("2027-03-06T09:00:00Z")); // +5 days
  });

  it("next stage activates only when every instance in the group is settled", () => {
    let run = createRun({ steps: defaultSignageSteps, entity: richSignage, settings, runNumber: 1, now: NOW });
    run = decideOk(run, "Marketing brand check", "approve", richSignage).instances;
    expect(byName(run, "Ops technical check").status).toBe("waiting"); // sponsor still pending
    run = decideOk(run, "Sponsor approval", "approve", richSignage).instances;
    expect(byName(run, "Ops technical check").status).toBe("pending");
  });

  it("skipped steps do not block activation", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const afterMarketing = decideOk(run, "Marketing brand check").instances;
    // Sponsor (same group) is skipped, so ops activates immediately.
    expect(byName(afterMarketing, "Ops technical check").status).toBe("pending");
  });
});

describe("decisions (6.3)", () => {
  it("full happy path completes the run as approved", () => {
    let run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    run = decideOk(run, "Marketing brand check").instances;
    run = decideOk(run, "Ops technical check").instances;
    run = decideOk(run, "Sent to print", "confirm").instances;
    run = decideOk(run, "Delivered", "confirm").instances;
    const final = decideOk(run, "Installed", "confirm");
    expect(final.entityEvent.type).toBe("run_approved");
  });

  it("any conditions anywhere make the run approved_with_conditions", () => {
    let run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const marketing = byName(run, "Marketing brand check");
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
    run = decideOk(run, "Ops technical check").instances;
    run = decideOk(run, "Sent to print", "confirm").instances;
    run = decideOk(run, "Delivered", "confirm").instances;
    const final = decideOk(run, "Installed", "confirm");
    expect(final.entityEvent.type).toBe("run_approved_with_conditions");
  });

  it("request_changes and reject need a comment; approve_with_conditions needs text", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const inst = byName(run, "Marketing brand check");
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
    const marketing = byName(run, "Marketing brand check");
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
    run = decideOk(run, "Marketing brand check").instances;
    run = decideOk(run, "Ops technical check").instances;
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
    const inst = byName(run, "Marketing brand check");
    // Two clients open the same step. First decides fine.
    const first = decideOk(run, "Marketing brand check");
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
    run = decideOk(run, "Marketing brand check", "approve", noSupplier).instances;
    run = decideOk(run, "Ops technical check", "approve", noSupplier).instances;
    const print = byName(run, "Sent to print");
    expect(print.status).toBe("pending");
    expect(print.assignedRole).toBe("ops");
    expect(print.noSupplierFallback).toBe(true);
  });
});

describe("delegation (6.3)", () => {
  it("stores the delegator and reassigns to the named user", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const inst = byName(run, "Marketing brand check");
    const after = applyDelegation(run, { instanceId: inst.id, toUserId: "kate", fromUserId: "mark" });
    const delegated = byName(after, "Marketing brand check");
    expect(delegated.assignedUserId).toBe("kate");
    expect(delegated.delegatedFromUserId).toBe("mark");
  });

  it("only pending steps can be delegated", () => {
    const run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    const waiting = byName(run, "Ops technical check");
    expect(() =>
      applyDelegation(run, { instanceId: waiting.id, toUserId: "a", fromUserId: "b" }),
    ).toThrow(WorkflowError);
  });
});

describe("changes-requested restart (6.3)", () => {
  function runToOpsChangesRequested() {
    let run = createRun({ steps: defaultSignageSteps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    run = decideOk(run, "Marketing brand check").instances;
    const ops = byName(run, "Ops technical check");
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
    expect(byName(result.instances, "Marketing brand check").status).toBe("approved"); // stands
    expect(byName(result.instances, "Ops technical check").status).toBe("pending"); // reset
    expect(byName(result.instances, "Sent to print").status).toBe("waiting");
  });

  it("restart_from_here=false demands a whole new run", () => {
    const steps = defaultSignageSteps.map((s) =>
      s.id === "sig-ops" ? { ...s, restartFromHereOnChanges: false } : s,
    );
    let run = createRun({ steps, entity: plainSignage, settings, runNumber: 1, now: NOW });
    run = decideOk(run, "Marketing brand check").instances;
    const ops = byName(run, "Ops technical check");
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
    run = decideOk(run, "Marketing brand check").instances;
    run = decideOk(run, "Ops technical check").instances;
    run = decideOk(run, "Sent to print", "confirm").instances;
    run = decideOk(run, "Delivered", "confirm").instances; // invalidate_on_new_version = false

    const { instances, invalidated } = invalidateOnNewVersion(run, { entity: plainSignage, now: NOW });
    const invalidatedNames = invalidated.map((i) => i.stepName).sort();
    // Delivered has invalidate=false so its confirmation stands.
    expect(invalidatedNames).toEqual(["Marketing brand check", "Ops technical check", "Sent to print"]);
    expect(byName(instances, "Delivered").status).toBe("confirmed");
    // Fresh instances exist and the earliest re-created step is pending again.
    expect(byName(instances, "Marketing brand check").status).toBe("pending");
    expect(byName(instances, "Ops technical check").status).toBe("waiting");
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
    const marketing = byName(shifted, "Marketing brand check");
    expect(marketing.dueAt).toEqual(new Date("2027-03-08T09:00:00Z")); // +3 SLA +4 hold
    expect(marketing.holdShiftDays).toBe(4);
    // Waiting instances untouched.
    expect(byName(shifted, "Ops technical check").dueAt).toBeNull();
  });
});
