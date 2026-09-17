import { boolean, date, index, integer, pgTable, text, uuid } from "drizzle-orm/pg-core";
import { docType, documentStatus, entityType } from "./enums";
import { editions } from "./events";
import { organisations, timestamps, users } from "./tenancy";

export const documents = pgTable(
  "documents",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    editionId: uuid("edition_id").references(() => editions.id),
    entityType: entityType("entity_type").notNull(),
    entityId: uuid("entity_id").notNull(),
    docType: docType("doc_type").notNull(),
    filePath: text("file_path").notNull(),
    fileName: text("file_name").notNull(),
    mimeType: text("mime_type").notNull(),
    fileSize: integer("file_size").notNull(),
    sha256: text("sha256").notNull(),
    submissionVersion: integer("submission_version"),
    expiresAt: date("expires_at"),
    uploadedBy: uuid("uploaded_by").references(() => users.id),
    isExternalUpload: boolean("is_external_upload").notNull().default(false),
    status: documentStatus("status").notNull().default("received"),
    reviewNote: text("review_note"),
    ...timestamps,
  },
  (t) => [
    index("documents_org_idx").on(t.organisationId),
    index("documents_edition_idx").on(t.editionId),
    index("documents_entity_idx").on(t.entityType, t.entityId),
    index("documents_uploaded_by_idx").on(t.uploadedBy),
  ],
);
