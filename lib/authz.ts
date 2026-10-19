/**
 * The single authorisation module (non-negotiable 1). Every server action and
 * route handler checks `can(actor, action, resource)` before reading
 * non-public data or mutating anything. Pure TypeScript — unit tested per
 * permission-matrix row, including negatives (tests/unit/authz*.test.ts,
 * with a frozen snapshot of the rules before the abilities registry).
 *
 * can() runs in this order: tenancy → external people → events → sections →
 * abilities → the role, item or assignment rule. Who may add and change
 * people (super admins and managers) is at the end of the file.
 */
import { roleLabel } from "./format";

export type StaffRole = "admin" | "ops" | "marketing" | "sales" | "event_director" | "viewer";

/** Staff roles in the order they are offered. `admin` is shown as "Super admin". */
export const STAFF_ROLES: readonly StaffRole[] = [
  "admin",
  "ops",
  "marketing",
  "sales",
  "event_director",
  "viewer",
];

export type ExternalRole =
  "venue" | "structural_engineer" | "hs" | "supplier" | "exhibitor" | "contractor" | "sponsor";

export type ScopeType = "venue" | "supplier" | "exhibitor" | "sponsor";

/** Who a manager may add and change: their own department, or everyone. */
export type ManagerScope = "department" | "everyone";
export const MANAGER_SCOPES: readonly ManagerScope[] = ["department", "everyone"];

export type GrantInfo = {
  role: ExternalRole;
  editionId: string;
  scopeType: ScopeType | null;
  scopeId: string | null;
  expiresAt: Date | null;
  revokedAt: Date | null;
};

/**
 * App sections a person can be given (Users → Sections). A person with no
 * list (null) has every section, which is how everyone worked before
 * sections existed. Admins always have every section. Viewing a single
 * record, deciding a sign-off assigned to you, tasks and comments are never
 * gated, so links from emails and sign-offs keep working.
 */
export const FEATURES = [
  "signage",
  "sponsorship",
  "stand_designs",
  "stands",
  "onsite",
  "calendar",
  "reports",
  "suppliers",
  "approvals",
] as const;
export type Feature = (typeof FEATURES)[number];

export const FEATURE_LABELS: Record<Feature, string> = {
  signage: "Signage",
  sponsorship: "Sponsorship",
  stand_designs: "Feature stands",
  stands: "Exhibitor stands",
  onsite: "Onsite",
  calendar: "Calendar",
  reports: "Reports",
  suppliers: "Suppliers",
  approvals: "Approvals",
};

/** Keep only known section keys (stored values may predate a rename). */
export function parseFeatures(value: unknown): Feature[] | null {
  if (!Array.isArray(value)) return null;
  return value.filter((v): v is Feature => (FEATURES as readonly string[]).includes(v));
}

// ---------------------------------------------------------------------------
// Abilities: what can be fine-tuned per person on top of their role.
// ---------------------------------------------------------------------------

/**
 * Every ability, in the order the person form shows them. Stored per person
 * as `memberships.permission_overrides` (only differences from the role).
 * Precedence: super admins ignore anything stored; a stored false always
 * blocks; a stored true grants a "grant" ability outright, and for a "gate"
 * ability only switches it on — the item or step assignment rule still
 * applies (so `approval.decide: true` never lets anyone decide steps that
 * aren't theirs). Super-admin powers (`users.manage`, `system.manage`,
 * `events.archive`) and being a manager are never abilities, so nothing
 * stored can reach them.
 */
export const ABILITY_KEYS = [
  "signage.create",
  "signage.delete",
  "signage.lifecycle",
  "signage.bulk",
  "approval.decide",
  "approval.delegate",
  "approval.chase",
  "costs.view",
  "costs.edit",
  "sponsorship.create",
  "sponsorship.sell",
  "events.create",
  "events.edit",
  "halls.manage",
  "suppliers.manage",
  "lists.manage",
  "organisation.manage",
  "signage.confirm",
  "snag.manage",
  "reports.download",
  "task.assign",
  "partners.invite",
  "departments.manage",
] as const;
export type AbilityKey = (typeof ABILITY_KEYS)[number];

/**
 * Keys stored before the registry. They are still read (as a fallback for
 * the abilities that replaced them) but never written again: saving a person
 * writes the new keys and drops these.
 */
export type LegacyOverrideKey = "settings.manage";

export type PermissionOverrides = Partial<Record<AbilityKey | LegacyOverrideKey, boolean>>;

export const ABILITY_GROUPS = [
  "signage",
  "signoff",
  "money",
  "sponsorship",
  "events",
  "onsite",
  "people",
] as const;
export type AbilityGroup = (typeof ABILITY_GROUPS)[number];

export const ABILITY_GROUP_LABELS: Record<AbilityGroup, string> = {
  signage: "Signage and artwork",
  signoff: "Sign-off",
  money: "Money",
  sponsorship: "Sponsorship",
  events: "Events and setup",
  onsite: "Onsite and reports",
  people: "People",
};

export type AbilityDef = {
  label: string;
  description: string;
  group: AbilityGroup;
  /** Roles that have it by default (admins always do). */
  roles: readonly StaffRole[];
  /** "grant": a stored true grants it. "gate": a stored true only switches it on. */
  kind: "grant" | "gate";
  /** The section it belongs to: the form hides it while that section is off. */
  feature: Feature | null;
  /** An older stored key read when nothing is stored under this one. */
  legacy?: LegacyOverrideKey | "sponsorship.create";
  /** With nothing stored, it follows this ability (a granted one included). */
  derivedFrom?: AbilityKey;
  /** Off whenever any of these is off. */
  requires?: readonly AbilityKey[];
  /** Roles that have part of it by default, and what part. */
  partial?: Partial<Record<StaffRole, { kinds: readonly string[]; label: string }>>;
  /** Only a super admin may give it; managers never can. */
  superAdminGrants?: true;
  /** Not a checkbox in the form (approval.decide shows as "Sign-off paused"). */
  hidden?: true;
};

const EVERYONE: readonly StaffRole[] = STAFF_ROLES;
const ADMIN_OPS: readonly StaffRole[] = ["admin", "ops"];
const SETUP = { group: "events", roles: ADMIN_OPS, kind: "grant", feature: null } as const;

