-- Cross-cycle foreign keys that drizzle-kit cannot express without circular imports
ALTER TABLE "external_grants" ADD CONSTRAINT "external_grants_edition_fk"
  FOREIGN KEY ("edition_id") REFERENCES "editions"("id");--> statement-breakpoint
ALTER TABLE "editions" ADD CONSTRAINT "editions_cloned_from_fk"
  FOREIGN KEY ("cloned_from_edition_id") REFERENCES "editions"("id");--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_current_artwork_version_fk"
  FOREIGN KEY ("current_artwork_version_id") REFERENCES "artwork_versions"("id");--> statement-breakpoint
ALTER TABLE "artwork_annotations" ADD CONSTRAINT "artwork_annotations_comment_fk"
  FOREIGN KEY ("comment_id") REFERENCES "comments"("id");--> statement-breakpoint
ALTER TABLE "comments" ADD CONSTRAINT "comments_parent_fk"
  FOREIGN KEY ("parent_id") REFERENCES "comments"("id");--> statement-breakpoint
CREATE INDEX "signage_items_current_artwork_version_idx" ON "signage_items" ("current_artwork_version_id");--> statement-breakpoint

-- Data integrity checks
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_quantity_positive" CHECK (quantity > 0);--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_width_positive" CHECK (width_mm IS NULL OR width_mm > 0);--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_height_positive" CHECK (height_mm IS NULL OR height_mm > 0);--> statement-breakpoint
ALTER TABLE "signage_items" ADD CONSTRAINT "signage_items_depth_positive" CHECK (depth_mm IS NULL OR depth_mm > 0);--> statement-breakpoint
ALTER TABLE "stand_submissions" ADD CONSTRAINT "stand_submissions_height_positive" CHECK (max_height_mm IS NULL OR max_height_mm > 0);--> statement-breakpoint
ALTER TABLE "artwork_versions" ADD CONSTRAINT "artwork_versions_version_positive" CHECK (version_number > 0);--> statement-breakpoint
ALTER TABLE "artwork_versions" ADD CONSTRAINT "artwork_versions_size_positive" CHECK (file_size >= 0);--> statement-breakpoint
ALTER TABLE "sponsor_entitlements" ADD CONSTRAINT "sponsor_entitlements_quantity_positive" CHECK (quantity > 0);--> statement-breakpoint

-- Audit log is append-only, enforced at the database level
CREATE OR REPLACE FUNCTION forbid_audit_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'audit_log is append-only: % is not permitted', TG_OP;
END;
$$ LANGUAGE plpgsql;--> statement-breakpoint
CREATE TRIGGER audit_log_append_only
  BEFORE UPDATE OR DELETE ON "audit_log"
  FOR EACH ROW EXECUTE FUNCTION forbid_audit_mutation();--> statement-breakpoint

-- updated_at maintenance
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;--> statement-breakpoint
DO $$
DECLARE t text;
BEGIN
  FOR t IN
    SELECT DISTINCT table_name FROM information_schema.columns
    WHERE table_schema = 'public' AND column_name = 'updated_at'
  LOOP
    EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at()',
      t || '_set_updated_at', t);
  END LOOP;
END $$;--> statement-breakpoint

-- Row Level Security: enabled on every table, deny by default. The app talks
-- to Postgres as the service role from the server only; anon/authenticated
-- get no policies, so every access is denied.
DO $$
DECLARE t text;
BEGIN
  FOR t IN
    SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT LIKE '__drizzle%'
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;--> statement-breakpoint

-- Revoke direct table access from client-facing roles if they exist
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated;
  END IF;
END $$;
