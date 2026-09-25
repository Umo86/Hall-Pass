export type WorkflowCondition =
  | "always"
  | "if_sponsored"
  | "if_requires_venue_approval"
  | "if_requires_event_director"
  | "if_cost_over_threshold"
  | "if_rigged"
  | "if_complex_structure"
  | "if_venue_requires_stand_approval";

export type StepKind = "approval" | "confirmation";

export type StepDef = {
  id: string;
  sortOrder: number;
  parallelGroup: number | null;
  name: string;
  kind: StepKind;
  approverType: "role" | "user";
  approverRole: string | null;
  approverUserId: string | null;
  conditions: WorkflowCondition[];
  slaDays: number;
  invalidateOnNewVersion: boolean;
  restartFromHereOnChanges: boolean;
  /**
   * Department sign-off steps: the categories that get this step by default.
   * Empty (or absent) for steps that only follow their conditions.
   */
  defaultFor?: SignageCategory[];
  /** The department this sign-off belongs to; its approvers may decide. */
  departmentId?: string | null;
};

export type SignageCategory = "organiser" | "sponsor";

/** Who signs an item off: department steps and, optionally, a named person. */
export type SignoffPlan = { stepId: string; userId: string | null }[];

export type SignageEntityCtx = {
  kind: "signage";
  sponsorId: string | null;
  requiresVenueApproval: boolean;
  requiresEventDirector: boolean;
  costEstimate: number | null;
  fixingMethod: string | null;
  supplierId: string | null;
  /** Organiser or sponsor signage; picks the default sign-offs. */
  category?: SignageCategory | null;
  /** The item's own sign-off choices; null or absent means the defaults. */
  signoffs?: SignoffPlan | null;
};

export type StandEntityCtx = {
  kind: "stand";
  isComplex: boolean;
  venueRequiresStandApproval: boolean;
};

export type EntityCtx = SignageEntityCtx | StandEntityCtx;

export type EngineSettings = {
  costThresholdForDirector: number;
};

export type InstanceStatus =
  | "waiting"
  | "pending"
  | "approved"
  | "approved_with_conditions"
  | "changes_requested"
  | "rejected"
  | "confirmed"
  | "skipped"
  | "invalidated";

/**
 * In-memory representation of an approval instance. The engine works on
 * these; the persistence layer maps them to/from the approval_instances
 * table. `id` may be a temporary identifier for freshly created instances.
 */
export type Instance = {
  id: string;
  stepId: string;
  runNumber: number;
  stepName: string;
  stepKind: StepKind;
  sortOrder: number;
  parallelGroup: number | null;
  status: InstanceStatus;
  assignedRole: string | null;
  assignedUserId: string | null;
  /** Department sign-offs: anyone in the department, unless a person is named. */
  assignedDepartmentId?: string | null;
  delegatedFromUserId: string | null;
  decidedBy: string | null;
  decidedAt: Date | null;
  decisionComment: string | null;
  conditionsText: string | null;
  lockedVersionType: "artwork_version" | "submission_version" | null;
  lockedVersionId: string | null;
  lockedSha256: string | null;
  pendingSince: Date | null;
  dueAt: Date | null;
  holdShiftDays: number;
  /** Present when the supplier fallback re-assigned the step to ops. */
  noSupplierFallback?: boolean;
  /** Steps whose invalidation config applies (snapshot from the step def). */
  invalidateOnNewVersion: boolean;
  restartFromHereOnChanges: boolean;
  /** SLA carried on the instance so activation can compute due dates. */
  slaDaysSnapshot?: number;
};

export type Decision =
  | { type: "approve"; comment?: string }
  | { type: "approve_with_conditions"; conditionsText: string; comment?: string }
  | { type: "request_changes"; comment: string }
  | { type: "reject"; comment: string }
  | { type: "confirm"; comment?: string };

/** What the caller must do to the entity after a decision or engine step. */
export type EntityEvent =
  | { type: "none" }
  | { type: "changes_requested" }
  | { type: "rejected" }
  | { type: "run_approved" }
  | { type: "run_approved_with_conditions" };

export class WorkflowError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "WorkflowError";
  }
}

export class ConflictError extends Error {
  constructor(
    message = "This item changed since you opened it — refresh and check the latest version.",
  ) {
    super(message);
    this.name = "ConflictError";
  }
}

export const POSITIVE_STATUSES: InstanceStatus[] = [
  "approved",
  "approved_with_conditions",
  "confirmed",
  "skipped",
];
