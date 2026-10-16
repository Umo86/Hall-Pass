"use server";

import { unstable_rethrow } from "next/navigation";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq, ne } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { taskAttachments, tasks } from "@/lib/db/schema";
import { buildStoragePath, putObject, sanitiseFilename } from "@/lib/storage";
import { can } from "@/lib/authz";
import { canWorkOnTask } from "@/lib/domain/tasks";
import { loadItemBundle, ownEdition } from "@/lib/domain/signage";
import { loadStandBundle } from "@/lib/domain/stand";
import { writeAudit } from "@/lib/audit";
import { checkPick } from "@/lib/people";
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
  /** Adding a subtask to this task. */
  parentTaskId: z.string().uuid().optional().nullable(),
});

type Task = typeof tasks.$inferSelect;
type TaskSession = Awaited<ReturnType<typeof requireSession>>;

const canWorkOn = (session: TaskSession, task: Task) =>
  canWorkOnTask(session.actor, session.organisation.id, task);

export async function createTask(input: unknown): Promise<ActionResult<{ id: string }>> {
  const parsed = createTaskSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "task.create" })) return fail("You cannot create tasks");

  // An event or record the task points at must be this organisation's.
  if (Boolean(parsed.data.entityType) !== Boolean(parsed.data.entityId)) {
    return fail("Invalid request");
  }
  if (parsed.data.editionId) {
    if (!(await ownEdition(db, session.organisation.id, parsed.data.editionId))) {
      return fail("Event not found");
    }
  }
  // A task about an item belongs to the item's event.
  let entityEditionId: string | null = null;
  if (parsed.data.entityType === "signage_item" && parsed.data.entityId) {
    const item = await loadItemBundle(db, parsed.data.entityId, {
      organisationId: session.organisation.id,
    });
    if (!item || item.item.deletedAt) return fail("Item not found");
    entityEditionId = item.edition.id;
  }
  if (parsed.data.entityType === "stand_submission" && parsed.data.entityId) {
    const sub = await loadStandBundle(db, parsed.data.entityId, {
      organisationId: session.organisation.id,
    });
    if (!sub) return fail("Stand not found");
    entityEditionId = sub.edition.id;
  }
  if (entityEditionId && parsed.data.editionId && parsed.data.editionId !== entityEditionId) {
    return fail("That item belongs to another event");
  }
  let parent: Task | undefined;
  if (parsed.data.parentTaskId) {
    parent = await loadOwnTask(parsed.data.parentTaskId, session.organisation.id);
    if (!parent || parent.parentTaskId) return fail("Task not found");
    if (!(await canWorkOn(session, parent))) return fail("This task is not yours to change");
  }
  // Subtasks go to the task's owner unless someone else is named.
  const assignee = parsed.data.assignedToUserId ?? parent?.assignedToUserId ?? session.user.id;
  if (
    assignee !== session.user.id &&
    assignee !== parent?.assignedToUserId &&
    !can(session.actor, { type: "task.assign" })
  ) {
    return fail("You cannot assign tasks to other people");
  }
  if (assignee !== session.user.id) {
    const pick = await checkPick(db, session.organisation.id, assignee, { type: "task" });
    if (!pick.ok) return fail(pick.error);
  }

  try {
    const id = await db.transaction(async (tx) => {
      const [task] = await tx
        .insert(tasks)
        .values({
          organisationId: session.organisation.id,
          editionId: entityEditionId ?? parsed.data.editionId ?? parent?.editionId ?? null,
          parentTaskId: parent?.id ?? null,
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
        editionId: task.editionId ?? undefined,
        actorUserId: session.user.id,
        entityType: "task",
        entityId: task.id,
        action: "create",
        after: { title: task.title, assignedTo: assignee },
        summary: parent
          ? `Subtask added to “${parent.title}”: ${task.title}`
          : `Task created: ${task.title}`,
      });
      if (assignee !== session.user.id && !parent) {
        await notify(tx, {
          userIds: [assignee],
          kind: "task_assigned",
          title: `Task assigned: ${task.title}`,
          body: parsed.data.dueDate ? `Due ${parsed.data.dueDate}` : undefined,
          link: "/my-work",
        });
      }
      return task.id;
    });
    revalidatePath("/my-work");
    return success({ id }, parent ? "Subtask added" : "Task added");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not add the task");
  }
}

