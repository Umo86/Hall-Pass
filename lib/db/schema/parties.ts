import { sql } from "drizzle-orm";
import {
  check,
  date,
  foreignKey,
  index,
  integer,
  numeric,
  pgTable,
  primaryKey,
  boolean,
  text,
  timestamp,
  unique,
  uniqueIndex,
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
    /** Hidden from lists and pickers; kept for the items that used it. */
    isArchived: boolean("is_archived").notNull().default(false),
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

/** What sponsors can buy as a package at one event: a price, what's included, how many. */
export const sponsorshipPackages = pgTable(
  "sponsorship_packages",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    editionId: uuid("edition_id")
      .notNull()
      .references(() => editions.id),
    name: text("name").notNull(),
    description: text("description"),
    /** List price in the organisation's currency; null = "No price yet". */
    price: numeric("price", { precision: 12, scale: 2 }),
    /** How many can be sold; null = no limit. */
    places: integer("places"),
    sortOrder: integer("sort_order").notNull().default(0),
    /** No longer offered; its sales stay. */
    isArchived: boolean("is_archived").notNull().default(false),
    ...timestamps,
  },
  (t) => [
    index("sponsorship_packages_edition_idx").on(t.editionId, t.sortOrder),
    uniqueIndex("sponsorship_packages_edition_name_unique").on(t.editionId, sql`lower(${t.name})`),
    unique("sponsorship_packages_id_edition_unique").on(t.id, t.editionId),
    check("sponsorship_packages_price_not_negative", sql`${t.price} IS NULL OR ${t.price} >= 0`),
    check("sponsorship_packages_places_positive", sql`${t.places} IS NULL OR ${t.places} >= 1`),
  ],
);

/** A package's "what's included" line; copied into a sponsor's entitlements when sold. */
export const sponsorshipPackageLines = pgTable(
  "sponsorship_package_lines",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    packageId: uuid("package_id")
      .notNull()
      .references(() => sponsorshipPackages.id, { onDelete: "cascade" }),
    description: text("description").notNull(),
    quantity: integer("quantity").notNull().default(1),
    sortOrder: integer("sort_order").notNull().default(0),
    ...timestamps,
  },
  (t) => [
    index("sponsorship_package_lines_package_idx").on(t.packageId, t.sortOrder),
    check("sponsorship_package_lines_quantity_positive", sql`${t.quantity} >= 1`),
  ],
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
    /** Kept in step with the linked package's name (older code reads it); not edited directly. */
    packageName: text("package_name"),
    /** The package they bought (one per sponsor), always one of their own event's. */
    packageId: uuid("package_id"),
    /** The agreed price; defaults to the package price when sold. */
    packagePrice: numeric("package_price", { precision: 12, scale: 2 }),
    /** Why the agreed price differs from the package price (e.g. a discount). */
    packagePriceNote: text("package_price_note"),
    /** When it was sold. */
    packageSoldAt: timestamp("package_sold_at", { withTimezone: true }),
    notes: text("notes"),
    ...timestamps,
  },
  (t) => [
    index("sponsors_edition_idx").on(t.editionId),
    index("sponsors_package_idx").on(t.packageId),
    // A sponsor's package is always one of their own event's packages.
    foreignKey({
      name: "sponsors_package_same_event_fk",
      columns: [t.packageId, t.editionId],
      foreignColumns: [sponsorshipPackages.id, sponsorshipPackages.editionId],
    }),
    check(
      "sponsors_package_sale_fields",
      sql`${t.packageId} IS NOT NULL OR (${t.packagePrice} IS NULL AND ${t.packagePriceNote} IS NULL AND ${t.packageSoldAt} IS NULL)`,
    ),
    check(
      "sponsors_package_price_not_negative",
      sql`${t.packagePrice} IS NULL OR ${t.packagePrice} >= 0`,
    ),
  ],
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
    /** The package whose sale added this line; null = added by hand. */
    fromPackageId: uuid("from_package_id").references(() => sponsorshipPackages.id),
    ...timestamps,
  },
  (t) => [
    index("sponsor_entitlements_sponsor_idx").on(t.sponsorId),
    index("sponsor_entitlements_from_package_idx").on(t.fromPackageId),
  ],
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
