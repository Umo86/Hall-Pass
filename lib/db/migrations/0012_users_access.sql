-- Users v2: managers, suspension and access end dates, per-person access
-- history, who raised a snag, and one main approver per department.
-- Stored ability overrides are not rewritten: the new abilities read an older
-- settings.manage / sponsorship.create as a fallback (lib/authz.ts).
-- Every statement is safe to run twice.
DO $$ BEGIN
  CREATE TYPE "public"."manager_scope" AS ENUM('department', 'everyone');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
-- The reminder log also records the week-before warning for access end dates.
ALTER TYPE "public"."reminder_target_type" ADD VALUE IF NOT EXISTS 'membership';--> statement-breakpoint
ALTER TABLE "memberships" ADD COLUMN IF NOT EXISTS "manager_scope" "manager_scope";--> statement-breakpoint
ALTER TABLE "memberships" ADD COLUMN IF NOT EXISTS "suspended_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "memberships" ADD COLUMN IF NOT EXISTS "suspended_by" uuid;--> statement-breakpoint
ALTER TABLE "memberships" ADD COLUMN IF NOT EXISTS "access_ends_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "staff_invites" ADD COLUMN IF NOT EXISTS "manager_scope" "manager_scope";--> statement-breakpoint
ALTER TABLE "staff_invites" ADD COLUMN IF NOT EXISTS "access_ends_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "snags" ADD COLUMN IF NOT EXISTS "raised_by_user_id" uuid;--> statement-breakpoint
ALTER TABLE "audit_log" ADD COLUMN IF NOT EXISTS "subject_user_id" uuid;--> statement-breakpoint
ALTER TABLE "audit_log" ADD COLUMN IF NOT EXISTS "subject_email" text;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "memberships" ADD CONSTRAINT "memberships_suspended_by_users_id_fk" FOREIGN KEY ("suspended_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "snags" ADD CONSTRAINT "snags_raised_by_user_id_users_id_fk" FOREIGN KEY ("raised_by_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "memberships" ADD CONSTRAINT "memberships_manager_scope_not_admin" CHECK ("memberships"."role" <> 'admin' OR "memberships"."manager_scope" IS NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "memberships_suspended_by_idx" ON "memberships" USING btree ("suspended_by");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "snags_raised_by_user_idx" ON "snags" USING btree ("raised_by_user_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "audit_log_subject_user_idx" ON "audit_log" USING btree ("organisation_id","subject_user_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "audit_log_subject_email_idx" ON "audit_log" USING btree ("organisation_id","subject_email");--> statement-breakpoint
-- One main approver per department: where saves raced and left more than
-- one, the oldest stays main and the others become ordinary approvers.
UPDATE "approvers" a SET "is_main" = false
FROM (
  SELECT "id", row_number() OVER (PARTITION BY "department_id" ORDER BY "created_at", "id") AS n
  FROM "approvers" WHERE "is_main"
) x
WHERE a."id" = x."id" AND x.n > 1;--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "approvers_one_main" ON "approvers" USING btree ("department_id") WHERE "approvers"."is_main";--> statement-breakpoint
-- Who raised each snag, where the audit log says (raiseSnag records the
-- snag's id); older snags without such a row stay unknown.
UPDATE "snags" s SET "raised_by_user_id" = x."actor_user_id"
FROM (
  SELECT DISTINCT ON (a."after"->>'snagId') a."after"->>'snagId' AS "snag_id", a."actor_user_id"
  FROM "audit_log" a
  JOIN "users" u ON u."id" = a."actor_user_id"
  WHERE a."after"->>'snagId' IS NOT NULL AND a."summary" LIKE 'Snag raised on %'
  ORDER BY a."after"->>'snagId', a."created_at"
) x
WHERE s."raised_by_user_id" IS NULL AND s."id"::text = x."snag_id";