async function loadOwnTask(id: string, organisationId: string) {
  return db.query.tasks.findFirst({
    where: and(eq(tasks.id, id), eq(tasks.organisationId, organisationId)),
  });
}

const STATUS_WORDS = { open: "To do", in_progress: "In progress", done: "Done" } as const;

/**
 * Move a task between To do, In progress and Done (the board columns);
 * subtasks are ticked off the same way.
 */
export async function setTaskStatus(input: unknown): Promise<ActionResult> {
  try {
    const parsed = z
      .object({ id: z.string().uuid(), status: z.enum(["open", "in_progress", "done"]) })
      .safeParse(input);
    if (!parsed.success) return fail("Invalid request");
    const session = await requireSession();
    const task = await loadOwnTask(parsed.data.id, session.organisation.id);
    if (!task) return fail("Task not found");
    if (!(await canWorkOn(session, task))) return fail("This task is not yours to update");
    if (task.status === parsed.data.status) return success();
    const done = parsed.data.status === "done";
    await db.transaction(async (tx) => {
      await tx
        .update(tasks)
        .set({ status: parsed.data.status, completedAt: done ? new Date() : null })
        .where(eq(tasks.id, task.id));
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: task.editionId ?? undefined,
        actorUserId: session.user.id,
        entityType: "task",
        entityId: task.id,
        action: "status_change",
        before: { status: task.status },
        after: { status: parsed.data.status },
        summary: `${task.parentTaskId ? "Subtask" : "Task"} “${task.title}” → ${STATUS_WORDS[parsed.data.status]}`,
      });
      // Let whoever handed the task over know it's done.
      if (done && !task.parentTaskId && task.createdByUserId !== session.user.id) {
        await notify(tx, {
          userIds: [task.createdByUserId],
          kind: "task_assigned",
          title: `Done: ${task.title}`,
          body: `${session.user.fullName || session.user.email} completed this task.`,
          link: "/my-work",
        });
      }
    });
    revalidatePath("/my-work");
    return success(undefined, `Moved to ${STATUS_WORDS[parsed.data.status]}`);
  } catch (err) {
    unstable_rethrow(err);
    console.error("setTaskStatus", err);
    return fail("Could not save — please try again");
  }
}

/** Tick a task or subtask done (or undo). */
export async function completeTask(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid(), done: z.boolean() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  return setTaskStatus({ id: parsed.data.id, status: parsed.data.done ? "done" : "open" });
}

const updateTaskSchema = z.object({
  id: z.string().uuid(),
  title: z.string().trim().min(1).max(300).optional(),
  notes: z.string().max(2000).optional().nullable(),
  dueDate: z.string().date().optional().nullable(),
  assignedToUserId: z.string().uuid().optional(),
});