export const ABILITIES: Record<AbilityKey, AbilityDef> = {
  "signage.create": {
    label: "Add signage",
    description: "Add signs and take your own through to sign-off.",
    group: "signage",
    roles: ["admin", "ops", "marketing"],
    kind: "grant",
    feature: "signage",
  },
  "signage.delete": {
    label: "Delete and restore items",
    description:
      "Delete signs, sponsorship items and stands; restore them from Recently deleted or the Recycle bin.",
    group: "signage",
    roles: ADMIN_OPS,
    kind: "grant",
    feature: null,
  },
  "signage.lifecycle": {
    label: "Hold, reopen and mark complete",
    description:
      "Put items on hold and resume them, reopen finished items, mark installed items complete and undo it.",
    group: "signage",
    roles: ADMIN_OPS,
    kind: "grant",
    feature: null,
  },
  "signage.bulk": {
    label: "Import from Excel and bulk actions",
    description:
      "Import a schedule and change many items at once; each item still checks what you may change.",
    group: "signage",
    roles: ["admin", "ops", "marketing"],
    kind: "gate",
    feature: "signage",
    derivedFrom: "signage.create",
  },
  "approval.decide": {
    label: "Sign off artwork",
    description: "Decide sign-offs that are theirs. Switched off, it shows as “Sign-off paused”.",
    group: "signoff",
    roles: EVERYONE,
    kind: "gate",
    feature: null,
    hidden: true,
  },
  "approval.delegate": {
    label: "Hand sign-offs to someone else",
    description: "Pass a sign-off that is waiting on you to a colleague.",
    group: "signoff",
    roles: ["admin", "ops", "marketing", "sales", "event_director"],
    kind: "gate",
    feature: null,
  },
  "approval.chase": {
    label: "Chase overdue sign-offs",
    description: "See everyone's sign-offs and send reminders.",
    group: "signoff",
    roles: ADMIN_OPS,
    kind: "grant",
    feature: null,
  },
  "costs.view": {
    label: "See costs and prices",
    description:
      "Cost estimates, actual costs, budgets, sale prices, package prices and sponsor spend.",
    group: "money",
    roles: EVERYONE,
    kind: "grant",
    feature: null,
  },
  "costs.edit": {
    label: "Edit costs and PO numbers",
    description: "Costs, PO numbers, budget lines and the supplier on signage.",
    group: "money",
    roles: ADMIN_OPS,
    kind: "grant",
    feature: null,
    requires: ["costs.view"],
  },
  "sponsorship.create": {
    label: "Add sponsorship items",
    description: "Add items for sale and take your own through to sign-off.",
    group: "sponsorship",
    roles: ["admin", "ops", "sales"],
    kind: "grant",
    feature: "sponsorship",
  },
  "sponsorship.sell": {
    label: "Mark sold and manage sponsors and packages",
    description:
      "Record and undo sales; add or change sponsors, sponsorship packages and their prices, and what each package includes.",
    group: "sponsorship",
    roles: ["admin", "ops", "sales"],
    kind: "grant",
    feature: "sponsorship",
    legacy: "sponsorship.create",
    requires: ["costs.view"],
  },
  "events.create": {
    ...SETUP,
    label: "Create and copy events",
    description: "Start an event or copy a previous one; add event series.",
    legacy: "settings.manage",
  },
  "events.edit": {
    ...SETUP,
    label: "Edit event dates and deadlines",
    description: "Dates, venue, budget, logo and deadlines; tick off setup.",
    legacy: "settings.manage",
  },
  "halls.manage": {
    ...SETUP,
    label: "Manage halls and locations",
    description: "Add, rename and remove halls and the locations in them.",
    legacy: "settings.manage",
  },
  "suppliers.manage": {
    ...SETUP,
    label: "Manage suppliers",
    description: "Suppliers and install contractors: add, edit, archive and delete.",
    legacy: "settings.manage",
  },
  "lists.manage": {
    ...SETUP,
    label: "Manage lists",
    description: "Item types, supplier services and venues.",
    legacy: "settings.manage",
  },
  "organisation.manage": {
    ...SETUP,
    label: "Organisation settings",
    description: "Name, currency, chasing rules and the install photo rule.",
    legacy: "settings.manage",
    superAdminGrants: true,
  },
  "signage.confirm": {
    label: "Confirm print, delivery and install",
    description:
      "Confirm a supplier's print and delivery, and installs and build checks, yourself.",
    group: "onsite",
    roles: ADMIN_OPS,
    kind: "grant",
    feature: null,
  },
  "snag.manage": {
    label: "Raise and fix snags",
    description: "Report damage and problems on items, and mark them fixed.",
    group: "onsite",
    roles: ["admin", "ops", "marketing"],
    kind: "grant",
    feature: null,
  },
  "reports.download": {
    label: "Download reports",
    description:
      "Venue pack, contractor schedule, labels, schedule, registers, certificates and the sponsorship report.",
    group: "onsite",
    roles: ["admin", "ops", "marketing", "event_director"],
    kind: "grant",
    feature: null,
    partial: { sales: { kinds: ["sponsor_report"], label: "Sponsorship report only" } },
  },
  "task.assign": {
    label: "Give tasks to others",
    description: "Assign tasks to colleagues, not just themselves.",
    group: "people",
    roles: ["admin", "ops", "marketing", "sales", "event_director"],
    kind: "grant",
    feature: null,
  },
  "partners.invite": {
    label: "Invite partners",
    description: "Give suppliers, the venue and sponsors portal access, and take it away.",
    group: "people",
    roles: ["admin"],
    kind: "grant",
    feature: null,
    superAdminGrants: true,
  },
  "departments.manage": {
    label: "Manage departments and who signs off",
    description: "Departments, sign-off order and rules, and approvers.",
    group: "people",
    roles: ["admin"],
    kind: "grant",
    feature: null,
    superAdminGrants: true,
  },
};

/** The six abilities that were one "settings.manage" before the registry. */
export const SETTINGS_ABILITIES = [
  "events.create",
  "events.edit",
  "halls.manage",
  "suppliers.manage",
  "lists.manage",
  "organisation.manage",
] as const satisfies readonly AbilityKey[];

/** Getting an event ready: any of these opens Setup. */
export const EVENT_SETUP_ABILITIES = [
  "events.edit",
  "halls.manage",
  "lists.manage",
  "suppliers.manage",
] as const satisfies readonly AbilityKey[];

/**
 * @deprecated The keys that could be stored before the registry. Kept for
 * the v1 override tests; use ABILITY_KEYS.
 */
export const OVERRIDE_KEYS = [
  "signage.create",
  "sponsorship.create",
  "costs.edit",
  "approval.decide",
  "settings.manage",
] as const;
/** @deprecated See OVERRIDE_KEYS. */
export type OverrideKey = (typeof OVERRIDE_KEYS)[number];

/** Events (editions) someone works on: a list, or null for every event. */
export type EditionScope = readonly string[] | null;

