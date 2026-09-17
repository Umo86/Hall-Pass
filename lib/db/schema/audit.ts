import { index, jsonb, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { actorType, auditAction } from "./enums";

// Append-only: a database trigger (see the RLS/trigger migration) raises an
// exception on any UPDATE or DELETE. No updated_at by design.
export const auditLog = pgTable(
  "audit_log",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    organisationId: uuid("organisation_id"),
    editionId: uuid("edition_id"),
    actorUserId: uuid("actor_user_id"),
    actorType: actorType("actor_type").notNull().default("user"),
    entityType: text("entity_type").notNull(),
    entityId: uuid("entity_id"),
    action: auditAction("action").notNull(),
    before: jsonb("before"),
    after: jsonb("after"),
    summary: text("summary").notNull(),
    ip: text("ip"),
    userAgent: text("user_agent"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index("audit_log_org_idx").on(t.organisationId),
    index("audit_log_edition_idx").on(t.editionId),
    index("audit_log_actor_idx").on(t.actorUserId),
    index("audit_log_entity_idx").on(t.entityType, t.entityId),
    index("audit_log_created_at_idx").on(t.createdAt),
  ],
);
