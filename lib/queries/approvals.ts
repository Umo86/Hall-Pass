import "server-only";
import {
  and,
  asc,
  eq,
  ilike,
  inArray,
  isNotNull,
  isNull,
  lt,
  ne,
  or,
  sql,
  type SQL,
} from "drizzle-orm";
import { alias } from "drizzle-orm/pg-core";
import { db } from "@/lib/db/client";
import {
  approvalInstances,
  departments,
  editions,
  events,
  exhibitors,
  memberships,
  signageItems,
  sponsors,
  standSubmissions,
  users,
  approvers,
  reminderLog,
} from "@/lib/db/schema";
import {
  can,
  confirmsForSuppliers,
  signoffPaused,
  type ApprovalStepCtx,
  type PermissionOverrides,
} from "@/lib/authz";
import { activeMembership } from "@/lib/users/active";
import { requireSession, type Session } from "@/lib/auth/actor";
import { itemAuthzCtx, loadItemBundle, stepIsMine } from "@/lib/domain/signage";
import { loadStandBundle, standAuthzCtx } from "@/lib/domain/stand";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { standsEnabled } from "@/lib/config";
import { rowToInstance } from "@/lib/workflow/persist";
import { roleLabel } from "@/lib/format";
import { itemPath } from "@/lib/edition-path";
import { todayInLondon } from "@/lib/today";
import {
  ARTWORK_FILTERS,
  reviewArtworkForItems,
  type ArtworkFilter,
  type ArtworkRow,
} from "@/lib/queries/artwork-approvals";

/**
 * Which pending steps could be this person's, narrowed in SQL so My Work
 * doesn't load every open sign-off in the organisation. can() still makes
 * the final call on each row.
 */
function candidateFilter(session: Session, all: boolean): SQL | undefined {
  const actor = session.actor;
  const me = eq(approvalInstances.assignedUserId, actor.userId);
  if (actor.kind === "staff") {
    if (actor.role === "admin") {
      return all ? undefined : or(me, eq(approvalInstances.assignedRole, "admin"));
    }
    const depts = actor.signoffDepartmentIds ?? [];
    // Print, delivery and install confirmations (supplier and ops steps) go
    // to whoever confirms for suppliers (signage.confirm), not by role.
    const production = and(
      isNull(approvalInstances.assignedUserId),
      eq(approvalInstances.stepKindSnapshot, "confirmation"),
      inArray(approvalInstances.assignedRole, ["supplier", "ops"]),
    );
    return or(
      me,
      and(
        isNull(approvalInstances.assignedUserId),
        eq(approvalInstances.assignedRole, actor.role),
        actor.role === "ops" ? ne(approvalInstances.stepKindSnapshot, "confirmation") : undefined,
      ),
      confirmsForSuppliers(actor) ? production : undefined,
      depts.length > 0
        ? and(
            isNull(approvalInstances.assignedUserId),
            inArray(approvalInstances.assignedDepartmentId, depts),
          )
        : undefined,
    );
  }
  const roles = [...new Set(actor.grants.map((g) => g.role))];
  if (roles.length === 0) return me;
  return or(
    me,
    and(isNull(approvalInstances.assignedUserId), inArray(approvalInstances.assignedRole, roles)),
  );
}

/**
 * My Work sign-offs: pending steps the current user can decide. Admins see
 * the ones addressed to them unless `all` is set. Deleted, held and archived
 * items are left out until they are restored or resumed.
 */
