/**
 * Who can do what, for the places that hand work to people: item owners,
 * named sign-off people and delegates, task assignees and the people who
 * confirm production. One load of the team (loadTeam), pure rules for each
 * purpose (unit tested in tests/unit/people.test.ts) and one list for every
 * picker (peopleFor). Only active members are offered (lib/users/active.ts);
 * someone a record is already with who can no longer act is kept in the
 * list with why ("Suspended", "Access ended", "Can't sign off", "No longer
 * has Signage"…), so nothing silently disappears.
 *
 * Kept free of lib/domain imports so departments, signage and the cron can
 * all use it.
 */
import { and, eq, inArray, isNotNull, isNull } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import {
  approvalInstances,
  approvers,
  departments,
  editions,
  events,
  memberships,
  notifications,
  signageItems,
  users,
} from "@/lib/db/schema";
import {
  abilityOn,
  can,
  confirmsForSuppliers,
  FEATURE_LABELS,
  featureForAction,
  hasFeature,
  parseFeatures,
  signoffPaused,
  type Feature,
  type ManagerScope,
  type PermissionOverrides,
  type SignageItemCtx,
  type StaffActor,
  type StaffRole,
} from "@/lib/authz";
import { accessState, canReceiveSignoff } from "@/lib/access";
import { activeMembership } from "@/lib/users/active";
import { notify } from "@/lib/notify";
import { writeAudit } from "@/lib/audit";
import { itemPath } from "@/lib/edition-path";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { APPROVAL_REQUEST_KINDS } from "@/lib/notification-kinds";
import type { PersonOption } from "@/components/people/groups";

export type { PersonOption } from "@/components/people/groups";

/** A team member as the people rules see them (suspended and ended people included). */
export type TeamMember = {
  userId: string;
  name: string;
  email: string;
  jobTitle: string | null;
  role: StaffRole;
  overrides: PermissionOverrides;
  features: Feature[] | null;
  departmentId: string | null;
  departmentName: string | null;
  managerScope: ManagerScope | null;
  suspendedAt: Date | null;
  accessEndsAt: Date | null;
  /** Departments they sign off for (Users → Departments). */
  signoffDepartmentIds: string[];
};

export type OwnableKind = "signage" | "sponsorship_item" | "stand_design" | "stand_panel";

/** What owning an item depends on: its kind, and whether it is a sponsor's. */
export type OwnableItem = { kind: OwnableKind; sponsored?: boolean };

export type PeoplePurpose =
  /** Owns this kind of item: can edit it, upload its artwork and send it for sign-off. */
  | { type: "owner"; item: OwnableItem }
  /** Can be handed a sign-off (delegation, named approver); in a department when given. */
  | { type: "signoff"; departmentId?: string | null }
  /** Can be given a task: any active member. */
  | { type: "task" }
  /** Confirms print, delivery and install for suppliers (signage.confirm). */
  | { type: "confirm" };

/** Why someone can't be picked: a code for messages and a short label for pickers. */
export type Refusal = {
  code: "left" | "suspended" | "ended" | "section" | "cannot";
  label: string;
};

/** The person as an actor, for asking authz what they could do. */
export function memberActor(m: TeamMember, organisationId: string): StaffActor {
  return {
    kind: "staff",
    userId: m.userId,
    organisationId,
    role: m.role,
    overrides: m.overrides,
    signoffDepartmentIds: m.signoffDepartmentIds,
    departmentId: m.departmentId,
    features: m.features,
    managerScope: m.role === "admin" ? null : m.managerScope,
  };
}

/** "sponsor signage", "sponsorship items", "feature stands"… for messages. */
export function kindWords(item: OwnableItem): string {
  switch (item.kind) {
    case "sponsorship_item":
      return "sponsorship items";
    case "stand_design":
      return "feature stands";
    case "stand_panel":
      return "stand panels";
    default:
      return item.sponsored ? "sponsor signage" : "signage";
  }
}

function itemCtx(item: OwnableItem, organisationId: string, ownerUserId: string): SignageItemCtx {
  return {
    organisationId,
    editionId: "",
    venueId: "",
    kind: item.kind,
    ownerUserId,
    // Only whether there is a sponsor matters to who may work on it.
    sponsorId: item.sponsored || item.kind === "sponsorship_item" ? "sponsor" : null,
  };
}

