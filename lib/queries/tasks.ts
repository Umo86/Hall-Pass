import "server-only";
import { and, asc, eq, gte, inArray, isNull, ne, or, sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { alias } from "drizzle-orm/pg-core";
import { editions, taskAttachments, tasks, users } from "@/lib/db/schema";
import { todayInLondon } from "@/lib/today";

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
  subtasks: BoardSubtask[];
  /** Subtasks past their date and not done. */
  overdueSubtasks: number;
  canDelete: boolean;
};

export type BoardScope = "mine" | "given" | "everyone";

/**
 * The My Work board: top-level tasks with their subtasks and attachments.
 * "mine" = assigned to me; "given" = I handed to others; "everyone" (admins).
 * Completed tasks drop off after 30 days.
 */
export async function boardTasks(opts: {
  organisationId: string;
  userId: string;
  isAdmin: boolean;
  scope: BoardScope;
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
  const top = await db
    .select({
      task: tasks,
      editionCode: editions.code,
      creatorName: creator.fullName,
      creatorEmail: creator.email,
      ownerName: owner.fullName,
      ownerEmail: owner.email,
    })
    .from(tasks)
    .leftJoin(editions, eq(tasks.editionId, editions.id))
    .innerJoin(creator, eq(tasks.createdByUserId, creator.id))
    .innerJoin(owner, eq(tasks.assignedToUserId, owner.id))
    .where(
      and(
        eq(tasks.organisationId, opts.organisationId),
        isNull(tasks.parentTaskId),
        scopeFilter,
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

  return top.map(({ task, editionCode, creatorName, creatorEmail, ownerName, ownerEmail }) => {
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
      subtasks,
      overdueSubtasks: subtasks.filter((s) => s.overdue).length,
      canDelete: opts.isAdmin || task.createdByUserId === opts.userId,
    };
  });
}
