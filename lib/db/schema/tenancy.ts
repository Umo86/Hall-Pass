import {
  boolean,
  index,
  jsonb,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";
import { externalRole, scopeType, staffRole } from "./enums";

const timestamps = {
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
};

export type OrganisationSettings = {
  escalate_after_days: number;
  install_photo_required: boolean;
  cost_threshold_for_director: number;
  currency: string;
};

export const organisations = pgTable("organisations", {
  id: uuid("id").primaryKey().defaultRandom(),
  name: text("name").notNull(),
  slug: text("slug").notNull().unique(),
  brandName: text("brand_name").notNull().default("Hall Pass"),
  logoPath: text("logo_path"),
  settings: jsonb("settings")
    .$type<OrganisationSettings>()
    .notNull()
    .default({
      escalate_after_days: 2,
      install_photo_required: true,
      cost_threshold_for_director: 5000,
      currency: "GBP",
    }),
  ...timestamps,
});

export type NotificationPrefs = Record<string, boolean>;

export const users = pgTable("users", {
  // Matches the Supabase auth uid.
  id: uuid("id").primaryKey(),
  email: text("email").notNull().unique(),
  fullName: text("full_name").notNull().default(""),
  phone: text("phone"),
  avatarPath: text("avatar_path"),
  isExternal: boolean("is_external").notNull().default(false),
  notificationPrefs: jsonb("notification_prefs").$type<NotificationPrefs>().notNull().default({}),
  lastSeenAt: timestamp("last_seen_at", { withTimezone: true }),
  ...timestamps,
});

export const memberships = pgTable(
  "memberships",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => users.id),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    role: staffRole("role").notNull(),
    ...timestamps,
  },
  (t) => [
    unique("memberships_user_org_unique").on(t.userId, t.organisationId),
    index("memberships_user_idx").on(t.userId),
    index("memberships_org_idx").on(t.organisationId),
  ],
);

export const externalGrants = pgTable(
  "external_grants",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    // Null until the invite is accepted.
    userId: uuid("user_id").references(() => users.id),
    invitedEmail: text("invited_email").notNull(),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    editionId: uuid("edition_id").notNull(),
    role: externalRole("role").notNull(),
    scopeType: scopeType("scope_type"),
    scopeId: uuid("scope_id"),
    expiresAt: timestamp("expires_at", { withTimezone: true }),
    invitedBy: uuid("invited_by").references(() => users.id),
    inviteTokenHash: text("invite_token_hash").notNull(),
    acceptedAt: timestamp("accepted_at", { withTimezone: true }),
    revokedAt: timestamp("revoked_at", { withTimezone: true }),
    ...timestamps,
  },
  (t) => [
    index("external_grants_user_idx").on(t.userId),
    index("external_grants_org_idx").on(t.organisationId),
    index("external_grants_edition_idx").on(t.editionId),
    index("external_grants_invited_by_idx").on(t.invitedBy),
    index("external_grants_token_idx").on(t.inviteTokenHash),
  ],
);

export { timestamps };
