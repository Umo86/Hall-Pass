-- Sign-in moves from Supabase Auth to Better Auth, running inside the app
-- and storing everything in this database. Every statement is safe to run
-- twice; nothing is dropped or renamed.
-- (1) users is Better Auth's user table (same uuid ids): it gains
--     email_verified (every existing row came from an invitation link or the
--     seed, so existing rows are marked verified once, when the column is
--     added), a gen_random_uuid() default on id (Better Auth lets the
--     database make ids), and emails are stored lower-case (Better Auth
--     looks people up by the lower-cased email).
-- (2) Better Auth's own tables: auth_session, auth_account (passwords),
--     auth_verification (sign-in and reset tokens) and auth_rate_limit.
--     Deny-by-default like every other table; updated_at maintained.
-- (3) Carry-over, only where Supabase's auth schema exists: each Supabase
--     password (bcrypt) becomes the credential account of the users row with
--     the same id, so people keep their passwords. Re-running never
--     overwrites a password changed since.

-- (1) users -----------------------------------------------------------------
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'email_verified'
  ) THEN
    ALTER TABLE "users" ADD COLUMN "email_verified" boolean DEFAULT false NOT NULL;
    UPDATE "users" SET "email_verified" = true;
  END IF;
END $$;--> statement-breakpoint
ALTER TABLE "users" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();--> statement-breakpoint
UPDATE "users" u SET "email" = lower(btrim(u."email"))
WHERE u."email" <> lower(btrim(u."email"))
  AND NOT EXISTS (SELECT 1 FROM "users" o WHERE o."id" <> u."id" AND o."email" = lower(btrim(u."email")));--> statement-breakpoint

-- (2) Better Auth tables -----------------------------------------------------
CREATE TABLE IF NOT EXISTS "auth_session" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "token" text NOT NULL,
  "expires_at" timestamp with time zone NOT NULL,
  "ip_address" text,
  "user_agent" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT "auth_session_token_unique" UNIQUE("token")
);--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "auth_account" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "account_id" text NOT NULL,
  "provider_id" text NOT NULL,
  "access_token" text,
  "refresh_token" text,
  "id_token" text,
  "access_token_expires_at" timestamp with time zone,
  "refresh_token_expires_at" timestamp with time zone,
  "scope" text,
  "password" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "auth_verification" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "identifier" text NOT NULL,
  "value" text NOT NULL,
  "expires_at" timestamp with time zone NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "auth_rate_limit" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "key" text NOT NULL,
  "count" integer NOT NULL,
  "last_request" bigint NOT NULL,
  CONSTRAINT "auth_rate_limit_key_unique" UNIQUE("key")
);--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "auth_session" ADD CONSTRAINT "auth_session_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "auth_account" ADD CONSTRAINT "auth_account_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "auth_session_user_idx" ON "auth_session" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "auth_session_expires_idx" ON "auth_session" USING btree ("expires_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "auth_account_user_idx" ON "auth_account" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "auth_account_provider_account_unique" ON "auth_account" USING btree ("provider_id","account_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "auth_verification_identifier_idx" ON "auth_verification" USING btree ("identifier");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "auth_verification_expires_idx" ON "auth_verification" USING btree ("expires_at");--> statement-breakpoint
-- Deny-by-default, as every other table: RLS on with no policies, and no
-- direct privileges for client roles where they exist (Supabase's anon and
-- authenticated; Neon's Data API anonymous).
ALTER TABLE "auth_session" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "auth_account" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "auth_verification" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "auth_rate_limit" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['anon', 'authenticated', 'anonymous'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('REVOKE ALL ON "auth_session", "auth_account", "auth_verification", "auth_rate_limit" FROM %I', r);
    END IF;
  END LOOP;
END $$;--> statement-breakpoint
DO $$ BEGIN
  CREATE TRIGGER auth_session_set_updated_at BEFORE UPDATE ON "auth_session" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  CREATE TRIGGER auth_account_set_updated_at BEFORE UPDATE ON "auth_account" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint
DO $$ BEGIN
  CREATE TRIGGER auth_verification_set_updated_at BEFORE UPDATE ON "auth_verification" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;--> statement-breakpoint

-- (3) Carry-over from Supabase Auth (runs only on the Supabase database) ----
-- bcrypt hashes start "$2a$"/"$2b$"/"$2y$"; the pattern is built with chr(36)
-- ("$") so no "$2" appears in the SQL text. Matched by id only, never by
-- email: a users row with another id (the seeded demo accounts) never takes
-- a password from a Supabase sign-up. Confirmed Supabase emails are verified
-- ones. ON CONFLICT keeps a password set since the first run.
DO $$
BEGIN
  IF to_regclass('auth.users') IS NOT NULL THEN
    INSERT INTO "auth_account" ("user_id", "account_id", "provider_id", "password", "created_at", "updated_at")
    SELECT u."id", u."id"::text, 'credential', au."encrypted_password", coalesce(au."created_at", now()), now()
    FROM auth.users au
    JOIN "users" u ON u."id" = au."id"
    WHERE au."encrypted_password" LIKE chr(36) || '2_' || chr(36) || '%'
      AND au."deleted_at" IS NULL
    ON CONFLICT ("provider_id", "account_id") DO NOTHING;
    UPDATE "users" u SET "email_verified" = true
    FROM auth.users au
    WHERE au."id" = u."id" AND au."email_confirmed_at" IS NOT NULL AND NOT u."email_verified";
  END IF;
END $$;
