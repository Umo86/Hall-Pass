ALTER TABLE "signage_items" ADD COLUMN "order_by_date" date;--> statement-breakpoint
ALTER TABLE "signage_items" ADD COLUMN "photo_path" text;--> statement-breakpoint
ALTER TABLE "signage_items" ADD COLUMN "sale_price" numeric(12, 2);--> statement-breakpoint
ALTER TABLE "signage_items" ADD COLUMN "sold_at" timestamp with time zone;--> statement-breakpoint
-- Anything already bought by a sponsor counts as sold.
UPDATE "signage_items" SET "sold_at" = "created_at" WHERE "sponsor_id" IS NOT NULL;