export type StaffActor = {
  kind: "staff";
  userId: string;
  organisationId: string;
  role: StaffRole;
  overrides?: PermissionOverrides;
  /** Sign-off departments this person approves for (Users → Departments). */
  signoffDepartmentIds?: string[];
  /** The department they belong to. */
  departmentId?: string | null;
  /** Sections they can use; null or missing = every section. */
  features?: Feature[] | null;
  /** Managers add and change people in this scope; super admins manage everyone. */
  managerScope?: ManagerScope | null;
  /**
   * Events they work on (Users → Events); null or missing = every event,
   * including ones created later. Super admins are never limited.
   */
  editionIds?: string[] | null;
};

export type ExternalActor = {
  kind: "external";
  userId: string;
  organisationId: string;
  grants: GrantInfo[];
};

export type Actor = StaffActor | ExternalActor;

/** Just what abilities and events depend on: a role and what is stored for the person. */
export type AbilityHolder = {
  role: StaffRole;
  overrides?: PermissionOverrides | null;
  /** Events they work on; null or missing = every event. */
  editionIds?: readonly string[] | null;
};

/** A signage item, reduced to the fields authorisation depends on. */
export type SignageItemCtx = {
  /** The organisation that owns the item; nobody outside it may touch it. */
  organisationId?: string;
  editionId: string;
  venueId: string;
  kind?: "signage" | "sponsorship_item" | "stand_design" | "stand_panel";
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
  /** The task's event, if it has one. */
  editionId?: string | null;
};

export type StandSubmissionCtx = {
  /** The organisation that owns the stand; nobody outside it may touch it. */
  organisationId?: string;
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
  /** Department sign-off: anyone in the department may decide. */
  assignedDepartmentId?: string | null;
  /** Confirmations (sent to print, delivered, installed) can also be done by operations. */
  stepKind?: "approval" | "confirmation" | null;
  entity:
    { type: "signage_item"; item: SignageItemCtx } | { type: "stand"; sub: StandSubmissionCtx };
};

/** A team member or an open staff invitation, as the people rules see them. */
export type PersonCtx = {
  organisationId: string;
  /** Null for an invitation nobody has accepted yet. */
  userId: string | null;
  role: StaffRole;
  departmentId: string | null;
  managerScope: ManagerScope | null;
};

export type Action =
  | { type: "view_edition"; editionId?: string }
  | { type: "signage.view"; item: SignageItemCtx }
  | { type: "signage.create"; editionId?: string }
  | { type: "sponsorship.create"; editionId?: string }
  | { type: "stand_design.create"; editionId?: string }
  | { type: "task.create"; editionId?: string }
  | { type: "task.assign"; editionId?: string }
  | { type: "task.update"; task: TaskCtx }
  | { type: "task.delete"; task: TaskCtx }
  | { type: "signage.edit"; item: SignageItemCtx }
  | { type: "signage.delete"; editionId?: string }
  | { type: "signage.restore"; editionId?: string }
  /** Change many items at once (each item still checks its own rule). */
  | { type: "signage.bulk"; editionId?: string }
  /** Import a schedule from Excel: bulk and adding signage. */
  | { type: "signage.import"; editionId?: string }
  | { type: "artwork.upload"; item: SignageItemCtx }
  | { type: "signage.submit"; item: SignageItemCtx }
  | { type: "approval.decide"; step: ApprovalStepCtx }
  | { type: "approval.delegate"; step: ApprovalStepCtx }
  /** Chase someone else's sign-off (Remind on Approvals → Everyone's). */
  | { type: "approval.remind"; step: ApprovalStepCtx }
  /** See everyone's sign-offs (Approvals → Everyone's, the team views). */
  | { type: "approval.chase"; editionId?: string }
  | { type: "signage.hold"; editionId?: string }
  | { type: "signage.resume"; editionId?: string }
  | { type: "signage.reopen"; editionId?: string }
  | { type: "signage.close"; editionId?: string }
  | { type: "stand.view"; sub: StandSubmissionCtx }
  | { type: "stand.review"; editionId?: string }
  | { type: "stand.submit"; sub: StandSubmissionCtx }
  | { type: "costs.view"; editionId?: string }
  /** With an item: sponsorship items also let whoever may edit them set costs. */
  | { type: "costs.edit"; item?: SignageItemCtx }
  | { type: "sponsorship.sell"; editionId?: string }
  | { type: "comment.internal.write"; editionId?: string }
  | { type: "comment.internal.read"; editionId?: string }
  | { type: "comment.external.write"; entity: SignageItemCtx | StandSubmissionCtx }
  | { type: "snag.manage"; editionId?: string }
  | { type: "export.run"; kind: string; editionId?: string }
  | { type: "events.create" }
  | { type: "events.edit"; editionId?: string }
  | { type: "halls.manage"; editionId?: string }
  | { type: "suppliers.manage" }
  | { type: "lists.manage" }
  | { type: "organisation.manage" }
  /** Derived: any of the six setup abilities (opens Settings). */
  | { type: "settings.manage" }
  /** Derived: dates, halls, lists or suppliers (opens an event's Setup). */
  | { type: "event.setup"; editionId?: string }
  | { type: "partners.invite"; editionId?: string }
  | { type: "departments.manage" }
  /** Super admins only: grant super admin or manager, remove people, removal impact. */
  | { type: "users.manage" }
  /** Super admins only: storage, email and calendar feed settings. */
  | { type: "system.manage" }
  /** Super admins only: archive and restore events. */
  | { type: "events.archive" }
  /** Open Users to add people: super admins and managers. */
  | { type: "people.manage" }
  | { type: "person.edit"; person: PersonCtx }
  | { type: "person.suspend"; person: PersonCtx & { lastActiveAdmin?: boolean } }
  | { type: "person.remove"; person: PersonCtx };

function holderOf(a: Actor | AbilityHolder): AbilityHolder | null {
  if ("kind" in a && a.kind === "external") return null;
  return a as AbilityHolder;
}

/**
 * What is stored for this ability: its own key, else the older key it
 * replaced, else nothing (undefined = the role default).
 */
export function storedAbility(
  overrides: PermissionOverrides | null | undefined,
  key: AbilityKey,
): boolean | undefined {
  if (!overrides) return undefined;
  const o = overrides as Record<string, unknown>;
  if (typeof o[key] === "boolean") return o[key] as boolean;
  const legacy = ABILITIES[key].legacy;
  if (legacy && typeof o[legacy] === "boolean") return o[legacy] as boolean;
  return undefined;
}

