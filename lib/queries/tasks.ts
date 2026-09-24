import "server-only";
import { and, asc, desc, eq, ne } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { alias } from "drizzle-orm/pg-core";
import { editions, tasks, users } from "@/lib/db/schema";
import { todayInLondon } from "@/lib/today";

export type TaskRow = {
  id: string;
  title: string;
  notes: string | null;
  status: string;
  dueDate: string | null;
  overdue: boolean;
  editionCode: string | null;
  assignedToUserId: string;
  createdByUserId: string;
  createdByName: string | null;
  assignedToName: string | null;
  entityType: string | null;
  entityId: string | null;
  completedAt: string | null;
};

function toRow(
  r: {
    task: typeof tasks.$inferSelect;
    editionCode: string | null;
    createdByName: string | null;
    assignedToName?: string | null;
  },
  todayIso: string,
): TaskRow {
  return {
    id: r.task.id,
    title: r.task.title,
    notes: r.task.notes,
    status: r.task.status,
    dueDate: r.task.dueDate,
    overdue: r.task.status === "open" && Boolean(r.task.dueDate && r.task.dueDate < todayIso),
    editionCode: r.editionCode,
    assignedToUserId: r.task.assignedToUserId,
    createdByUserId: r.task.createdByUserId,
    createdByName: r.createdByName,
    assignedToName: r.assignedToName ?? null,
    entityType: r.task.entityType,
    entityId: r.task.entityId,
    completedAt: r.task.completedAt?.toISOString() ?? null,
  };
}

const baseSelect = {
  task: tasks,
  editionCode: editions.code,
  createdByName: users.fullName,
};

/** Open tasks assigned to the user, soonest due first (undated last). */
export async function openTasksForUser(userId: string): Promise<TaskRow[]> {
  const todayIso = todayInLondon();
  const rows = await db
    .select(baseSelect)
    .from(tasks)
    .leftJoin(editions, eq(tasks.editionId, editions.id))
    .leftJoin(users, eq(tasks.createdByUserId, users.id))
    .where(and(eq(tasks.assignedToUserId, userId), eq(tasks.status, "open")))
    .orderBy(asc(tasks.dueDate), asc(tasks.createdAt));
  return rows.map((r) => toRow(r, todayIso));
}

/** The most recently completed tasks, for a small "done" tail. */
export async function recentlyCompletedForUser(userId: string, limit = 5): Promise<TaskRow[]> {
  const todayIso = todayInLondon();
  const rows = await db
    .select(baseSelect)
    .from(tasks)
    .leftJoin(editions, eq(tasks.editionId, editions.id))
    .leftJoin(users, eq(tasks.createdByUserId, users.id))
    .where(and(eq(tasks.assignedToUserId, userId), eq(tasks.status, "done")))
    .orderBy(desc(tasks.completedAt))
    .limit(limit);
  return rows.map((r) => toRow(r, todayIso));
}

const assignee = alias(users, "task_assignee");

/** Open tasks this user gave to other people, so they can follow them up. */
export async function tasksAssignedByUser(userId: string): Promise<TaskRow[]> {
  const todayIso = todayInLondon();
  const rows = await db
    .select({ ...baseSelect, assignedToName: assignee.fullName })
    .from(tasks)
    .leftJoin(editions, eq(tasks.editionId, editions.id))
    .leftJoin(users, eq(tasks.createdByUserId, users.id))
    .leftJoin(assignee, eq(tasks.assignedToUserId, assignee.id))
    .where(
      and(
        eq(tasks.createdByUserId, userId),
        ne(tasks.assignedToUserId, userId),
        eq(tasks.status, "open"),
      ),
    )
    .orderBy(asc(tasks.dueDate), asc(tasks.createdAt));
  return rows.map((r) => toRow(r, todayIso));
}
