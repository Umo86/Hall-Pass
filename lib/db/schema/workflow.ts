import {
  boolean,
  date,
  index,
  integer,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";
import {
  approvalEntityType,
  approverType,
  externalRole,
  instanceStatus,
  reminderKind,
  reminderTargetType,
  stepKind,
  workflowAppliesTo,
} from "./enums";
import { organisations, timestamps, users } from "./tenancy";

export const workflowConditionValues = [
  "always",
  "if_sponsored",
  "if_requires_venue_approval",
  "if_requires_event_director",
  "if_cost_over_threshold",
  "if_rigged",
  "if_complex_structure",
  "if_venue_requires_stand_approval",
] as const;

export type WorkflowCondition = (typeof workflowConditionValues)[number];

export const workflows = pgTable(
  "workflows",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    name: text("name").notNull(),
    appliesTo: workflowAppliesTo("applies_to").notNull(),
    isDefault: boolean("is_default").notNull().default(false),
    isArchived: boolean("is_archived").notNull().default(false),
    ...timestamps,
  },
  (t) => [index("workflows_org_idx").on(t.organisationId)],
);

export const workflowSteps = pgTable(
  "workflow_steps",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    workflowId: uuid("workflow_id")
      .notNull()
      .references(() => workflows.id),
    sortOrder: integer("sort_order").notNull(),
    parallelGroup: integer("parallel_group"),
    name: text("name").notNull(),
    kind: stepKind("kind").notNull(),
    approverType: approverType("approver_type").notNull(),
    // Any staff or external role. Kept as text and validated with zod so the
    // two role enums do not need a merged Postgres enum.
    approverRole: text("approver_role"),
    approverUserId: uuid("approver_user_id").references(() => users.id),
    conditions: text("conditions").array().notNull().default(["always"]),
    slaDays: integer("sla_days").notNull().default(0),
    invalidateOnNewVersion: boolean("invalidate_on_new_version").notNull().default(true),
    restartFromHereOnChanges: boolean("restart_from_here_on_changes").notNull().default(true),
    ...timestamps,
  },
  (t) => [
    index("workflow_steps_workflow_idx").on(t.workflowId),
    index("workflow_steps_approver_user_idx").on(t.approverUserId),
  ],
);

export const approvalInstances = pgTable(
  "approval_instances",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    entityType: approvalEntityType("entity_type").notNull(),
    entityId: uuid("entity_id").notNull(),
    runNumber: integer("run_number").notNull(),
    workflowStepId: uuid("workflow_step_id")
      .notNull()
      .references(() => workflowSteps.id),
    stepNameSnapshot: text("step_name_snapshot").notNull(),
    stepKindSnapshot: stepKind("step_kind_snapshot").notNull(),
    sortOrderSnapshot: integer("sort_order_snapshot").notNull(),
    parallelGroupSnapshot: integer("parallel_group_snapshot"),
    status: instanceStatus("status").notNull().default("waiting"),
    assignedRole: text("assigned_role"),
    assignedUserId: uuid("assigned_user_id").references(() => users.id),
    delegatedFromUserId: uuid("delegated_from_user_id").references(() => users.id),
    decidedBy: uuid("decided_by").references(() => users.id),
    decidedAt: timestamp("decided_at", { withTimezone: true }),
    decisionComment: text("decision_comment"),
    conditionsText: text("conditions_text"),
    lockedVersionType: text("locked_version_type", {
      enum: ["artwork_version", "submission_version"],
    }),
    lockedVersionId: text("locked_version_id"),
    lockedSha256: text("locked_sha256"),
    pendingSince: timestamp("pending_since", { withTimezone: true }),
    dueAt: timestamp("due_at", { withTimezone: true }),
    holdShiftDays: integer("hold_shift_days").notNull().default(0),
    escalatedAt: timestamp("escalated_at", { withTimezone: true }),
    escalatedTo: uuid("escalated_to").array(),
    ...timestamps,
  },
  (t) => [
    index("approval_instances_entity_idx").on(t.entityType, t.entityId, t.runNumber),
    index("approval_instances_step_idx").on(t.workflowStepId),
    index("approval_instances_assigned_user_idx").on(t.assignedUserId),
    index("approval_instances_status_idx").on(t.status),
    index("approval_instances_delegated_from_idx").on(t.delegatedFromUserId),
    index("approval_instances_decided_by_idx").on(t.decidedBy),
  ],
);

export const reminderLog = pgTable(
  "reminder_log",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    targetType: reminderTargetType("target_type").notNull(),
    targetId: uuid("target_id").notNull(),
    kind: reminderKind("kind").notNull(),
    sentOn: date("sent_on").notNull(),
    ...timestamps,
  },
  (t) => [
    unique("reminder_log_unique_send").on(t.targetType, t.targetId, t.kind, t.sentOn),
    index("reminder_log_target_idx").on(t.targetType, t.targetId),
  ],
);

export { externalRole };
