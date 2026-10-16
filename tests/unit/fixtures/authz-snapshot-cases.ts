/**
 * The fixture list behind the frozen can() snapshot (authz-v1-snapshot.json).
 * The snapshot was produced by running generate-authz-snapshot.ts against
 * lib/authz.ts as it stood before the abilities registry (Users v2), so the
 * refactored can() can be held to exactly the same answers. Change this list
 * only together with a regenerated snapshot from that older code.
 */
import type {
  Action,
  ApprovalStepCtx,
  ExternalActor,
  Feature,
  PermissionOverrides,
  SignageItemCtx,
  StaffActor,
  StaffRole,
  StandSubmissionCtx,
  TaskCtx,
} from "@/lib/authz";

export const ROLES: readonly StaffRole[] = [
  "admin",
  "ops",
  "marketing",
  "sales",
  "event_director",
  "viewer",
];

const ORG = "org-1";
const ME = "me";
const base = { organisationId: ORG, editionId: "ed-1", venueId: "v-1" };

/** Item variants: every kind, owned by the actor or not, plus another organisation's. */
const ITEMS: Record<string, SignageItemCtx> = {};
for (const [name, extra] of [
  ["sign", { kind: "signage" }],
  ["sponsorSign", { kind: "signage", sponsorId: "sp-1" }],
  ["sponsorshipItem", { kind: "sponsorship_item" }],
  ["standDesign", { kind: "stand_design" }],
  ["panel", { kind: "stand_panel" }],
] as const) {
  ITEMS[`${name}:mine`] = { ...base, ...extra, ownerUserId: ME, supplierId: "sup-1" };
  ITEMS[`${name}:other`] = { ...base, ...extra, ownerUserId: "someone-else", supplierId: "sup-1" };
}
ITEMS["sign:otherOrg"] = { ...base, organisationId: "org-2", kind: "signage", ownerUserId: ME };

const stand: StandSubmissionCtx = { ...base, exhibitorId: "ex-1" };

const onItem = (item: SignageItemCtx) => ({ type: "signage_item" as const, item });
const sign = ITEMS["sign:other"];

/** Step variants: department, named, role, supplier print, ops Installed, venue, stand. */
const STEPS: Record<string, ApprovalStepCtx> = {
  deptMine: { assignedDepartmentId: "d-mine", stepKind: "approval", entity: onItem(sign) },
  deptOther: { assignedDepartmentId: "d-other", stepKind: "approval", entity: onItem(sign) },
  deptMineSponsorshipItem: {
    assignedDepartmentId: "d-mine",
    stepKind: "approval",
    entity: onItem(ITEMS["sponsorshipItem:other"]),
  },
  deptMineSponsorSign: {
    assignedDepartmentId: "d-mine",
    stepKind: "approval",
    entity: onItem(ITEMS["sponsorSign:other"]),
  },
  deptMineStandDesign: {
    assignedDepartmentId: "d-mine",
    stepKind: "approval",
    entity: onItem(ITEMS["standDesign:other"]),
  },
  deptMineOwnSign: {
    assignedDepartmentId: "d-mine",
    stepKind: "approval",
    entity: onItem(ITEMS["sign:mine"]),
  },
  namedMe: { assignedUserId: ME, stepKind: "approval", entity: onItem(sign) },
  namedOther: { assignedUserId: "someone-else", stepKind: "approval", entity: onItem(sign) },
  namedMeConfirmation: { assignedUserId: ME, stepKind: "confirmation", entity: onItem(sign) },
  roleOps: { assignedRole: "ops", stepKind: "approval", entity: onItem(sign) },
  roleMarketing: { assignedRole: "marketing", stepKind: "approval", entity: onItem(sign) },
  roleSales: { assignedRole: "sales", stepKind: "approval", entity: onItem(sign) },
  roleDirector: { assignedRole: "event_director", stepKind: "approval", entity: onItem(sign) },
  supplierPrint: { assignedRole: "supplier", stepKind: "confirmation", entity: onItem(sign) },
  supplierPrintNamed: {
    assignedRole: "supplier",
    assignedUserId: "supplier-user",
    stepKind: "confirmation",
    entity: onItem(sign),
  },
  opsInstalled: { assignedRole: "ops", stepKind: "confirmation", entity: onItem(sign) },
  venue: {
    assignedRole: "venue",
    stepKind: "approval",
    entity: onItem({ ...sign, requiresVenueApproval: true }),
  },
  standVenue: {
    assignedRole: "venue",
    stepKind: "approval",
    entity: { type: "stand", sub: stand },
  },
  standOpsCheck: {
    assignedRole: "ops",
    stepKind: "confirmation",
    entity: { type: "stand", sub: stand },
  },
  otherOrg: {
    assignedDepartmentId: "d-mine",
    stepKind: "approval",
    entity: onItem(ITEMS["sign:otherOrg"]),
  },
};

const TASKS: Record<string, TaskCtx> = {
  mine: { assignedToUserId: ME, createdByUserId: ME },
  assignedToMe: { assignedToUserId: ME, createdByUserId: "someone-else" },
  createdByMe: { assignedToUserId: "someone-else", createdByUserId: ME },
  someoneElses: { assignedToUserId: "x", createdByUserId: "y" },
};

