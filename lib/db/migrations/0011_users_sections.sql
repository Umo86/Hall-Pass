-- Users section: a department per person, app sections per person, richer
-- staff invitations, event setup progress, and archiving for suppliers and
-- venues. Every statement is safe to run twice.
ALTER TABLE "memberships" ADD COLUMN IF NOT EXISTS "department_id" uuid;--> statement-breakpoint
ALTER TABLE "memberships" ADD COLUMN IF NOT EXISTS "features" text[];--> statement-breakpoint
ALTER TABLE "memberships" ADD COLUMN IF NOT EXISTS "job_title" text;--> statement-breakpoint
ALTER TABLE "staff_invites" ADD COLUMN IF NOT EXISTS "full_name" text DEFAULT '' NOT NULL;--> statement-breakpoint
ALTER TABLE "staff_invites" ADD COLUMN IF NOT EXISTS "job_title" text;--> statement-breakpoint
ALTER TABLE "staff_invites" ADD COLUMN IF NOT EXISTS "department_id" uuid;--> statement-breakpoint
ALTER TABLE "staff_invites" ADD COLUMN IF NOT EXISTS "features" text[];--> statement-breakpoint
ALTER TABLE "staff_invites" ADD COLUMN IF NOT EXISTS "expires_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "editions" ADD COLUMN IF NOT EXISTS "setup_checked" text[] DEFAULT '{}' NOT NULL;--> statement-breakpoint
ALTER TABLE "venues" ADD COLUMN IF NOT EXISTS "is_archived" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "suppliers" ADD COLUMN IF NOT EXISTS "is_archived" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "departments" ADD COLUMN IF NOT EXISTS "signs_off" boolean DEFAULT true NOT NULL;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "memberships" ADD CONSTRAINT "memberships_department_id_departments_id_fk" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "staff_invites" ADD CONSTRAINT "staff_invites_department_id_departments_id_fk" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "memberships_department_idx" ON "memberships" USING btree ("department_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "staff_invites_department_idx" ON "staff_invites" USING btree ("department_id");--> statement-breakpoint
-- Existing people who approve for exactly one live department belong to it.
-- Everyone else starts with no department; nobody's access changes.
UPDATE "memberships" m SET "department_id" = x."department_id"
FROM (
  SELECT a."organisation_id", a."user_id", (array_agg(a."department_id"))[1] AS "department_id", count(*) AS n
  FROM "approvers" a
  JOIN "departments" d ON d."id" = a."department_id" AND NOT d."is_archived"
  WHERE a."user_id" IS NOT NULL
  GROUP BY a."organisation_id", a."user_id"
) x
WHERE x.n = 1 AND m."department_id" IS NULL AND m."user_id" = x."user_id" AND m."organisation_id" = x."organisation_id";
