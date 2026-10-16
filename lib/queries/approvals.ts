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
  standSubmissions,
  users,
  approvers,
  reminderLog,
} from "@/lib/db/schema";
import { can, type ApprovalStepCtx } from "@/lib/authz";
import { requireSession, type Session } from "@/lib/auth/actor";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { loadStandBundle, standAuthzCtx } from "@/lib/domain/stand";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { standsEnabled } from "@/lib/config";
import { rowToInstance } from "@/lib/workflow/persist";
import { roleLabel } from "@/lib/format";
import { itemPath } from "@/lib/edition-path";
import { todayInLondon } from "@/lib/today";

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
    return or(
      me,
      and(isNull(approvalInstances.assignedUserId), eq(approvalInstances.assignedRole, actor.role)),
      // Operations can confirm a supplier's print / delivery steps themselves.
      actor.role === "ops"
        ? and(
            isNull(approvalInstances.assignedUserId),
            eq(approvalInstances.assignedRole, "supplier"),
            eq(approvalInstances.stepKindSnapshot, "confirmation"),
          )
        : undefined,
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
function signoffPaused(session: Session): boolean {
  const a = session.actor;
  return a.kind === "staff" && a.role !== "admin" && a.overrides?.["approval.decide"] === false;
}

/** How many sign-offs are waiting on me, and how many of those are overdue. */
export async function countPendingForUser(
  session: Session,
): Promise<{ total: number; overdue: number }> {
  if (signoffPaused(session)) return { total: 0, overdue: 0 };
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
  if (signoffPaused(session)) return [];
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
  if (wanted.length === 0 || signoffPaused(session)) return new Set();
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
  opts: { editionId?: string | null; search?: string; overdueOnly?: boolean } = {},
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
  const deptPeople = deptIds.length
    ? await db
        .select({ departmentId: approvers.departmentId, name: users.fullName, email: users.email })
        .from(approvers)
        .innerJoin(users, eq(users.id, approvers.userId))
        .where(
          and(
            eq(approvers.organisationId, session.organisation.id),
            inArray(approvers.departmentId, deptIds),
          ),
        )
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
    ? await db
        .select({ role: memberships.role, name: users.fullName, email: users.email })
        .from(memberships)
        .innerJoin(users, eq(users.id, memberships.userId))
        .where(
          and(
            eq(memberships.organisationId, session.organisation.id),
            inArray(memberships.role, roles as (typeof memberships.$inferSelect)["role"][]),
          ),
        )
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
    if (inst.assignedDepartmentId) {
      return (me.signoffDepartmentIds ?? []).includes(inst.assignedDepartmentId);
    }
    if (inst.assignedRole === me.role) return true;
    return (
      me.role === "ops" &&
      inst.assignedRole === "supplier" &&
      inst.stepKindSnapshot === "confirmation"
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
    const canRemind =
      stepCtx.entity.type === "signage_item"
        ? can(session.actor, { type: "signage.submit", item: stepCtx.entity.item })
        : can(session.actor, { type: "stand.review" });
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
      groupKey: inst.assignedUserId
        ? `user:${inst.assignedUserId}`
        : inst.assignedDepartmentId
          ? `dept:${inst.assignedDepartmentId}`
          : `role:${inst.assignedRole ?? "none"}`,
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
