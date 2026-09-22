CREATE TYPE "public"."item_kind" AS ENUM('signage', 'sponsorship_item');--> statement-breakpoint
CREATE TYPE "public"."signage_category" AS ENUM('directional', 'venue', 'sponsorship');--> statement-breakpoint
CREATE TYPE "public"."task_status" AS ENUM('open', 'done');--> statement-breakpoint
CREATE TABLE "staff_invites" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organisation_id" uuid NOT NULL,
	"invited_email" text NOT NULL,
	"role" "staff_role" NOT NULL,
	"permission_overrides" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"invited_by" uuid,
	"invite_token_hash" text NOT NULL,
	"accepted_at" timestamp with time zone,
	"revoked_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "tasks" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organisation_id" uuid NOT NULL,
	"edition_id" uuid,
	"title" text NOT NULL,
	"notes" text,
	"status" "task_status" DEFAULT 'open' NOT NULL,
	"due_date" date,
	"assigned_to_user_id" uuid NOT NULL,
	"created_by_user_id" uuid NOT NULL,
	"entity_type" "entity_type",
	"entity_id" uuid,
	"completed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "memberships" ADD COLUMN "permission_overrides" jsonb DEFAULT '{}'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "item_types" ADD COLUMN "kind" "item_kind" DEFAULT 'signage' NOT NULL;--> statement-breakpoint
ALTER TABLE "signage_items" ADD COLUMN "kind" "item_kind" DEFAULT 'signage' NOT NULL;--> statement-breakpoint
ALTER TABLE "signage_items" ADD COLUMN "category" "signage_category";--> statement-breakpoint
ALTER TABLE "staff_invites" ADD CONSTRAINT "staff_invites_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_invites" ADD CONSTRAINT "staff_invites_invited_by_users_id_fk" FOREIGN KEY ("invited_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_edition_id_editions_id_fk" FOREIGN KEY ("edition_id") REFERENCES "public"."editions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_assigned_to_user_id_users_id_fk" FOREIGN KEY ("assigned_to_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_created_by_user_id_users_id_fk" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "staff_invites_org_idx" ON "staff_invites" USING btree ("organisation_id");--> statement-breakpoint
CREATE INDEX "staff_invites_email_idx" ON "staff_invites" USING btree ("invited_email");--> statement-breakpoint
CREATE INDEX "staff_invites_invited_by_idx" ON "staff_invites" USING btree ("invited_by");--> statement-breakpoint
CREATE INDEX "staff_invites_token_idx" ON "staff_invites" USING btree ("invite_token_hash");--> statement-breakpoint
CREATE INDEX "tasks_assignee_status_idx" ON "tasks" USING btree ("assigned_to_user_id","status");--> statement-breakpoint
CREATE INDEX "tasks_org_idx" ON "tasks" USING btree ("organisation_id");--> statement-breakpoint
CREATE INDEX "tasks_edition_idx" ON "tasks" USING btree ("edition_id");--> statement-breakpoint
CREATE INDEX "tasks_created_by_idx" ON "tasks" USING btree ("created_by_user_id");--> statement-breakpoint
CREATE INDEX "signage_items_edition_kind_idx" ON "signage_items" USING btree ("edition_id","kind");--> statement-breakpoint
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_title_not_empty" CHECK (title <> '');--> statement-breakpoint
ALTER TABLE "tasks" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "staff_invites" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TRIGGER tasks_set_updated_at BEFORE UPDATE ON "tasks" FOR EACH ROW EXECUTE FUNCTION set_updated_at();--> statement-breakpoint
CREATE TRIGGER staff_invites_set_updated_at BEFORE UPDATE ON "staff_invites" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
