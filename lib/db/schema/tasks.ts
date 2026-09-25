import {
  date,
  index,
  integer,
  pgTable,
  text,
  timestamp,
  type AnyPgColumn,
  uuid,
} from "drizzle-orm/pg-core";
import { entityType, taskStatus } from "./enums";
import { editions } from "./events";
import { organisations, timestamps, users } from "./tenancy";

/**
 * Jobs on the My Work board: self-created or assigned by a colleague, with a
 * due date, subtasks (tasks with a parent) and attachments.
 */
export const tasks = pgTable(
  "tasks",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    editionId: uuid("edition_id").references(() => editions.id),
    /** Set on subtasks: the task they belong to. */
    parentTaskId: uuid("parent_task_id").references((): AnyPgColumn => tasks.id, {
      onDelete: "cascade",
    }),
    title: text("title").notNull(),
    notes: text("notes"),
    status: taskStatus("status").notNull().default("open"),
    dueDate: date("due_date"),
    assignedToUserId: uuid("assigned_to_user_id")
      .notNull()
      .references(() => users.id),
    createdByUserId: uuid("created_by_user_id")
      .notNull()
      .references(() => users.id),
    // Optional link to the record the task is about.
    entityType: entityType("entity_type"),
    entityId: uuid("entity_id"),
    completedAt: timestamp("completed_at", { withTimezone: true }),
    ...timestamps,
  },
  (t) => [
    index("tasks_assignee_status_idx").on(t.assignedToUserId, t.status),
    index("tasks_org_idx").on(t.organisationId),
    index("tasks_edition_idx").on(t.editionId),
    index("tasks_created_by_idx").on(t.createdByUserId),
    index("tasks_parent_idx").on(t.parentTaskId),
  ],
);

/** Files attached to a task or subtask (documents bucket). */
export const taskAttachments = pgTable(
  "task_attachments",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    taskId: uuid("task_id")
      .notNull()
      .references(() => tasks.id, { onDelete: "cascade" }),
    filePath: text("file_path").notNull(),
    fileName: text("file_name").notNull(),
    mimeType: text("mime_type").notNull(),
    fileSize: integer("file_size").notNull(),
    uploadedBy: uuid("uploaded_by")
      .notNull()
      .references(() => users.id),
    ...timestamps,
  },
  (t) => [
    index("task_attachments_task_idx").on(t.taskId),
    index("task_attachments_uploaded_by_idx").on(t.uploadedBy),
  ],
);