/** A stored "approval.decide: false" — their sign-off has been paused. */
export function signoffPaused(overrides: PermissionOverrides | null | undefined): boolean {
  return overrides?.["approval.decide"] === false;
}

/**
 * Has this person the ability, leaving items and steps aside? Super admins
 * always; a stored false never; a required ability off never; a stored true
 * yes; otherwise the ability it derives from, or the role default.
 */
export function abilityOn(actor: Actor | AbilityHolder, key: AbilityKey): boolean {
  const h = holderOf(actor);
  if (!h) return false;
  if (h.role === "admin") return true;
  const def = ABILITIES[key];
  const stored = storedAbility(h.overrides, key);
  if (stored === false) return false;
  if (def.requires?.some((r) => !abilityOn(h, r))) return false;
  if (stored === true) return true;
  if (def.derivedFrom) return abilityOn(h, def.derivedFrom);
  return def.roles.includes(h.role);
}

export type AbilityLevel = "yes" | "partial" | "no";

/** "yes", "no", or "partial" (a role that has part of it, nothing stored). */
export function abilityLevel(actor: Actor | AbilityHolder, key: AbilityKey): AbilityLevel {
  if (abilityOn(actor, key)) return "yes";
  const h = holderOf(actor);
  if (!h) return "no";
  const def = ABILITIES[key];
  if (def.partial?.[h.role] && storedAbility(h.overrides, key) === undefined) {
    if (!def.requires?.some((r) => !abilityOn(h, r))) return "partial";
  }
  return "no";
}

const LEVEL_RANK: Record<AbilityLevel, number> = { no: 0, partial: 1, yes: 2 };

/** The ability an action is governed by, if any. */
export function abilityFor(action: Action): AbilityKey | null {
  switch (action.type) {
    case "signage.create":
    case "sponsorship.create":
    case "signage.bulk":
    case "approval.decide":
    case "approval.delegate":
    case "approval.chase":
    case "costs.view":
    case "costs.edit":
    case "sponsorship.sell":
    case "events.create":
    case "events.edit":
    case "halls.manage":
    case "suppliers.manage":
    case "lists.manage":
    case "organisation.manage":
    case "snag.manage":
    case "task.assign":
    case "partners.invite":
    case "departments.manage":
      return action.type;
    case "signage.delete":
    case "signage.restore":
      return "signage.delete";
    case "signage.hold":
    case "signage.resume":
    case "signage.reopen":
    case "signage.close":
      return "signage.lifecycle";
    case "approval.remind":
      return "approval.chase";
    case "export.run":
      return "reports.download";
    default:
      return null;
  }
}

/** Does the role have the ability by default (nothing stored)? */
function roleHas(key: AbilityKey, role: StaffRole): boolean {
  return ABILITIES[key].roles.includes(role);
}

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
          return (
            g.scopeType === "venue" && g.scopeId === sub.venueId && sub.venueStepActive === true
          );
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

/**
 * Where an item waits for artwork, so a sponsor may provide their own
 * (P4.2): not yet sent, sent but waiting for artwork, or changes asked for.
 * Once it is in sign-off or beyond, new artwork is the team's call.
 */
export const SPONSOR_UPLOAD_STATUSES = ["draft", "awaiting_artwork", "changes_requested"] as const;

/**
 * A sponsor uploads artwork for their own items: a live sponsor grant for
 * the item's event, scoped to the item's sponsor, while the item waits for
 * artwork. Never stands or panels. Nothing else follows from it (no edit,
 * delete, costs or sending other items).
 */
