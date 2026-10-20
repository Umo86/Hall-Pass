import { sql } from "drizzle-orm";
import {
  boolean,
  check,
  index,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";
import { externalRole, managerScope, scopeType, staffRole } from "./enums";

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
  settings: jsonb("settings").$type<OrganisationSettings>().notNull().default({
    escalate_after_days: 2,
    install_photo_required: true,
    cost_threshold_for_director: 5000,
    currency: "GBP",
  }),
  ...timestamps,
});

/**
 * The organisation's departments (Operations, Marketing, Finance…). Every
 * staff member can belong to one. A department with `signsOff` also gets one
 * sign-off step in the signage workflow and a list of approvers; one without
 * is only a team for grouping people.
 */
export const departments = pgTable(
  "departments",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    name: text("name").notNull(),
    sortOrder: integer("sort_order").notNull().default(0),
    /** Approves artwork: has a sign-off step and approvers. */
    signsOff: boolean("signs_off").notNull().default(true),
    /** Signs off after the other departments have (e.g. Senior management). */
    signsLast: boolean("signs_last").notNull().default(false),
    /** Signage that gets this department's sign-off by default: organiser, sponsor. */
    defaultFor: text("default_for").array().notNull().default([]),
    isArchived: boolean("is_archived").notNull().default(false),
    ...timestamps,
  },
  (t) => [unique("departments_org_name_unique").on(t.organisationId, t.name)],
);

export type NotificationPrefs = Record<string, boolean>;

export const users = pgTable("users", {
  // Same id as the person's sign-in account (Better Auth uses this table).
  // lib/auth/server.ts maps Better Auth's name to full_name, image to avatar_path.
  id: uuid("id").primaryKey().defaultRandom(),
  // Always stored lower-case.
  email: text("email").notNull().unique(),
  fullName: text("full_name").notNull().default(""),
  phone: text("phone"),
  avatarPath: text("avatar_path"),
  isExternal: boolean("is_external").notNull().default(false),
  notificationPrefs: jsonb("notification_prefs").$type<NotificationPrefs>().notNull().default({}),
  lastSeenAt: timestamp("last_seen_at", { withTimezone: true }),
  /** Control of the inbox is proven (invitation link, magic link, or carried over by migration 0014). */
  emailVerified: boolean("email_verified").notNull().default(false),
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
    // Per-user ability overrides on top of the role defaults; keys are the
    // ABILITIES registry in lib/authz.ts. Admins ignore overrides.
    permissionOverrides: jsonb("permission_overrides")
      .$type<Record<string, boolean>>()
      .notNull()
      .default({}),
    /** The department they belong to (shown in Users); null = none yet. */
    departmentId: uuid("department_id").references(() => departments.id, {
      onDelete: "set null",
    }),
    /**
     * App sections they can use (keys in lib/authz.ts FEATURES). Null means
     * every section — what everyone had before sections existed.
     */
    features: text("features").array(),
    jobTitle: text("job_title"),
    /**
     * A manager adds and changes people: their own department, or everyone
     * (never other managers or super admins). Null = not a manager. Super
     * admins manage everyone already, so theirs is always null.
     */
    managerScope: managerScope("manager_scope"),
    /** Paused: can't sign in or be told about anything until reactivated. */
    suspendedAt: timestamp("suspended_at", { withTimezone: true }),
    suspendedBy: uuid("suspended_by").references(() => users.id),
    /** Access ends at this moment (the end of a London day); null = no end. */
    accessEndsAt: timestamp("access_ends_at", { withTimezone: true }),
    /**
     * Events (editions) they work on (Users → Events). Null = every event,
     * including ones created later — what everyone had before. Never set for
     * super admins; never an empty list.
     */
    editionIds: uuid("edition_ids").array(),
    ...timestamps,
  },
  (t) => [
    unique("memberships_user_org_unique").on(t.userId, t.organisationId),
    index("memberships_department_idx").on(t.departmentId),
    index("memberships_user_idx").on(t.userId),
    index("memberships_org_idx").on(t.organisationId),
    index("memberships_suspended_by_idx").on(t.suspendedBy),
    check(
      "memberships_manager_scope_not_admin",
      sql`${t.role} <> 'admin' OR ${t.managerScope} IS NULL`,
    ),
    check(
      "memberships_edition_ids_not_admin",
      sql`${t.role} <> 'admin' OR ${t.editionIds} IS NULL`,
    ),
    check(
      "memberships_edition_ids_not_empty",
      sql`${t.editionIds} IS NULL OR cardinality(${t.editionIds}) > 0`,
    ),
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

/**
 * Pending invitations for staff users. A membership row needs the account,
 * which doesn't exist until the invitation is accepted, so the invite carries
 * the role (and overrides) to apply when the email first signs in.
 */
export const staffInvites = pgTable(
  "staff_invites",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    organisationId: uuid("organisation_id")
      .notNull()
      .references(() => organisations.id),
    invitedEmail: text("invited_email").notNull(),
    fullName: text("full_name").notNull().default(""),
    jobTitle: text("job_title"),
    role: staffRole("role").notNull(),
    permissionOverrides: jsonb("permission_overrides")
      .$type<Record<string, boolean>>()
      .notNull()
      .default({}),
    /** Copied onto the membership when the invitation is accepted. */
    departmentId: uuid("department_id").references(() => departments.id, {
      onDelete: "set null",
    }),
    features: text("features").array(),
    /** Copied onto the membership when accepted. */
    managerScope: managerScope("manager_scope"),
    accessEndsAt: timestamp("access_ends_at", { withTimezone: true }),
    /**
     * Events (editions) they will work on; null = every event, including
     * ones created later. Copied onto the membership when accepted. Never set
     * for super admins; never an empty list.
     */
    editionIds: uuid("edition_ids").array(),
    /** Null on invitations sent before expiry existed: they never expire. */
    expiresAt: timestamp("expires_at", { withTimezone: true }),
    invitedBy: uuid("invited_by").references(() => users.id),
    inviteTokenHash: text("invite_token_hash").notNull(),
    acceptedAt: timestamp("accepted_at", { withTimezone: true }),
    revokedAt: timestamp("revoked_at", { withTimezone: true }),
    ...timestamps,
  },
  (t) => [
    index("staff_invites_org_idx").on(t.organisationId),
    index("staff_invites_email_idx").on(t.invitedEmail),
    index("staff_invites_invited_by_idx").on(t.invitedBy),
    index("staff_invites_token_idx").on(t.inviteTokenHash),
    index("staff_invites_department_idx").on(t.departmentId),
    check(
      "staff_invites_edition_ids_not_admin",
      sql`${t.role} <> 'admin' OR ${t.editionIds} IS NULL`,
    ),
    check(
      "staff_invites_edition_ids_not_empty",
      sql`${t.editionIds} IS NULL OR cardinality(${t.editionIds}) > 0`,
    ),
  ],
);

export { timestamps };
