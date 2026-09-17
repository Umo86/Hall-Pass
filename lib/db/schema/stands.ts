import {
  boolean,
  index,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";
import { standOutcome, standStatus } from "./enums";
import { editions } from "./events";
import { contractors, exhibitors } from "./parties";
import { timestamps, users } from "./tenancy";
import { workflows } from "./workflow";

export type RulesChecklistEntry = {
  rule_id: string;
  checked: boolean;
  checked_by: string | null;
  checked_at: string | null;
  note: string | null;
};

export const standSubmissions = pgTable(
  "stand_submissions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    editionId: uuid("edition_id")
      .notNull()
      .references(() => editions.id),
    exhibitorId: uuid("exhibitor_id")
      .notNull()
      .references(() => exhibitors.id),
    ref: text("ref").notNull().unique(),
    contractorId: uuid("contractor_id").references(() => contractors.id),
    submissionVersion: integer("submission_version").notNull().default(1),
    maxHeightMm: integer("max_height_mm"),
    isDoubleDeck: boolean("is_double_deck").notNull().default(false),
    hasPlatformOver600mm: boolean("has_platform_over_600mm").notNull().default(false),
    hasRampedRaisedFloor: boolean("has_ramped_raised_floor").notNull().default(false),
    hasRigging: boolean("has_rigging").notNull().default(false),
    hasCeilingOrRoof: boolean("has_ceiling_or_roof").notNull().default(false),
    hasTieredSeating: boolean("has_tiered_seating").notNull().default(false),
    otherComplexNotes: text("other_complex_notes"),
    isComplex: boolean("is_complex").notNull().default(false),
    status: standStatus("status").notNull().default("not_submitted"),
    previousStatus: standStatus("previous_status"),
    onHoldReason: text("on_hold_reason"),
    outcome: standOutcome("outcome"),
    conditionsText: text("conditions_text"),
    submittedAt: timestamp("submitted_at", { withTimezone: true }),
    submittedBy: uuid("submitted_by").references(() => users.id),
    rulesChecklist: jsonb("rules_checklist").$type<RulesChecklistEntry[]>().notNull().default([]),
    buildCheckDoneAt: timestamp("build_check_done_at", { withTimezone: true }),
    buildCheckBy: uuid("build_check_by").references(() => users.id),
    buildCheckNotes: text("build_check_notes"),
    buildCheckPhotoPath: text("build_check_photo_path"),
    workflowId: uuid("workflow_id").references(() => workflows.id),
    currentRunNumber: integer("current_run_number").notNull().default(0),
    createdBy: uuid("created_by").references(() => users.id),
    ...timestamps,
  },
  (t) => [
    index("stand_submissions_edition_status_idx").on(t.editionId, t.status),
    index("stand_submissions_edition_idx").on(t.editionId),
    index("stand_submissions_contractor_idx").on(t.contractorId),
    index("stand_submissions_submitted_by_idx").on(t.submittedBy),
    index("stand_submissions_build_check_by_idx").on(t.buildCheckBy),
    index("stand_submissions_workflow_idx").on(t.workflowId),
    index("stand_submissions_created_by_idx").on(t.createdBy),
    unique("stand_submissions_exhibitor_unique").on(t.exhibitorId),
  ],
);