function externalSponsorCanUpload(actor: ExternalActor, item: SignageItemCtx, now = new Date()) {
  if (item.kind === "stand_design" || item.kind === "stand_panel") return false;
  if (!item.sponsorId) return false;
  if (!item.status || !(SPONSOR_UPLOAD_STATUSES as readonly string[]).includes(item.status)) {
    return false;
  }
  return hasGrant(
    actor,
    (g) =>
      g.role === "sponsor" &&
      g.scopeType === "sponsor" &&
      g.scopeId === item.sponsorId &&
      g.editionId === item.editionId,
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

/** Is this a print, delivery or install confirmation that Operations do for the supplier? */
function isProductionConfirmation(step: ApprovalStepCtx): boolean {
  return (
    step.stepKind === "confirmation" &&
    !step.assignedUserId &&
    (step.assignedRole === "supplier" || step.assignedRole === "ops")
  );
}

function staffCanDecide(actor: StaffActor, step: ApprovalStepCtx): boolean {
  if (actor.role === "admin") return true;
  // Confirm print, delivery and install: a supplier's step when the supplier
  // hasn't (or has no portal access), and the Installed / build check steps.
  if (isProductionConfirmation(step)) {
    return (
      storedAbility(actor.overrides, "signage.confirm") ?? roleHas("signage.confirm", actor.role)
    );
  }
  if (step.assignedUserId) return step.assignedUserId === actor.userId;
  if (step.assignedDepartmentId) {
    return actor.signoffDepartmentIds?.includes(step.assignedDepartmentId) ?? false;
  }
  return step.assignedRole === actor.role;
}

/**
 * Does this person confirm suppliers' print and delivery (and the Installed
 * steps) themselves? The same answer as can(approval.decide) on such a step,
 * for the queries and notifications that list who holds those steps.
 */
export function confirmsForSuppliers(actor: Actor | AbilityHolder): boolean {
  const h = holderOf(actor);
  if (!h) return false;
  if (h.role === "admin") return true;
  if (signoffPaused(h.overrides)) return false;
  return storedAbility(h.overrides, "signage.confirm") ?? roleHas("signage.confirm", h.role);
}

const sponsorScopedRoles: StaffRole[] = ["sales"];

/**
 * Someone granted "add signage" / "add sponsorship items" by override can
 * also carry their own items through to sign-off (edit, artwork, submit).
 */
function ownsGrantedCreation(actor: StaffActor, item: SignageItemCtx): boolean {
  const key = item.kind === "sponsorship_item" ? "sponsorship.create" : "signage.create";
  return storedAbility(actor.overrides, key) === true && item.ownerUserId === actor.userId;
}

function isSponsorItem(item: SignageItemCtx) {
  return item.sponsorId != null;
}

/** Stands the organiser designs, and their panels: operations' own work. */
function isStandItem(item: SignageItemCtx) {
  return item.kind === "stand_design" || item.kind === "stand_panel";
}

/** The organisation of the record an action is about, if it names one. */
function recordOrganisation(action: Action): string | undefined {
  const a = action as {
    item?: { organisationId?: string };
    sub?: { organisationId?: string };
    step?: ApprovalStepCtx;
    entity?: { organisationId?: string };
    person?: { organisationId?: string };
  };
  if (a.item) return a.item.organisationId;
  if (a.sub) return a.sub.organisationId;
  if (a.step) {
    return a.step.entity.type === "signage_item"
      ? a.step.entity.item.organisationId
      : a.step.entity.sub.organisationId;
  }
  if (a.person) return a.person.organisationId;
  return a.entity?.organisationId;
}

// ---------------------------------------------------------------------------
// Events per person (Users → Events). Super admins and anyone without a list
// see every event; a list limits a team member to those events. Partners
// have their own per-event grants, which their rules below decide.
// ---------------------------------------------------------------------------

/** The events this person works on: null = every event (super admins, unlimited staff). */
export function editionScope(actor: Actor | AbilityHolder): EditionScope {
  if ("kind" in actor && actor.kind === "external") {
    return [...new Set(activeGrants(actor).map((g) => g.editionId))];
  }
  const h = actor as AbilityHolder;
  if (h.role === "admin" || h.editionIds == null) return null;
  return h.editionIds;
}

/**
 * Can this team member open the event at all? Super admins and people
 * without a list: always. Partners: false (their grant rules decide).
 */
export function seesEdition(actor: Actor | AbilityHolder, editionId: string): boolean {
  if ("kind" in actor && actor.kind === "external") return false;
  const scope = editionScope(actor);
  return scope === null || scope.includes(editionId);
}

/** Does `who` see every one of these events? */
export function seesAllEditions(
  who: Actor | AbilityHolder,
  editionIds: readonly string[],
): boolean {
  return editionIds.every((id) => seesEdition(who, id));
}

/**
 * The loaders' check (record bundles, ownEdition, getEditionByCode):
 * partners pass, because their grant rules in can() decide each record;
 * team members need seesEdition.
 */
export function opensEdition(actor: Actor, editionId: string): boolean {
  if (actor.kind === "external") return true;
  return seesEdition(actor, editionId);
}

/**
 * The event of the record an action is about, if it names one: its item,
 * stand, step, entity or task, else its editionId. "" (the people rules'
 * role probes) counts as none.
 */
export function editionOf(action: Action): string | undefined {
  const a = action as {
    editionId?: string;
    item?: { editionId?: string };
    sub?: { editionId?: string };
    step?: ApprovalStepCtx;
    entity?: { editionId?: string };
    task?: { editionId?: string | null };
  };
  const id =
    a.item?.editionId ||
    a.sub?.editionId ||
    (a.step
      ? a.step.entity.type === "signage_item"
        ? a.step.entity.item.editionId
        : a.step.entity.sub.editionId
      : undefined) ||
    a.entity?.editionId ||
    a.task?.editionId ||
    a.editionId;
  return id || undefined;
}

/** Can this person use the section? See FEATURES. */
export function hasFeature(actor: Actor, feature: Feature): boolean {
  if (actor.kind !== "staff") return false;
  if (actor.role === "admin") return true;
  // Approvers can always reach their sign-offs.
  if (feature === "approvals" && (actor.signoffDepartmentIds?.length ?? 0) > 0) return true;
  if (actor.features == null) return true;
  return actor.features.includes(feature);
}

function itemFeature(item: SignageItemCtx): Feature {
  if (item.kind === "sponsorship_item") return "sponsorship";
  if (item.kind === "stand_design" || item.kind === "stand_panel") return "stand_designs";
  return "signage";
}

/**
 * The section an action belongs to, or null when it is never gated by
 * sections (viewing one record, deciding, tasks, comments, settings, people).
 */
export function featureForAction(action: Action): Feature | null {
  switch (action.type) {
    case "signage.create":
    case "signage.bulk":
    case "signage.import":
      return "signage";
    case "sponsorship.create":
    case "sponsorship.sell":
      return "sponsorship";
    case "stand_design.create":
      return "stand_designs";
    case "signage.edit":
    case "artwork.upload":
    case "signage.submit":
      return itemFeature(action.item);
    case "comment.external.write":
      return "exhibitorId" in action.entity ? "stands" : itemFeature(action.entity);
    case "stand.review":
      return "stands";
    case "approval.remind":
      return action.step.entity.type === "signage_item"
        ? itemFeature(action.step.entity.item)
        : "stands";
    case "export.run":
      if (action.kind === "certificate") return null;
      if (action.kind === "sponsor_report") return "sponsorship";
      return "reports";
    default:
      return null;
  }
}

export function can(actor: Actor, action: Action, now = new Date()): boolean {
  // Tenancy first: nobody — admins included — acts on another organisation's records.
  const recordOrg = recordOrganisation(action);
  if (recordOrg !== undefined && recordOrg !== actor.organisationId) return false;
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
      case "artwork.upload":
        return externalSponsorCanUpload(actor, action.item, now);
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
      // Externals never: costs, internal comments, settings, exports, people, CRUD,
      // sending for sign-off (a sponsor's upload sends their own item itself)…
      default:
        return false;
    }
  }

  // Events (Users → Events): a team member limited to some events can do
  // nothing — view, change, decide or be counted — in any other. Super admins
  // are never limited. Before sections and abilities, so no ability reopens it.
  const editionId = editionOf(action);
  if (editionId !== undefined && !seesEdition(actor, editionId)) return false;

  const role = actor.role;

  // Sections switched off for this person (admins are immune). Checked
  // before abilities so a granted ability can never reopen a section.
  if (role !== "admin") {
    if (action.type === "export.run" && action.kind === "sponsor_report") {
      if (!hasFeature(actor, "sponsorship") && !hasFeature(actor, "reports")) return false;
    } else {
      const feature = featureForAction(action);
      if (feature && !hasFeature(actor, feature)) return false;
    }
  }

  // Abilities (admins are immune, so an admin can never lock themselves
  // out). A stored false always blocks, and so does a required ability that
  // is off; a stored true grants a "grant" ability; a "gate" ability falls
  // through to the item or assignment rule below.
  if (role !== "admin") {
    const key = abilityFor(action);
    if (key) {
      const def = ABILITIES[key];
      const stored = storedAbility(actor.overrides, key);
      if (stored === false) return false;
      if (def.requires?.some((r) => !abilityOn(actor, r))) return false;
      if (stored === true && def.kind === "grant") return true;
    }
  }

  switch (action.type) {
    case "view_edition":
      // Every staff role views every event they work on (the events rule
      // above has already refused one outside their list).
      return true;
    case "signage.view":
      return true;
    case "stand.view":
      return true;

    case "signage.create":
    case "sponsorship.create":
      return roleHas(action.type, role);
    case "signage.bulk":
      return abilityOn(actor, "signage.bulk");
    case "signage.import":
      return (
        can(actor, { type: "signage.bulk" }, now) && can(actor, { type: "signage.create" }, now)
      );
    case "stand_design.create":
      // Admins and operations set up stands, their approvers and panels.
      return role === "admin" || role === "ops";

    case "task.create":
      return true; // everyone keeps their own to-do list, viewers included
    case "task.assign":
      return roleHas("task.assign", role);
    case "task.update":
      return (
        role === "admin" ||
        action.task.assignedToUserId === actor.userId ||
        action.task.createdByUserId === actor.userId
      );
    case "task.delete":
      return role === "admin" || action.task.createdByUserId === actor.userId;

    case "signage.edit":
      if (isStandItem(action.item)) return role === "admin" || role === "ops";
      if (ownsGrantedCreation(actor, action.item)) return true;
      if (role === "admin" || role === "ops" || role === "marketing") return true;
      if (sponsorScopedRoles.includes(role)) {
        return isSponsorItem(action.item) || action.item.kind === "sponsorship_item";
      }
      return false;

    case "signage.delete":
    case "signage.restore":
      return roleHas("signage.delete", role);

    case "artwork.upload":
      if (isStandItem(action.item)) return role === "admin" || role === "ops";
      if (ownsGrantedCreation(actor, action.item)) return true;
      if (role === "admin" || role === "ops" || role === "marketing") return true;
      if (role === "sales") {
        return isSponsorItem(action.item) || action.item.kind === "sponsorship_item";
      }
      return false;

    case "signage.submit":
      if (isStandItem(action.item)) return role === "admin" || role === "ops";
      if (ownsGrantedCreation(actor, action.item)) return true;
      if (role === "admin" || role === "ops" || role === "marketing") return true;
      if (role === "sales") {
        return isSponsorItem(action.item) || action.item.kind === "sponsorship_item";
      }
      return false;

    case "approval.decide":
      return staffCanDecide(actor, action.step);

    case "approval.delegate":
      // Only steps that are yours to decide (admins: any).
      return abilityOn(actor, "approval.delegate") && staffCanDecide(actor, action.step);

    case "approval.remind": {
      // Those who chase sign-offs chase any; otherwise whoever can send the
      // item for sign-off (stands: whoever reviews them). Deciding a step
      // doesn't make you its chaser.
      if (roleHas("approval.chase", role)) return true;
      const entity = action.step.entity;
      return entity.type === "signage_item"
        ? can(actor, { type: "signage.submit", item: entity.item }, now)
        : can(actor, { type: "stand.review" }, now);
    }
    case "approval.chase":
      return roleHas("approval.chase", role);

    case "signage.hold":
    case "signage.resume":
    case "signage.reopen":
    case "signage.close":
      return roleHas("signage.lifecycle", role);

    case "stand.review":
      return role === "admin" || role === "ops";
    case "stand.submit":
      return false; // staff never submit on behalf of exhibitors

    case "costs.view":
      return roleHas("costs.view", role);
    case "costs.edit":
      if (roleHas("costs.edit", role)) return true;
      // Whoever may edit a sponsorship item sets its supplier, cost and PO.
      return (
        action.item?.kind === "sponsorship_item" &&
        can(actor, { type: "signage.edit", item: action.item }, now)
      );
    case "sponsorship.sell":
      return roleHas("sponsorship.sell", role);

    case "comment.internal.write":
      return role !== "viewer";
    case "comment.internal.read":
      return true;
    case "comment.external.write":
      return role !== "viewer";

    case "snag.manage":
      return roleHas("snag.manage", role);

    case "export.run": {
      if (roleHas("reports.download", role)) return true;
      const part = ABILITIES["reports.download"].partial?.[role];
      return part?.kinds.includes(action.kind) ?? false;
    }

    case "events.create":
    case "events.edit":
    case "halls.manage":
    case "suppliers.manage":
    case "lists.manage":
    case "organisation.manage":
    case "partners.invite":
    case "departments.manage":
      return roleHas(action.type, role);
    case "settings.manage":
      return SETTINGS_ABILITIES.some((k) => can(actor, { type: k }, now));
    case "event.setup":
      return EVENT_SETUP_ABILITIES.some((k) => can(actor, { type: k }, now));

    case "users.manage":
    case "system.manage":
    case "events.archive":
      return role === "admin";

    case "people.manage":
      return managerScope(actor) != null;
    case "person.edit":
      return canManagePerson(actor, action.person);
    case "person.suspend":
      return canSuspendPerson(actor, action.person, {
        lastActiveAdmin: action.person.lastActiveAdmin ?? false,
      });
    case "person.remove":
      return canRemovePerson(actor, action.person);
  }
}

