/**
 * The single authorisation module (non-negotiable 1). Every server action and
 * route handler checks `can(actor, action, resource)` before reading
 * non-public data or mutating anything. Pure TypeScript — unit tested per
 * permission-matrix row, including negatives.
 */

export type StaffRole = "admin" | "ops" | "marketing" | "sales" | "event_director" | "viewer";

export type ExternalRole =
  | "venue"
  | "structural_engineer"
  | "hs"
  | "supplier"
  | "exhibitor"
  | "contractor"
  | "sponsor";

export type ScopeType = "venue" | "supplier" | "exhibitor" | "sponsor";

export type GrantInfo = {
  role: ExternalRole;
  editionId: string;
  scopeType: ScopeType | null;
  scopeId: string | null;
  expiresAt: Date | null;
  revokedAt: Date | null;
};

/**
 * Abilities an admin can grant or remove per user on top of the role
 * defaults. Precedence: admins ignore overrides entirely; an explicit
 * true/false wins over the role default; anything else falls back to the
 * role. `approval.decide: true` never bypasses step assignment — it can only
 * be used to remove the ability. `users.manage` is deliberately not
 * overridable (no privilege-escalation path).
 */
export const OVERRIDE_KEYS = [
  "signage.create",
  "sponsorship.create",
  "costs.edit",
  "approval.decide",
  "settings.manage",
] as const;
export type OverrideKey = (typeof OVERRIDE_KEYS)[number];
export type PermissionOverrides = Partial<Record<OverrideKey, boolean>>;

export type StaffActor = {
  kind: "staff";
  userId: string;
  organisationId: string;
  role: StaffRole;
  overrides?: PermissionOverrides;
};

export type ExternalActor = {
  kind: "external";
  userId: string;
  organisationId: string;
  grants: GrantInfo[];
};

export type Actor = StaffActor | ExternalActor;

/** A signage item, reduced to the fields authorisation depends on. */
export type SignageItemCtx = {
  editionId: string;
  venueId: string;
  kind?: "signage" | "sponsorship_item";
  ownerUserId?: string | null;
  sponsorId?: string | null;
  supplierId?: string | null;
  requiresVenueApproval?: boolean;
  status?: string;
};

/** A personal task, reduced to the fields authorisation depends on. */
export type TaskCtx = {
  assignedToUserId: string;
  createdByUserId: string;
};

export type StandSubmissionCtx = {
  editionId: string;
  venueId: string;
  exhibitorId: string;
  contractorId?: string | null;
  /** True once the venue step of the current run is pending or later. */
  venueStepActive?: boolean;
  /** True once the engineer step of the current run is pending or later. */
  engineerStepActive?: boolean;
  /** True once the H&S step of the current run is pending or later. */
  hsStepActive?: boolean;
};

export type ApprovalStepCtx = {
  /** Role the step is assigned to (staff or external role), if role-assigned. */
  assignedRole?: string | null;
  /** Specific user the step is assigned to, if user-assigned. */
  assignedUserId?: string | null;
  entity: { type: "signage_item"; item: SignageItemCtx } | { type: "stand"; sub: StandSubmissionCtx };
};

export type Action =
  | { type: "view_edition" }
  | { type: "signage.view"; item: SignageItemCtx }
  | { type: "signage.create" }
  | { type: "sponsorship.create" }
  | { type: "task.create" }
  | { type: "task.assign" }
  | { type: "task.update"; task: TaskCtx }
  | { type: "task.delete"; task: TaskCtx }
  | { type: "signage.edit"; item: SignageItemCtx }
  | { type: "signage.delete" }
  | { type: "signage.restore" }
  | { type: "artwork.upload"; item: SignageItemCtx }
  | { type: "signage.submit"; item: SignageItemCtx }
  | { type: "approval.decide"; step: ApprovalStepCtx }
  | { type: "approval.delegate"; step: ApprovalStepCtx }
  | { type: "signage.hold" }
  | { type: "signage.resume" }
  | { type: "signage.reopen" }
  | { type: "change_request.raise" }
  | { type: "change_request.approve" }
  | { type: "stand.view"; sub: StandSubmissionCtx }
  | { type: "stand.review" }
  | { type: "stand.submit"; sub: StandSubmissionCtx }
  | { type: "costs.view" }
  | { type: "costs.edit" }
  | { type: "comment.internal.write" }
  | { type: "comment.internal.read" }
  | { type: "comment.external.write"; entity: SignageItemCtx | StandSubmissionCtx }
  | { type: "onsite.confirm_install" }
  | { type: "snag.manage" }
  | { type: "export.run"; kind: string }
  | { type: "settings.manage" }
  | { type: "users.manage" };

function activeGrants(actor: ExternalActor, now = new Date()): GrantInfo[] {
  return actor.grants.filter(
    (g) => !g.revokedAt && (!g.expiresAt || g.expiresAt.getTime() > now.getTime()),
  );
}

