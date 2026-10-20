-- Supabase Auth password carry-over, on its own (part 3 of migration
-- 0014_better_auth). Run it once against the Supabase database right after
-- the Better Auth release is live, to pick up any account Supabase Auth
-- created between applying 0014 and the deployment going live. It changes
-- nothing that is already there (ON CONFLICT DO NOTHING; email_verified is
-- only ever set to true), so running it more than once is safe. It does
-- nothing on a database without Supabase's auth schema.
--   psql "$DIRECT_DATABASE_URL" -f scripts/auth-carry-over.sql
-- or paste it into the Supabase SQL editor.

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
