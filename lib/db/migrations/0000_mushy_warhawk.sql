CREATE TYPE "public"."actor_type" AS ENUM('user', 'system', 'cron');--> statement-breakpoint
CREATE TYPE "public"."approval_entity_type" AS ENUM('signage_item', 'stand_submission');--> statement-breakpoint
CREATE TYPE "public"."approver_type" AS ENUM('role', 'user');--> statement-breakpoint
CREATE TYPE "public"."audit_action" AS ENUM('create', 'update', 'soft_delete', 'restore', 'status_change', 'submit', 'decide', 'delegate', 'escalate', 'upload', 'download', 'export', 'import', 'login', 'invite', 'grant_revoke', 'settings_change');--> statement-breakpoint
CREATE TYPE "public"."change_request_status" AS ENUM('open', 'approved', 'rejected', 'applied');--> statement-breakpoint
CREATE TYPE "public"."deadline_key" AS ENUM('artwork_due', 'venue_rigging_submission', 'print_deadline', 'delivery', 'stand_design_due', 'insurance_due');--> statement-breakpoint
CREATE TYPE "public"."doc_type" AS ENUM('plan', 'elevation', 'structural_calcs', 'rams', 'insurance_pl', 'fire_cert', 'electrical_cert', 'rigging_plan', 'spec_sheet', 'quote', 'po', 'other');--> statement-breakpoint
CREATE TYPE "public"."document_status" AS ENUM('received', 'accepted', 'rejected');--> statement-breakpoint
CREATE TYPE "public"."edition_status" AS ENUM('planning', 'live', 'closed', 'archived');--> statement-breakpoint
CREATE TYPE "public"."email_status" AS ENUM('sent', 'failed');--> statement-breakpoint
CREATE TYPE "public"."entity_type" AS ENUM('signage_item', 'stand_submission', 'exhibitor', 'contractor', 'supplier', 'edition');--> statement-breakpoint
CREATE TYPE "public"."external_role" AS ENUM('venue', 'structural_engineer', 'hs', 'supplier', 'exhibitor', 'contractor', 'sponsor');--> statement-breakpoint
CREATE TYPE "public"."fixing_method" AS ENUM('rigged', 'freestanding', 'wall_mounted', 'shell_mounted', 'floor', 'digital', 'other');--> statement-breakpoint
CREATE TYPE "public"."install_slot" AS ENUM('am', 'pm', 'overnight');--> statement-breakpoint
CREATE TYPE "public"."instance_status" AS ENUM('waiting', 'pending', 'approved', 'approved_with_conditions', 'changes_requested', 'rejected', 'confirmed', 'skipped', 'invalidated');--> statement-breakpoint
CREATE TYPE "public"."owner_role" AS ENUM('ops', 'marketing');--> statement-breakpoint
CREATE TYPE "public"."proof_status" AS ENUM('draft', 'proof', 'final');--> statement-breakpoint
CREATE TYPE "public"."reminder_kind" AS ENUM('minus7', 'minus2', 'due', 'overdue', 'escalation', 'chaser', 'expiry');--> statement-breakpoint
CREATE TYPE "public"."reminder_target_type" AS ENUM('approval_instance', 'signage_item', 'exhibitor', 'document');--> statement-breakpoint
CREATE TYPE "public"."scope_type" AS ENUM('venue', 'supplier', 'exhibitor', 'sponsor');--> statement-breakpoint
CREATE TYPE "public"."sided" AS ENUM('single', 'double');--> statement-breakpoint
CREATE TYPE "public"."signage_status" AS ENUM('draft', 'awaiting_artwork', 'in_review', 'changes_requested', 'approved', 'approved_with_conditions', 'in_production', 'delivered', 'installed', 'snagged', 'closed', 'rejected', 'on_hold');--> statement-breakpoint
CREATE TYPE "public"."snag_severity" AS ENUM('low', 'medium', 'high');--> statement-breakpoint
CREATE TYPE "public"."snag_status" AS ENUM('open', 'in_progress', 'resolved', 'wont_fix');--> statement-breakpoint
CREATE TYPE "public"."staff_role" AS ENUM('admin', 'ops', 'marketing', 'sales', 'event_director', 'viewer');--> statement-breakpoint
CREATE TYPE "public"."stand_outcome" AS ENUM('approved', 'approved_with_conditions', 'rejected');--> statement-breakpoint
CREATE TYPE "public"."stand_status" AS ENUM('not_submitted', 'submitted', 'in_review', 'changes_requested', 'approved', 'approved_with_conditions', 'rejected', 'build_checked', 'closed', 'on_hold');--> statement-breakpoint
CREATE TYPE "public"."stand_type" AS ENUM('space_only', 'shell', 'custom_shell');--> statement-breakpoint
CREATE TYPE "public"."step_kind" AS ENUM('approval', 'confirmation');--> statement-breakpoint
CREATE TYPE "public"."supplier_kind" AS ENUM('print', 'rigging', 'av', 'contractor', 'structural_engineer', 'other');--> statement-breakpoint
CREATE TYPE "public"."workflow_applies_to" AS ENUM('signage', 'stand');--> statement-breakpoint
CREATE TABLE "external_grants" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid,
	"invited_email" text NOT NULL,
	"organisation_id" uuid NOT NULL,
	"edition_id" uuid NOT NULL,
	"role" "external_role" NOT NULL,
	"scope_type" "scope_type",
	"scope_id" uuid,
	"expires_at" timestamp with time zone,
	"invited_by" uuid,
	"invite_token_hash" text NOT NULL,
	"accepted_at" timestamp with time zone,
	"revoked_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "memberships" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"organisation_id" uuid NOT NULL,
	"role" "staff_role" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "memberships_user_org_unique" UNIQUE("user_id","organisation_id")
);
--> statement-breakpoint
CREATE TABLE "organisations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"slug" text NOT NULL,
	"brand_name" text DEFAULT 'Hall Pass' NOT NULL,
	"logo_path" text,
	"settings" jsonb DEFAULT '{"escalate_after_days":2,"install_photo_required":true,"cost_threshold_for_director":5000,"currency":"GBP"}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "organisations_slug_unique" UNIQUE("slug")
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY NOT NULL,
	"email" text NOT NULL,
	"full_name" text DEFAULT '' NOT NULL,
	"phone" text,
	"avatar_path" text,
	"is_external" boolean DEFAULT false NOT NULL,
	"notification_prefs" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"last_seen_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "users_email_unique" UNIQUE("email")
);
--> statement-breakpoint
CREATE TABLE "edition_counters" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"edition_id" uuid NOT NULL,
	"key" text NOT NULL,
	"value" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "edition_counters_edition_key_unique" UNIQUE("edition_id","key")
);
--> statement-breakpoint
CREATE TABLE "edition_deadlines" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"edition_id" uuid NOT NULL,
	"key" "deadline_key" NOT NULL,
	"label" text NOT NULL,
	"days_before_build_start" integer NOT NULL,
	"override_date" date,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "edition_deadlines_edition_key_unique" UNIQUE("edition_id","key")
);
--> statement-breakpoint
CREATE TABLE "editions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"event_id" uuid NOT NULL,
	"venue_id" uuid NOT NULL,
	"name" text NOT NULL,
	"code" text NOT NULL,
	"build_start" date NOT NULL,
	"build_end" date NOT NULL,
	"open_start" date NOT NULL,
	"open_end" date NOT NULL,
	"breakdown_end" date NOT NULL,
	"status" "edition_status" DEFAULT 'planning' NOT NULL,
	"cloned_from_edition_id" uuid,
	"signage_budget" numeric(12, 2),
	"stand_required_doc_types" text[] DEFAULT '{"plan","elevation","rams","insurance_pl"}' NOT NULL,
	"complex_structure_triggers" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organisation_id" uuid NOT NULL,
	"name" text NOT NULL,
	"code" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "events_org_code_unique" UNIQUE("organisation_id","code")
);
--> statement-breakpoint
CREATE TABLE "venue_rules" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"venue_id" uuid NOT NULL,
	"category" text NOT NULL,
	"title" text NOT NULL,
	"rule_text" text NOT NULL,
	"applies_to" text NOT NULL,
	"is_checklist_item" boolean DEFAULT false NOT NULL,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "venues" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organisation_id" uuid NOT NULL,
	"name" text NOT NULL,
	"code" text NOT NULL,
	"address" text,
	"rigging_contact_name" text,
	"rigging_contact_email" text,
	"requires_stand_approval" boolean DEFAULT false NOT NULL,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "venues_org_code_unique" UNIQUE("organisation_id","code")
);
--> statement-breakpoint
CREATE TABLE "halls" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"edition_id" uuid NOT NULL,
	"name" text NOT NULL,
	"floorplan_path" text,
	"floorplan_width_px" integer,
	"floorplan_height_px" integer,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "locations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"hall_id" uuid NOT NULL,
	"name" text NOT NULL,
	"zone" text,
	"x_pct" numeric(6, 5),
	"y_pct" numeric(6, 5),
	"near_stand_number" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "contractors" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organisation_id" uuid NOT NULL,
	"name" text NOT NULL,
	"contact_name" text,
	"email" text,
	"phone" text,
	"insurance_expiry" date,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "exhibitors" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"edition_id" uuid NOT NULL,
	"company_name" text NOT NULL,
	"stand_number" text NOT NULL,
	"hall_id" uuid,
	"stand_size_sqm" numeric(8, 2),
	"stand_type" "stand_type" DEFAULT 'space_only' NOT NULL,
	"contact_name" text,
	"contact_email" text,
	"contractor_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "exhibitors_edition_stand_unique" UNIQUE("edition_id","stand_number")
);
--> statement-breakpoint
CREATE TABLE "sponsor_entitlements" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"sponsor_id" uuid NOT NULL,
	"description" text NOT NULL,
	"quantity" integer DEFAULT 1 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "sponsors" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"edition_id" uuid NOT NULL,
	"company_name" text NOT NULL,
	"contact_name" text,
	"contact_email" text,
	"package_name" text,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "suppliers" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organisation_id" uuid NOT NULL,
	"name" text NOT NULL,
	"kind" "supplier_kind" NOT NULL,
	"contact_name" text,
	"email" text,
	"phone" text,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "approval_instances" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"entity_type" "approval_entity_type" NOT NULL,
	"entity_id" uuid NOT NULL,
	"run_number" integer NOT NULL,
	"workflow_step_id" uuid NOT NULL,
	"step_name_snapshot" text NOT NULL,
	"step_kind_snapshot" "step_kind" NOT NULL,
	"sort_order_snapshot" integer NOT NULL,
	"parallel_group_snapshot" integer,
	"status" "instance_status" DEFAULT 'waiting' NOT NULL,
	"assigned_role" text,
	"assigned_user_id" uuid,
	"delegated_from_user_id" uuid,
	"decided_by" uuid,
	"decided_at" timestamp with time zone,
	"decision_comment" text,
	"conditions_text" text,
	"locked_version_type" text,
	"locked_version_id" text,
	"locked_sha256" text,
	"pending_since" timestamp with time zone,
	"due_at" timestamp with time zone,
	"hold_shift_days" integer DEFAULT 0 NOT NULL,
	"escalated_at" timestamp with time zone,
	"escalated_to" uuid[],
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "reminder_log" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"target_type" "reminder_target_type" NOT NULL,
	"target_id" uuid NOT NULL,
	"kind" "reminder_kind" NOT NULL,
	"sent_on" date NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "reminder_log_unique_send" UNIQUE("target_type","target_id","kind","sent_on")
);
--> statement-breakpoint
CREATE TABLE "workflow_steps" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"workflow_id" uuid NOT NULL,
	"sort_order" integer NOT NULL,
	"parallel_group" integer,
	"name" text NOT NULL,
	"kind" "step_kind" NOT NULL,
	"approver_type" "approver_type" NOT NULL,
	"approver_role" text,
	"approver_user_id" uuid,
	"conditions" text[] DEFAULT '{"always"}' NOT NULL,
	"sla_days" integer DEFAULT 0 NOT NULL,
	"invalidate_on_new_version" boolean DEFAULT true NOT NULL,
	"restart_from_here_on_changes" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "workflows" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organisation_id" uuid NOT NULL,
	"name" text NOT NULL,
	"applies_to" "workflow_applies_to" NOT NULL,
	"is_default" boolean DEFAULT false NOT NULL,
	"is_archived" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "artwork_annotations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"artwork_version_id" uuid NOT NULL,
	"page" integer DEFAULT 1 NOT NULL,
	"x_pct" numeric(6, 5) NOT NULL,
	"y_pct" numeric(6, 5) NOT NULL,
	"comment_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "artwork_versions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"signage_item_id" uuid NOT NULL,
	"version_number" integer NOT NULL,
	"file_path" text NOT NULL,
	"file_name" text NOT NULL,
	"mime_type" text NOT NULL,
	"file_size" integer NOT NULL,
	"sha256" text NOT NULL,
	"page_count" integer,
	"preview_path" text,
	"uploaded_by" uuid,
	"proof_status" "proof_status" DEFAULT 'draft' NOT NULL,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "artwork_versions_item_version_unique" UNIQUE("signage_item_id","version_number")
);
--> statement-breakpoint
CREATE TABLE "item_types" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organisation_id" uuid NOT NULL,
	"name" text NOT NULL,
	"code" text NOT NULL,
	"default_workflow_id" uuid,
	"default_fixing_method" "fixing_method",
	"requires_venue_approval_default" boolean DEFAULT false NOT NULL,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "item_types_org_code_unique" UNIQUE("organisation_id","code")
);
--> statement-breakpoint
CREATE TABLE "signage_items" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"edition_id" uuid NOT NULL,
	"ref" text NOT NULL,
	"seq" integer NOT NULL,
	"name" text NOT NULL,
	"description" text,
	"item_type_id" uuid,
	"hall_id" uuid,
	"location_id" uuid,
	"owner_role" "owner_role" DEFAULT 'ops' NOT NULL,
	"owner_user_id" uuid,
	"sponsor_id" uuid,
	"sponsor_entitlement_id" uuid,
	"is_sponsor_deliverable" boolean DEFAULT false NOT NULL,
	"width_mm" integer,
	"height_mm" integer,
	"depth_mm" integer,
	"quantity" integer DEFAULT 1 NOT NULL,
	"sided" "sided" DEFAULT 'single' NOT NULL,
	"material" text,
	"finish" text,
	"fixing_method" "fixing_method",
	"weight_kg" numeric(8, 2),
	"requires_venue_approval" boolean DEFAULT false NOT NULL,
	"requires_event_director" boolean DEFAULT false NOT NULL,
	"budget_line" text,
	"cost_estimate" numeric(12, 2),
	"cost_actual" numeric(12, 2),
	"po_number" text,
	"supplier_id" uuid,
	"artwork_due_override" date,
	"print_deadline" date,
	"delivery_date" date,
	"install_date" date,
	"install_slot" "install_slot",
	"install_contractor_id" uuid,
	"status" "signage_status" DEFAULT 'draft' NOT NULL,
	"previous_status" "signage_status",
	"on_hold_reason" text,
	"workflow_id" uuid,
	"current_run_number" integer DEFAULT 0 NOT NULL,
	"current_artwork_version_id" uuid,
	"installed_at" timestamp with time zone,
	"installed_by" uuid,
	"install_photo_path" text,
	"created_by" uuid,
	"deleted_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "signage_items_ref_unique" UNIQUE("ref"),
	CONSTRAINT "signage_items_edition_seq_unique" UNIQUE("edition_id","seq")
);
--> statement-breakpoint
CREATE TABLE "stand_submissions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"edition_id" uuid NOT NULL,
	"exhibitor_id" uuid NOT NULL,
	"ref" text NOT NULL,
	"contractor_id" uuid,
	"submission_version" integer DEFAULT 1 NOT NULL,
	"max_height_mm" integer,
	"is_double_deck" boolean DEFAULT false NOT NULL,
	"has_platform_over_600mm" boolean DEFAULT false NOT NULL,
	"has_ramped_raised_floor" boolean DEFAULT false NOT NULL,
	"has_rigging" boolean DEFAULT false NOT NULL,
	"has_ceiling_or_roof" boolean DEFAULT false NOT NULL,
	"has_tiered_seating" boolean DEFAULT false NOT NULL,
	"other_complex_notes" text,
	"is_complex" boolean DEFAULT false NOT NULL,
	"status" "stand_status" DEFAULT 'not_submitted' NOT NULL,
	"previous_status" "stand_status",
	"on_hold_reason" text,
	"outcome" "stand_outcome",
	"conditions_text" text,
	"submitted_at" timestamp with time zone,
	"submitted_by" uuid,
	"rules_checklist" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"build_check_done_at" timestamp with time zone,
	"build_check_by" uuid,
	"build_check_notes" text,
	"build_check_photo_path" text,
	"workflow_id" uuid,
	"current_run_number" integer DEFAULT 0 NOT NULL,
	"created_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "stand_submissions_ref_unique" UNIQUE("ref"),
	CONSTRAINT "stand_submissions_exhibitor_unique" UNIQUE("exhibitor_id")
);
--> statement-breakpoint
CREATE TABLE "documents" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organisation_id" uuid NOT NULL,
	"edition_id" uuid,
	"entity_type" "entity_type" NOT NULL,
	"entity_id" uuid NOT NULL,
	"doc_type" "doc_type" NOT NULL,
	"file_path" text NOT NULL,
	"file_name" text NOT NULL,
	"mime_type" text NOT NULL,
	"file_size" integer NOT NULL,
	"sha256" text NOT NULL,
	"submission_version" integer,
	"expires_at" date,
	"uploaded_by" uuid,
	"is_external_upload" boolean DEFAULT false NOT NULL,
	"status" "document_status" DEFAULT 'received' NOT NULL,
	"review_note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "change_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"entity_type" "entity_type" NOT NULL,
	"entity_id" uuid NOT NULL,
	"requested_by" uuid NOT NULL,
	"reason" text NOT NULL,
	"field_changes" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"status" "change_request_status" DEFAULT 'open' NOT NULL,
	"decided_by" uuid,
	"decided_at" timestamp with time zone,
	"reopened_instance_ids" uuid[],
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "comment_attachments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"comment_id" uuid NOT NULL,
	"document_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "comments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"entity_type" "entity_type" NOT NULL,
	"entity_id" uuid NOT NULL,
	"parent_id" uuid,
	"author_id" uuid NOT NULL,
	"body" text NOT NULL,
	"mention_user_ids" uuid[] DEFAULT '{}' NOT NULL,
	"is_internal" boolean DEFAULT true NOT NULL,
	"edited_at" timestamp with time zone,
	"deleted_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "email_log" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"to_email" text NOT NULL,
	"template" text NOT NULL,
	"entity_type" text,
	"entity_id" uuid,
	"provider_message_id" text,
	"status" "email_status" NOT NULL,
	"error" text,
	"attempts" integer DEFAULT 1 NOT NULL,
	"sent_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "exports" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"edition_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"filters" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"file_path" text NOT NULL,
	"generated_by" uuid,
	"expires_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "notifications" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"entity_type" "entity_type",
	"entity_id" uuid,
	"title" text NOT NULL,
	"body" text,
	"link" text,
	"read_at" timestamp with time zone,
	"emailed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "snags" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"edition_id" uuid NOT NULL,
	"signage_item_id" uuid,
	"stand_submission_id" uuid,
	"description" text NOT NULL,
	"photo_path" text,
	"severity" "snag_severity" DEFAULT 'medium' NOT NULL,
	"assigned_user_id" uuid,
	"assigned_supplier_id" uuid,
	"assigned_contractor_id" uuid,
	"status" "snag_status" DEFAULT 'open' NOT NULL,
	"resolved_at" timestamp with time zone,
	"resolved_by" uuid,
	"resolution_note" text,
	"resolution_photo_path" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "audit_log" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organisation_id" uuid,
	"edition_id" uuid,
	"actor_user_id" uuid,
	"actor_type" "actor_type" DEFAULT 'user' NOT NULL,
	"entity_type" text NOT NULL,
	"entity_id" uuid,
	"action" "audit_action" NOT NULL,
	"before" jsonb,
	"after" jsonb,
	"summary" text NOT NULL,
	"ip" text,
	"user_agent" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "external_grants" ADD CONSTRAINT "external_grants_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "external_grants" ADD CONSTRAINT "external_grants_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "external_grants" ADD CONSTRAINT "external_grants_invited_by_users_id_fk" FOREIGN KEY ("invited_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "edition_counters" ADD CONSTRAINT "edition_counters_edition_id_editions_id_fk" FOREIGN KEY ("edition_id") REFERENCES "public"."editions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "edition_deadlines" ADD CONSTRAINT "edition_deadlines_edition_id_editions_id_fk" FOREIGN KEY ("edition_id") REFERENCES "public"."editions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "editions" ADD CONSTRAINT "editions_event_id_events_id_fk" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "editions" ADD CONSTRAINT "editions_venue_id_venues_id_fk" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "events" ADD CONSTRAINT "events_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "venue_rules" ADD CONSTRAINT "venue_rules_venue_id_venues_id_fk" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "venues" ADD CONSTRAINT "venues_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "halls" ADD CONSTRAINT "halls_edition_id_editions_id_fk" FOREIGN KEY ("edition_id") REFERENCES "public"."editions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "locations" ADD CONSTRAINT "locations_hall_id_halls_id_fk" FOREIGN KEY ("hall_id") REFERENCES "public"."halls"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "contractors" ADD CONSTRAINT "contractors_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exhibitors" ADD CONSTRAINT "exhibitors_edition_id_editions_id_fk" FOREIGN KEY ("edition_id") REFERENCES "public"."editions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exhibitors" ADD CONSTRAINT "exhibitors_hall_id_halls_id_fk" FOREIGN KEY ("hall_id") REFERENCES "public"."halls"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exhibitors" ADD CONSTRAINT "exhibitors_contractor_id_contractors_id_fk" FOREIGN KEY ("contractor_id") REFERENCES "public"."contractors"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sponsor_entitlements" ADD CONSTRAINT "sponsor_entitlements_sponsor_id_sponsors_id_fk" FOREIGN KEY ("sponsor_id") REFERENCES "public"."sponsors"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sponsors" ADD CONSTRAINT "sponsors_edition_id_editions_id_fk" FOREIGN KEY ("edition_id") REFERENCES "public"."editions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "suppliers" ADD CONSTRAINT "suppliers_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "approval_instances" ADD CONSTRAINT "approval_instances_workflow_step_id_workflow_steps_id_fk" FOREIGN KEY ("workflow_step_id") REFERENCES "public"."workflow_steps"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "approval_instances" ADD CONSTRAINT "approval_instances_assigned_user_id_users_id_fk" FOREIGN KEY ("assigned_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "approval_instances" ADD CONSTRAINT "approval_instances_delegated_from_user_id_users_id_fk" FOREIGN KEY ("delegated_from_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "approval_instances" ADD CONSTRAINT "approval_instances_decided_by_users_id_fk" FOREIGN KEY ("decided_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workflow_steps" ADD CONSTRAINT "workflow_steps_workflow_id_workflows_id_fk" FOREIGN KEY ("workflow_id") REFERENCES "public"."workflows"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workflow_steps" ADD CONSTRAINT "workflow_steps_approver_user_id_users_id_fk" FOREIGN KEY ("approver_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workflows" ADD CONSTRAINT "workflows_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "artwork_annotations" ADD CONSTRAINT "artwork_annotations_artwork_version_id_artwork_versions_id_fk" FOREIGN KEY ("artwork_version_id") REFERENCES "public"."artwork_versions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "artwork_versions" ADD CONSTRAINT "artwork_versions_signage_item_id_signage_items_id_fk" FOREIGN KEY ("signage_item_id") REFERENCES "public"."signage_items"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "artwork_versions" ADD CONSTRAINT "artwork_versions_uploaded_by_users_id_fk" FOREIGN KEY ("uploaded_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "item_types" ADD CONSTRAINT "item_types_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "item_types" ADD CONSTRAINT "item_types_default_workflow_id_workflows_id_fk" FOREIGN KEY ("default_workflow_id") REFERENCES "public"."workflows"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_edition_id_editions_id_fk" FOREIGN KEY ("edition_id") REFERENCES "public"."editions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_item_type_id_item_types_id_fk" FOREIGN KEY ("item_type_id") REFERENCES "public"."item_types"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_hall_id_halls_id_fk" FOREIGN KEY ("hall_id") REFERENCES "public"."halls"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_location_id_locations_id_fk" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_owner_user_id_users_id_fk" FOREIGN KEY ("owner_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_sponsor_id_sponsors_id_fk" FOREIGN KEY ("sponsor_id") REFERENCES "public"."sponsors"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_sponsor_entitlement_id_sponsor_entitlements_id_fk" FOREIGN KEY ("sponsor_entitlement_id") REFERENCES "public"."sponsor_entitlements"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_supplier_id_suppliers_id_fk" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_install_contractor_id_contractors_id_fk" FOREIGN KEY ("install_contractor_id") REFERENCES "public"."contractors"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_workflow_id_workflows_id_fk" FOREIGN KEY ("workflow_id") REFERENCES "public"."workflows"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_installed_by_users_id_fk" FOREIGN KEY ("installed_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "stand_submissions" ADD CONSTRAINT "stand_submissions_edition_id_editions_id_fk" FOREIGN KEY ("edition_id") REFERENCES "public"."editions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "stand_submissions" ADD CONSTRAINT "stand_submissions_exhibitor_id_exhibitors_id_fk" FOREIGN KEY ("exhibitor_id") REFERENCES "public"."exhibitors"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "stand_submissions" ADD CONSTRAINT "stand_submissions_contractor_id_contractors_id_fk" FOREIGN KEY ("contractor_id") REFERENCES "public"."contractors"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "stand_submissions" ADD CONSTRAINT "stand_submissions_submitted_by_users_id_fk" FOREIGN KEY ("submitted_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "stand_submissions" ADD CONSTRAINT "stand_submissions_build_check_by_users_id_fk" FOREIGN KEY ("build_check_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "stand_submissions" ADD CONSTRAINT "stand_submissions_workflow_id_workflows_id_fk" FOREIGN KEY ("workflow_id") REFERENCES "public"."workflows"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "stand_submissions" ADD CONSTRAINT "stand_submissions_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "documents" ADD CONSTRAINT "documents_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "documents" ADD CONSTRAINT "documents_edition_id_editions_id_fk" FOREIGN KEY ("edition_id") REFERENCES "public"."editions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "documents" ADD CONSTRAINT "documents_uploaded_by_users_id_fk" FOREIGN KEY ("uploaded_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "change_requests" ADD CONSTRAINT "change_requests_requested_by_users_id_fk" FOREIGN KEY ("requested_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "change_requests" ADD CONSTRAINT "change_requests_decided_by_users_id_fk" FOREIGN KEY ("decided_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "comment_attachments" ADD CONSTRAINT "comment_attachments_comment_id_comments_id_fk" FOREIGN KEY ("comment_id") REFERENCES "public"."comments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "comment_attachments" ADD CONSTRAINT "comment_attachments_document_id_documents_id_fk" FOREIGN KEY ("document_id") REFERENCES "public"."documents"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "comments" ADD CONSTRAINT "comments_author_id_users_id_fk" FOREIGN KEY ("author_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exports" ADD CONSTRAINT "exports_edition_id_editions_id_fk" FOREIGN KEY ("edition_id") REFERENCES "public"."editions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exports" ADD CONSTRAINT "exports_generated_by_users_id_fk" FOREIGN KEY ("generated_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "snags" ADD CONSTRAINT "snags_edition_id_editions_id_fk" FOREIGN KEY ("edition_id") REFERENCES "public"."editions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "snags" ADD CONSTRAINT "snags_signage_item_id_signage_items_id_fk" FOREIGN KEY ("signage_item_id") REFERENCES "public"."signage_items"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "snags" ADD CONSTRAINT "snags_stand_submission_id_stand_submissions_id_fk" FOREIGN KEY ("stand_submission_id") REFERENCES "public"."stand_submissions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "snags" ADD CONSTRAINT "snags_assigned_user_id_users_id_fk" FOREIGN KEY ("assigned_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "snags" ADD CONSTRAINT "snags_assigned_supplier_id_suppliers_id_fk" FOREIGN KEY ("assigned_supplier_id") REFERENCES "public"."suppliers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "snags" ADD CONSTRAINT "snags_assigned_contractor_id_contractors_id_fk" FOREIGN KEY ("assigned_contractor_id") REFERENCES "public"."contractors"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "snags" ADD CONSTRAINT "snags_resolved_by_users_id_fk" FOREIGN KEY ("resolved_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "external_grants_user_idx" ON "external_grants" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "external_grants_org_idx" ON "external_grants" USING btree ("organisation_id");--> statement-breakpoint
CREATE INDEX "external_grants_edition_idx" ON "external_grants" USING btree ("edition_id");--> statement-breakpoint
CREATE INDEX "external_grants_invited_by_idx" ON "external_grants" USING btree ("invited_by");--> statement-breakpoint
CREATE INDEX "external_grants_token_idx" ON "external_grants" USING btree ("invite_token_hash");--> statement-breakpoint
CREATE INDEX "memberships_user_idx" ON "memberships" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "memberships_org_idx" ON "memberships" USING btree ("organisation_id");--> statement-breakpoint
CREATE INDEX "edition_counters_edition_idx" ON "edition_counters" USING btree ("edition_id");--> statement-breakpoint
CREATE INDEX "edition_deadlines_edition_idx" ON "edition_deadlines" USING btree ("edition_id");--> statement-breakpoint
CREATE INDEX "editions_event_idx" ON "editions" USING btree ("event_id");--> statement-breakpoint
CREATE INDEX "editions_venue_idx" ON "editions" USING btree ("venue_id");--> statement-breakpoint
CREATE INDEX "editions_cloned_from_idx" ON "editions" USING btree ("cloned_from_edition_id");--> statement-breakpoint
CREATE INDEX "events_org_idx" ON "events" USING btree ("organisation_id");--> statement-breakpoint
CREATE INDEX "venue_rules_venue_idx" ON "venue_rules" USING btree ("venue_id");--> statement-breakpoint
CREATE INDEX "venues_org_idx" ON "venues" USING btree ("organisation_id");--> statement-breakpoint
CREATE INDEX "halls_edition_idx" ON "halls" USING btree ("edition_id");--> statement-breakpoint
CREATE INDEX "locations_hall_idx" ON "locations" USING btree ("hall_id");--> statement-breakpoint
CREATE INDEX "contractors_org_idx" ON "contractors" USING btree ("organisation_id");--> statement-breakpoint
CREATE INDEX "exhibitors_edition_idx" ON "exhibitors" USING btree ("edition_id");--> statement-breakpoint
CREATE INDEX "exhibitors_hall_idx" ON "exhibitors" USING btree ("hall_id");--> statement-breakpoint
CREATE INDEX "exhibitors_contractor_idx" ON "exhibitors" USING btree ("contractor_id");--> statement-breakpoint
CREATE INDEX "sponsor_entitlements_sponsor_idx" ON "sponsor_entitlements" USING btree ("sponsor_id");--> statement-breakpoint
CREATE INDEX "sponsors_edition_idx" ON "sponsors" USING btree ("edition_id");--> statement-breakpoint
CREATE INDEX "suppliers_org_idx" ON "suppliers" USING btree ("organisation_id");--> statement-breakpoint
CREATE INDEX "approval_instances_entity_idx" ON "approval_instances" USING btree ("entity_type","entity_id","run_number");--> statement-breakpoint
CREATE INDEX "approval_instances_step_idx" ON "approval_instances" USING btree ("workflow_step_id");--> statement-breakpoint
CREATE INDEX "approval_instances_assigned_user_idx" ON "approval_instances" USING btree ("assigned_user_id");--> statement-breakpoint
CREATE INDEX "approval_instances_status_idx" ON "approval_instances" USING btree ("status");--> statement-breakpoint
CREATE INDEX "approval_instances_delegated_from_idx" ON "approval_instances" USING btree ("delegated_from_user_id");--> statement-breakpoint
CREATE INDEX "approval_instances_decided_by_idx" ON "approval_instances" USING btree ("decided_by");--> statement-breakpoint
CREATE INDEX "reminder_log_target_idx" ON "reminder_log" USING btree ("target_type","target_id");--> statement-breakpoint
CREATE INDEX "workflow_steps_workflow_idx" ON "workflow_steps" USING btree ("workflow_id");--> statement-breakpoint
CREATE INDEX "workflow_steps_approver_user_idx" ON "workflow_steps" USING btree ("approver_user_id");--> statement-breakpoint
CREATE INDEX "workflows_org_idx" ON "workflows" USING btree ("organisation_id");--> statement-breakpoint
CREATE INDEX "artwork_annotations_version_idx" ON "artwork_annotations" USING btree ("artwork_version_id");--> statement-breakpoint
CREATE INDEX "artwork_annotations_comment_idx" ON "artwork_annotations" USING btree ("comment_id");--> statement-breakpoint
CREATE INDEX "artwork_versions_item_idx" ON "artwork_versions" USING btree ("signage_item_id");--> statement-breakpoint
CREATE INDEX "artwork_versions_uploaded_by_idx" ON "artwork_versions" USING btree ("uploaded_by");--> statement-breakpoint
CREATE INDEX "item_types_org_idx" ON "item_types" USING btree ("organisation_id");--> statement-breakpoint
CREATE INDEX "item_types_default_workflow_idx" ON "item_types" USING btree ("default_workflow_id");--> statement-breakpoint
CREATE INDEX "signage_items_edition_status_idx" ON "signage_items" USING btree ("edition_id","status");--> statement-breakpoint
CREATE INDEX "signage_items_edition_idx" ON "signage_items" USING btree ("edition_id");--> statement-breakpoint
CREATE INDEX "signage_items_item_type_idx" ON "signage_items" USING btree ("item_type_id");--> statement-breakpoint
CREATE INDEX "signage_items_hall_idx" ON "signage_items" USING btree ("hall_id");--> statement-breakpoint
CREATE INDEX "signage_items_location_idx" ON "signage_items" USING btree ("location_id");--> statement-breakpoint
CREATE INDEX "signage_items_owner_user_idx" ON "signage_items" USING btree ("owner_user_id");--> statement-breakpoint
CREATE INDEX "signage_items_sponsor_idx" ON "signage_items" USING btree ("sponsor_id");--> statement-breakpoint
CREATE INDEX "signage_items_sponsor_entitlement_idx" ON "signage_items" USING btree ("sponsor_entitlement_id");--> statement-breakpoint
CREATE INDEX "signage_items_supplier_idx" ON "signage_items" USING btree ("supplier_id");--> statement-breakpoint
CREATE INDEX "signage_items_install_contractor_idx" ON "signage_items" USING btree ("install_contractor_id");--> statement-breakpoint
CREATE INDEX "signage_items_workflow_idx" ON "signage_items" USING btree ("workflow_id");--> statement-breakpoint
CREATE INDEX "signage_items_installed_by_idx" ON "signage_items" USING btree ("installed_by");--> statement-breakpoint
CREATE INDEX "signage_items_created_by_idx" ON "signage_items" USING btree ("created_by");--> statement-breakpoint
CREATE INDEX "stand_submissions_edition_status_idx" ON "stand_submissions" USING btree ("edition_id","status");--> statement-breakpoint
CREATE INDEX "stand_submissions_edition_idx" ON "stand_submissions" USING btree ("edition_id");--> statement-breakpoint
CREATE INDEX "stand_submissions_contractor_idx" ON "stand_submissions" USING btree ("contractor_id");--> statement-breakpoint
CREATE INDEX "stand_submissions_submitted_by_idx" ON "stand_submissions" USING btree ("submitted_by");--> statement-breakpoint
CREATE INDEX "stand_submissions_build_check_by_idx" ON "stand_submissions" USING btree ("build_check_by");--> statement-breakpoint
CREATE INDEX "stand_submissions_workflow_idx" ON "stand_submissions" USING btree ("workflow_id");--> statement-breakpoint
CREATE INDEX "stand_submissions_created_by_idx" ON "stand_submissions" USING btree ("created_by");--> statement-breakpoint
CREATE INDEX "documents_org_idx" ON "documents" USING btree ("organisation_id");--> statement-breakpoint
CREATE INDEX "documents_edition_idx" ON "documents" USING btree ("edition_id");--> statement-breakpoint
CREATE INDEX "documents_entity_idx" ON "documents" USING btree ("entity_type","entity_id");--> statement-breakpoint
CREATE INDEX "documents_uploaded_by_idx" ON "documents" USING btree ("uploaded_by");--> statement-breakpoint
CREATE INDEX "change_requests_entity_idx" ON "change_requests" USING btree ("entity_type","entity_id");--> statement-breakpoint
CREATE INDEX "change_requests_requested_by_idx" ON "change_requests" USING btree ("requested_by");--> statement-breakpoint
CREATE INDEX "change_requests_decided_by_idx" ON "change_requests" USING btree ("decided_by");--> statement-breakpoint
CREATE INDEX "comment_attachments_comment_idx" ON "comment_attachments" USING btree ("comment_id");--> statement-breakpoint
CREATE INDEX "comment_attachments_document_idx" ON "comment_attachments" USING btree ("document_id");--> statement-breakpoint
CREATE INDEX "comments_entity_idx" ON "comments" USING btree ("entity_type","entity_id");--> statement-breakpoint
CREATE INDEX "comments_parent_idx" ON "comments" USING btree ("parent_id");--> statement-breakpoint
CREATE INDEX "comments_author_idx" ON "comments" USING btree ("author_id");--> statement-breakpoint
CREATE INDEX "email_log_entity_idx" ON "email_log" USING btree ("entity_type","entity_id");--> statement-breakpoint
CREATE INDEX "exports_edition_idx" ON "exports" USING btree ("edition_id");--> statement-breakpoint
CREATE INDEX "exports_generated_by_idx" ON "exports" USING btree ("generated_by");--> statement-breakpoint
CREATE INDEX "notifications_user_idx" ON "notifications" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "notifications_user_unread_idx" ON "notifications" USING btree ("user_id","read_at");--> statement-breakpoint
CREATE INDEX "snags_edition_idx" ON "snags" USING btree ("edition_id");--> statement-breakpoint
CREATE INDEX "snags_signage_item_idx" ON "snags" USING btree ("signage_item_id");--> statement-breakpoint
CREATE INDEX "snags_stand_submission_idx" ON "snags" USING btree ("stand_submission_id");--> statement-breakpoint
CREATE INDEX "snags_assigned_user_idx" ON "snags" USING btree ("assigned_user_id");--> statement-breakpoint
CREATE INDEX "snags_assigned_supplier_idx" ON "snags" USING btree ("assigned_supplier_id");--> statement-breakpoint
CREATE INDEX "snags_assigned_contractor_idx" ON "snags" USING btree ("assigned_contractor_id");--> statement-breakpoint
CREATE INDEX "snags_resolved_by_idx" ON "snags" USING btree ("resolved_by");--> statement-breakpoint
CREATE INDEX "audit_log_org_idx" ON "audit_log" USING btree ("organisation_id");--> statement-breakpoint
CREATE INDEX "audit_log_edition_idx" ON "audit_log" USING btree ("edition_id");--> statement-breakpoint
CREATE INDEX "audit_log_actor_idx" ON "audit_log" USING btree ("actor_user_id");--> statement-breakpoint
CREATE INDEX "audit_log_entity_idx" ON "audit_log" USING btree ("entity_type","entity_id");--> statement-breakpoint
CREATE INDEX "audit_log_created_at_idx" ON "audit_log" USING btree ("created_at");