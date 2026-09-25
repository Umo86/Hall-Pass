import "server-only";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { tasks } from "@/lib/db/schema";
import { can, type Actor } from "@/lib/authz";

type Task = typeof tasks.$inferSelect;

/**
 * May this person work on the task — its assignee, its creator or an admin —
 * or, for a subtask, on the task it belongs to?
 */
export async function canWorkOnTask(
  actor: Actor,
  organisationId: string,
  task: Task,
): Promise<boolean> {
  const allowed = (t: Task) =>
    can(actor, {
      type: "task.update",
      task: { assignedToUserId: t.assignedToUserId, createdByUserId: t.createdByUserId },
    });
  if (allowed(task)) return true;
  if (!task.parentTaskId) return false;
  const parent = await db.query.tasks.findFirst({
    where: and(eq(tasks.id, task.parentTaskId), eq(tasks.organisationId, organisationId)),
  });
  return Boolean(parent && allowed(parent));
}