export async function pendingInstancesForUser(existing?: Session, opts: { all?: boolean } = {}) {
  const session = existing ?? (await requireSession());
  const filter = candidateFilter(session, opts.all ?? false);
  const rows = await db
    .select()
    .from(approvalInstances)
    .where(
      and(
        eq(approvalInstances.status, "pending"),
        standsEnabled ? undefined : eq(approvalInstances.entityType, "signage_item"),
        filter,
      ),
    )
    .orderBy(sql`${approvalInstances.dueAt} ASC NULLS LAST`);

  const bundles = await Promise.all(
    rows.map((row) =>
      row.entityType === "signage_item"
        ? loadItemBundle(db, row.entityId, { organisationId: session.organisation.id })
        : loadStandBundle(db, row.entityId, { organisationId: session.organisation.id }),
    ),
  );

  const now = Date.now();
  const out = [];
  for (const [index, row] of rows.entries()) {
    const bundle = bundles[index];
    if (!bundle) continue;
    if (editionIsReadOnly(bundle.edition.status)) continue;
    const isSignage = row.entityType === "signage_item";
    if (isSignage) {
      const item = (bundle as NonNullable<Awaited<ReturnType<typeof loadItemBundle>>>).item;
      if (item.deletedAt || item.status === "on_hold") continue;
    }
    const stepCtx: ApprovalStepCtx = {
      assignedRole: row.assignedRole,
      assignedDepartmentId: row.assignedDepartmentId,
      stepKind: row.stepKindSnapshot,
      assignedUserId: row.assignedUserId,
      entity: isSignage
        ? { type: "signage_item", item: itemAuthzCtx(bundle as never) }
        : { type: "stand", sub: standAuthzCtx(bundle as never) },
    };
    if (!can(session.actor, { type: "approval.decide", step: stepCtx })) continue;
    out.push({
      row: rowToInstance(row),
      raw: row,
      bundle,
      isSignage,
      isOverdue: Boolean(row.dueAt && row.dueAt.getTime() < now),
    });
  }
  return out;
}

// ---------------------------------------------------------------------------
// Cheap SQL-only views of open sign-offs (counts for the navigation, the
// "Needs you" strip on My Work, the bell's Done state, and the Everyone's
// view). They join the record and its event instead of loading bundles, and
// leave out held, deleted and archived items like pendingInstancesForUser.

const itemJoin = and(
  eq(approvalInstances.entityType, "signage_item"),
  eq(signageItems.id, approvalInstances.entityId),
);
const subJoin = and(
  eq(approvalInstances.entityType, "stand_submission"),
  eq(standSubmissions.id, approvalInstances.entityId),
);
const editionJoin = sql`${editions.id} = coalesce(${signageItems.editionId}, ${standSubmissions.editionId})`;

/** Open steps on live records of this organisation. */
function liveOpen(organisationId: string): SQL | undefined {
  return and(
    eq(approvalInstances.status, "pending"),
    eq(events.organisationId, organisationId),
    ne(editions.status, "archived"),
    or(
      and(
        isNotNull(signageItems.id),
        isNull(signageItems.deletedAt),
        ne(signageItems.status, "on_hold"),
      ),
      standsEnabled ? isNotNull(standSubmissions.id) : undefined,
    ),
  );
}

/** Someone whose sign-off is paused (Users → "Sign-off paused") decides nothing. */
function isPaused(session: Session): boolean {
  const a = session.actor;
  return a.kind === "staff" && a.role !== "admin" && signoffPaused(a.overrides);
}

/** How many sign-offs are waiting on me, and how many of those are overdue. */
export async function countPendingForUser(
  session: Session,
): Promise<{ total: number; overdue: number }> {
  if (isPaused(session)) return { total: 0, overdue: 0 };
  const [row] = await db
    .select({
      total: sql<number>`count(*)::int`,
      overdue: sql<number>`(count(*) filter (where ${approvalInstances.dueAt} < now()))::int`,
    })
    .from(approvalInstances)
    .leftJoin(signageItems, itemJoin)
    .leftJoin(standSubmissions, subJoin)
    .innerJoin(editions, editionJoin)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(liveOpen(session.organisation.id), candidateFilter(session, false)));
  return { total: Number(row?.total ?? 0), overdue: Number(row?.overdue ?? 0) };
}

export type PendingSummaryRow = {
  instanceId: string;
  entityType: "signage_item" | "stand_submission";
  ref: string;
  name: string;
  href: string;
  eventName: string;
  stepName: string;
  stepKind: "approval" | "confirmation";
  dueAt: Date | null;
};