// ---------------------------------------------------------------------------
// People: super admins and managers (Users v2). Pure, so the Users pages and
// the server agree; the server runs personChangeRefusal inside the
// transaction after loading the person.
// ---------------------------------------------------------------------------

/** A staff member with the admin role ("Super admin" in the app). */
export function isSuperAdmin(actor: Actor): boolean {
  return actor.kind === "staff" && actor.role === "admin";
}

/** Who this person may add and change: super admins everyone, managers their scope. */
export function managerScope(actor: Actor): ManagerScope | null {
  if (actor.kind !== "staff") return null;
  if (actor.role === "admin") return "everyone";
  return actor.managerScope ?? null;
}

function isSelf(actor: Actor, target: PersonCtx): boolean {
  return target.userId != null && target.userId === actor.userId;
}

/**
 * May this person change that one's access? Super admins: anyone in their
 * organisation (the self rules in lib/users/manage.ts still apply).
 * Managers: never themselves, a super admin or another manager; a
 * department manager only people (and invitations) in their own department,
 * and nobody when they have no department.
 */
export function canManagePerson(actor: Actor, target: PersonCtx): boolean {
  if (actor.kind !== "staff") return false;
  if (target.organisationId !== actor.organisationId) return false;
  if (isSuperAdmin(actor)) return true;
  const scope = managerScope(actor);
  if (!scope) return false;
  if (isSelf(actor, target)) return false;
  if (target.role === "admin" || target.managerScope != null) return false;
  if (scope === "everyone") return true;
  return (
    actor.departmentId != null &&
    target.departmentId != null &&
    target.departmentId === actor.departmentId
  );
}

