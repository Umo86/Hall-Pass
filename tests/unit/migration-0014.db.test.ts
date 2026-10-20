/**
 * Migration 0014 (Better Auth) against a real database. The file is run on
 * a scratch database built from migrations 0000–0013 (so its DDL never locks
 * tables other test files are using), with a Supabase-shaped `auth.users`
 * beside data shaped like live, then run again: existing people are marked
 * verified and their emails lower-cased; each Supabase bcrypt password
 * becomes the credential account of the users row with the same id, never
 * an empty or deleted one, and never one matched only by email (a Supabase
 * sign-up can't take over a seeded demo account); a second run, and
 * scripts/auth-carry-over.sql, keep a password changed since; the new tables are
 * deny-by-default and owned like users. Then, in the shared test database,
 * a carried-over bcrypt password signs in through Better Auth and is
 * rehashed to scrypt.
 */
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { randomUUID } from "node:crypto";
import bcrypt from "bcryptjs";
import { eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) {
  vi.stubEnv("DATABASE_URL", url);
  vi.stubEnv("BETTER_AUTH_SECRET", "test-secret-0123456789-abcdefghijklmnopqrstuvwxyz");
  vi.stubEnv("NEXT_PUBLIC_APP_URL", "http://localhost:3901");
}

const FILE = readFileSync("lib/db/migrations/0014_better_auth.sql", "utf8");
const CARRY_OVER = readFileSync("scripts/auth-carry-over.sql", "utf8");
const PART_3 = "-- (3) Carry-over from Supabase Auth";
/** The file as psql would run it: drizzle's breakpoint markers stripped. */
const SQL_TEXT = FILE.replaceAll("--> statement-breakpoint", "");
const AUTH_TABLES = ["auth_session", "auth_account", "auth_verification", "auth_rate_limit"];

const n = Date.now() % 1_000_000;
const SCRATCH = `hp_m14_${process.pid}_${n}`;
let admin: ReturnType<typeof postgres>;
let scratch: ReturnType<typeof postgres>;
let migrationsDir: string;

const bcryptOf = (password: string, prefix: "$2a$" | "$2b$" = "$2a$") =>
  bcrypt.hashSync(password, 4).replace(/^\$2[aby]\$/, prefix);

