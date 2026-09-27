ALTER TABLE "signage_items" ADD COLUMN "stand_number" text;--> statement-breakpoint
-- Two more supplier types for every organisation, after the ones it has.
-- A name an admin already added is left as it is.
INSERT INTO "supplier_services" ("organisation_id", "name", "sort_order")
SELECT o."id", v."name",
       COALESCE((SELECT max(ss."sort_order") FROM "supplier_services" ss WHERE ss."organisation_id" = o."id"), 0) + v."n"
FROM "organisations" o
CROSS JOIN (VALUES ('Floor Manager', 1), ('Security', 2)) AS v("name", "n")
ON CONFLICT DO NOTHING;