function accessRefusal(m: TeamMember | null | undefined, now: Date): Refusal | null {
  if (!m) return { code: "left", label: "No longer on the team" };
  const state = accessState(m, now);
  if (state === "suspended") return { code: "suspended", label: "Suspended" };
  if (state === "ended") return { code: "ended", label: "Access ended" };
  return null;
}

/**
 * Why this person can't own the item, or null when they can: on the team
 * with access, and able to edit it, upload its artwork and send it for
 * sign-off — the work an owner is chased for. Checked as if they owned it,
 * so people granted "Add signage" count for their own items.
 */
export function ownerRefusal(
  m: TeamMember | null | undefined,
  item: OwnableItem,
  opts: { organisationId: string; now?: Date },
): Refusal | null {
  const now = opts.now ?? new Date();
  const access = accessRefusal(m, now);
  if (access || !m) return access;
  const actor = memberActor(m, opts.organisationId);
  const ctx = itemCtx(item, opts.organisationId, m.userId);
  const feature = featureForAction({ type: "signage.edit", item: ctx });
  if (feature && !hasFeature(actor, feature)) {
    return { code: "section", label: `No longer has ${FEATURE_LABELS[feature]}` };
  }
  const ok =
    can(actor, { type: "signage.edit", item: ctx }, now) &&
    can(actor, { type: "artwork.upload", item: ctx }, now) &&
    can(actor, { type: "signage.submit", item: ctx }, now);
  return ok ? null : { code: "cannot", label: `Can't work on ${kindWords(item)}` };
}

export function canOwnItem(
  m: TeamMember | null | undefined,
  item: OwnableItem,
  opts: { organisationId: string; now?: Date },
): boolean {
  return ownerRefusal(m, item, opts) === null;
}

/**
 * Why this person can't be handed a sign-off, or null: active, not a
 * viewer, sign-off not paused (canReceiveSignoff) and, for a department's
 * step, one of its approvers.
 */
export function signoffRefusal(
  m: TeamMember | null | undefined,
  opts: { departmentId?: string | null; now?: Date } = {},
): Refusal | null {
  const now = opts.now ?? new Date();
  const access = accessRefusal(m, now);
  if (access || !m) return access;
  if (!canReceiveSignoff(m, now)) return { code: "cannot", label: "Can't sign off" };
  if (opts.departmentId && !m.signoffDepartmentIds.includes(opts.departmentId)) {
    return { code: "cannot", label: "Can't sign off" };
  }
  return null;
}

/** Anyone on the team with access can be given a task. */
export function taskRefusal(
  m: TeamMember | null | undefined,
  opts: { now?: Date } = {},
): Refusal | null {
  return accessRefusal(m, opts.now ?? new Date());
}

/** Confirms print, delivery and install for suppliers (never when sign-off is paused). */
export function confirmRefusal(
  m: TeamMember | null | undefined,
  opts: { now?: Date } = {},
): Refusal | null {
  const access = accessRefusal(m, opts.now ?? new Date());
  if (access || !m) return access;
  return confirmsForSuppliers(m) ? null : { code: "cannot", label: "Can't confirm production" };
}

export function refusalFor(
  purpose: PeoplePurpose,
  m: TeamMember | null | undefined,
  opts: { organisationId: string; now?: Date },
): Refusal | null {
  switch (purpose.type) {
    case "owner":
      return ownerRefusal(m, purpose.item, opts);
    case "signoff":
      return signoffRefusal(m, { departmentId: purpose.departmentId, now: opts.now });
    case "task":
      return taskRefusal(m, opts);
    case "confirm":
      return confirmRefusal(m, opts);
  }
}

/** A plain-language refusal for a server action ("Sam can't work on sponsor signage — pick someone else"). */
export function refusalMessage(name: string, refusal: Refusal, purpose: PeoplePurpose): string {
  switch (refusal.code) {
    case "left":
      return "That person isn't on the team any more — pick someone else";
    case "suspended":
      return `${name}'s access is suspended — pick someone else`;
    case "ended":
      return `${name}'s access has ended — pick someone else`;
    case "section":
      return `${name} ${refusal.label.replace(/^No longer has /, "doesn't have ")} — pick someone else`;
    case "cannot":
      return purpose.type === "owner"
        ? `${name} can't work on ${kindWords(purpose.item)} — pick someone else`
        : purpose.type === "signoff"
          ? `${name} can't sign this off — pick someone else`
          : `${name} can't do that — pick someone else`;
  }
}