/** Does this external actor hold an active grant matching the predicate? */
function hasGrant(actor: ExternalActor, pred: (g: GrantInfo) => boolean, now = new Date()) {
  return activeGrants(actor, now).some(pred);
}

/** External visibility of a signage item, per the scoping table in the brief. */
function externalCanViewSignage(actor: ExternalActor, item: SignageItemCtx, now = new Date()) {
  return hasGrant(
    actor,
    (g) => {
      switch (g.role) {
        case "venue":
          return (
            g.scopeType === "venue" &&
            g.scopeId === item.venueId &&
            g.editionId === item.editionId &&
            item.requiresVenueApproval === true
          );
        case "supplier":
          return (
            g.scopeType === "supplier" &&
            g.scopeId != null &&
            g.scopeId === item.supplierId &&
            g.editionId === item.editionId
          );
        case "sponsor":
          return (
            g.scopeType === "sponsor" &&
            g.scopeId != null &&
            g.scopeId === item.sponsorId &&
            g.editionId === item.editionId
          );
        default:
          return false;
      }
    },
    now,
  );
}

/** External visibility of a stand submission, per the scoping table. */
function externalCanViewStand(actor: ExternalActor, sub: StandSubmissionCtx, now = new Date()) {
  return hasGrant(
    actor,
    (g) => {
      if (g.editionId !== sub.editionId) return false;
      switch (g.role) {
        case "venue":
          return g.scopeType === "venue" && g.scopeId === sub.venueId && sub.venueStepActive === true;
        case "structural_engineer":
          return sub.engineerStepActive === true;
        case "hs":
          return sub.hsStepActive === true;
        case "exhibitor":
        case "contractor":
          return g.scopeType === "exhibitor" && g.scopeId === sub.exhibitorId;
        default:
          return false;
      }
    },
    now,
  );
}

/** Can this external actor decide a role-assigned step? */
function externalCanDecide(actor: ExternalActor, step: ApprovalStepCtx, now = new Date()) {
  const role = step.assignedRole;
  if (!role) return false;
  if (step.assignedUserId) {
    return hasGrant(actor, (g) => g.role === role, now) && step.assignedUserId === actor.userId;
  }
  if (step.entity.type === "signage_item") {
    const item = step.entity.item;
    return hasGrant(
      actor,
      (g) => {
        if (g.role !== role || g.editionId !== item.editionId) return false;
        switch (role) {
          case "venue":
            return g.scopeType === "venue" && g.scopeId === item.venueId;
          case "supplier":
            return g.scopeType === "supplier" && g.scopeId != null && g.scopeId === item.supplierId;
          case "sponsor":
            return g.scopeType === "sponsor" && g.scopeId != null && g.scopeId === item.sponsorId;
          default:
            return false;
        }
      },
      now,
    );
  }
  const sub = step.entity.sub;
  return hasGrant(
    actor,
    (g) => {
      if (g.role !== role || g.editionId !== sub.editionId) return false;
      switch (role) {
        case "venue":
          return g.scopeType === "venue" && g.scopeId === sub.venueId;
        case "structural_engineer":
        case "hs":
          return true; // scoped to the edition
        default:
          return false;
      }
    },
    now,
  );
}

function staffCanDecide(actor: StaffActor, step: ApprovalStepCtx): boolean {
  if (actor.role === "admin") return true;
  if (step.assignedUserId) return step.assignedUserId === actor.userId;
  return step.assignedRole === actor.role;
}

const sponsorScopedRoles: StaffRole[] = ["sales"];

/**
 * Someone granted "add signage" / "add sponsorship items" by override can
 * also carry their own items through to sign-off (edit, artwork, submit).
 */
function ownsGrantedCreation(actor: StaffActor, item: SignageItemCtx): boolean {
  const key = item.kind === "sponsorship_item" ? "sponsorship.create" : "signage.create";
  return actor.overrides?.[key] === true && item.ownerUserId === actor.userId;
}

function isSponsorItem(item: SignageItemCtx) {
  return item.sponsorId != null;
}

