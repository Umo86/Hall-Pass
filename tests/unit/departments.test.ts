import { describe, expect, it } from "vitest";
import {
  createRun,
  defaultSignageSteps,
  defaultSignoffs,
  isDepartmentStep,
  type SignageEntityCtx,
  type StepDef,
} from "@/lib/workflow";
import { can, type ApprovalStepCtx, type StaffActor } from "@/lib/authz";
import { orderSignageSteps, signoffStepName } from "@/lib/domain/departments";

const NOW = new Date("2027-03-01T09:00:00Z");
const settings = { costThresholdForDirector: 5000 };

// The default steps, each department step belonging to a department.
const DEPT = {
  "sig-ops": "dept-ops",
  "sig-marketing": "dept-marketing",
  "sig-sales": "dept-sales",
  "sig-senior": "dept-senior",
} as Record<string, string>;
const steps: StepDef[] = defaultSignageSteps.map((s) =>
  DEPT[s.id] ? { ...s, departmentId: DEPT[s.id], approverRole: null } : s,
);

const organiser: SignageEntityCtx = {
  kind: "signage",
  sponsorId: null,
  requiresVenueApproval: false,
  requiresEventDirector: false,
  costEstimate: 100,
  fixingMethod: "freestanding",
  supplierId: "sup-1",
  category: "organiser",
  signoffs: null,
};

const run = (entity: SignageEntityCtx, stepDefs = steps) =>
  createRun({ steps: stepDefs, entity, settings, runNumber: 1, now: NOW });

describe("department sign-offs", () => {
  it("go to anyone in the department by default", () => {
    const marketing = run(organiser).find((i) => i.stepId === "sig-marketing")!;
    expect(marketing.status).toBe("pending");
    expect(marketing.assignedDepartmentId).toBe("dept-marketing");
    expect(marketing.assignedRole).toBeNull();
    expect(marketing.assignedUserId).toBeNull();
  });

  it("go to the main approver when the department has one", () => {
    const withMain = steps.map((s) =>
      s.id === "sig-marketing" ? { ...s, approverType: "user" as const, approverUserId: "maya" } : s,
    );
    const marketing = run(organiser, withMain).find((i) => i.stepId === "sig-marketing")!;
    expect(marketing.assignedUserId).toBe("maya");
    expect(marketing.assignedDepartmentId).toBe("dept-marketing");
  });

  it("follow the item's choices: a named person, or anyone in the department", () => {
    const instances = run({
      ...organiser,
      signoffs: [
        { stepId: "sig-marketing", userId: "marcus" },
        { stepId: "sig-senior", userId: null },
      ],
    });
    const byStep = new Map(instances.map((i) => [i.stepId, i]));
    expect(byStep.get("sig-ops")!.status).toBe("skipped");
    expect(byStep.get("sig-marketing")!.assignedUserId).toBe("marcus");
    expect(byStep.get("sig-senior")!.assignedUserId).toBeNull();
    expect(byStep.get("sig-senior")!.assignedDepartmentId).toBe("dept-senior");
    // Senior management signs last: it waits for Marketing.
    expect(byStep.get("sig-senior")!.status).toBe("waiting");
  });

  it("a department only ticked per item still counts as a sign-off step", () => {
    const legal: StepDef = {
      ...steps.find((s) => s.id === "sig-ops")!,
      id: "sig-legal",
      name: "Legal sign-off",
      departmentId: "dept-legal",
      defaultFor: [],
    };
    expect(isDepartmentStep(legal)).toBe(true);
    expect(defaultSignoffs([legal], "organiser")).toEqual([]);
    const instances = run(
      { ...organiser, signoffs: [{ stepId: "sig-legal", userId: null }] },
      [...steps, legal],
    );
    expect(instances.find((i) => i.stepId === "sig-legal")!.status).toBe("pending");
  });
});