function optionFor(m: TeamMember, unavailable: string | null): PersonOption {
  return {
    id: m.userId,
    name: m.name,
    jobTitle: m.jobTitle,
    departmentId: m.departmentId,
    departmentName: m.departmentName,
    unavailable,
  };
}

/**
 * The people a picker offers for this purpose: everyone who can, plus each
 * `include` id (the record's current owner, assignee or approver) whatever
 * their state, labelled when they can't. Pure.
 */
export function personOptions(
  team: readonly TeamMember[],
  purpose: PeoplePurpose,
  opts: {
    organisationId: string;
    include?: readonly (string | null | undefined)[];
    /** Names for included people who are no longer members. */
    formerNames?: ReadonlyMap<string, string>;
    now?: Date;
  },
): PersonOption[] {
  const out: PersonOption[] = [];
  const byId = new Map(team.map((m) => [m.userId, m]));
  for (const m of team) {
    if (!refusalFor(purpose, m, opts)) out.push(optionFor(m, null));
  }
  for (const id of new Set(opts.include ?? [])) {
    if (!id || out.some((p) => p.id === id)) continue;
    const m = byId.get(id);
    const refusal = refusalFor(purpose, m, opts);
    if (m) out.push(optionFor(m, refusal?.label ?? null));
    else {
      const name = opts.formerNames?.get(id);
      if (name) {
        out.push({
          id,
          name,
          jobTitle: null,
          departmentId: null,
          departmentName: null,
          unavailable: "No longer on the team",
        });
      }
    }
  }
  return out;
}

/**
 * People who can do at least one of these (e.g. own organiser or sponsor
 * signage), for a picker that serves mixed records such as a bulk change
 * of owner; the server still checks each record. Pure.
 */
export function personOptionsForAny(
  team: readonly TeamMember[],
  purposes: readonly PeoplePurpose[],
  opts: { organisationId: string; now?: Date },
): PersonOption[] {
  return team
    .filter((m) => purposes.some((p) => !refusalFor(p, m, opts)))
    .map((m) => optionFor(m, null));
}

/** The ids of the people who can do this (no labels, nobody extra). Pure. */
export function eligibleIds(
  team: readonly TeamMember[],
  purpose: PeoplePurpose,
  opts: { organisationId: string; now?: Date },
): string[] {
  return team.filter((m) => !refusalFor(purpose, m, opts)).map((m) => m.userId);
}

/** The whole team (suspended and ended people included), with their departments and sign-offs. */
export async function loadTeam(exec: Db | Tx, organisationId: string): Promise<TeamMember[]> {
  const [rows, approverRows] = await Promise.all([
    exec
      .select({
        userId: memberships.userId,
        role: memberships.role,
        overrides: memberships.permissionOverrides,
        features: memberships.features,
        departmentId: memberships.departmentId,
        departmentName: departments.name,
        jobTitle: memberships.jobTitle,
        managerScope: memberships.managerScope,
        suspendedAt: memberships.suspendedAt,
        accessEndsAt: memberships.accessEndsAt,
        fullName: users.fullName,
        email: users.email,
      })
      .from(memberships)
      .innerJoin(users, eq(users.id, memberships.userId))
      .leftJoin(departments, eq(departments.id, memberships.departmentId))
      .where(eq(memberships.organisationId, organisationId)),
    exec
      .select({ userId: approvers.userId, departmentId: approvers.departmentId })
      .from(approvers)
      .where(and(eq(approvers.organisationId, organisationId), isNotNull(approvers.userId))),
  ]);
  const signs = new Map<string, string[]>();
  for (const a of approverRows) {
    if (a.userId) signs.set(a.userId, [...(signs.get(a.userId) ?? []), a.departmentId]);
  }
  return rows.map((r) => ({
    userId: r.userId,
    name: r.fullName || r.email,
    email: r.email,
    jobTitle: r.jobTitle?.trim() || null,
    role: r.role,
    overrides: (r.overrides ?? {}) as PermissionOverrides,
    features: parseFeatures(r.features),
    departmentId: r.departmentId,
    departmentName: r.departmentName,
    managerScope: r.managerScope,
    suspendedAt: r.suspendedAt,
    accessEndsAt: r.accessEndsAt,
    signoffDepartmentIds: signs.get(r.userId) ?? [],
  }));
}

