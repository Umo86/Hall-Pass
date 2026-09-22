import { date, index, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { entityType, taskStatus } from "./enums";
import { editions } from "./events";
import { organisations, timestamps, users } from "./tenancy";

/**
 * Personal to-dos: self-created or assigned by a colleague. Deliberately flat —
 * a title, an owner, an optional due date and an optional link to a record.
 */
export const tasks = pgTable(
  "tasks",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    editionId: uuid("edition_id").references(() => editions.id),
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
  ],
);
