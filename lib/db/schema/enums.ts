import { pgEnum } from "drizzle-orm/pg-core";

export const staffRole = pgEnum("staff_role", [
  "admin",
  "ops",
  "marketing",
  "sales",
  "event_director",
  "viewer",
]);

export const externalRole = pgEnum("external_role", [
  "venue",
  "structural_engineer",
  "hs",
  "supplier",
  "exhibitor",
  "contractor",
  "sponsor",
]);

export const scopeType = pgEnum("scope_type", ["venue", "supplier", "exhibitor", "sponsor"]);

export const editionStatus = pgEnum("edition_status", ["planning", "live", "closed", "archived"]);

export const deadlineKey = pgEnum("deadline_key", [
  "artwork_due",
  "venue_rigging_submission",
  "print_deadline",
  "delivery",
  "stand_design_due",
  "insurance_due",
]);

export const supplierKind = pgEnum("supplier_kind", [
  "print",
  "rigging",
  "av",
  "contractor",
  "structural_engineer",
  "other",
]);

export const standType = pgEnum("stand_type", ["space_only", "shell", "custom_shell"]);

export const ownerRole = pgEnum("owner_role", ["ops", "marketing"]);

export const sided = pgEnum("sided", ["single", "double"]);

export const fixingMethod = pgEnum("fixing_method", [
  "rigged",
  "freestanding",
  "wall_mounted",
  "shell_mounted",
  "floor",
  "digital",
  "other",
]);

export const installSlot = pgEnum("install_slot", ["am", "pm", "overnight"]);

export const signageStatus = pgEnum("signage_status", [
  "draft",
  "awaiting_artwork",
  "in_review",
  "changes_requested",
  "approved",
  "approved_with_conditions",
  "in_production",
  "delivered",
  "installed",
  "snagged",
  "closed",
  "rejected",
  "on_hold",
]);

export const proofStatus = pgEnum("proof_status", ["draft", "proof", "final"]);

export const standStatus = pgEnum("stand_status", [
  "not_submitted",
  "submitted",
  "in_review",
  "changes_requested",
  "approved",
  "approved_with_conditions",
  "rejected",
  "build_checked",
  "closed",
  "on_hold",
]);

export const standOutcome = pgEnum("stand_outcome", [
  "approved",
  "approved_with_conditions",
  "rejected",
]);

export const entityType = pgEnum("entity_type", [
  "signage_item",
  "stand_submission",
  "exhibitor",
  "contractor",
  "supplier",
  "edition",
]);

export const docType = pgEnum("doc_type", [
  "plan",
  "elevation",
  "structural_calcs",
  "rams",
  "insurance_pl",
  "fire_cert",
  "electrical_cert",
  "rigging_plan",
  "spec_sheet",
  "quote",
  "po",
  "other",
]);

export const documentStatus = pgEnum("document_status", ["received", "accepted", "rejected"]);

export const workflowAppliesTo = pgEnum("workflow_applies_to", ["signage", "stand"]);

export const stepKind = pgEnum("step_kind", ["approval", "confirmation"]);

export const approverType = pgEnum("approver_type", ["role", "user"]);

export const approvalEntityType = pgEnum("approval_entity_type", [
  "signage_item",
  "stand_submission",
]);

export const instanceStatus = pgEnum("instance_status", [
  "waiting",
  "pending",
  "approved",
  "approved_with_conditions",
  "changes_requested",
  "rejected",
  "confirmed",
  "skipped",
  "invalidated",
]);

export const reminderTargetType = pgEnum("reminder_target_type", [
  "approval_instance",
  "signage_item",
  "exhibitor",
  "document",
]);

export const reminderKind = pgEnum("reminder_kind", [
  "minus7",
  "minus2",
  "due",
  "overdue",
  "escalation",
  "chaser",
  "expiry",
]);

export const changeRequestStatus = pgEnum("change_request_status", [
  "open",
  "approved",
  "rejected",
  "applied",
]);

export const snagSeverity = pgEnum("snag_severity", ["low", "medium", "high"]);

export const snagStatus = pgEnum("snag_status", ["open", "in_progress", "resolved", "wont_fix"]);

export const emailStatus = pgEnum("email_status", ["sent", "failed"]);

export const auditAction = pgEnum("audit_action", [
  "create",
  "update",
  "soft_delete",
  "restore",
  "status_change",
  "submit",
  "decide",
  "delegate",
  "escalate",
  "upload",
  "download",
  "export",
  "import",
  "login",
  "invite",
  "grant_revoke",
  "settings_change",
]);

export const actorType = pgEnum("actor_type", ["user", "system", "cron"]);