/** Names of people who have left (no membership any more), for labelling what they still hold. */
async function formerNames(
  exec: Db | Tx,
  team: readonly TeamMember[],
  ids: readonly (string | null | undefined)[],
): Promise<Map<string, string>> {
  const known = new Set(team.map((m) => m.userId));
  const missing = [...new Set(ids)].filter((id): id is string => Boolean(id) && !known.has(id!));
  if (missing.length === 0) return new Map();
  const rows = await exec
    .select({ id: users.id, fullName: users.fullName, email: users.email })
    .from(users)
    .where(inArray(users.id, missing));
  return new Map(rows.map((r) => [r.id, r.fullName || r.email]));
}

/**
 * The people a picker offers in this organisation for one purpose, with
 * the record's current holders (`include`) kept and labelled. Group them
 * with groupPeople() (the PersonPicker does).
 */
export async function peopleFor(
  exec: Db | Tx,
  organisationId: string,
  purpose: PeoplePurpose,
  opts: { include?: readonly (string | null | undefined)[]; team?: TeamMember[] } = {},
): Promise<PersonOption[]> {
  const team = opts.team ?? (await loadTeam(exec, organisationId));
  return personOptions(team, purpose, {
    organisationId,
    include: opts.include,
    formerNames: await formerNames(exec, team, opts.include ?? []),
  });
}

/**
 * Check a person picked for this purpose (an owner, a delegate, a task's
 * assignee) on the server. Returns them, or the reason in words.
 */
export async function checkPick(
  exec: Db | Tx,
  organisationId: string,
  userId: string,
  purpose: PeoplePurpose,
  opts: { team?: TeamMember[] } = {},
): Promise<{ ok: true; member: TeamMember } | { ok: false; error: string }> {
  const team = opts.team ?? (await loadTeam(exec, organisationId));
  const m = team.find((x) => x.userId === userId);
  const refusal = refusalFor(purpose, m, { organisationId });
  if (refusal || !m) {
    return {
      ok: false,
      error: refusalMessage(
        m?.name ?? "That person",
        refusal ?? accessRefusal(m, new Date())!,
        purpose,
      ),
    };
  }
  return { ok: true, member: m };
}

/** The owning team that follows an owner (the two teams that own items). */
export function ownerRoleOf(m: { role: StaffRole }): "ops" | "marketing" | null {
  return m.role === "ops" || m.role === "marketing" ? m.role : null;
}

/** Active people who may invite partners (partners.invite; super admins included). */
export async function partnerInviters(
  exec: Db | Tx,
  organisationId: string,
  opts: { team?: TeamMember[] } = {},
): Promise<TeamMember[]> {
  const team = opts.team ?? (await loadTeam(exec, organisationId));
  return team.filter((m) => !accessRefusal(m, new Date()) && abilityOn(m, "partners.invite"));
}

/** "Alex Admin", "Alex Admin or Jo Bloggs", "Alex, Jo or Sam" — or "a super admin". */
export function orNames(names: readonly string[]): string {
  const list = [...new Set(names)].filter(Boolean);
  if (list.length === 0) return "a super admin";
  if (list.length === 1) return list[0];
  return `${list.slice(0, -1).join(", ")} or ${list[list.length - 1]}`;
}

// ---------------------------------------------------------------------------
// Sign-off routing: when a department's main approver changes or someone
// stops signing for a department, open department steps follow.
// ---------------------------------------------------------------------------

/** A department step of an item's current round. */
export type OpenDeptStep = {
  id: string;
  status: string;
  stepKind: string;
  assignedUserId: string | null;
  assignedDepartmentId: string | null;
  delegatedFromUserId: string | null;
};

export type StepMove = { id: string; from: string | null; to: string | null };

/**
 * Where each open department step should be now (pure). Items following
 * their category's defaults (no stored plan) go to the department's
 * current main approver, or anyone in it when there is none — unless the
 * step was handed to someone on purpose (delegated) who can still sign.
 * Items with a stored plan keep whoever was chosen, unless that person can
 * no longer sign for the department; then the step follows the department.
 * Plans don't record whether a named person was picked or just pre-filled,
 * so they are never rewritten here.
 */