/** The sign-offs waiting on me that are due soonest (My Work's "Needs you"). */
export async function oldestPendingForUser(
  session: Session,
  limit = 3,
): Promise<PendingSummaryRow[]> {
  if (isPaused(session)) return [];
  const rows = await db
    .select({
      instance: approvalInstances,
      itemRef: signageItems.ref,
      itemName: signageItems.name,
      itemKind: signageItems.kind,
      subRef: standSubmissions.ref,
      eventCode: editions.code,
      eventName: editions.name,
    })
    .from(approvalInstances)
    .leftJoin(signageItems, itemJoin)
    .leftJoin(standSubmissions, subJoin)
    .innerJoin(editions, editionJoin)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(liveOpen(session.organisation.id), candidateFilter(session, false)))
    .orderBy(sql`${approvalInstances.dueAt} ASC NULLS LAST`, asc(approvalInstances.createdAt))
    .limit(limit);
  return rows.map((r) => {
    const isItem = r.instance.entityType === "signage_item";
    const ref = (isItem ? r.itemRef : r.subRef) ?? "";
    return {
      instanceId: r.instance.id,
      entityType: r.instance.entityType,
      ref,
      name: isItem ? (r.itemName ?? "") : `Stand ${ref}`,
      href: isItem
        ? `${itemPath(r.eventCode, { kind: r.itemKind ?? "signage", ref })}?tab=artwork`
        : `/${r.eventCode}/stands/${ref}`,
      eventName: r.eventName,
      stepName: r.instance.stepNameSnapshot,
      stepKind: r.instance.stepKindSnapshot,
      dueAt: r.instance.dueAt,
    };
  });
}

/** Every open sign-off in the organisation: how many, how many overdue, on how many items. */
export async function teamPendingSummary(
  organisationId: string,
): Promise<{ total: number; overdue: number; records: number }> {
  const [row] = await db
    .select({
      total: sql<number>`count(*)::int`,
      overdue: sql<number>`(count(*) filter (where ${approvalInstances.dueAt} < now()))::int`,
      records: sql<number>`count(distinct ${approvalInstances.entityId})::int`,
    })
    .from(approvalInstances)
    .leftJoin(signageItems, itemJoin)
    .leftJoin(standSubmissions, subJoin)
    .innerJoin(editions, editionJoin)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(liveOpen(organisationId));
  return {
    total: Number(row?.total ?? 0),
    overdue: Number(row?.overdue ?? 0),
    records: Number(row?.records ?? 0),
  };
}

/**
 * Of these records, the ones where I still have a step waiting — for the
 * bell, which shows the others' "Please sign off" as Done.
 */
export async function pendingEntityIdsForUser(
  session: Session,
  entityIds: string[],
): Promise<Set<string>> {
  const wanted = [...new Set(entityIds)].filter(Boolean);
  if (wanted.length === 0 || isPaused(session)) return new Set();
  const rows = await db
    .selectDistinct({ id: approvalInstances.entityId })
    .from(approvalInstances)
    .leftJoin(signageItems, itemJoin)
    .leftJoin(standSubmissions, subJoin)
    .innerJoin(editions, editionJoin)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(
      and(
        inArray(approvalInstances.entityId, wanted),
        liveOpen(session.organisation.id),
        candidateFilter(session, false),
      ),
    );
  return new Set(rows.map((r) => r.id));
}

/**
 * The group a step belongs to in Approvals → Everyone's (and the ?who= key
 * that opens it): the named person, else the department, else the role.
 */