const PROBE_ITEMS: SignageItemCtx[] = [
  { editionId: "probe", venueId: "probe", kind: "signage" },
  { editionId: "probe", venueId: "probe", kind: "signage", sponsorId: "probe" },
  { editionId: "probe", venueId: "probe", kind: "sponsorship_item" },
  { editionId: "probe", venueId: "probe", kind: "stand_design" },
  { editionId: "probe", venueId: "probe", kind: "stand_panel" },
];

/** What a role can do that no ability covers (editing, artwork, sending, stands). */
const ROLE_POWER_PROBES: Action[] = [
  ...PROBE_ITEMS.flatMap((item) =>
    (["signage.edit", "artwork.upload", "signage.submit"] as const).map(
      (type) => ({ type, item }) as Action,
    ),
  ),
  { type: "stand.review" },
  { type: "stand_design.create" },
  { type: "comment.internal.write" },
  { type: "comment.external.write", entity: PROBE_ITEMS[0] },
];

function roleProbe(role: StaffRole): StaffActor {
  return { kind: "staff", userId: "probe", organisationId: "probe", role };
}

/** A role power the target would gain that the actor's role doesn't have. */
function gainedRolePower(actorRole: StaffRole, from: StaffRole | null, to: StaffRole): boolean {
  const actor = roleProbe(actorRole);
  const after = roleProbe(to);
  const before = from ? roleProbe(from) : null;
  return ROLE_POWER_PROBES.some(
    (a) => can(after, a) && !(before && can(before, a)) && !can(actor, a),
  );
}

/**
 * Roles this person may give. Super admins: every role. Managers: viewer,
 * plus each role whose own powers and default abilities they fully have
 * (abilities only a super admin gives are switched off for the new person,
 * not counted here). Everyone else: none.
 */
export function assignableRoles(actor: Actor): StaffRole[] {
  if (actor.kind !== "staff") return [];
  if (isSuperAdmin(actor)) return [...STAFF_ROLES];
  if (!managerScope(actor)) return [];
  return STAFF_ROLES.filter((r) => {
    if (r === "admin") return false;
    if (r === "viewer") return true;
    if (gainedRolePower(actor.role, null, r)) return false;
    return ABILITY_KEYS.every((k) => {
      const def = ABILITIES[k];
      if (def.superAdminGrants || def.hidden) return true;
      return LEVEL_RANK[abilityLevel({ role: r }, k)] <= LEVEL_RANK[abilityLevel(actor, k)];
    });
  });
}

/** Sections this person may give: "all", or the ones they have themselves. */
export function assignableFeatures(actor: Actor): "all" | Feature[] {
  if (actor.kind !== "staff") return [];
  if (isSuperAdmin(actor) || actor.features == null) return "all";
  return FEATURES.filter((f) => hasFeature(actor, f));
}

/** Abilities this person may give: super admins all; managers what they fully have. */
export function assignableAbilities(actor: Actor): AbilityKey[] {
  if (actor.kind !== "staff") return [];
  if (isSuperAdmin(actor)) return [...ABILITY_KEYS];
  if (!managerScope(actor)) return [];
  return ABILITY_KEYS.filter(
    (k) => !ABILITIES[k].superAdminGrants && abilityLevel(actor, k) === "yes",
  );
}

/**
 * Departments this person may make someone sign off for (of the live ones
 * that sign off): all of them with departments.manage, otherwise only the
 * ones they sign off for themselves.
 */
export function assignableSignoffDepartments(
  actor: Actor,
  liveSigning: readonly string[],
): string[] {
  if (actor.kind !== "staff") return [];
  if (can(actor, { type: "departments.manage" })) return [...liveSigning];
  const mine = new Set(actor.signoffDepartmentIds ?? []);
  return liveSigning.filter((id) => mine.has(id));
}

/** Only super admins make managers (or change what a manager manages). */
export function canGrantManager(actor: Actor): boolean {
  return isSuperAdmin(actor);
}

/** Suspend, reactivate or give an end date: in scope, never yourself or the last active super admin. */
export function canSuspendPerson(
  actor: Actor,
  target: PersonCtx,
  opts: { lastActiveAdmin: boolean },
): boolean {
  return canManagePerson(actor, target) && !isSelf(actor, target) && !opts.lastActiveAdmin;
}

/** Remove someone from the team: super admins only, never themselves. */
export function canRemovePerson(actor: Actor, target: PersonCtx): boolean {
  return (
    isSuperAdmin(actor) && target.organisationId === actor.organisationId && !isSelf(actor, target)
  );
}

/** What a person's access is, or is proposed to be, for personChangeRefusal. */
export type PersonAccess = {
  role: StaffRole;
  departmentId: string | null;
  /** "+ New department…" in the form. */
  newDepartmentName?: string | null;
  /** Null = every section. */
  features: Feature[] | null;
  /** As stored (a paused sign-off is approval.decide: false). */
  overrides: PermissionOverrides;
  managerScope: ManagerScope | null;
  /** isMain: main approver now, or (for an invitation) when they accept. */
  signoffs: readonly { departmentId: string; isMain: boolean }[];
  accessEndsAt?: Date | null;
  /**
   * Events they work on: undefined = not part of this check (templates,
   * callers that don't touch events); null = every event.
   */
  editionIds?: readonly string[] | null;
};

/**
 * Why this change to someone's access is refused, or null when it may go
 * ahead. `target` and `before` are null when adding someone. Checks, in
 * order: (1) the person is in scope; (2) only super admins make super
 * admins; (3) or managers; (4) department managers keep people in their
 * department; (5) a new department needs departments.manage; (6) sections
 * the actor has (ones the person already had may stay); (7) role powers and
 * abilities the person would newly gain must be ones the actor fully has,
 * and never one only a super admin gives; (8) sign-off rows only for the
 * actor's own sign-off departments, and main approvers (including "main
 * when they accept") only with departments.manage; (9) a paused actor can't resume someone else's
 * sign-off; (6b) events the actor can open (ones the person already had may
 * stay; none can be taken away that the actor can't open; a list is never
 * empty, for super admins too). An access end date within scope is fine.
 */
