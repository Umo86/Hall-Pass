ALTER TYPE "public"."reminder_kind" ADD VALUE IF NOT EXISTS 'print_due';--> statement-breakpoint
ALTER TYPE "public"."reminder_kind" ADD VALUE IF NOT EXISTS 'delivery_due';--> statement-breakpoint
ALTER TYPE "public"."reminder_kind" ADD VALUE IF NOT EXISTS 'install_due';--> statement-breakpoint
ALTER TYPE "public"."reminder_kind" ADD VALUE IF NOT EXISTS 'order_by_due';--> statement-breakpoint
ALTER TABLE "approval_instances" ADD COLUMN IF NOT EXISTS "confirmed_on" date;--> statement-breakpoint
ALTER TABLE "signage_items" ADD COLUMN IF NOT EXISTS "sent_to_print_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "signage_items" ADD COLUMN IF NOT EXISTS "delivered_at" timestamp with time zone;