export function signoffGroupKey(step: {
  assignedUserId: string | null;
  assignedDepartmentId: string | null;
  assignedRole: string | null;
}): string {
  if (step.assignedUserId) return `user:${step.assignedUserId}`;
  if (step.assignedDepartmentId) return `dept:${step.assignedDepartmentId}`;
  return `role:${step.assignedRole ?? "none"}`;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * ?who= on Approvals → Everyone's: one or more group keys, comma-separated
 * ("dept:<id>", "user:<id>", "role:<role>"). Anything else is dropped.
 */
export function parseWhoParam(value: string | string[] | undefined | null): string[] {
  const raw = Array.isArray(value) ? value.join(",") : (value ?? "");
  const keys = raw
    .split(",")
    .map((k) => k.trim())
    .filter((k) => {
      const at = k.indexOf(":");
      const kind = k.slice(0, at);
      const id = k.slice(at + 1);
      if (at < 0) return false;
      if (kind === "user" || kind === "dept") return UUID.test(id);
      return kind === "role" && /^[a-z_]{1,40}$/.test(id);
    });
  return [...new Set(keys)].slice(0, 20);
}

/** SQL for the steps in these groups (exactly as signoffGroupKey groups them). */
function whoFilter(keys: string[]): SQL | undefined {
  if (keys.length === 0) return undefined;
  return or(
    ...keys.map((key) => {
      const at = key.indexOf(":");
      const kind = key.slice(0, at);
      const id = key.slice(at + 1);
      if (kind === "user") return eq(approvalInstances.assignedUserId, id);
      if (kind === "dept") {
        return and(
          isNull(approvalInstances.assignedUserId),
          eq(approvalInstances.assignedDepartmentId, id),
        );
      }
      return and(
        isNull(approvalInstances.assignedUserId),
        isNull(approvalInstances.assignedDepartmentId),
        id === "none"
          ? isNull(approvalInstances.assignedRole)
          : eq(approvalInstances.assignedRole, id),
      );
    }),
  );
}

export type TeamSignoff = {
  instanceId: string;
  entityType: "signage_item" | "stand_submission";
  ref: string;
  name: string;
  href: string;
  eventCode: string;
  eventName: string;
  stepName: string;
  stepKind: "approval" | "confirmation";
  dueAt: Date | null;
  isOverdue: boolean;
  /** Who it is with, in words: "Dana Director", "Marketing", "Venue". */
  waitingOn: string;
  /** Group key: the department, the named person or the role. */
  groupKey: string;
  /** People it is with, by name (for "Marcus Marketing will be told"). */
  people: string[];
  expectedLockedVersionId: string | null;
  canRemind: boolean;
  /** Someone already pressed Remind on it today (once a day per step). */
  remindedToday: boolean;
  /** It is (also) the viewer's own to decide, so it is in their Waiting on me. */
  isMine: boolean;
  canDecide: boolean;
  requiresPhoto: boolean;
};

/**
 * Every open sign-off in the organisation with who it is waiting on — the
 * Approvals "Everyone's" view for chasing. can() decides who may chase or
 * decide each one.
 */
export async function openSignoffsForTeam(
  session: Session,
  opts: {
    editionId?: string | null;
    search?: string;
    overdueOnly?: boolean;
    /** Only these groups (?who=, see signoffGroupKey). */
    who?: string[];
  } = {},
): Promise<TeamSignoff[]> {
  const search = opts.search?.trim();
  const assignee = alias(users, "assignee");
  const rows = await db
    .select({
      instance: approvalInstances,
      item: {
        id: signageItems.id,
        ref: signageItems.ref,
        name: signageItems.name,
        kind: signageItems.kind,
        ownerUserId: signageItems.ownerUserId,
        sponsorId: signageItems.sponsorId,
        supplierId: signageItems.supplierId,
        requiresVenueApproval: signageItems.requiresVenueApproval,
        status: signageItems.status,
        currentArtworkVersionId: signageItems.currentArtworkVersionId,
      },
      sub: {
        id: standSubmissions.id,
        ref: standSubmissions.ref,
        exhibitorId: standSubmissions.exhibitorId,
        contractorId: standSubmissions.contractorId,
        submissionVersion: standSubmissions.submissionVersion,
      },
      exhibitorName: exhibitors.companyName,
      standNumber: exhibitors.standNumber,
      edition: {
        id: editions.id,
        code: editions.code,
        name: editions.name,
        venueId: editions.venueId,
      },
      departmentName: departments.name,
      assigneeName: assignee.fullName,
      assigneeEmail: assignee.email,
    })
    .from(approvalInstances)
    .leftJoin(signageItems, itemJoin)
    .leftJoin(standSubmissions, subJoin)
    .leftJoin(exhibitors, eq(exhibitors.id, standSubmissions.exhibitorId))
    .innerJoin(editions, editionJoin)
    .innerJoin(events, eq(editions.eventId, events.id))
    .leftJoin(departments, eq(departments.id, approvalInstances.assignedDepartmentId))
    .leftJoin(assignee, eq(assignee.id, approvalInstances.assignedUserId))
    .where(
      and(
        liveOpen(session.organisation.id),
        opts.editionId ? eq(editions.id, opts.editionId) : undefined,
        opts.overdueOnly ? lt(approvalInstances.dueAt, new Date()) : undefined,
        whoFilter(opts.who ?? []),
        search
          ? or(
              ilike(signageItems.name, `%${search}%`),
              ilike(signageItems.ref, `%${search}%`),
              ilike(standSubmissions.ref, `%${search}%`),
            )
          : undefined,
      ),
    )
    .orderBy(sql`${approvalInstances.dueAt} ASC NULLS LAST`, asc(approvalInstances.createdAt))
    .limit(500);

  // Names of the people each department or role step is with.
  const deptIds = [
    ...new Set(rows.map((r) => r.instance.assignedDepartmentId).filter(Boolean)),
  ] as string[];
  // Only people who can sign now: active, sign-off not paused.
  const deptPeople = deptIds.length
    ? (
        await db
          .select({
            departmentId: approvers.departmentId,
            name: users.fullName,
            email: users.email,
            overrides: memberships.permissionOverrides,
          })
          .from(approvers)
          .innerJoin(users, eq(users.id, approvers.userId))
          .innerJoin(
            memberships,
            and(
              eq(memberships.userId, approvers.userId),
              eq(memberships.organisationId, approvers.organisationId),
            ),
          )
          .where(
            and(
              eq(approvers.organisationId, session.organisation.id),
              inArray(approvers.departmentId, deptIds),
              activeMembership(),
            ),
          )
      ).filter((p) => !signoffPaused(p.overrides as PermissionOverrides))
    : [];
  const staffRoles = ["admin", "ops", "marketing", "sales", "event_director", "viewer"];
  const roles = [
    ...new Set(
      rows
        .filter((r) => !r.instance.assignedUserId && !r.instance.assignedDepartmentId)
        .map((r) => r.instance.assignedRole)
        .filter((role): role is string => Boolean(role && staffRoles.includes(role))),
    ),
  ];
  const rolePeople = roles.length
    ? (
        await db
          .select({
            role: memberships.role,
            name: users.fullName,
            email: users.email,
            overrides: memberships.permissionOverrides,
          })
          .from(memberships)
          .innerJoin(users, eq(users.id, memberships.userId))
          .where(
            and(
              eq(memberships.organisationId, session.organisation.id),
              inArray(memberships.role, roles as (typeof memberships.$inferSelect)["role"][]),
              activeMembership(),
            ),
          )
      ).filter((p) => !signoffPaused(p.overrides as PermissionOverrides))
    : [];

  const instanceIds = rows.map((r) => r.instance.id);
  const reminded = instanceIds.length
    ? await db
        .select({ id: reminderLog.targetId })
        .from(reminderLog)
        .where(
          and(
            eq(reminderLog.targetType, "approval_instance"),
            eq(reminderLog.kind, "chaser"),
            eq(reminderLog.sentOn, todayInLondon()),
            inArray(reminderLog.targetId, instanceIds),
          ),
        )
    : [];
  const remindedIds = new Set(reminded.map((r) => r.id));

  const now = Date.now();
  const install = session.organisation.settings.install_photo_required;
  const me = session.actor;
  const mineIf = (inst: typeof approvalInstances.$inferSelect) => {
    if (inst.assignedUserId) return inst.assignedUserId === me.userId;
    if (me.kind !== "staff") return false;
    return stepIsMine(
      {
        stepKind: inst.stepKindSnapshot,
        assignedRole: inst.assignedRole,
        assignedUserId: inst.assignedUserId,
        assignedDepartmentId: inst.assignedDepartmentId,
      },
      me,
    );
  };
  return rows.map((r) => {
    const inst = r.instance;
    const isItem = inst.entityType === "signage_item" && r.item?.id;
    const ref = (isItem ? r.item!.ref : r.sub?.ref) ?? "";
    const people = inst.assignedUserId
      ? [r.assigneeName || r.assigneeEmail || "a named person"]
      : inst.assignedDepartmentId
        ? deptPeople
            .filter((p) => p.departmentId === inst.assignedDepartmentId)
            .map((p) => p.name || p.email)
        : inst.assignedRole
          ? rolePeople.filter((p) => p.role === inst.assignedRole).map((p) => p.name || p.email)
          : [];
    const waitingOn = inst.assignedUserId
      ? people[0]
      : inst.assignedDepartmentId
        ? (r.departmentName ?? "the department")
        : inst.assignedRole
          ? inst.assignedRole === "supplier" && inst.stepKindSnapshot === "confirmation"
            ? "Supplier or Operations"
            : roleLabel(inst.assignedRole)
          : "Nobody yet";
    const stepCtx: ApprovalStepCtx = {
      assignedRole: inst.assignedRole,
      assignedDepartmentId: inst.assignedDepartmentId,
      stepKind: inst.stepKindSnapshot,
      assignedUserId: inst.assignedUserId,
      entity: isItem
        ? {
            type: "signage_item",
            item: {
              organisationId: session.organisation.id,
              editionId: r.edition.id,
              venueId: r.edition.venueId,
              kind: r.item!.kind!,
              ownerUserId: r.item!.ownerUserId,
              sponsorId: r.item!.sponsorId,
              supplierId: r.item!.supplierId,
              requiresVenueApproval: r.item!.requiresVenueApproval!,
              status: r.item!.status!,
            },
          }
        : {
            type: "stand",
            sub: {
              organisationId: session.organisation.id,
              editionId: r.edition.id,
              venueId: r.edition.venueId,
              exhibitorId: r.sub!.exhibitorId!,
              contractorId: r.sub!.contractorId,
            },
          },
    };
    const canRemind = can(session.actor, { type: "approval.remind", step: stepCtx });
    return {
      instanceId: inst.id,
      entityType: inst.entityType,
      ref,
      name: isItem ? r.item!.name! : `${r.exhibitorName ?? "Stand"} — stand ${r.standNumber ?? ""}`,
      href: isItem
        ? `${itemPath(r.edition.code, { kind: r.item!.kind!, ref })}?tab=artwork`
        : `/${r.edition.code}/stands/${ref}`,
      eventCode: r.edition.code,
      eventName: r.edition.name,
      stepName: inst.stepNameSnapshot,
      stepKind: inst.stepKindSnapshot,
      dueAt: inst.dueAt,
      isOverdue: Boolean(inst.dueAt && inst.dueAt.getTime() < now),
      waitingOn,
      groupKey: signoffGroupKey(inst),
      people,
      expectedLockedVersionId: isItem
        ? (r.item!.currentArtworkVersionId ?? null)
        : String(r.sub?.submissionVersion ?? ""),
      canRemind,
      remindedToday: remindedIds.has(inst.id),
      isMine: mineIf(inst),
      canDecide: can(session.actor, { type: "approval.decide", step: stepCtx }),
      requiresPhoto: Boolean(
        inst.stepNameSnapshot === "Installed" && isItem && r.item!.kind === "signage" && install,
      ),
    };
  });
}

const OVERDUE_ARTWORK_LIMIT = 150;

/**
 * Approvals → All artwork with ?overdue=1: artwork whose sign-off in the
 * current round is past its due date (print, delivery and install
 * confirmations are not sign-offs), most overdue first. Live, not held,
 * not archived; optionally one event, a search and one of the status filters.
 */
export async function listOverdueArtwork(opts: {
  organisationId: string;
  editionId?: string | null;
  search?: string;
  filter?: ArtworkFilter;
}): Promise<{ rows: ArtworkRow[]; truncated: boolean }> {
  const search = opts.search?.trim();
  const statuses =
    opts.filter && opts.filter !== "all"
      ? (ARTWORK_FILTERS[opts.filter].statuses as readonly string[])
      : null;
  const late = await db
    .select({ id: signageItems.id })
    .from(approvalInstances)
    .innerJoin(signageItems, itemJoin)
    .innerJoin(editions, eq(editions.id, signageItems.editionId))
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(
      and(
        eq(approvalInstances.status, "pending"),
        eq(approvalInstances.stepKindSnapshot, "approval"),
        lt(approvalInstances.dueAt, new Date()),
        eq(approvalInstances.runNumber, signageItems.currentRunNumber),
        eq(events.organisationId, opts.organisationId),
        ne(editions.status, "archived"),
        isNull(signageItems.deletedAt),
        ne(signageItems.status, "on_hold"),
        isNotNull(signageItems.currentArtworkVersionId),
        opts.editionId ? eq(signageItems.editionId, opts.editionId) : undefined,
        statuses
          ? inArray(signageItems.status, statuses as (typeof signageItems.$inferSelect)["status"][])
          : undefined,
        search
          ? or(ilike(signageItems.name, `%${search}%`), ilike(signageItems.ref, `%${search}%`))
          : undefined,
      ),
    )
    .groupBy(signageItems.id)
    .orderBy(sql`min(${approvalInstances.dueAt}) ASC`, asc(signageItems.ref))
    .limit(OVERDUE_ARTWORK_LIMIT + 1);
  const truncated = late.length > OVERDUE_ARTWORK_LIMIT;
  const ids = late.slice(0, OVERDUE_ARTWORK_LIMIT).map((r) => r.id);
  if (ids.length === 0) return { rows: [], truncated: false };

  const [artwork, items] = await Promise.all([
    reviewArtworkForItems(opts.organisationId, ids),
    db
      .select({
        item: {
          id: signageItems.id,
          ref: signageItems.ref,
          name: signageItems.name,
          kind: signageItems.kind,
          status: signageItems.status,
          category: signageItems.category,
        },
        showCode: editions.code,
        showName: editions.name,
        sponsorName: sponsors.companyName,
      })
      .from(signageItems)
      .innerJoin(editions, eq(editions.id, signageItems.editionId))
      .leftJoin(sponsors, eq(sponsors.id, signageItems.sponsorId))
      .where(inArray(signageItems.id, ids)),
  ]);
  const byId = new Map(items.map((r) => [r.item.id, r]));
  const rows: ArtworkRow[] = [];
  for (const id of ids) {
    const found = byId.get(id);
    const art = artwork.get(id);
    if (!found || !art) continue;
    const { item, showCode, showName, sponsorName } = found;
    rows.push({
      id: item.id,
      ref: item.ref,
      name: item.name,
      kind: item.kind,
      status: item.status,
      category: item.category,
      sponsorName,
      showCode,
      showName,
      version: art.current.versionNumber,
      uploadedAt: new Date(art.current.uploadedAt),
      previewUrl: art.current.thumbUrl,
      href: `${itemPath(showCode, item)}?tab=artwork`,
      signoffs: art.signoffs
        .filter((st) => st.stepKind === "approval")
        .map((st) => ({
          id: st.id,
          stepName: st.stepName,
          status: st.status,
          who: st.who,
          deciderName: st.deciderName,
          decidedAt: st.decidedAt,
          comment: st.comment,
        })),
    });
  }
  return { rows, truncated };
}
