import {
  boolean,
  index,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  uuid,
} from "drizzle-orm/pg-core";
import {
  changeRequestStatus,
  emailStatus,
  entityType,
  snagSeverity,
  snagStatus,
} from "./enums";
import { editions } from "./events";
import { contractors, suppliers } from "./parties";
import { signageItems } from "./signage";
import { standSubmissions } from "./stands";
import { documents } from "./documents";
import { timestamps, users } from "./tenancy";

export const comments = pgTable(
  "comments",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    entityType: entityType("entity_type").notNull(),
    entityId: uuid("entity_id").notNull(),
    parentId: uuid("parent_id"),
    authorId: uuid("author_id")
      .notNull()
      .references(() => users.id),
    body: text("body").notNull(),
    mentionUserIds: uuid("mention_user_ids").array().notNull().default([]),
    isInternal: boolean("is_internal").notNull().default(true),
    editedAt: timestamp("edited_at", { withTimezone: true }),
    deletedAt: timestamp("deleted_at", { withTimezone: true }),
    ...timestamps,
  },
  (t) => [
    index("comments_entity_idx").on(t.entityType, t.entityId),
    index("comments_parent_idx").on(t.parentId),
    index("comments_author_idx").on(t.authorId),
  ],
);

export const commentAttachments = pgTable(
  "comment_attachments",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    commentId: uuid("comment_id")
      .notNull()
      .references(() => comments.id),
    documentId: uuid("document_id")
      .notNull()
      .references(() => documents.id),
    ...timestamps,
  },
  (t) => [
    index("comment_attachments_comment_idx").on(t.commentId),
    index("comment_attachments_document_idx").on(t.documentId),
  ],
);

export type FieldChange = { field: string; from: unknown; to: unknown };

export const changeRequests = pgTable(
  "change_requests",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    entityType: entityType("entity_type").notNull(),
    entityId: uuid("entity_id").notNull(),
    requestedBy: uuid("requested_by")
      .notNull()
      .references(() => users.id),
    reason: text("reason").notNull(),
    fieldChanges: jsonb("field_changes").$type<FieldChange[]>().notNull().default([]),
    status: changeRequestStatus("status").notNull().default("open"),
    decidedBy: uuid("decided_by").references(() => users.id),
    decidedAt: timestamp("decided_at", { withTimezone: true }),
    reopenedInstanceIds: uuid("reopened_instance_ids").array(),
    ...timestamps,
  },
  (t) => [
    index("change_requests_entity_idx").on(t.entityType, t.entityId),
    index("change_requests_requested_by_idx").on(t.requestedBy),
    index("change_requests_decided_by_idx").on(t.decidedBy),
  ],
);

export const snags = pgTable(
  "snags",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    editionId: uuid("edition_id")
      .notNull()
      .references(() => editions.id),
    signageItemId: uuid("signage_item_id").references(() => signageItems.id),
    standSubmissionId: uuid("stand_submission_id").references(() => standSubmissions.id),
    description: text("description").notNull(),
    photoPath: text("photo_path"),
    severity: snagSeverity("severity").notNull().default("medium"),
    assignedUserId: uuid("assigned_user_id").references(() => users.id),
    assignedSupplierId: uuid("assigned_supplier_id").references(() => suppliers.id),
    assignedContractorId: uuid("assigned_contractor_id").references(() => contractors.id),
    status: snagStatus("status").notNull().default("open"),
    resolvedAt: timestamp("resolved_at", { withTimezone: true }),
    resolvedBy: uuid("resolved_by").references(() => users.id),
    resolutionNote: text("resolution_note"),
    resolutionPhotoPath: text("resolution_photo_path"),
    ...timestamps,
  },
  (t) => [
    index("snags_edition_idx").on(t.editionId),
    index("snags_signage_item_idx").on(t.signageItemId),
    index("snags_stand_submission_idx").on(t.standSubmissionId),
    index("snags_assigned_user_idx").on(t.assignedUserId),
    index("snags_assigned_supplier_idx").on(t.assignedSupplierId),
    index("snags_assigned_contractor_idx").on(t.assignedContractorId),
    index("snags_resolved_by_idx").on(t.resolvedBy),
  ],
);

export const notifications = pgTable(
  "notifications",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => users.id),
    kind: text("kind").notNull(),
    entityType: entityType("entity_type"),
    entityId: uuid("entity_id"),
    title: text("title").notNull(),
    body: text("body"),
    link: text("link"),
    readAt: timestamp("read_at", { withTimezone: true }),
    emailedAt: timestamp("emailed_at", { withTimezone: true }),
    ...timestamps,
  },
  (t) => [
    index("notifications_user_idx").on(t.userId),
    index("notifications_user_unread_idx").on(t.userId, t.readAt),
  ],
);

export const emailLog = pgTable(
  "email_log",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    toEmail: text("to_email").notNull(),
    template: text("template").notNull(),
    entityType: text("entity_type"),
    entityId: uuid("entity_id"),
    providerMessageId: text("provider_message_id"),
    status: emailStatus("status").notNull(),
    error: text("error"),
    attempts: integer("attempts").notNull().default(1),
    sentAt: timestamp("sent_at", { withTimezone: true }),
    ...timestamps,
  },
  (t) => [index("email_log_entity_idx").on(t.entityType, t.entityId)],
);

export const exports = pgTable(
  "exports",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    editionId: uuid("edition_id")
      .notNull()
      .references(() => editions.id),
    kind: text("kind").notNull(),
    filters: jsonb("filters").$type<Record<string, unknown>>().notNull().default({}),
    filePath: text("file_path").notNull(),
    generatedBy: uuid("generated_by").references(() => users.id),
    expiresAt: timestamp("expires_at", { withTimezone: true }),
    ...timestamps,
  },
  (t) => [
    index("exports_edition_idx").on(t.editionId),
    index("exports_generated_by_idx").on(t.generatedBy),
  ],
);