export function personChangeRefusal(
  actor: Actor,
  target: PersonCtx | null,
  before: PersonAccess | null,
  after: PersonAccess,
): string | null {
  if (actor.kind !== "staff") return "You can't change people's access";
  // 1. Scope.
  if (target) {
    if (target.organisationId !== actor.organisationId) {
      return "This person isn't in your organisation";
    }
    if (!canManagePerson(actor, target)) return "You can't change this person's access";
  } else if (!managerScope(actor)) {
    return "You can't add people — ask a super admin";
  }
  // 6b (for everyone). "Only these events" needs at least one event.
  if (after.editionIds != null && after.editionIds.length === 0) {
    return "Tick at least one event, or choose All events";
  }
  if (isSuperAdmin(actor)) return null;
  const scope = managerScope(actor);

  // 2–3. Super admins and managers are made by super admins.
  if (after.role === "admin") return "Only a super admin can make someone a super admin";
  if ((after.managerScope ?? null) !== (before?.managerScope ?? null)) {
    return "Only a super admin can make someone a manager or change what they manage";
  }

  // 4–5. Departments.
  const newDept = after.newDepartmentName?.trim();
  if (scope === "department") {
    if (newDept || after.departmentId == null || after.departmentId !== actor.departmentId) {
      return target
        ? "You manage your own department only, so they stay in it"
        : "You can only add people to your own department";
    }
  }
  if (newDept && !can(actor, { type: "departments.manage" })) {
    return "Only people who manage departments can add a new one — pick an existing department";
  }

  // 6. Sections.
  const giveable = assignableFeatures(actor);
  if (giveable !== "all") {
    const had: readonly Feature[] = before ? (before.features ?? FEATURES) : [];
    if (after.features == null) {
      if (!(before && before.features == null)) {
        return "You can only give the sections you have yourself — choose them one by one";
      }
    } else {
      for (const f of after.features) {
        if (!giveable.includes(f) && !had.includes(f)) {
          return `You can't give the ${FEATURE_LABELS[f]} section — you don't have it yourself`;
        }
      }
    }
  }

  // 6b. Events: only the events the actor can open themselves.
  const events = eventsRefusal(actor, before, after);
  if (events) return events;

  // 7. Role powers and abilities newly gained.
  if (
    after.role !== before?.role &&
    gainedRolePower(actor.role, before?.role ?? null, after.role)
  ) {
    return `You can't make someone ${roleLabel(after.role)}: that role can do things yours can't`;
  }
  const nextHolder: AbilityHolder = { role: after.role, overrides: after.overrides };
  const prevHolder: AbilityHolder | null = before
    ? { role: before.role, overrides: before.overrides }
    : null;
  for (const k of ABILITY_KEYS) {
    const def = ABILITIES[k];
    if (def.hidden) continue; // a paused sign-off is rule 9
    const next = LEVEL_RANK[abilityLevel(nextHolder, k)];
    const prev = prevHolder ? LEVEL_RANK[abilityLevel(prevHolder, k)] : 0;
    if (next <= prev) continue;
    if (def.superAdminGrants) return `Only a super admin can give “${def.label}”`;
    if (next > LEVEL_RANK[abilityLevel(actor, k)]) {
      return `You can't give “${def.label}” — you don't have it yourself`;
    }
  }

  // 8. Sign-off rows and main approvers (including "main when they accept",
  // which an invitation's rows report as isMain).
  if (!can(actor, { type: "departments.manage" })) {
    const prevRows = new Map((before?.signoffs ?? []).map((s) => [s.departmentId, s.isMain]));
    const nextRows = new Map(after.signoffs.map((s) => [s.departmentId, s.isMain]));
    const mine = new Set(actor.signoffDepartmentIds ?? []);
    for (const [dept, main] of nextRows) {
      if (!prevRows.has(dept)) {
        if (!mine.has(dept)) {
          return "You can only give sign-off for departments you sign off for yourself";
        }
        if (main) return "Only people who manage departments can choose a main approver";
      } else if (prevRows.get(dept) !== main) {
        return "Only people who manage departments can choose a main approver";
      }
    }
    for (const dept of prevRows.keys()) {
      if (!nextRows.has(dept) && !mine.has(dept)) {
        return "You can only take away sign-off for departments you sign off for yourself";
      }
    }
  }

  // 9. Resuming a paused sign-off.
  if (
    before &&
    signoffPaused(before.overrides) &&
    !signoffPaused(after.overrides) &&
    signoffPaused(actor.overrides)
  ) {
    return "Your own sign-off is paused, so you can't resume someone else's";
  }

  // 10. An access end date within scope is fine.
  return null;
}

/** Rule 6b for an actor limited to some events (see personChangeRefusal). */
function eventsRefusal(
  actor: Actor,
  before: PersonAccess | null,
  after: PersonAccess,
): string | null {
  if (after.editionIds === undefined) return null;
  const mine = editionScope(actor);
  if (mine === null) return null;
  const had: EditionScope = before ? (before.editionIds ?? null) : [];
  if (after.editionIds === null) {
    return had === null
      ? null
      : "You can only give the events you can open yourself — tick them one by one";
  }
  if (had === null) {
    return "You can only take away events you can open yourself — ask a super admin";
  }
  for (const id of after.editionIds) {
    if (!had.includes(id) && !mine.includes(id)) {
      return "You can only give the events you can open yourself";
    }
  }
  for (const id of had) {
    if (!after.editionIds.includes(id) && !mine.includes(id)) {
      return "You can only take away events you can open yourself — ask a super admin";
    }
  }
  return null;
}

/**
 * The events this person may give (Users → Events): "all" for super admins
 * and anyone who sees every event, otherwise those of `all` they can open.
 */
export function assignableEditions(actor: Actor, all: readonly string[]): "all" | string[] {
  if (actor.kind !== "staff") return [];
  const mine = editionScope(actor);
  if (mine === null) return "all";
  return all.filter((id) => mine.includes(id));
}

/**
 * Copying an event may give the copy to someone limited to the source:
 * super admins anyone; managers people they may change, when they can open
 * the source themselves.
 */
export function canExtendToCopy(actor: Actor, person: PersonCtx, sourceEditionId: string): boolean {
  if (isSuperAdmin(actor)) return person.organisationId === actor.organisationId;
  return canManagePerson(actor, person) && seesEdition(actor, sourceEditionId);
}

/**
 * May this person send an open team invitation again (Resend, New link)?
 * A new link is a working way in as whoever accepts it, so someone who
 * isn't a super admin may renew only an invitation they could have made
 * themselves: personChangeRefusal as if adding the person now, with
 * `access` being what the invitation gives. Whether the invitation is in
 * their scope at all is canManagePerson, checked first by the server.
 */
export function canRenewInvite(actor: Actor, access: PersonAccess): boolean {
  if (actor.kind !== "staff") return false;
  return isSuperAdmin(actor) || personChangeRefusal(actor, null, null, access) === null;
}

/** The refusal shown when someone lacks an ability (the server's own words). */
export function missingAbilityMessage(key: AbilityKey): string {
  return `You need “${ABILITIES[key].label}” for that — ask a super admin`;
}
