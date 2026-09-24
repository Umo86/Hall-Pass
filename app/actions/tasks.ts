"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { tasks } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { notify } from "@/lib/notify";
import { fail, success, type ActionResult } from "@/lib/actions/result";

const createTaskSchema = z.object({
  title: z.string().trim().min(1, "Give the task a title").max(300),
  notes: z.string().max(2000).optional().nullable(),
  dueDate: z.string().date().optional().nullable(),
  assignedToUserId: z.string().uuid().optional().nullable(),
  editionId: z.string().uuid().optional().nullable(),
  entityType: z.enum(["signage_item", "stand_submission"]).optional().nullable(),
  entityId: z.string().uuid().optional().nullable(),
});

export async function createTask(input: unknown): Promise<ActionResult<{ id: string }>> {
  const parsed = createTaskSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "task.create" })) return fail("You cannot create tasks");

  const assignee = parsed.data.assignedToUserId ?? session.user.id;
  if (assignee !== session.user.id && !can(session.actor, { type: "task.assign" })) {
    return fail("You cannot assign tasks to other people");
  }

  try {
    const id = await db.transaction(async (tx) => {
      const [task] = await tx
        .insert(tasks)
        .values({
          organisationId: session.organisation.id,
          editionId: parsed.data.editionId ?? null,
          title: parsed.data.title,
          notes: parsed.data.notes?.trim() ? parsed.data.notes.trim() : null,
          dueDate: parsed.data.dueDate ?? null,
          assignedToUserId: assignee,
          createdByUserId: session.user.id,
          entityType: parsed.data.entityType ?? null,
          entityId: parsed.data.entityId ?? null,
        })
        .returning();
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: parsed.data.editionId ?? undefined,
        actorUserId: session.user.id,
        entityType: "task",
        entityId: task.id,
        action: "create",
        after: { title: task.title, assignedTo: assignee },
        summary: `Task created: ${task.title}`,
      });
      if (assignee !== session.user.id) {
        await notify(tx, {
          userIds: [assignee],
          kind: "task_assigned",
          title: `Task assigned: ${task.title}`,
          body: parsed.data.dueDate ? `Due ${parsed.data.dueDate}` : undefined,
          link: "/approvals",
        });
      }
      return task.id;
    });
    revalidatePath("/approvals");
    return success({ id }, "Task added");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not add the task");
  }
}

async function loadOwnTask(id: string, organisationId: string) {
  return db.query.tasks.findFirst({
    where: and(eq(tasks.id, id), eq(tasks.organisationId, organisationId)),
  });
}

/** Toggle a task between open and done. */
export async function completeTask(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid(), done: z.boolean() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const task = await loadOwnTask(parsed.data.id, session.organisation.id);
  if (!task) return fail("Task not found");
  if (
    !can(session.actor, {
      type: "task.update",
      task: { assignedToUserId: task.assignedToUserId, createdByUserId: task.createdByUserId },
    })
  ) {
    return fail("This task is not yours to update");
  }
  await db.transaction(async (tx) => {
    await tx
      .update(tasks)
      .set({
        status: parsed.data.done ? "done" : "open",
        completedAt: parsed.data.done ? new Date() : null,
      })
      .where(eq(tasks.id, task.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: task.editionId ?? undefined,
      actorUserId: session.user.id,
      entityType: "task",
      entityId: task.id,
      action: "update",
      summary: `Task ${parsed.data.done ? "completed" : "reopened"}: ${task.title}`,
    });
  });
  revalidatePath("/approvals");
  return success(undefined, parsed.data.done ? "Task completed" : "Task reopened");
}

const updateTaskSchema = z.object({
  id: z.string().uuid(),
  title: z.string().trim().min(1).max(300).optional(),
  notes: z.string().max(2000).optional().nullable(),
  dueDate: z.string().date().optional().nullable(),
  assignedToUserId: z.string().uuid().optional(),
});

export async function updateTask(input: unknown): Promise<ActionResult> {
  const parsed = updateTaskSchema.safeParse(input);
  if (!parsed.success) return fail("Check the task details");
  const session = await requireSession();
  const task = await loadOwnTask(parsed.data.id, session.organisation.id);
  if (!task) return fail("Task not found");
  if (
    !can(session.actor, {
      type: "task.update",
      task: { assignedToUserId: task.assignedToUserId, createdByUserId: task.createdByUserId },
    })
  ) {
    return fail("This task is not yours to update");
  }
  const reassigned =
    parsed.data.assignedToUserId !== undefined &&
    parsed.data.assignedToUserId !== task.assignedToUserId;
  if (reassigned && !can(session.actor, { type: "task.assign" })) {
    return fail("You cannot assign tasks to other people");
  }
  await db.transaction(async (tx) => {
    await tx
      .update(tasks)
      .set({
        ...(parsed.data.title !== undefined ? { title: parsed.data.title } : {}),
        ...(parsed.data.notes !== undefined
          ? { notes: parsed.data.notes?.trim() ? parsed.data.notes.trim() : null }
          : {}),
        ...(parsed.data.dueDate !== undefined ? { dueDate: parsed.data.dueDate } : {}),
        ...(parsed.data.assignedToUserId !== undefined
          ? { assignedToUserId: parsed.data.assignedToUserId }
          : {}),
      })
      .where(eq(tasks.id, task.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: task.editionId ?? undefined,
      actorUserId: session.user.id,
      entityType: "task",
      entityId: task.id,
      action: "update",
      summary: `Task updated: ${parsed.data.title ?? task.title}`,
    });
    if (reassigned && parsed.data.assignedToUserId !== session.user.id) {
      await notify(tx, {
        userIds: [parsed.data.assignedToUserId!],
        kind: "task_assigned",
        title: `Task assigned: ${parsed.data.title ?? task.title}`,
        link: "/approvals",
      });
    }
  });
  revalidatePath("/approvals");
  return success(undefined, "Task saved");
}

export async function deleteTask(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const task = await loadOwnTask(parsed.data.id, session.organisation.id);
  if (!task) return fail("Task not found");
  if (
    !can(session.actor, {
      type: "task.delete",
      task: { assignedToUserId: task.assignedToUserId, createdByUserId: task.createdByUserId },
    })
  ) {
    return fail("Only the task's creator (or an admin) can delete it");
  }
  await db.transaction(async (tx) => {
    await tx.delete(tasks).where(eq(tasks.id, task.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: task.editionId ?? undefined,
      actorUserId: session.user.id,
      entityType: "task",
      entityId: task.id,
      action: "soft_delete",
      summary: `Task deleted: ${task.title}`,
    });
  });
  revalidatePath("/approvals");
  return success(undefined, "Task deleted");
}
