import {
  date,
  index,
  integer,
  numeric,
  pgTable,
  primaryKey,
  boolean,
  text,
  unique,
  uuid,
} from "drizzle-orm/pg-core";
import { standType, supplierKind } from "./enums";
import { editions } from "./events";
import { halls } from "./floorplans";
import { organisations, timestamps } from "./tenancy";

export const suppliers = pgTable(
  "suppliers",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    name: text("name").notNull(),
    // Superseded by services (below); kept for older rows and exports.
    kind: supplierKind("kind").notNull().default("other"),
    contactName: text("contact_name"),
    email: text("email"),
    phone: text("phone"),
    notes: text("notes"),
    ...timestamps,
  },
  (t) => [index("suppliers_org_idx").on(t.organisationId)],
);

/** What suppliers can do (Signage print, Staffing, AV…) — a list admins manage. */
export const supplierServices = pgTable(
  "supplier_services",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    name: text("name").notNull(),
    sortOrder: integer("sort_order").notNull().default(0),
    isArchived: boolean("is_archived").notNull().default(false),
    ...timestamps,
  },
  (t) => [unique("supplier_services_org_name_unique").on(t.organisationId, t.name)],
);

export const supplierServiceLinks = pgTable(
  "supplier_service_links",
  {
    supplierId: uuid("supplier_id")
      .notNull()
      .references(() => suppliers.id, { onDelete: "cascade" }),
    serviceId: uuid("service_id")
      .notNull()
      .references(() => supplierServices.id, { onDelete: "cascade" }),
  },
  (t) => [
    primaryKey({ columns: [t.supplierId, t.serviceId] }),
    index("supplier_service_links_service_idx").on(t.serviceId),
  ],
);

export const contractors = pgTable(
  "contractors",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    name: text("name").notNull(),
    contactName: text("contact_name"),
    email: text("email"),
    phone: text("phone"),
    insuranceExpiry: date("insurance_expiry"),
    ...timestamps,
  },
  (t) => [index("contractors_org_idx").on(t.organisationId)],
);

export const sponsors = pgTable(
  "sponsors",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    editionId: uuid("edition_id")
      .notNull()
      .references(() => editions.id),
    companyName: text("company_name").notNull(),
    contactName: text("contact_name"),
    contactEmail: text("contact_email"),
    packageName: text("package_name"),
    notes: text("notes"),
    ...timestamps,
  },
  (t) => [index("sponsors_edition_idx").on(t.editionId)],
);

export const sponsorEntitlements = pgTable(
  "sponsor_entitlements",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    sponsorId: uuid("sponsor_id")
      .notNull()
      .references(() => sponsors.id),
    description: text("description").notNull(),
    quantity: integer("quantity").notNull().default(1),
    ...timestamps,
  },
  (t) => [index("sponsor_entitlements_sponsor_idx").on(t.sponsorId)],
);

export const exhibitors = pgTable(
  "exhibitors",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    editionId: uuid("edition_id")
      .notNull()
      .references(() => editions.id),
    companyName: text("company_name").notNull(),
    standNumber: text("stand_number").notNull(),
    hallId: uuid("hall_id").references(() => halls.id),
    standSizeSqm: numeric("stand_size_sqm", { precision: 8, scale: 2 }),
    standType: standType("stand_type").notNull().default("space_only"),
    contactName: text("contact_name"),
    contactEmail: text("contact_email"),
    contractorId: uuid("contractor_id").references(() => contractors.id),
    ...timestamps,
  },
  (t) => [
    index("exhibitors_edition_idx").on(t.editionId),
    index("exhibitors_hall_idx").on(t.hallId),
    index("exhibitors_contractor_idx").on(t.contractorId),
    unique("exhibitors_edition_stand_unique").on(t.editionId, t.standNumber),
  ],
);