export const EXPORT_KINDS = [
  "certificate",
  "sponsor_report",
  "venue_pack",
  "spec_labels",
  "stand_register",
  "contractor_schedule",
  "schedule",
] as const;

/** Every action type with each of its context variants. */
export function snapshotActions(): [string, Action][] {
  const out: [string, Action][] = [];
  for (const type of [
    "view_edition",
    "signage.create",
    "sponsorship.create",
    "stand_design.create",
    "task.create",
    "task.assign",
    "signage.delete",
    "signage.restore",
    "signage.hold",
    "signage.resume",
    "signage.reopen",
    "signage.close",
    "stand.review",
    "costs.view",
    "costs.edit",
    "comment.internal.write",
    "comment.internal.read",
    "snag.manage",
    "settings.manage",
    "users.manage",
  ] as const) {
    out.push([type, { type } as Action]);
  }
  for (const [name, item] of Object.entries(ITEMS)) {
    for (const type of [
      "signage.view",
      "signage.edit",
      "artwork.upload",
      "signage.submit",
    ] as const) {
      out.push([`${type}@${name}`, { type, item }]);
    }
    out.push([`comment.external.write@${name}`, { type: "comment.external.write", entity: item }]);
  }
  out.push(["stand.view", { type: "stand.view", sub: stand }]);
  out.push(["stand.submit", { type: "stand.submit", sub: stand }]);
  out.push(["comment.external.write@stand", { type: "comment.external.write", entity: stand }]);
  for (const [name, task] of Object.entries(TASKS)) {
    out.push([`task.update@${name}`, { type: "task.update", task }]);
    out.push([`task.delete@${name}`, { type: "task.delete", task }]);
  }
  for (const [name, step] of Object.entries(STEPS)) {
    for (const type of ["approval.decide", "approval.delegate", "approval.remind"] as const) {
      out.push([`${type}@${name}`, { type, step }]);
    }
  }
  for (const kind of EXPORT_KINDS) out.push([`export.run@${kind}`, { type: "export.run", kind }]);
  return out;
}

/**
 * Cost editing on an item, as the item actions decided it before Users v2:
 * costs.edit, or a sponsorship item the person may edit (signage.ts). After
 * the refactor this is can(actor, { type: "costs.edit", item }).
 */
export function costItems(): [string, SignageItemCtx][] {
  return Object.entries(ITEMS).filter(([n]) => !n.endsWith(":otherOrg"));
}

const OVERRIDE_VARIANTS: [string, PermissionOverrides][] = [
  ["settings.manage=true", { "settings.manage": true }],
  ["settings.manage=false", { "settings.manage": false }],
  ["sponsorship.create=true", { "sponsorship.create": true }],
  ["sponsorship.create=false", { "sponsorship.create": false }],
  ["signage.create=true", { "signage.create": true }],
  ["signage.create=false", { "signage.create": false }],
  ["approval.decide=false", { "approval.decide": false }],
  ["costs.edit=true", { "costs.edit": true }],
  ["costs.edit=false", { "costs.edit": false }],
];

const SECTION_VARIANTS: [string, Feature[]][] = [
  ["sections=sponsorship", ["sponsorship"]],
  ["sections=calendar", ["calendar"]],
  ["sections=signage,reports", ["signage", "reports"]],
];

/** Each role plain, as a department signer, with overrides and with sections switched off. */
export function snapshotActors(): [string, StaffActor | ExternalActor][] {
  const out: [string, StaffActor | ExternalActor][] = [];
  const staff = (role: StaffRole, extra: Partial<StaffActor> = {}): StaffActor => ({
    kind: "staff",
    userId: ME,
    organisationId: ORG,
    role,
    ...extra,
  });
  for (const role of ROLES) {
    out.push([role, staff(role)]);
    out.push([`${role}+signer`, staff(role, { signoffDepartmentIds: ["d-mine"] })]);
    for (const [name, overrides] of OVERRIDE_VARIANTS) {
      out.push([`${role}+${name}`, staff(role, { overrides, signoffDepartmentIds: ["d-mine"] })]);
    }
    for (const [name, features] of SECTION_VARIANTS) {
      out.push([`${role}+${name}`, staff(role, { features })]);
    }
  }
  // A signer with sections switched off and an override, to pin the order.
  out.push([
    "sales+sections=calendar+sponsorship.create=true",
    staff("sales", { features: ["calendar"], overrides: { "sponsorship.create": true } }),
  ]);
  out.push([
    "marketing+sections=sponsorship+signage.create=true",
    staff("marketing", { features: ["sponsorship"], overrides: { "signage.create": true } }),
  ]);
  const grant = (
    role: ExternalActor["grants"][number]["role"],
    scopeType: ExternalActor["grants"][number]["scopeType"],
    scopeId: string | null,
  ): ExternalActor => ({
    kind: "external",
    userId: ME,
    organisationId: ORG,
    grants: [{ role, editionId: "ed-1", scopeType, scopeId, expiresAt: null, revokedAt: null }],
  });
  out.push(["external:venue", grant("venue", "venue", "v-1")]);
  out.push(["external:supplier", grant("supplier", "supplier", "sup-1")]);
  out.push(["external:sponsor", grant("sponsor", "sponsor", "sp-1")]);
  out.push(["external:exhibitor", grant("exhibitor", "exhibitor", "ex-1")]);
  out.push(["external:engineer", grant("structural_engineer", null, null)]);
  return out;
}