export function rerouteDepartmentSteps(
  steps: readonly OpenDeptStep[],
  opts: {
    followsDefaults: boolean;
    /** People who can sign for the department now. */
    signersOf: (departmentId: string) => ReadonlySet<string>;
    /** The department's main approver if they can sign now, else null. */
    mainOf: (departmentId: string) => string | null;
    /**
     * Can this person be handed a sign-off at all now (canReceiveSignoff)?
     * A step delegated or handed over to them stays theirs while they can,
     * whatever their department.
     */
    canSign: (userId: string) => boolean;
  },
): StepMove[] {
  const moves: StepMove[] = [];
  for (const s of steps) {
    if (s.stepKind !== "approval" || !s.assignedDepartmentId) continue;
    if (s.status !== "waiting" && s.status !== "pending") continue;
    const signers = opts.signersOf(s.assignedDepartmentId);
    const main = opts.mainOf(s.assignedDepartmentId);
    const current = s.assignedUserId;
    let to: string | null = current;
    if (s.delegatedFromUserId && current) {
      // Handed to someone on purpose: theirs while they can sign at all.
      if (!opts.canSign(current)) to = main;
    } else if (current && !signers.has(current)) to = main;
    else if (opts.followsDefaults) to = main;
    if (to !== current) moves.push({ id: s.id, from: current, to });
  }
  return moves;
}

/** Who can sign for each department now, and its main approver (if they can). */
export async function departmentRouting(
  exec: Db | Tx,
  organisationId: string,
): Promise<{
  signersOf: (departmentId: string) => ReadonlySet<string>;
  mainOf: (departmentId: string) => string | null;
  canSign: (userId: string) => boolean;
}> {
  const team = await loadTeam(exec, organisationId);
  const now = new Date();
  const receivers = new Set(team.filter((m) => canReceiveSignoff(m, now)).map((m) => m.userId));
  const rows = await exec
    .select({
      departmentId: approvers.departmentId,
      userId: approvers.userId,
      isMain: approvers.isMain,
      overrides: memberships.permissionOverrides,
    })
    .from(approvers)
    .innerJoin(
      memberships,
      and(
        eq(memberships.userId, approvers.userId),
        eq(memberships.organisationId, approvers.organisationId),
      ),
    )
    .where(and(eq(approvers.organisationId, organisationId), activeMembership()));
  const signers = new Map<string, Set<string>>();
  const mains = new Map<string, string>();
  for (const r of rows) {
    if (!r.userId || signoffPaused(r.overrides as PermissionOverrides)) continue;
    signers.set(r.departmentId, (signers.get(r.departmentId) ?? new Set()).add(r.userId));
    if (r.isMain) mains.set(r.departmentId, r.userId);
  }
  const empty = new Set<string>();
  return {
    signersOf: (id) => signers.get(id) ?? empty,
    mainOf: (id) => mains.get(id) ?? null,
    canSign: (id) => receivers.has(id),
  };
}

/**
 * Bring every open department sign-off in the organisation into line with
 * who signs for each department now (rerouteDepartmentSteps): one audit row
 * per step moved (about the person it moved from), "Please sign off" for
 * whoever it now waits on and the old request settled. Items in archived
 * events, deleted items and stand submissions are left alone. Run after any
 * change to departments or approvers (syncDepartmentSteps). Returns how
 * many steps moved.
 */
