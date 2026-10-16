import "server-only";
import { and, asc, eq, gte, inArray, isNull, lte, ne, or, sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { alias } from "drizzle-orm/pg-core";
import {
  editions,
  signageItems,
  standSubmissions,
  taskAttachments,
  tasks,
  users,
} from "@/lib/db/schema";
import { todayInLondon } from "@/lib/today";
import { addDaysIso } from "@/lib/deadlines";
import { itemPath } from "@/lib/edition-path";

export type BoardAttachment = { id: string; fileName: string; fileSize: number };

export type BoardSubtask = {
  id: string;
  title: string;
  status: "open" | "in_progress" | "done";
  dueDate: string | null;
  overdue: boolean;
  attachments: BoardAttachment[];
};

export type BoardTask = BoardSubtask & {
  notes: string | null;
  assignedToUserId: string;
  assignedToName: string;
  createdByUserId: string;
  createdByName: string;
  editionCode: string | null;
  editionName: string | null;
  /** The item the task is about, with a link to it. */
  entity: { ref: string; href: string } | null;
  createdAt: string;
  completedAt: string | null;
  subtasks: BoardSubtask[];
  /** Subtasks past their date and not done. */
  overdueSubtasks: number;
  canDelete: boolean;
};

export type BoardScope = "mine" | "given" | "everyone";

/**
 * The My Work board: top-level tasks with their subtasks and attachments.
 * "mine" = assigned to me; "given" = I handed to others; "everyone" (admins).
 * Completed tasks drop off after 30 days. `editionId` narrows it to one event.
 */
export async function boardTasks(opts: {
  organisationId: string;
  userId: string;
  isAdmin: boolean;
  scope: BoardScope;
  editionId?: string | null;
}): Promise<BoardTask[]> {
  const todayIso = todayInLondon();
  const creator = alias(users, "task_creator");
  const owner = alias(users, "task_owner");
  const cutoff = new Date(Date.now() - 30 * 86_400_000);
  const scopeFilter =
    opts.scope === "given"
      ? and(eq(tasks.createdByUserId, opts.userId), ne(tasks.assignedToUserId, opts.userId))
      : opts.scope === "everyone" && opts.isAdmin
        ? undefined
        : eq(tasks.assignedToUserId, opts.userId);
  const itemEdition = alias(editions, "item_edition");
  const subEdition = alias(editions, "sub_edition");
  const top = await db
    .select({
      task: tasks,
      editionCode: editions.code,
      editionName: editions.name,
      itemRef: signageItems.ref,
      itemKind: signageItems.kind,
      itemDeleted: signageItems.deletedAt,
      itemEditionCode: itemEdition.code,
      subRef: standSubmissions.ref,
      subEditionCode: subEdition.code,
      creatorName: creator.fullName,
      creatorEmail: creator.email,
      ownerName: owner.fullName,
      ownerEmail: owner.email,
    })
    .from(tasks)
    .leftJoin(editions, eq(tasks.editionId, editions.id))
    .leftJoin(
      signageItems,
      and(eq(tasks.entityType, "signage_item"), eq(signageItems.id, tasks.entityId)),
    )
    .leftJoin(itemEdition, eq(itemEdition.id, signageItems.editionId))
    .leftJoin(
      standSubmissions,
      and(eq(tasks.entityType, "stand_submission"), eq(standSubmissions.id, tasks.entityId)),
    )
    .leftJoin(subEdition, eq(subEdition.id, standSubmissions.editionId))
    .innerJoin(creator, eq(tasks.createdByUserId, creator.id))
    .innerJoin(owner, eq(tasks.assignedToUserId, owner.id))
    .where(
      and(
        eq(tasks.organisationId, opts.organisationId),
        isNull(tasks.parentTaskId),
        scopeFilter,
        opts.editionId ? eq(tasks.editionId, opts.editionId) : undefined,
        or(ne(tasks.status, "done"), gte(tasks.completedAt, cutoff)),
      ),
    )
    .orderBy(sql`${tasks.dueDate} ASC NULLS LAST`, asc(tasks.createdAt))
    .limit(300);
  const ids = top.map((t) => t.task.id);
  const subs = ids.length
    ? await db
        .select()
        .from(tasks)
        .where(inArray(tasks.parentTaskId, ids))
        .orderBy(sql`${tasks.dueDate} ASC NULLS LAST`, asc(tasks.createdAt))
    : [];
  const allIds = [...ids, ...subs.map((s) => s.id)];
  const files = allIds.length
    ? await db
        .select({
          id: taskAttachments.id,
          taskId: taskAttachments.taskId,
          fileName: taskAttachments.fileName,
          fileSize: taskAttachments.fileSize,
        })
        .from(taskAttachments)
        .where(inArray(taskAttachments.taskId, allIds))
        .orderBy(asc(taskAttachments.createdAt))
    : [];
  const filesOf = (id: string) =>
    files
      .filter((f) => f.taskId === id)
      .map(({ id: fid, fileName, fileSize }) => ({ id: fid, fileName, fileSize }));
  const isOverdue = (t: { status: string; dueDate: string | null }) =>
    t.status !== "done" && Boolean(t.dueDate && t.dueDate < todayIso);

  return top.map((row) => {
    const { task, editionCode, editionName, creatorName, creatorEmail, ownerName, ownerEmail } =
      row;
    const entity =
      row.itemRef && row.itemEditionCode && !row.itemDeleted
        ? {
            ref: row.itemRef,
            href: itemPath(row.itemEditionCode, {
              kind: row.itemKind ?? "signage",
              ref: row.itemRef,
            }),
          }
        : row.subRef && row.subEditionCode
          ? { ref: row.subRef, href: `/${row.subEditionCode}/stands/${row.subRef}` }
          : null;
    const subtasks = subs
      .filter((s) => s.parentTaskId === task.id)
      .map((s) => ({
        id: s.id,
        title: s.title,
        status: s.status,
        dueDate: s.dueDate,
        overdue: isOverdue(s),
        attachments: filesOf(s.id),
      }));
    return {
      id: task.id,
      title: task.title,
      notes: task.notes,
      status: task.status,
      dueDate: task.dueDate,
      overdue: isOverdue(task),
      attachments: filesOf(task.id),
      assignedToUserId: task.assignedToUserId,
      assignedToName: ownerName || ownerEmail,
      createdByUserId: task.createdByUserId,
      createdByName: creatorName || creatorEmail,
      editionCode,
      editionName,
      entity,
      createdAt: task.createdAt.toISOString(),
      completedAt: task.completedAt ? task.completedAt.toISOString() : null,
      subtasks,
      overdueSubtasks: subtasks.filter((s) => s.overdue).length,
      canDelete: opts.isAdmin || task.createdByUserId === opts.userId,
    };
  });
}

/**
 * Open top-level tasks per person: overdue (the task or one of its
 * subtasks), due today, and due in the next seven days. The one count both
 * My Work (its strip and the number by My Work in the navigation: overdue +
 * due today) and the morning task reminder use, so they always agree.
 */
export async function dueTaskCounts(opts: {
  today?: string;
  organisationId?: string;
  userId?: string;
}): Promise<
  {
    organisationId: string;
    userId: string;
    overdue: number;
    dueToday: number;
    dueThisWeek: number;
  }[]
> {
  const today = opts.today ?? todayInLondon();
  const weekEnd = addDaysIso(today, 7);
  const lateSubtask = sql`exists (
    select 1 from ${tasks} sub
    where sub.parent_task_id = ${tasks.id} and sub.status <> 'done' and sub.due_date < ${today}
  )`;
  const rows = await db
    .select({
      organisationId: tasks.organisationId,
      userId: tasks.assignedToUserId,
      overdue: sql<number>`(count(*) filter (where ${tasks.dueDate} < ${today} or ${lateSubtask}))::int`,
      dueToday: sql<number>`(count(*) filter (where ${tasks.dueDate} = ${today} and not ${lateSubtask}))::int`,
      dueThisWeek: sql<number>`(count(*) filter (where ${tasks.dueDate} >= ${today} and ${tasks.dueDate} <= ${weekEnd}))::int`,
    })
    .from(tasks)
    .where(
      and(
        opts.organisationId ? eq(tasks.organisationId, opts.organisationId) : undefined,
        opts.userId ? eq(tasks.assignedToUserId, opts.userId) : undefined,
        isNull(tasks.parentTaskId),
        ne(tasks.status, "done"),
        or(lte(tasks.dueDate, weekEnd), lateSubtask),
      ),
    )
    .groupBy(tasks.organisationId, tasks.assignedToUserId);
  return rows.map((r) => ({
    organisationId: r.organisationId,
    userId: r.userId,
    overdue: Number(r.overdue ?? 0),
    dueToday: Number(r.dueToday ?? 0),
    dueThisWeek: Number(r.dueThisWeek ?? 0),
  }));
}

/**
 * My open tasks at a glance: overdue (the task or one of its subtasks), due
 * today, and due in the next seven days (dueTaskCounts). Drives the My Work
 * strip and the count next to My Work in the navigation (overdue + due today).
 */
export async function myTaskSummary(opts: {
  organisationId: string;
  userId: string;
  today?: string;
}): Promise<{ overdue: number; dueToday: number; dueThisWeek: number }> {
  const [row] = await dueTaskCounts(opts);
  return {
    overdue: row?.overdue ?? 0,
    dueToday: row?.dueToday ?? 0,
    dueThisWeek: row?.dueThisWeek ?? 0,
  };
}
