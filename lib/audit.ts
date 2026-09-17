/**
 * Audit writer (non-negotiables 2 and 3). Every server action calls this
 * inside the same transaction as its change; the audit_log table itself is
 * append-only via a database trigger.
 */
import { auditLog } from "./db/schema";
import type { Tx } from "./db/client";

export type AuditAction =
  | "create"
  | "update"
  | "soft_delete"
  | "restore"
  | "status_change"
  | "submit"
  | "decide"
  | "delegate"
  | "escalate"
  | "upload"
  | "download"
  | "export"
  | "import"
  | "login"
  | "invite"
  | "grant_revoke"
  | "settings_change";

export type AuditEntry = {
  organisationId?: string | null;
  editionId?: string | null;
  actorUserId?: string | null;
  actorType?: "user" | "system" | "cron";
  entityType: string;
  entityId?: string | null;
  action: AuditAction;
  before?: unknown;
  after?: unknown;
  summary: string;
  ip?: string | null;
  userAgent?: string | null;
};

export async function writeAudit(tx: Tx, entry: AuditEntry): Promise<void> {
  await tx.insert(auditLog).values({
    organisationId: entry.organisationId ?? null,
    editionId: entry.editionId ?? null,
    actorUserId: entry.actorUserId ?? null,
    actorType: entry.actorType ?? "user",
    entityType: entry.entityType,
    entityId: entry.entityId ?? null,
    action: entry.action,
    before: entry.before ?? null,
    after: entry.after ?? null,
    summary: entry.summary,
    ip: entry.ip ?? null,
    userAgent: entry.userAgent ?? null,
  });
}