export async function updateTask(input: unknown): Promise<ActionResult> {
  try {
    const parsed = updateTaskSchema.safeParse(input);
    if (!parsed.success) return fail("Check the task details");
    const session = await requireSession();
    const task = await loadOwnTask(parsed.data.id, session.organisation.id);
    if (!task) return fail("Task not found");
    if (!(await canWorkOn(session, task))) return fail("This task is not yours to update");
    const toUserId = parsed.data.assignedToUserId;
    const reassigned = toUserId !== undefined && toUserId !== task.assignedToUserId;
    if (reassigned && !can(session.actor, { type: "task.assign" })) {
      return fail("You cannot assign tasks to other people");
    }
    // Only people with access can be given it; keeping the current assignee is always fine.
    let toName: string | null = null;
    if (reassigned) {
      const pick = await checkPick(db, session.organisation.id, toUserId!, { type: "task" });
      if (!pick.ok) return fail(pick.error);
      toName = pick.member.name;
    }
    const set: Partial<typeof tasks.$inferInsert> = {};
    if (parsed.data.title !== undefined && parsed.data.title !== task.title) {
      set.title = parsed.data.title;
    }
    if (parsed.data.notes !== undefined) {
      const notes = parsed.data.notes?.trim() ? parsed.data.notes.trim() : null;
      if (notes !== task.notes) set.notes = notes;
    }
    if (parsed.data.dueDate !== undefined && parsed.data.dueDate !== task.dueDate) {
      set.dueDate = parsed.data.dueDate;
    }
    if (reassigned) set.assignedToUserId = toUserId;
    if (Object.keys(set).length === 0) return success(undefined, "No changes to save");
    const title = set.title ?? task.title;
    const followers = await db.transaction(async (tx) => {
      await tx.update(tasks).set(set).where(eq(tasks.id, task.id));
      // Open subtasks that were with the old assignee go with the task.
      const moved = reassigned
        ? await tx
            .update(tasks)
            .set({ assignedToUserId: toUserId })
            .where(
              and(
                eq(tasks.parentTaskId, task.id),
                eq(tasks.assignedToUserId, task.assignedToUserId),
                ne(tasks.status, "done"),
              ),
            )
            .returning({ id: tasks.id, title: tasks.title })
        : [];
      const keys = Object.keys(set) as (keyof typeof set)[];
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: task.editionId ?? undefined,
        actorUserId: session.user.id,
        entityType: "task",
        entityId: task.id,
        action: "update",
        before: Object.fromEntries(keys.map((k) => [k, task[k as keyof Task] ?? null])),
        after: { ...set, ...(moved.length ? { subtasksMoved: moved.length } : {}) },
        summary: reassigned
          ? `Task “${title}” moved to ${toName}${moved.length ? ` with ${moved.length} subtask${moved.length === 1 ? "" : "s"}` : ""}`
          : `Task updated: ${title} (${keys.join(", ")})`,
        // A reassignment is about the person it was taken from.
        ...(reassigned ? { subjectUserId: task.assignedToUserId } : {}),
      });
      for (const sub of moved) {
        await writeAudit(tx, {
          organisationId: session.organisation.id,
          editionId: task.editionId ?? undefined,
          actorUserId: session.user.id,
          entityType: "task",
          entityId: sub.id,
          action: "update",
          before: { assignedToUserId: task.assignedToUserId },
          after: { assignedToUserId: toUserId },
          summary: `Subtask “${sub.title}” moved to ${toName} with its task`,
          subjectUserId: task.assignedToUserId,
        });
      }
      if (reassigned && toUserId !== session.user.id) {
        await notify(tx, {
          userIds: [toUserId!],
          kind: "task_assigned",
          title: `Task assigned: ${title}`,
          body: `${session.user.fullName || session.user.email} gave it to you${moved.length ? `, with ${moved.length} subtask${moved.length === 1 ? "" : "s"}` : ""}.`,
          link: "/my-work",
        });
      }
      // The person it was taken from hears where it went (not when they moved it).
      if (reassigned && task.assignedToUserId !== session.user.id) {
        await notify(tx, {
          userIds: [task.assignedToUserId],
          kind: "task_assigned",
          title: `Task moved to ${toName}: ${title}`,
          body: `${session.user.fullName || session.user.email} gave it to ${toName}.`,
          link: "/my-work",
        });
      }
      return moved.length;
    });
    revalidatePath("/my-work");
    return success(
      undefined,
      reassigned
        ? `Task moved to ${toName}${followers ? ` with ${followers} subtask${followers === 1 ? "" : "s"}` : ""}`
        : "Task saved",
    );
  } catch (err) {
    unstable_rethrow(err);
    console.error("updateTask", err);
    return fail("Could not save — please try again");
  }
}

export async function deleteTask(input: unknown): Promise<ActionResult> {
  try {
    const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
    if (!parsed.success) return fail("Invalid request");
    const session = await requireSession();
    const task = await loadOwnTask(parsed.data.id, session.organisation.id);
    if (!task) return fail("Task not found");
    // Subtasks can be removed by anyone working on the task; whole tasks only
    // by their creator (or an admin).
    const allowed = task.parentTaskId
      ? await canWorkOn(session, task)
      : can(session.actor, {
          type: "task.delete",
          task: { assignedToUserId: task.assignedToUserId, createdByUserId: task.createdByUserId },
        });
    if (!allowed) return fail("Only the task's creator (or an admin) can delete it");
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
    revalidatePath("/my-work");
    return success(undefined, task.parentTaskId ? "Subtask deleted" : "Task deleted");
  } catch (err) {
    unstable_rethrow(err);
    console.error("deleteTask", err);
    return fail("Could not save — please try again");
  }
}

