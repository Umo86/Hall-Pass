-- Three things that ship together; every statement is safe to run twice and
-- no enum value is added (nothing could be used in the same migration).
-- (1) Main approver when they accept: an invitee chosen as a department's
--     main approver while the current main can sign takes over when they
--     accept. The ask lives on their email-keyed approver row.
-- (2) Events per person: memberships.edition_ids / staff_invites.edition_ids
--     list the events a team member works on; NULL = every event, including
--     later ones (what everyone has today, so no row is rewritten). Super
--     admins are never limited and a list is never empty. notifications get
--     the event they are about, filled in for existing rows.
-- (3) Sponsorship packages: a priced catalogue per event and which package
--     each sponsor bought at what agreed price. One package per distinct
--     package name per event is created (no price yet) and its sponsors are
--     linked, sold when they were added. sponsors.package_name is kept and
--     mirrored for older code.
-- Adds and backfills only; drops and renames nothing.

-- (1) Main approver when they accept ---------------------------------------
ALTER TABLE "approvers" ADD COLUMN IF NOT EXISTS "main_on_accept" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "approvers" ADD COLUMN IF NOT EXISTS "main_on_accept_by" uuid;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "approvers" ADD CONSTRAINT "approvers_main_on_accept_by_users_id_fk" FOREIGN KEY ("main_on_accept_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "approvers" ADD CONSTRAINT "approvers_main_on_accept_invite_only" CHECK (NOT "approvers"."main_on_accept" OR ("approvers"."user_id" IS NULL AND NOT "approvers"."is_main"));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "approvers_main_on_accept_by_idx" ON "approvers" USING btree ("main_on_accept_by");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "approvers_one_main_on_accept" ON "approvers" USING btree ("department_id") WHERE "approvers"."main_on_accept";--> statement-breakpoint

-- (2) Events per person ----------------------------------------------------
ALTER TABLE "memberships" ADD COLUMN IF NOT EXISTS "edition_ids" uuid[];--> statement-breakpoint
ALTER TABLE "staff_invites" ADD COLUMN IF NOT EXISTS "edition_ids" uuid[];--> statement-breakpoint
ALTER TABLE "notifications" ADD COLUMN IF NOT EXISTS "edition_id" uuid;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "memberships" ADD CONSTRAINT "memberships_edition_ids_not_admin" CHECK ("memberships"."role" <> 'admin' OR "memberships"."edition_ids" IS NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "memberships" ADD CONSTRAINT "memberships_edition_ids_not_empty" CHECK ("memberships"."edition_ids" IS NULL OR cardinality("memberships"."edition_ids") > 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "staff_invites" ADD CONSTRAINT "staff_invites_edition_ids_not_admin" CHECK ("staff_invites"."role" <> 'admin' OR "staff_invites"."edition_ids" IS NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "staff_invites" ADD CONSTRAINT "staff_invites_edition_ids_not_empty" CHECK ("staff_invites"."edition_ids" IS NULL OR cardinality("staff_invites"."edition_ids") > 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
-- Editions are never deleted in the app; test clean-ups do delete them, so
-- the link is cleared rather than blocking (the row becomes "about no one
-- event", which is how every existing row without a record reads).
DO $$ BEGIN
  ALTER TABLE "notifications" ADD CONSTRAINT "notifications_edition_id_editions_id_fk" FOREIGN KEY ("edition_id") REFERENCES "public"."editions"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "notifications_edition_idx" ON "notifications" USING btree ("edition_id");--> statement-breakpoint
-- Which event each existing notification is about: its record's event, else
-- the event code at the start of its link ("/BIRM27/..."; codes are
-- [A-Z0-9-] and unique across the platform, so LIKE has no wildcards to
-- trip on). Rows about nothing in particular stay NULL. Data only; re-run
-- after deploying to catch rows the old code wrote in between.
UPDATE "notifications" n SET "edition_id" = s."edition_id"
FROM "signage_items" s
WHERE n."edition_id" IS NULL AND n."entity_type" = 'signage_item' AND s."id" = n."entity_id";--> statement-breakpoint
UPDATE "notifications" n SET "edition_id" = s."edition_id"
FROM "stand_submissions" s
WHERE n."edition_id" IS NULL AND n."entity_type" = 'stand_submission' AND s."id" = n."entity_id";--> statement-breakpoint
UPDATE "notifications" n SET "edition_id" = x."edition_id"
FROM "exhibitors" x
WHERE n."edition_id" IS NULL AND n."entity_type" = 'exhibitor' AND x."id" = n."entity_id";--> statement-breakpoint
UPDATE "notifications" n SET "edition_id" = e."id"
FROM "editions" e
WHERE n."edition_id" IS NULL AND n."entity_type" = 'edition' AND e."id" = n."entity_id";--> statement-breakpoint
UPDATE "notifications" n SET "edition_id" = e."id"
FROM "editions" e
WHERE n."edition_id" IS NULL
  AND n."link" IS NOT NULL
  AND (n."link" = '/' || e."code"
    OR n."link" LIKE '/' || e."code" || '/%'
    OR n."link" LIKE '/' || e."code" || '?%');--> statement-breakpoint

-- (3) Sponsorship packages -------------------------------------------------
CREATE TABLE IF NOT EXISTS "sponsorship_packages" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"edition_id" uuid NOT NULL,
	"name" text NOT NULL,
	"description" text,
	"price" numeric(12, 2),
	"places" integer,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"is_archived" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "sponsorship_packages_id_edition_unique" UNIQUE("id","edition_id"),
	CONSTRAINT "sponsorship_packages_price_not_negative" CHECK ("sponsorship_packages"."price" IS NULL OR "sponsorship_packages"."price" >= 0),
	CONSTRAINT "sponsorship_packages_places_positive" CHECK ("sponsorship_packages"."places" IS NULL OR "sponsorship_packages"."places" >= 1)
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "sponsorship_package_lines" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"package_id" uuid NOT NULL,
	"description" text NOT NULL,
	"quantity" integer DEFAULT 1 NOT NULL,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "sponsorship_package_lines_quantity_positive" CHECK ("sponsorship_package_lines"."quantity" >= 1)
);
--> statement-breakpoint
ALTER TABLE "sponsors" ADD COLUMN IF NOT EXISTS "package_id" uuid;--> statement-breakpoint
ALTER TABLE "sponsors" ADD COLUMN IF NOT EXISTS "package_price" numeric(12, 2);--> statement-breakpoint
ALTER TABLE "sponsors" ADD COLUMN IF NOT EXISTS "package_price_note" text;--> statement-breakpoint
ALTER TABLE "sponsors" ADD COLUMN IF NOT EXISTS "package_sold_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "sponsor_entitlements" ADD COLUMN IF NOT EXISTS "from_package_id" uuid;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "sponsorship_packages" ADD CONSTRAINT "sponsorship_packages_edition_id_editions_id_fk" FOREIGN KEY ("edition_id") REFERENCES "public"."editions"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "sponsorship_package_lines" ADD CONSTRAINT "sponsorship_package_lines_package_id_sponsorship_packages_id_fk" FOREIGN KEY ("package_id") REFERENCES "public"."sponsorship_packages"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
-- A sponsor's package is always one of their own event's packages.
DO $$ BEGIN
  ALTER TABLE "sponsors" ADD CONSTRAINT "sponsors_package_same_event_fk" FOREIGN KEY ("package_id","edition_id") REFERENCES "public"."sponsorship_packages"("id","edition_id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "sponsor_entitlements" ADD CONSTRAINT "sponsor_entitlements_from_package_id_sponsorship_packages_id_fk" FOREIGN KEY ("from_package_id") REFERENCES "public"."sponsorship_packages"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
-- The agreed price, its reason and the sold date only go with a package.
DO $$ BEGIN
  ALTER TABLE "sponsors" ADD CONSTRAINT "sponsors_package_sale_fields" CHECK ("sponsors"."package_id" IS NOT NULL OR ("sponsors"."package_price" IS NULL AND "sponsors"."package_price_note" IS NULL AND "sponsors"."package_sold_at" IS NULL));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "sponsors" ADD CONSTRAINT "sponsors_package_price_not_negative" CHECK ("sponsors"."package_price" IS NULL OR "sponsors"."package_price" >= 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "sponsorship_packages_edition_idx" ON "sponsorship_packages" USING btree ("edition_id","sort_order");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "sponsorship_packages_edition_name_unique" ON "sponsorship_packages" USING btree ("edition_id",lower("name"));--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "sponsorship_package_lines_package_idx" ON "sponsorship_package_lines" USING btree ("package_id","sort_order");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "sponsors_package_idx" ON "sponsors" USING btree ("package_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "sponsor_entitlements_from_package_idx" ON "sponsor_entitlements" USING btree ("from_package_id");--> statement-breakpoint
-- Deny-by-default, as every other table: RLS on with no policies, and no
-- direct privileges for Supabase's client roles where they exist.
ALTER TABLE "sponsorship_packages" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "sponsorship_package_lines" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON "sponsorship_packages", "sponsorship_package_lines" FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON "sponsorship_packages", "sponsorship_package_lines" FROM authenticated;
  END IF;
END $$;--> statement-breakpoint
DO $$ BEGIN
  CREATE TRIGGER sponsorship_packages_set_updated_at BEFORE UPDATE ON "sponsorship_packages" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  CREATE TRIGGER sponsorship_package_lines_set_updated_at BEFORE UPDATE ON "sponsorship_package_lines" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
-- One package per distinct package name per event among sponsors not yet
-- linked (trimmed, any case; the earliest spelling names it), no price yet,
-- after the event's existing packages in A-Z order.
INSERT INTO "sponsorship_packages" ("edition_id", "name", "sort_order")
SELECT x."edition_id", x."name",
       coalesce((SELECT max(p."sort_order") FROM "sponsorship_packages" p WHERE p."edition_id" = x."edition_id"), 0) + x."n"
FROM (
  SELECT s."edition_id",
         (array_agg(btrim(s."package_name") ORDER BY s."created_at", s."id"))[1] AS "name",
         row_number() OVER (PARTITION BY s."edition_id" ORDER BY lower(btrim(s."package_name"))) AS "n"
  FROM "sponsors" s
  WHERE s."package_id" IS NULL AND s."package_name" IS NOT NULL AND btrim(s."package_name") <> ''
  GROUP BY s."edition_id", lower(btrim(s."package_name"))
) x
ON CONFLICT ("edition_id", lower("name")) DO NOTHING;--> statement-breakpoint
-- Their sponsors bought it when they were added; the agreed price is left
-- for the team to fill in ("No price agreed yet").
UPDATE "sponsors" s
SET "package_id" = p."id", "package_sold_at" = s."created_at"
FROM "sponsorship_packages" p
WHERE s."package_id" IS NULL
  AND s."package_name" IS NOT NULL AND btrim(s."package_name") <> ''
  AND p."edition_id" = s."edition_id"
  AND lower(p."name") = lower(btrim(s."package_name"));
