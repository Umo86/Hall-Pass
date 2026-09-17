import {
  boolean,
  date,
  index,
  integer,
  jsonb,
  numeric,
  pgTable,
  text,
  unique,
  uuid,
} from "drizzle-orm/pg-core";
import { deadlineKey, editionStatus } from "./enums";
import { organisations, timestamps, users } from "./tenancy";

export const events = pgTable(
  "events",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    name: text("name").notNull(),
    code: text("code").notNull(),
    ...timestamps,
  },
  (t) => [
    index("events_org_idx").on(t.organisationId),
    unique("events_org_code_unique").on(t.organisationId, t.code),
  ],
);

export const venues = pgTable(
  "venues",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    name: text("name").notNull(),
    code: text("code").notNull(),
    address: text("address"),
    riggingContactName: text("rigging_contact_name"),
    riggingContactEmail: text("rigging_contact_email"),
    requiresStandApproval: boolean("requires_stand_approval").notNull().default(false),
    notes: text("notes"),
    ...timestamps,
  },
  (t) => [
    index("venues_org_idx").on(t.organisationId),
    unique("venues_org_code_unique").on(t.organisationId, t.code),
  ],
);

export const venueRuleCategory = [
  "height",
  "rigging",
  "structure",
  "fire",
  "electrical",
  "walls",
  "gangways",
  "general",
] as const;

export const venueRules = pgTable(
  "venue_rules",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    venueId: uuid("venue_id")
      .notNull()
      .references(() => venues.id),
    category: text("category", { enum: venueRuleCategory }).notNull(),
    title: text("title").notNull(),
    ruleText: text("rule_text").notNull(),
    appliesTo: text("applies_to", { enum: ["signage", "stand", "both"] }).notNull(),
    isChecklistItem: boolean("is_checklist_item").notNull().default(false),
    sortOrder: integer("sort_order").notNull().default(0),
    ...timestamps,
  },
  (t) => [index("venue_rules_venue_idx").on(t.venueId)],
);

export type ComplexStructureTrigger = {
  key: string;
  label: string;
};

export const editions = pgTable(
  "editions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    eventId: uuid("event_id")
      .notNull()
      .references(() => events.id),
    venueId: uuid("venue_id")
      .notNull()
      .references(() => venues.id),
    name: text("name").notNull(),
    code: text("code").notNull(),
    buildStart: date("build_start").notNull(),
    buildEnd: date("build_end").notNull(),
    openStart: date("open_start").notNull(),
    openEnd: date("open_end").notNull(),
    breakdownEnd: date("breakdown_end").notNull(),
    status: editionStatus("status").notNull().default("planning"),
    clonedFromEditionId: uuid("cloned_from_edition_id"),
    signageBudget: numeric("signage_budget", { precision: 12, scale: 2 }),
    standRequiredDocTypes: text("stand_required_doc_types")
      .array()
      .notNull()
      .default(["plan", "elevation", "rams", "insurance_pl"]),
    complexStructureTriggers: jsonb("complex_structure_triggers")
      .$type<ComplexStructureTrigger[]>()
      .notNull()
      .default([]),
    ...timestamps,
  },
  (t) => [
    index("editions_event_idx").on(t.eventId),
    index("editions_venue_idx").on(t.venueId),
    index("editions_cloned_from_idx").on(t.clonedFromEditionId),
  ],
);

export const editionDeadlines = pgTable(
  "edition_deadlines",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    editionId: uuid("edition_id")
      .notNull()
      .references(() => editions.id),
    key: deadlineKey("key").notNull(),
    label: text("label").notNull(),
    daysBeforeBuildStart: integer("days_before_build_start").notNull(),
    overrideDate: date("override_date"),
    ...timestamps,
  },
  (t) => [
    index("edition_deadlines_edition_idx").on(t.editionId),
    unique("edition_deadlines_edition_key_unique").on(t.editionId, t.key),
  ],
);

export const editionCounters = pgTable(
  "edition_counters",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    editionId: uuid("edition_id")
      .notNull()
      .references(() => editions.id),
    key: text("key").notNull(),
    value: integer("value").notNull().default(0),
    ...timestamps,
  },
  (t) => [
    index("edition_counters_edition_idx").on(t.editionId),
    unique("edition_counters_edition_key_unique").on(t.editionId, t.key),
  ],
);

// Re-export so downstream schema files can reference people tables via one path.
export { organisations, users };