d("migration 0014: sign-in on Better Auth", () => {
  beforeAll(async () => {
    admin = postgres(url!, { max: 1, prepare: false, onnotice: () => {} });
    await admin.unsafe(`CREATE DATABASE "${SCRATCH}"`);
    const scratchUrl = new URL(url!);
    scratchUrl.pathname = `/${SCRATCH}`;
    scratch = postgres(scratchUrl.toString(), { max: 1, prepare: false, onnotice: () => {} });
    // Migrations 0000–0013 only, through drizzle's own migrator.
    migrationsDir = mkdtempSync(path.join(tmpdir(), "hp-m14-"));
    cpSync("lib/db/migrations", migrationsDir, { recursive: true });
    rmSync(path.join(migrationsDir, "0014_better_auth.sql"));
    const journalPath = path.join(migrationsDir, "meta", "_journal.json");
    const journal = JSON.parse(readFileSync(journalPath, "utf8")) as {
      entries: { idx: number }[];
    };
    journal.entries = journal.entries.filter((e) => e.idx < 14);
    writeFileSync(journalPath, JSON.stringify(journal));
    await migrate(drizzle(scratch), { migrationsFolder: migrationsDir });
  }, 120_000);

  afterAll(async () => {
    vi.unstubAllEnvs();
    await scratch?.end();
    await admin?.unsafe(`DROP DATABASE IF EXISTS "${SCRATCH}" WITH (FORCE)`);
    await admin?.end();
    if (migrationsDir) rmSync(migrationsDir, { recursive: true, force: true });
  });

  it("carries Supabase passwords over, marks people verified, and runs twice cleanly", async () => {
    const c = scratch;
    const [owner, byEmail, empty, deleted, dupLower, dupUpper, plain] = Array.from(
      { length: 7 },
      () => randomUUID(),
    );
    await c`INSERT INTO users (id, email, full_name) VALUES
      (${owner}, 'Owner@Example.TEST', 'Owner'),
      (${byEmail}, 'byemail@example.test', 'By Email'),
      (${empty}, 'empty@example.test', 'Empty'),
      (${deleted}, 'deleted@example.test', 'Deleted'),
      (${dupLower}, 'dup@example.test', 'Dup'),
      (${dupUpper}, 'DUP@example.test', 'Dup upper'),
      (${plain}, 'plain@example.test', 'Plain')`;
    const ownerHash = bcryptOf("owner-pass");
    const byEmailHash = bcryptOf("by-email-pass", "$2b$");
    await c.unsafe(`CREATE SCHEMA auth;
      CREATE TABLE auth.users (id uuid PRIMARY KEY, email text, encrypted_password text,
        email_confirmed_at timestamptz, deleted_at timestamptz, created_at timestamptz)`);
    // byemail@ has a confirmed Supabase account under another id (as the
    // seeded demo accounts would after a Supabase sign-up with their email).
    await c`INSERT INTO auth.users VALUES
      (${owner}, 'owner@example.test', ${ownerHash}, now(), NULL, now() - interval '30 days'),
      (${randomUUID()}, 'ByEmail@example.test', ${byEmailHash}, now(), NULL, now()),
      (${randomUUID()}, 'nouser@example.test', ${bcryptOf("x")}, now(), NULL, now()),
      (${empty}, 'empty@example.test', '', now(), NULL, now()),
      (${deleted}, 'deleted@example.test', ${bcryptOf("gone")}, now(), now(), now())`;

    await c.unsafe(SQL_TEXT);

    const credentials = await c<{ user_id: string; account_id: string; password: string }[]>`
      SELECT user_id, account_id, password FROM auth_account WHERE provider_id = 'credential'`;
    // Only the account with the same id; never by email alone.
    expect(credentials.map((r) => r.user_id)).toEqual([owner]);
    expect(credentials.every((r) => r.account_id === r.user_id)).toBe(true);
    expect(credentials.find((r) => r.user_id === owner)?.password).toBe(ownerHash);
    expect(credentials.some((r) => r.password === byEmailHash)).toBe(false);

    const people = await c<{ id: string; email: string; email_verified: boolean }[]>`
      SELECT id, email, email_verified FROM users
      WHERE id IN ${c([owner, byEmail, empty, deleted, dupLower, dupUpper, plain])}`;
    const byId = new Map(people.map((p) => [p.id, p]));
    // Everyone already here came from an invitation or the seed: verified.
    expect(people.every((p) => p.email_verified)).toBe(true);
    expect(byId.get(owner)?.email).toBe("owner@example.test");
    // Lower-casing never collides with someone else's email.
    expect(byId.get(dupUpper)?.email).toBe("DUP@example.test");
    const [idDefault] = await c<{ column_default: string }[]>`
      SELECT column_default FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'id'`;
    expect(idDefault.column_default).toBe("gen_random_uuid()");

    // Between runs: the owner changed their password; two people are unverified again.
    await c`UPDATE auth_account SET password = 'changed-since' WHERE user_id = ${owner}`;
    await c`UPDATE users SET email_verified = false WHERE id IN ${c([owner, byEmail])}`;
    await c.unsafe(SQL_TEXT);
    await c.unsafe(CARRY_OVER); // the catch-up run after the release (P1-6)
    const again = await c<{ user_id: string; password: string }[]>`
      SELECT user_id, password FROM auth_account WHERE provider_id = 'credential'`;
    expect(again.map((r) => r.user_id)).toEqual([owner]);
    expect(again.find((r) => r.user_id === owner)?.password).toBe("changed-since");
    const verified = await c<{ id: string; email_verified: boolean }[]>`
      SELECT id, email_verified FROM users WHERE id IN ${c([owner, byEmail])}`;
    // Confirmed in Supabase under the same id: verified again; matched by email only: not.
    expect(Object.fromEntries(verified.map((v) => [v.id, v.email_verified]))).toEqual({
      [owner]: true,
      [byEmail]: false,
    });

    // And without Supabase's auth schema it runs, changing nothing.
    await c.unsafe("DROP SCHEMA auth CASCADE");
    await c.unsafe(SQL_TEXT);
    expect((await c`SELECT 1 FROM auth_account WHERE provider_id = 'credential'`).length).toBe(1);
  });

  it("scripts/auth-carry-over.sql is part 3 of 0014, word for word", () => {
    const part3 = FILE.slice(FILE.indexOf(PART_3));
    expect(FILE.indexOf(PART_3)).toBeGreaterThan(0);
    expect(CARRY_OVER.slice(CARRY_OVER.indexOf(PART_3)).trim()).toBe(part3.trim());
  });

  it("makes the four tables deny-by-default, owned like users, with updated_at kept", async () => {
    const c = scratch;
    const tables = await c<{ tablename: string; tableowner: string; rowsecurity: boolean }[]>`
      SELECT tablename, tableowner, rowsecurity FROM pg_tables
      WHERE schemaname = 'public' AND tablename IN ${c([...AUTH_TABLES, "users"])}`;
    const owner = tables.find((t) => t.tablename === "users")!.tableowner;
    for (const name of AUTH_TABLES) {
      const t = tables.find((r) => r.tablename === name);
      expect(t, name).toBeDefined();
      expect(t!.rowsecurity, name).toBe(true);
      expect(t!.tableowner, name).toBe(owner);
    }
    const policies = await c`SELECT 1 FROM pg_policies WHERE tablename IN ${c(AUTH_TABLES)}`;
    expect(policies).toHaveLength(0);
    const triggers = await c<{ tgname: string }[]>`
      SELECT tgname FROM pg_trigger WHERE NOT tgisinternal AND tgname LIKE 'auth\\_%'`;
    expect(triggers.map((t) => t.tgname).sort()).toEqual([
      "auth_account_set_updated_at",
      "auth_session_set_updated_at",
      "auth_verification_set_updated_at",
    ]);
  });

  it("a carried-over bcrypt password signs in through Better Auth and becomes scrypt", async () => {
    const live = postgres(url!, { max: 1, prepare: false, onnotice: () => {} });
    const db = drizzle(live, { schema });
    const { getAuth } = await import("@/lib/auth/server");
    const { isLegacyHash, verifyPassword } = await import("@/lib/auth/password");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Carry-over Org", slug: `carry-${n}` })
      .returning();
    const id = randomUUID();
    const email = `legacy-${n}@migration.test`;
    try {
      await db.insert(schema.users).values({ id, email, fullName: "Legacy", emailVerified: true });
      await db
        .insert(schema.memberships)
        .values({ userId: id, organisationId: org.id, role: "ops" });
      await db.insert(schema.authAccount).values({
        userId: id,
        accountId: id,
        providerId: "credential",
        password: bcryptOf("legacy-pass"),
      });
      const res = await getAuth().api.signInEmail({
        body: { email: email.toUpperCase(), password: "legacy-pass" },
        headers: new Headers({ host: "localhost:3901" }),
      });
      expect(res.user.id).toBe(id);
      const [acct] = await db
        .select()
        .from(schema.authAccount)
        .where(eq(schema.authAccount.userId, id));
      expect(isLegacyHash(acct.password!)).toBe(false);
      expect(await verifyPassword({ hash: acct.password!, password: "legacy-pass" })).toBe(true);
    } finally {
      await db.delete(schema.authSession).where(eq(schema.authSession.userId, id));
      await db.delete(schema.authAccount).where(eq(schema.authAccount.userId, id));
      await db.delete(schema.memberships).where(eq(schema.memberships.userId, id));
      await db.delete(schema.users).where(eq(schema.users.id, id));
      await db.delete(schema.organisations).where(eq(schema.organisations.id, org.id));
      await live.end();
    }
  });
});