export function can(actor: Actor, action: Action, now = new Date()): boolean {
  if (actor.kind === "external") {
    switch (action.type) {
      case "signage.view":
        return externalCanViewSignage(actor, action.item, now);
      case "stand.view":
        return externalCanViewStand(actor, action.sub, now);
      case "stand.submit":
        return hasGrant(
          actor,
          (g) =>
            (g.role === "exhibitor" || g.role === "contractor") &&
            g.editionId === action.sub.editionId &&
            g.scopeType === "exhibitor" &&
            g.scopeId === action.sub.exhibitorId,
          now,
        );
      case "approval.decide":
        return externalCanDecide(actor, action.step, now);
      case "approval.delegate":
        // The assignee may delegate; externals delegate only steps assigned to them.
        return externalCanDecide(actor, action.step, now);
      case "comment.external.write": {
        const entity = action.entity;
        if ("exhibitorId" in entity) return externalCanViewStand(actor, entity, now);
        return externalCanViewSignage(actor, entity, now);
      }
      // Externals never: costs, internal comments, settings, exports, CRUD…
      default:
        return false;
    }
  }

  const role = actor.role;

  // Per-user overrides (admins are immune, so an admin can never lock
  // themselves out). An explicit false always blocks; an explicit true
  // grants directly — except approval.decide, where step assignment below
  // still applies, so a true can never let someone decide steps that are
  // not theirs.
  if (role !== "admin" && actor.overrides) {
    const key = (OVERRIDE_KEYS as readonly string[]).includes(action.type)
      ? (action.type as OverrideKey)
      : null;
    if (key != null) {
      const override = actor.overrides[key];
      if (override === false) return false;
      if (override === true && key !== "approval.decide") return true;
    }
  }

  switch (action.type) {
    case "view_edition":
      return true; // every staff role views all editions and records
    case "signage.view":
      return true;
    case "stand.view":
      return true;

    case "signage.create":
      return role === "admin" || role === "ops" || role === "marketing";
    case "sponsorship.create":
      // Sales sell sponsorship items; ops also manage them.
      return role === "admin" || role === "ops" || role === "sales";

    case "task.create":
      return true; // everyone keeps their own to-do list, viewers included
    case "task.assign":
      return role !== "viewer";
    case "task.update":
      return (
        role === "admin" ||
        action.task.assignedToUserId === actor.userId ||
        action.task.createdByUserId === actor.userId
      );
    case "task.delete":
      return role === "admin" || action.task.createdByUserId === actor.userId;

    case "signage.edit":
      if (ownsGrantedCreation(actor, action.item)) return true;
      if (role === "admin" || role === "ops" || role === "marketing") return true;
      if (sponsorScopedRoles.includes(role)) {
        return isSponsorItem(action.item) || action.item.kind === "sponsorship_item";
      }
      return false;

    case "signage.delete":
    case "signage.restore":
      return role === "admin" || role === "ops";

    case "artwork.upload":
      if (ownsGrantedCreation(actor, action.item)) return true;
      if (role === "admin" || role === "ops" || role === "marketing") return true;
      if (role === "sales") {
        return isSponsorItem(action.item) || action.item.kind === "sponsorship_item";
      }
      return false;

    case "signage.submit":
      if (ownsGrantedCreation(actor, action.item)) return true;
      if (role === "admin" || role === "ops" || role === "marketing") return true;
      if (role === "sales") {
        return isSponsorItem(action.item) || action.item.kind === "sponsorship_item";
      }
      return false;

    case "approval.decide":
      return staffCanDecide(actor, action.step);

    case "approval.delegate":
      if (role === "viewer") return false;
      if (role === "admin") return true;
      return staffCanDecide(actor, action.step);

    case "signage.hold":
    case "signage.resume":
    case "signage.reopen":
      return role === "admin" || role === "ops";

    case "change_request.raise":
      return role === "admin" || role === "ops" || role === "marketing" || role === "sales";
    case "change_request.approve":
      return role === "admin" || role === "ops";

    case "stand.review":
      return role === "admin" || role === "ops";
    case "stand.submit":
      return false; // staff never submit on behalf of exhibitors

    case "costs.view":
      if (actor.overrides?.["costs.edit"] === true) return true;
      return role === "admin" || role === "ops" || role === "marketing" || role === "event_director";
    case "costs.edit":
      return role === "admin" || role === "ops";

    case "comment.internal.write":
      return role !== "viewer";
    case "comment.internal.read":
      return true;
    case "comment.external.write":
      return role !== "viewer";

    case "onsite.confirm_install":
    case "snag.manage":
      return role === "admin" || role === "ops" || role === "marketing";

    case "export.run":
      if (role === "viewer") return false;
      if (role === "sales") return action.kind === "sponsor_report";
      return true;

    case "settings.manage":
      return role === "admin" || role === "ops";

    case "users.manage":
      return role === "admin";
  }
}

/** Fields a supplier is allowed to see on a signage item. */
export const supplierVisibleFields = [
  "ref",
  "name",
  "widthMm",
  "heightMm",
  "depthMm",
  "quantity",
  "sided",
  "material",
  "finish",
  "fixingMethod",
  "weightKg",
  "deliveryDate",
  "installDate",
  "installSlot",
  "poNumber",
] as const;

/** Venue users never see costs, PO numbers or internal comments. */
export const venueHiddenFields = ["costEstimate", "costActual", "poNumber", "budgetLine"] as const;