export async function rerouteDepartmentSignoffs(
  exec: Db | Tx,
  organisationId: string,
  opts: { actorUserId?: string | null } = {},
): Promise<number> {
  const tx = exec as Tx;
  const rows = await exec
    .select({
      instance: approvalInstances,
      item: {
        id: signageItems.id,
        ref: signageItems.ref,
        name: signageItems.name,
        kind: signageItems.kind,
        signoffs: signageItems.signoffs,
        editionId: signageItems.editionId,
      },
      editionCode: editions.code,
      editionStatus: editions.status,
    })
    .from(approvalInstances)
    .innerJoin(
      signageItems,
      and(
        eq(approvalInstances.entityType, "signage_item"),
        eq(signageItems.id, approvalInstances.entityId),
        eq(signageItems.currentRunNumber, approvalInstances.runNumber),
      ),
    )
    .innerJoin(editions, eq(editions.id, signageItems.editionId))
    .innerJoin(events, eq(events.id, editions.eventId))
    .where(
      and(
        eq(events.organisationId, organisationId),
        isNull(signageItems.deletedAt),
        isNotNull(approvalInstances.assignedDepartmentId),
        eq(approvalInstances.stepKindSnapshot, "approval"),
        inArray(approvalInstances.status, ["waiting", "pending"]),
      ),
    );
  const open = rows.filter((r) => !editionIsReadOnly(r.editionStatus));
  if (open.length === 0) return 0;
  const routing = await departmentRouting(exec, organisationId);
  const byItem = new Map<string, typeof open>();
  for (const r of open) byItem.set(r.item.id, [...(byItem.get(r.item.id) ?? []), r]);

  const team = await loadTeam(exec, organisationId);
  const nameOf = (id: string | null) =>
    (id && team.find((m) => m.userId === id)?.name) || "someone who has left";
  const deptRows = await exec
    .select({ id: departments.id, name: departments.name })
    .from(departments)
    .where(eq(departments.organisationId, organisationId));
  const deptName = (id: string) => deptRows.find((d) => d.id === id)?.name ?? "the department";

  let moved = 0;
  for (const [, list] of byItem) {
    const item = list[0].item;
    const moves = rerouteDepartmentSteps(
      list.map((r) => ({
        id: r.instance.id,
        status: r.instance.status,
        stepKind: r.instance.stepKindSnapshot,
        assignedUserId: r.instance.assignedUserId,
        assignedDepartmentId: r.instance.assignedDepartmentId,
        delegatedFromUserId: r.instance.delegatedFromUserId,
      })),
      { followsDefaults: !item.signoffs, ...routing },
    );
    for (const mv of moves) {
      const inst = list.find((r) => r.instance.id === mv.id)!.instance;
      const dept = inst.assignedDepartmentId!;
      await exec
        .update(approvalInstances)
        .set({ assignedUserId: mv.to })
        .where(eq(approvalInstances.id, mv.id));
      const toWords = mv.to ? nameOf(mv.to) : `anyone in ${deptName(dept)}`;
      const why =
        mv.from && inst.delegatedFromUserId
          ? `${nameOf(mv.from)} can't sign off any more`
          : mv.from && !routing.signersOf(dept).has(mv.from)
            ? `${nameOf(mv.from)} no longer signs off for ${deptName(dept)}`
            : `${deptName(dept)}'s main approver changed`;
      await writeAudit(tx, {
        organisationId,
        editionId: item.editionId,
        actorUserId: opts.actorUserId ?? null,
        actorType: opts.actorUserId ? "user" : "system",
        entityType: "signage_item",
        entityId: item.id,
        action: "delegate",
        before: { step: inst.stepNameSnapshot, assignedUserId: mv.from },
        after: { step: inst.stepNameSnapshot, assignedUserId: mv.to, departmentId: dept },
        summary: `${item.ref}: ${inst.stepNameSnapshot} now with ${toWords} — ${why}`,
        subjectUserId: mv.from,
      });
      if (inst.status === "pending") {
        // The person it left stops being asked; whoever it waits on now is.
        if (mv.from) {
          const stillHolds = list.some(
            (r) =>
              r.instance.id !== mv.id &&
              r.instance.status === "pending" &&
              (r.instance.assignedUserId === mv.from ||
                (!r.instance.assignedUserId &&
                  routing.signersOf(r.instance.assignedDepartmentId!).has(mv.from!))),
          );
          if (!stillHolds) {
            await exec
              .update(notifications)
              .set({ readAt: new Date() })
              .where(
                and(
                  eq(notifications.userId, mv.from),
                  eq(notifications.entityType, "signage_item"),
                  eq(notifications.entityId, item.id),
                  inArray(notifications.kind, [...APPROVAL_REQUEST_KINDS]),
                  isNull(notifications.readAt),
                ),
              );
          }
        }
        const told = mv.to ? [mv.to] : [...routing.signersOf(dept)];
        await notify(tx, {
          userIds: told.filter((id) => id !== mv.from),
          kind: "approval_requested",
          title: `Please sign off: ${item.name} (${item.ref})`,
          body: `${inst.stepNameSnapshot} — ${why}, so it is now with ${mv.to ? "you" : `anyone in ${deptName(dept)}`}.`,
          link: `${itemPath(list[0].editionCode, item)}?tab=artwork`,
          entityType: "signage_item",
          entityId: item.id,
        });
      }
      moved++;
    }
  }
  return moved;
}
