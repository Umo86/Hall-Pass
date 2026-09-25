CREATE TABLE "approvers" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organisation_id" uuid NOT NULL,
	"department_id" uuid NOT NULL,
	"full_name" text NOT NULL,
	"job_title" text,
	"email" text NOT NULL,
	"user_id" uuid,
	"is_main" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "approvers_department_email_unique" UNIQUE("department_id","email")
);
--> statement-breakpoint
CREATE TABLE "departments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organisation_id" uuid NOT NULL,
	"name" text NOT NULL,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"signs_last" boolean DEFAULT false NOT NULL,
	"default_for" text[] DEFAULT '{}' NOT NULL,
	"is_archived" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "departments_org_name_unique" UNIQUE("organisation_id","name")
);
--> statement-breakpoint
ALTER TABLE "approval_instances" ADD COLUMN "assigned_department_id" uuid;--> statement-breakpoint
ALTER TABLE "workflow_steps" ADD COLUMN "department_id" uuid;--> statement-breakpoint
ALTER TABLE "approvers" ADD CONSTRAINT "approvers_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "approvers" ADD CONSTRAINT "approvers_department_id_departments_id_fk" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "approvers" ADD CONSTRAINT "approvers_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "departments" ADD CONSTRAINT "departments_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "approvers_org_idx" ON "approvers" USING btree ("organisation_id");--> statement-breakpoint
CREATE INDEX "approvers_user_idx" ON "approvers" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "approvers_email_idx" ON "approvers" USING btree ("email");--> statement-breakpoint
ALTER TABLE "approval_instances" ADD CONSTRAINT "approval_instances_assigned_department_id_departments_id_fk" FOREIGN KEY ("assigned_department_id") REFERENCES "public"."departments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workflow_steps" ADD CONSTRAINT "workflow_steps_department_id_departments_id_fk" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "approval_instances_department_idx" ON "approval_instances" USING btree ("assigned_department_id");--> statement-breakpoint
CREATE INDEX "workflow_steps_department_idx" ON "workflow_steps" USING btree ("department_id");--> statement-breakpoint
ALTER TABLE "departments" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "approvers" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TRIGGER departments_set_updated_at BEFORE UPDATE ON "departments" FOR EACH ROW EXECUTE FUNCTION set_updated_at();--> statement-breakpoint
CREATE TRIGGER approvers_set_updated_at BEFORE UPDATE ON "approvers" FOR EACH ROW EXECUTE FUNCTION set_updated_at();--> statement-breakpoint
-- Each existing department sign-off step becomes a department of its own.
INSERT INTO "departments" ("organisation_id", "name", "sort_order", "signs_last", "default_for")
SELECT DISTINCT ON (w."organisation_id", regexp_replace(ws."name", ' sign-off$', ''))
  w."organisation_id", regexp_replace(ws."name", ' sign-off$', ''), ws."sort_order", ws."parallel_group" IS NULL,
  ws."default_for"
FROM "workflow_steps" ws
JOIN "workflows" w ON w."id" = ws."workflow_id"
WHERE w."applies_to" = 'signage' AND cardinality(ws."default_for") > 0 AND NOT ws."is_archived"
ORDER BY w."organisation_id", regexp_replace(ws."name", ' sign-off$', ''), w."is_default" DESC
ON CONFLICT DO NOTHING;--> statement-breakpoint
UPDATE "workflow_steps" ws SET "department_id" = d."id"
FROM "workflows" w, "departments" d
WHERE w."id" = ws."workflow_id" AND w."applies_to" = 'signage' AND cardinality(ws."default_for") > 0
  AND d."organisation_id" = w."organisation_id" AND d."name" = regexp_replace(ws."name", ' sign-off$', '');--> statement-breakpoint
-- Approvers: team members in the matching role, plus each step's named person.
INSERT INTO "approvers" ("organisation_id", "department_id", "full_name", "email", "user_id", "is_main")
SELECT DISTINCT ON (ws."department_id", u."id")
  d."organisation_id", d."id", coalesce(nullif(u."full_name", ''), u."email"), lower(u."email"), u."id",
  coalesce(u."id" = ws."approver_user_id", false)
FROM "workflow_steps" ws
JOIN "departments" d ON d."id" = ws."department_id"
JOIN "memberships" m ON m."organisation_id" = d."organisation_id"
JOIN "users" u ON u."id" = m."user_id"
WHERE (m."role"::text = ws."approver_role" OR u."id" = ws."approver_user_id")
  AND coalesce(m."permission_overrides" ->> 'approval.decide', 'true') <> 'false'
ORDER BY ws."department_id", u."id", (u."id" = ws."approver_user_id") DESC
ON CONFLICT DO NOTHING;--> statement-breakpoint
UPDATE "workflow_steps" SET "approver_role" = NULL WHERE "department_id" IS NOT NULL;--> statement-breakpoint
-- Sign-offs already created go to the department instead of the role.
UPDATE "approval_instances" ai SET "assigned_department_id" = ws."department_id", "assigned_role" = NULL
FROM "workflow_steps" ws
WHERE ws."id" = ai."workflow_step_id" AND ws."department_id" IS NOT NULL;
