import {
  boolean,
  date,
  index,
  integer,
  numeric,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";
import { fixingMethod, installSlot, ownerRole, proofStatus, sided, signageStatus } from "./enums";
import { editions } from "./events";
import { halls, locations } from "./floorplans";
import { contractors, sponsorEntitlements, sponsors, suppliers } from "./parties";
import { organisations, timestamps, users } from "./tenancy";
import { workflows } from "./workflow";

export const itemTypes = pgTable(
  "item_types",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    name: text("name").notNull(),
    code: text("code").notNull(),
    defaultWorkflowId: uuid("default_workflow_id").references(() => workflows.id),
    defaultFixingMethod: fixingMethod("default_fixing_method"),
    requiresVenueApprovalDefault: boolean("requires_venue_approval_default")
      .notNull()
      .default(false),
    sortOrder: integer("sort_order").notNull().default(0),
    ...timestamps,
  },
  (t) => [
    index("item_types_org_idx").on(t.organisationId),
    index("item_types_default_workflow_idx").on(t.defaultWorkflowId),
    unique("item_types_org_code_unique").on(t.organisationId, t.code),
  ],
);

export const signageItems = pgTable(
  "signage_items",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    editionId: uuid("edition_id")
      .notNull()
      .references(() => editions.id),
    ref: text("ref").notNull().unique(),
    seq: integer("seq").notNull(),
    name: text("name").notNull(),
    description: text("description"),
    itemTypeId: uuid("item_type_id").references(() => itemTypes.id),
    hallId: uuid("hall_id").references(() => halls.id),
    locationId: uuid("location_id").references(() => locations.id),
    ownerRole: ownerRole("owner_role").notNull().default("ops"),
    ownerUserId: uuid("owner_user_id").references(() => users.id),
    sponsorId: uuid("sponsor_id").references(() => sponsors.id),
    sponsorEntitlementId: uuid("sponsor_entitlement_id").references(() => sponsorEntitlements.id),
    isSponsorDeliverable: boolean("is_sponsor_deliverable").notNull().default(false),
    widthMm: integer("width_mm"),
    heightMm: integer("height_mm"),
    depthMm: integer("depth_mm"),
    quantity: integer("quantity").notNull().default(1),
    sided: sided("sided").notNull().default("single"),
    material: text("material"),
    finish: text("finish"),
    fixingMethod: fixingMethod("fixing_method"),
    weightKg: numeric("weight_kg", { precision: 8, scale: 2 }),
    requiresVenueApproval: boolean("requires_venue_approval").notNull().default(false),
    requiresEventDirector: boolean("requires_event_director").notNull().default(false),
    budgetLine: text("budget_line"),
    costEstimate: numeric("cost_estimate", { precision: 12, scale: 2 }),
    costActual: numeric("cost_actual", { precision: 12, scale: 2 }),
    poNumber: text("po_number"),
    supplierId: uuid("supplier_id").references(() => suppliers.id),
    artworkDueOverride: date("artwork_due_override"),
    printDeadline: date("print_deadline"),
    deliveryDate: date("delivery_date"),
    installDate: date("install_date"),
    installSlot: installSlot("install_slot"),
    installContractorId: uuid("install_contractor_id").references(() => contractors.id),
    status: signageStatus("status").notNull().default("draft"),
    previousStatus: signageStatus("previous_status"),
    onHoldReason: text("on_hold_reason"),
    workflowId: uuid("workflow_id").references(() => workflows.id),
    currentRunNumber: integer("current_run_number").notNull().default(0),
    // FK added in SQL migration (artwork_versions is declared after this table).
    currentArtworkVersionId: uuid("current_artwork_version_id"),
    installedAt: timestamp("installed_at", { withTimezone: true }),
    installedBy: uuid("installed_by").references(() => users.id),
    installPhotoPath: text("install_photo_path"),
    createdBy: uuid("created_by").references(() => users.id),
    deletedAt: timestamp("deleted_at", { withTimezone: true }),
    ...timestamps,
  },
  (t) => [
    index("signage_items_edition_status_idx").on(t.editionId, t.status),
    index("signage_items_edition_idx").on(t.editionId),
    index("signage_items_item_type_idx").on(t.itemTypeId),
    index("signage_items_hall_idx").on(t.hallId),
    index("signage_items_location_idx").on(t.locationId),
    index("signage_items_owner_user_idx").on(t.ownerUserId),
    index("signage_items_sponsor_idx").on(t.sponsorId),
    index("signage_items_sponsor_entitlement_idx").on(t.sponsorEntitlementId),
    index("signage_items_supplier_idx").on(t.supplierId),
    index("signage_items_install_contractor_idx").on(t.installContractorId),
    index("signage_items_workflow_idx").on(t.workflowId),
    index("signage_items_installed_by_idx").on(t.installedBy),
    index("signage_items_created_by_idx").on(t.createdBy),
    unique("signage_items_edition_seq_unique").on(t.editionId, t.seq),
  ],
);

export const artworkVersions = pgTable(
  "artwork_versions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    signageItemId: uuid("signage_item_id")
      .notNull()
      .references(() => signageItems.id),
    versionNumber: integer("version_number").notNull(),
    filePath: text("file_path").notNull(),
    fileName: text("file_name").notNull(),
    mimeType: text("mime_type").notNull(),
    fileSize: integer("file_size").notNull(),
    sha256: text("sha256").notNull(),
    pageCount: integer("page_count"),
    previewPath: text("preview_path"),
    uploadedBy: uuid("uploaded_by").references(() => users.id),
    proofStatus: proofStatus("proof_status").notNull().default("draft"),
    notes: text("notes"),
    ...timestamps,
  },
  (t) => [
    index("artwork_versions_item_idx").on(t.signageItemId),
    index("artwork_versions_uploaded_by_idx").on(t.uploadedBy),
    unique("artwork_versions_item_version_unique").on(t.signageItemId, t.versionNumber),
  ],
);

export const artworkAnnotations = pgTable(
  "artwork_annotations",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    artworkVersionId: uuid("artwork_version_id")
      .notNull()
      .references(() => artworkVersions.id),
    page: integer("page").notNull().default(1),
    xPct: numeric("x_pct", { precision: 6, scale: 5 }).notNull(),
    yPct: numeric("y_pct", { precision: 6, scale: 5 }).notNull(),
    // FK to comments added in SQL migration (comments is declared later).
    commentId: uuid("comment_id").notNull(),
    ...timestamps,
  },
  (t) => [
    index("artwork_annotations_version_idx").on(t.artworkVersionId),
    index("artwork_annotations_comment_idx").on(t.commentId),
  ],
);
