CREATE TYPE "public"."item_format" AS ENUM('print', 'digital');--> statement-breakpoint
CREATE TABLE "supplier_service_links" (
	"supplier_id" uuid NOT NULL,
	"service_id" uuid NOT NULL,
	CONSTRAINT "supplier_service_links_supplier_id_service_id_pk" PRIMARY KEY("supplier_id","service_id")
);
--> statement-breakpoint
CREATE TABLE "supplier_services" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organisation_id" uuid NOT NULL,
	"name" text NOT NULL,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"is_archived" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "supplier_services_org_name_unique" UNIQUE("organisation_id","name")
);
--> statement-breakpoint
ALTER TABLE "signage_items" ALTER COLUMN "category" SET DATA TYPE text;--> statement-breakpoint
-- Two categories now: organiser signage or sponsor signage.
UPDATE "signage_items" SET "category" = CASE
  WHEN "category" = 'sponsorship' OR "kind" = 'sponsorship_item' OR "sponsor_id" IS NOT NULL THEN 'sponsor'
  ELSE 'organiser'
END;--> statement-breakpoint
DROP TYPE "public"."signage_category";--> statement-breakpoint
CREATE TYPE "public"."signage_category" AS ENUM('organiser', 'sponsor');--> statement-breakpoint
ALTER TABLE "signage_items" ALTER COLUMN "category" SET DATA TYPE "public"."signage_category" USING "category"::"public"."signage_category";--> statement-breakpoint
ALTER TABLE "suppliers" ALTER COLUMN "kind" SET DEFAULT 'other';--> statement-breakpoint
ALTER TABLE "editions" ADD COLUMN "logo_path" text;--> statement-breakpoint
ALTER TABLE "workflow_steps" ADD COLUMN "default_for" text[] DEFAULT '{}' NOT NULL;--> statement-breakpoint
ALTER TABLE "workflow_steps" ADD COLUMN "is_archived" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "item_types" ADD COLUMN "format" "item_format";--> statement-breakpoint
ALTER TABLE "item_types" ADD COLUMN "is_archived" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "signage_items" ADD COLUMN "signoffs" jsonb;--> statement-breakpoint
ALTER TABLE "supplier_service_links" ADD CONSTRAINT "supplier_service_links_supplier_id_suppliers_id_fk" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "supplier_service_links" ADD CONSTRAINT "supplier_service_links_service_id_supplier_services_id_fk" FOREIGN KEY ("service_id") REFERENCES "public"."supplier_services"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "supplier_services" ADD CONSTRAINT "supplier_services_organisation_id_organisations_id_fk" FOREIGN KEY ("organisation_id") REFERENCES "public"."organisations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "supplier_service_links_service_idx" ON "supplier_service_links" USING btree ("service_id");--> statement-breakpoint
ALTER TABLE "supplier_services" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "supplier_service_links" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TRIGGER supplier_services_set_updated_at BEFORE UPDATE ON "supplier_services" FOR EACH ROW EXECUTE FUNCTION set_updated_at();--> statement-breakpoint
-- Signage types are print or digital.
UPDATE "item_types" SET "format" = CASE WHEN "code" = 'digital_screen' THEN 'digital'::"item_format" ELSE 'print'::"item_format" END
WHERE "kind" = 'signage';--> statement-breakpoint
-- Sign-off by department: Operations, Marketing and Sales in parallel, then
-- Senior management. Organiser signage gets all but Sales by default.
UPDATE "workflow_steps" ws SET
  "name" = 'Operations sign-off', "sort_order" = 1, "parallel_group" = 1,
  "conditions" = '{always}', "default_for" = '{organiser,sponsor}'
FROM "workflows" w
WHERE ws."workflow_id" = w."id" AND w."applies_to" = 'signage' AND ws."name" = 'Ops technical check';--> statement-breakpoint
UPDATE "workflow_steps" ws SET
  "name" = 'Marketing sign-off', "sort_order" = 2, "parallel_group" = 1,
  "conditions" = '{always}', "default_for" = '{organiser,sponsor}'
FROM "workflows" w
WHERE ws."workflow_id" = w."id" AND w."applies_to" = 'signage' AND ws."name" = 'Marketing brand check';--> statement-breakpoint
UPDATE "workflow_steps" ws SET
  "name" = 'Sales sign-off', "sort_order" = 3, "parallel_group" = 1,
  "conditions" = '{always}', "default_for" = '{sponsor}'
FROM "workflows" w
WHERE ws."workflow_id" = w."id" AND w."applies_to" = 'signage' AND ws."name" = 'Sponsor approval';--> statement-breakpoint
UPDATE "workflow_steps" ws SET
  "name" = 'Senior management sign-off',
  "conditions" = '{always}', "default_for" = '{organiser,sponsor}'
FROM "workflows" w
WHERE ws."workflow_id" = w."id" AND w."applies_to" = 'signage' AND ws."name" = 'Event Director sign-off';--> statement-breakpoint
-- Supplier services each organisation starts with; existing suppliers keep
-- what their old type said they do.
INSERT INTO "supplier_services" ("organisation_id", "name", "sort_order")
SELECT o."id", v."name", v."sort_order"
FROM "organisations" o
CROSS JOIN (VALUES
  ('Signage print', 1), ('Digital screens & AV', 2), ('Rigging', 3), ('Installation', 4),
  ('Staffing', 5), ('Furniture', 6), ('Structural engineering', 7)
) AS v("name", "sort_order")
ON CONFLICT DO NOTHING;--> statement-breakpoint
INSERT INTO "supplier_service_links" ("supplier_id", "service_id")
SELECT s."id", ss."id"
FROM "suppliers" s
JOIN "supplier_services" ss ON ss."organisation_id" = s."organisation_id" AND ss."name" = CASE s."kind"
  WHEN 'print' THEN 'Signage print'
  WHEN 'av' THEN 'Digital screens & AV'
  WHEN 'rigging' THEN 'Rigging'
  WHEN 'contractor' THEN 'Installation'
  WHEN 'structural_engineer' THEN 'Structural engineering'
END
ON CONFLICT DO NOTHING;--> statement-breakpoint
-- Department steps always record their department, even with a default person.
UPDATE "workflow_steps" SET "approver_role" = 'event_director'
WHERE "name" = 'Senior management sign-off' AND "approver_role" IS NULL;
--> statement-breakpoint
-- Sign-offs still in progress show the new department names; decided ones
-- keep the name they were decided under.
UPDATE "approval_instances" SET "step_name_snapshot" = CASE "step_name_snapshot"
  WHEN 'Ops technical check' THEN 'Operations sign-off'
  WHEN 'Marketing brand check' THEN 'Marketing sign-off'
  WHEN 'Sponsor approval' THEN 'Sales sign-off'
  WHEN 'Event Director sign-off' THEN 'Senior management sign-off'
END
WHERE "entity_type" = 'signage_item'
  AND "status" IN ('pending', 'waiting')
  AND "step_name_snapshot" IN ('Ops technical check', 'Marketing brand check', 'Sponsor approval', 'Event Director sign-off');