const ATTACHMENT_LIMIT = 20 * 1024 * 1024;
/** Documents, images and spreadsheets — no executables or web pages. */
const ATTACHMENT_TYPES = new Set([
  "application/pdf",
  "image/png",
  "image/jpeg",
  "image/webp",
  "image/gif",
  "image/heic",
  "image/heif",
  "text/plain",
  "text/csv",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "application/vnd.ms-powerpoint",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  "application/zip",
  "application/postscript",
  "application/illustrator",
]);

/** Attach a file to a task or subtask. */
export async function uploadTaskAttachment(formData: FormData): Promise<ActionResult> {
  const taskId = formData.get("taskId");
  const file = formData.get("file");
  if (typeof taskId !== "string" || !z.string().uuid().safeParse(taskId).success) {
    return fail("Invalid request");
  }
  if (!(file instanceof File) || file.size === 0) return fail("Choose a file first");
  if (file.size > ATTACHMENT_LIMIT) return fail("Files are limited to 20 MB");
  if (!ATTACHMENT_TYPES.has(file.type)) {
    return fail("That type of file can't be attached — use a PDF, image, Office file or ZIP");
  }
  const session = await requireSession();
  const task = await loadOwnTask(taskId, session.organisation.id);
  if (!task) return fail("Task not found");
  if (!(await canWorkOn(session, task))) return fail("This task is not yours to change");
  try {
    const path = buildStoragePath({
      organisationId: session.organisation.id,
      editionId: task.editionId,
      entityType: "task",
      entityId: task.id,
      fileName: file.name,
    });
    await putObject("documents", path, Buffer.from(await file.arrayBuffer()));
    await db.transaction(async (tx) => {
      const [row] = await tx
        .insert(taskAttachments)
        .values({
          taskId: task.id,
          filePath: path,
          fileName: sanitiseFilename(file.name),
          mimeType: file.type,
          fileSize: file.size,
          uploadedBy: session.user.id,
        })
        .returning();
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: task.editionId ?? undefined,
        actorUserId: session.user.id,
        entityType: "task",
        entityId: task.id,
        action: "upload",
        after: { attachmentId: row.id, fileName: row.fileName },
        summary: `Attached ${row.fileName} to “${task.title}”`,
      });
    });
    revalidatePath("/my-work");
    return success(undefined, "File attached");
  } catch (err) {
    unstable_rethrow(err);
    console.error("uploadTaskAttachment", err);
    return fail("Could not upload — please try again");
  }
}

export async function deleteTaskAttachment(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const [row] = await db
    .select({ attachment: taskAttachments, task: tasks })
    .from(taskAttachments)
    .innerJoin(tasks, eq(tasks.id, taskAttachments.taskId))
    .where(
      and(
        eq(taskAttachments.id, parsed.data.id),
        eq(tasks.organisationId, session.organisation.id),
      ),
    )
    .limit(1);
  if (!row) return fail("File not found");
  if (!(await canWorkOn(session, row.task))) return fail("This task is not yours to change");
  try {
    await db.transaction(async (tx) => {
      await tx.delete(taskAttachments).where(eq(taskAttachments.id, row.attachment.id));
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: row.task.editionId ?? undefined,
        actorUserId: session.user.id,
        entityType: "task",
        entityId: row.task.id,
        action: "update",
        before: { attachment: row.attachment.fileName },
        summary: `Removed ${row.attachment.fileName} from “${row.task.title}”`,
      });
    });
    revalidatePath("/my-work");
    return success(undefined, "File removed");
  } catch (err) {
    unstable_rethrow(err);
    console.error("deleteTaskAttachment", err);
    return fail("Could not save — please try again");
  }
}
