ALTER TYPE "public"."task_status" ADD VALUE 'in_progress' BEFORE 'done';--> statement-breakpoint
CREATE TABLE "task_attachments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"task_id" uuid NOT NULL,
	"file_path" text NOT NULL,
	"file_name" text NOT NULL,
	"mime_type" text NOT NULL,
	"file_size" integer NOT NULL,
	"uploaded_by" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "tasks" ADD COLUMN "parent_task_id" uuid;--> statement-breakpoint
ALTER TABLE "task_attachments" ADD CONSTRAINT "task_attachments_task_id_tasks_id_fk" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "task_attachments" ADD CONSTRAINT "task_attachments_uploaded_by_users_id_fk" FOREIGN KEY ("uploaded_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "task_attachments_task_idx" ON "task_attachments" USING btree ("task_id");--> statement-breakpoint
CREATE INDEX "task_attachments_uploaded_by_idx" ON "task_attachments" USING btree ("uploaded_by");--> statement-breakpoint
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_parent_task_id_tasks_id_fk" FOREIGN KEY ("parent_task_id") REFERENCES "public"."tasks"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "tasks_parent_idx" ON "tasks" USING btree ("parent_task_id");
--> statement-breakpoint
ALTER TABLE "task_attachments" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TRIGGER task_attachments_set_updated_at BEFORE UPDATE ON "task_attachments" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
