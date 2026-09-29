ALTER TYPE "public"."item_kind" ADD VALUE 'stand_design';--> statement-breakpoint
ALTER TYPE "public"."item_kind" ADD VALUE 'stand_panel';--> statement-breakpoint
ALTER TABLE "workflows" ADD COLUMN "for_kind" text;--> statement-breakpoint
ALTER TABLE "signage_items" ADD COLUMN "parent_item_id" uuid;--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_parent_item_id_signage_items_id_fk" FOREIGN KEY ("parent_item_id") REFERENCES "public"."signage_items"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "signage_items_parent_idx" ON "signage_items" USING btree ("parent_item_id");