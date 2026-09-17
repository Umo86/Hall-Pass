ALTER TABLE "approval_instances" ADD COLUMN "invalidate_on_new_version_snapshot" boolean DEFAULT true NOT NULL;--> statement-breakpoint
ALTER TABLE "approval_instances" ADD COLUMN "restart_from_here_snapshot" boolean DEFAULT true NOT NULL;--> statement-breakpoint
ALTER TABLE "approval_instances" ADD COLUMN "sla_days_snapshot" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "approval_instances" ADD COLUMN "no_supplier_fallback" boolean DEFAULT false NOT NULL;