describe("who can decide a department sign-off", () => {
  const actor = (departmentIds: string[], role: StaffActor["role"] = "viewer"): StaffActor => ({
    kind: "staff",
    userId: "u-1",
    organisationId: "org-1",
    role,
    departmentIds,
  });
  const step = (over: Partial<ApprovalStepCtx>): ApprovalStepCtx => ({
    assignedRole: null,
    assignedUserId: null,
    entity: { type: "signage_item", item: { editionId: "ed-1", venueId: "v-1" } },
    ...over,
  });

  it("anyone in the department, including view-only approvers", () => {
    const s = step({ assignedDepartmentId: "dept-marketing" });
    expect(can(actor(["dept-marketing"]), { type: "approval.decide", step: s })).toBe(true);
    expect(can(actor(["dept-sales"]), { type: "approval.decide", step: s })).toBe(false);
    // A role no longer decides a department's sign-off on its own.
    expect(can(actor([], "marketing"), { type: "approval.decide", step: s })).toBe(false);
  });

  it("only the named person when one is picked", () => {
    const s = step({ assignedDepartmentId: "dept-marketing", assignedUserId: "someone-else" });
    expect(can(actor(["dept-marketing"]), { type: "approval.decide", step: s })).toBe(false);
    expect(can(actor([], "admin"), { type: "approval.decide", step: s })).toBe(true);
  });

  it("switching off someone's sign-off right still wins", () => {
    const s = step({ assignedDepartmentId: "dept-marketing" });
    const off: StaffActor = { ...actor(["dept-marketing"]), overrides: { "approval.decide": false } };
    expect(can(off, { type: "approval.decide", step: s })).toBe(false);
  });
});

describe("sign-off order", () => {
  const step = (id: string, kind: "approval" | "confirmation", departmentId: string | null, sortOrder: number) => ({
    id,
    kind,
    departmentId,
    sortOrder,
    parallelGroup: null,
    isArchived: false,
  });
  const dept = (id: string, name: string, sortOrder: number, signsLast = false, isArchived = false) => ({
    id,
    name,
    sortOrder,
    signsLast,
    isArchived,
  });

  it("departments together, then venue, then those that sign last, then confirmations", () => {
    const order = orderSignageSteps(
      [
        step("print", "confirmation", null, 6),
        step("venue", "approval", null, 4),
        step("senior", "approval", "d-senior", 5),
        step("mkt", "approval", "d-mkt", 2),
        step("ops", "approval", "d-ops", 1),
        step("legal", "approval", "d-legal", 9),
      ],
      [
        dept("d-ops", "Operations", 1),
        dept("d-mkt", "Marketing", 2),
        dept("d-senior", "Senior management", 3, true),
        dept("d-legal", "Legal", 4),
      ],
    );
    expect(order.map((o) => o.id)).toEqual(["ops", "mkt", "legal", "venue", "senior", "print"]);
    expect(order.find((o) => o.id === "legal")!.parallelGroup).toBe(1);
    expect(order.find((o) => o.id === "senior")!.parallelGroup).toBeNull();
    expect(order.map((o) => o.sortOrder)).toEqual([1, 2, 3, 4, 5, 6]);
  });

  it("removed departments drop out; two final departments sign together", () => {
    const order = orderSignageSteps(
      [
        step("ops", "approval", "d-ops", 1),
        { ...step("old", "approval", "d-old", 2), isArchived: true },
        step("senior", "approval", "d-senior", 3),
        step("board", "approval", "d-board", 4),
      ],
      [
        dept("d-ops", "Operations", 1),
        dept("d-old", "Old", 2, false, true),
        dept("d-senior", "Senior management", 3, true),
        dept("d-board", "Board", 4, true),
      ],
    );
    expect(order.map((o) => o.id)).toEqual(["ops", "senior", "board"]);
    expect(order[0].parallelGroup).toBeNull(); // alone in the first group
    expect(order[1].parallelGroup).toBe(2);
    expect(order[2].parallelGroup).toBe(2);
  });

  it("names the step after the department", () => {
    expect(signoffStepName("Legal")).toBe("Legal sign-off");
  });
});
