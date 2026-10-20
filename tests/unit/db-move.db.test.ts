/**
 * The one-off database move (lib/db/move/*) between two real databases.
 * Needs TEST_DATABASE_URL with a user that can CREATE ROLE and CREATE
 * DATABASE (local and CI Postgres run as the superuser); skips otherwise.
 *
 * Two non-superuser owners stand in for Supabase's `postgres` and Neon's
 * `neondb_owner` (a superuser would ignore the freeze). The source is built
 * like the seeded database — migrations, then `pnpm db:seed` — plus
 * tests/unit/fixtures/move-fixture.sql (every foreign-key cycle, Better
 * Auth's tables, and values only an exact copy keeps). The target starts
 * empty. The shared test database is used once more, read-only, as a busy
 * source.
 */
import { execFileSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";
import path from "node:path";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { runMigrations } from "@/lib/db/migrate-core";
import { checkDatabases } from "@/lib/db/move/check";
import { connectForMove, MoveRefused, type MoveSql } from "@/lib/db/move/connect";
import { copyDatabase, type CopyReport } from "@/lib/db/move/copy";
import { finishMove } from "@/lib/db/move/finish";
import { freeze, isFrozen, unfreeze } from "@/lib/db/move/freeze";
import { databaseFingerprint, verifyDatabases } from "@/lib/db/move/verify";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);

const RUN = `${process.pid}_${Date.now() % 100_000}`;
const SRC_ROLE = `hp_move_src_${RUN}`;
const DST_ROLE = `hp_move_dst_${RUN}`;
const SRC_DB = `hp_move_src_${RUN}`;
const DST_DB = `hp_move_dst_${RUN}`;
const BUSY_DB = `hp_move_busy_${RUN}`;
const PASSWORD = randomBytes(16).toString("hex");
const SLOW = { timeout: 120_000 };

function urlFor(database: string, role?: string): string {
  const u = new URL(url!);
  u.pathname = `/${database}`;
  if (role) {
    u.username = role;
    u.password = PASSWORD;
  }
  return u.toString();
}

let admin: postgres.Sql;
let src: MoveSql;
let dst: MoveSql;
let ready = false;
let firstCopy: CopyReport;

const FIXTURE = readFileSync("tests/unit/fixtures/move-fixture.sql", "utf8");
const ITEM = "f1000000-0000-4000-8000-000000000062";
const CLONED_EDITION = "f1000000-0000-4000-8000-000000000052";

async function refusal(promise: Promise<unknown>): Promise<MoveRefused> {
  try {
    await promise;
  } catch (err) {
    if (err instanceof MoveRefused) return err;
    throw err;
  }
  throw new Error("expected a refusal");
}

async function one<T>(sql: MoveSql, query: string): Promise<T> {
  const rows = await sql.unsafe(query);
  return Object.values(rows[0] ?? {})[0] as T;
}

d("database move: copy, verify, freeze, finish", () => {
  beforeAll(async () => {
    admin = postgres(urlFor("postgres"), { max: 1, prepare: false, onnotice: () => {} });
    try {
      for (const role of [SRC_ROLE, DST_ROLE]) {
        await admin.unsafe(
          `CREATE ROLE "${role}" LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '${PASSWORD}'`,
        );
      }
      await admin.unsafe(`CREATE DATABASE "${SRC_DB}" OWNER "${SRC_ROLE}"`);
      await admin.unsafe(`CREATE DATABASE "${DST_DB}" OWNER "${DST_ROLE}"`);
      await admin.unsafe(`CREATE DATABASE "${BUSY_DB}" OWNER "${DST_ROLE}"`);
    } catch (err) {
      console.warn(`db-move: skipped, can't create roles or databases (${(err as Error).message})`);
      return;
    }
    for (const [database, role] of [
      [SRC_DB, SRC_ROLE],
      [DST_DB, DST_ROLE],
      [BUSY_DB, DST_ROLE],
    ]) {
      const c = postgres(urlFor(database), { max: 1, onnotice: () => {} });
      await c.unsafe(`ALTER SCHEMA public OWNER TO "${role}"`);
      await c.end();
    }
    // The source: migrations and the demo seed as its owner, then the fixture.
    const srcUrl = urlFor(SRC_DB, SRC_ROLE);
    await runMigrations(srcUrl);
    execFileSync(path.join(process.cwd(), "node_modules/.bin/tsx"), ["lib/db/seed/index.ts"], {
      env: {
        ...process.env,
        DIRECT_DATABASE_URL: srcUrl,
        DATABASE_URL: srcUrl,
        DATABASE_TARGET: "auto",
        SEED_MODE: "",
      },
      stdio: "pipe",
    });
    src = connectForMove(srcUrl);
    dst = connectForMove(urlFor(DST_DB, DST_ROLE));
    await src.unsafe(FIXTURE);
    ready = true;
  }, 180_000);

  afterAll(async () => {
    await src?.end({ timeout: 5 });
    await dst?.end({ timeout: 5 });
    if (admin) {
      for (const database of [SRC_DB, DST_DB, BUSY_DB]) {
        await admin.unsafe(`DROP DATABASE IF EXISTS "${database}" WITH (FORCE)`).catch(() => {});
      }
      for (const role of [SRC_ROLE, DST_ROLE]) {
        await admin.unsafe(`DROP ROLE IF EXISTS "${role}"`).catch(() => {});
      }
      await admin.end({ timeout: 5 });
    }
  });

  it(
    "1. check: an empty target is ready, the source's migrations match the release",
    SLOW,
    async (ctx) => {
      if (!ready) ctx.skip();
      const report = await checkDatabases(src, dst);
      expect(report.target.state).toBe("empty");
      expect(report.migrations).toMatchObject({
        bundled: 15,
        latest: "0014_better_auth",
        source: 15,
        match: true,
        mismatches: [],
      });
      expect(report.source.tables).toBe(48);
      expect(report.source.rows["public.auth_rate_limit"]).toBeGreaterThanOrEqual(1);
      expect(report.source.ownsAllTables).toBe(true);
      expect(report.target.ownsAllTables).toBe(true);
      expect(report.target.canCreate).toBe(true);
      expect(report.source.frozen).toBe(false);
      expect(report.collationMatch).toBe(true);
      expect(report.blockers).toEqual([]);
      expect(report.readyToCopy).toBe(true);
    },
  );

  it(
    "2. copy, then verify: every row, the schema, drizzle's rows and the sequence",
    SLOW,
    async (ctx) => {
      if (!ready) ctx.skip();
      firstCopy = await copyDatabase(src, dst, { batchRows: 50 });
      expect(firstCopy.migrationsApplied).toBe(15);
      expect(firstCopy.migrationsRun).toBe(15);
      expect(firstCopy.deferred.sort()).toEqual([
        "public.comments.parent_id",
        "public.editions.cloned_from_edition_id",
        "public.signage_items.current_artwork_version_id",
        "public.signage_items.parent_item_id",
        "public.tasks.parent_task_id",
      ]);
      const at = (k: string) => firstCopy.order.indexOf(k);
      expect(at("public.users")).toBeLessThan(at("public.auth_session"));
      expect(at("public.users")).toBeLessThan(at("public.auth_account"));
      expect(firstCopy.totalRows).toBeGreaterThan(100);

      const v = await verifyDatabases(src, dst);
      expect(v.mismatched).toEqual([]);
      expect(v.schema.differences).toEqual([]);
      expect(v.ok).toBe(true);
      expect(v.schema.target).toMatchObject({
        functionCount: 2,
        triggerCount: 46,
        constraintCounts: { c: 20, f: 106, p: 48, u: 21 },
        indexCount: 199,
      });
      expect(v.tables["drizzle.__drizzle_migrations"]).toEqual({
        source: 15,
        target: 15,
        match: true,
      });
      expect(v.sequences["drizzle.__drizzle_migrations_id_seq"].match).toBe(true);
      expect(v.sourceFingerprint).toBe(firstCopy.fingerprint);
      expect(v.targetFingerprint).toBe(firstCopy.fingerprint);

      // Values that only an exact copy keeps, read back as text by SQL.
      const asText = [
        `SELECT last_request::text FROM auth_rate_limit WHERE id = 'f1000000-0000-4000-8000-0000000000f5'`,
        `SELECT string_agg(token, ',' ORDER BY token) FROM auth_session WHERE token LIKE '%Fixture%'`,
        `SELECT default_for::text FROM departments WHERE id = 'f1000000-0000-4000-8000-000000000021'`,
        `SELECT after::text FROM audit_log WHERE id = 'f1000000-0000-4000-8000-0000000000c1'`,
        `SELECT summary FROM audit_log WHERE id = 'f1000000-0000-4000-8000-0000000000c1'`,
        `SELECT settings::text FROM organisations WHERE id = 'f1000000-0000-4000-8000-000000000001'`,
        `SELECT signage_budget::text FROM editions WHERE id = 'f1000000-0000-4000-8000-000000000051'`,
        `SELECT notes FROM venues WHERE id = 'f1000000-0000-4000-8000-000000000041'`,
        `SELECT full_name || '|' || (created_at AT TIME ZONE 'UTC')::text FROM users WHERE id = 'f1000000-0000-4000-8000-000000000011'`,
      ];
      for (const q of asText) {
        expect(await one<string>(dst, q), q).toBe(await one<string>(src, q));
      }
      expect(await one<string>(dst, asText[0])).toBe("9007199254740993");
      expect(await one<string>(dst, asText[1])).toBe(
        "Hk3q9VbN0aFixtureTokenOne_-x,Zz9-FixtureTokenTwo.with/odd+chars=",
      );
      expect(await one<string>(dst, asText[3])).toContain("123456789012345678901234567890.000");
    },
  );

  it(
    "3. updated_at survives the cycle fill; triggers are back on; the audit log stays append-only",
    SLOW,
    async (ctx) => {
      if (!ready) ctx.skip();
      for (const q of [
        `SELECT updated_at::text || '|' || current_artwork_version_id::text || '|' || parent_item_id::text FROM signage_items WHERE id = '${ITEM}'`,
        `SELECT updated_at::text || '|' || cloned_from_edition_id::text FROM editions WHERE id = '${CLONED_EDITION}'`,
        `SELECT updated_at::text || '|' || parent_id::text FROM comments WHERE id = 'f1000000-0000-4000-8000-000000000082'`,
        `SELECT updated_at::text || '|' || parent_task_id::text FROM tasks WHERE id = 'f1000000-0000-4000-8000-000000000092'`,
      ]) {
        const value = await one<string>(dst, q);
        expect(value, q).not.toContain("null");
        expect(value, q).toBe(await one<string>(src, q));
      }
      expect(
        await one<number>(
          dst,
          `SELECT count(*)::int FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
         WHERE c.relnamespace = 'public'::regnamespace AND NOT t.tgisinternal AND t.tgenabled <> 'O'`,
        ),
      ).toBe(0);
      await expect(dst.unsafe(`UPDATE audit_log SET summary = 'x'`)).rejects.toThrow(/append-only/);
    },
  );

  it("4. a second copy needs replace; refused copies change nothing", SLOW, async (ctx) => {
    if (!ready) ctx.skip();
    const before = await databaseFingerprint(dst);
    const r = await refusal(copyDatabase(src, dst));
    expect(r.message).toMatch(/Target is not empty.*replace=1/);
    expect((await databaseFingerprint(dst)).fingerprint).toBe(before.fingerprint);

    const check = await checkDatabases(src, dst);
    expect(check.target.state).toBe("previousCopy");
    expect(check.target.nonEmptyTables.length).toBeGreaterThan(10);

    const again = await copyDatabase(src, dst, { replace: true });
    expect(again.migrationsRun).toBe(0);
    expect(again.fingerprint).toBe(firstCopy.fingerprint);
    expect((await databaseFingerprint(dst)).fingerprint).toBe(firstCopy.fingerprint);
  });

  it(
    "5. a target holding anything else is foreign: refused even with replace",
    SLOW,
    async (ctx) => {
      if (!ready) ctx.skip();
      await dst.unsafe(`CREATE TABLE public.stray (id int PRIMARY KEY)`);
      try {
        const check = await checkDatabases(src, dst);
        expect(check.target.state).toBe("foreign");
        expect(check.readyToCopy).toBe(false);
        const r = await refusal(copyDatabase(src, dst, { replace: true }));
        expect(r.message).toMatch(/state foreign/);
      } finally {
        await dst.unsafe(`DROP TABLE public.stray`);
      }
      expect((await checkDatabases(src, dst)).target.state).toBe("previousCopy");
    },
  );

  it("6. a migration changed after it ran on the source: refused", SLOW, async (ctx) => {
    if (!ready) ctx.skip();
    const [row] = await src.unsafe<{ id: number; hash: string }[]>(
      `SELECT id, hash FROM drizzle.__drizzle_migrations ORDER BY created_at LIMIT 1 OFFSET 3`,
    );
    await src.unsafe(`UPDATE drizzle.__drizzle_migrations SET hash = 'tampered' WHERE id = $1`, [
      row.id,
    ]);
    try {
      const check = await checkDatabases(src, dst);
      expect(check.migrations.match).toBe(false);
      expect(check.migrations.mismatches).toEqual([
        { tag: "0003_flat_firebird", problem: "hash differs" },
      ]);
      expect(check.readyToCopy).toBe(false);
      const r = await refusal(copyDatabase(src, dst, { replace: true }));
      expect(r.message).toMatch(/applied migrations differ/);
    } finally {
      await src.unsafe(`UPDATE drizzle.__drizzle_migrations SET hash = $1 WHERE id = $2`, [
        row.hash,
        row.id,
      ]);
    }
    expect((await checkDatabases(src, dst)).migrations.match).toBe(true);
  });

  it(
    "7. freeze: the owner can't write, the copy still reads it; unfreeze makes it writable",
    SLOW,
    async (ctx) => {
      if (!ready) ctx.skip();
      expect(await freeze(src)).toMatchObject({ frozen: true, strategy: "A" });
      try {
        expect(await isFrozen(src)).toEqual({ frozen: true, strategy: "A" });
        // A fresh session of the same role (as a pooled app connection would be).
        const other = connectForMove(urlFor(SRC_DB, SRC_ROLE));
        try {
          await expect(
            other.unsafe(
              `INSERT INTO reminder_log (target_type, target_id, kind, sent_on)
             VALUES ('signage_item', gen_random_uuid(), 'due', '2026-10-20')`,
            ),
          ).rejects.toMatchObject({ code: "42501" });
        } finally {
          await other.end();
        }
        expect((await checkDatabases(src, dst)).source.frozen).toBe(true);
        const copy = await copyDatabase(src, dst, { replace: true });
        expect(copy.fingerprint).toBe(firstCopy.fingerprint);
      } finally {
        expect(await unfreeze(src)).toMatchObject({ frozen: false, undid: ["A"] });
      }
      expect(await isFrozen(src)).toEqual({ frozen: false, strategy: null });
    },
  );

  it(
    "8. all or nothing: a failure part-way, an overrun, or a frozen target leaves the target unchanged",
    SLOW,
    async (ctx) => {
      if (!ready) ctx.skip();
      const before = (await databaseFingerprint(dst)).fingerprint;
      await expect(
        copyDatabase(src, dst, { replace: true, failAfterTable: "public.signage_items" }),
      ).rejects.toThrow(/Stopped after public.signage_items/);
      expect((await databaseFingerprint(dst)).fingerprint).toBe(before);

      const overrun = await refusal(copyDatabase(src, dst, { replace: true, budgetMs: 1 }));
      expect(overrun.message).toMatch(/took longer than .* rolled back/);
      expect((await databaseFingerprint(dst)).fingerprint).toBe(before);

      await freeze(dst);
      try {
        const r = await refusal(copyDatabase(src, dst, { replace: true }));
        expect(r.message).toMatch(/target is frozen/);
      } finally {
        await unfreeze(dst);
      }
      expect((await databaseFingerprint(dst)).fingerprint).toBe(before);
    },
  );

  it(
    "9. a busy source (the shared test database other files write into): the snapshot holds",
    SLOW,
    async (ctx) => {
      if (!ready) ctx.skip();
      const busy = connectForMove(url!);
      const target = connectForMove(urlFor(BUSY_DB, DST_ROLE));
      try {
        const report = await copyDatabase(busy, target, { batchRows: 200 });
        // Each table holds exactly what the snapshot held (checked before commit)…
        for (const [table, n] of Object.entries(report.rows)) {
          expect(await one<number>(target, `SELECT count(*)::int FROM ${table}`), table).toBe(n);
        }
        // …and the append-only audit log can only have grown on the live source since.
        expect(
          await one<number>(target, `SELECT count(*)::int FROM audit_log`),
        ).toBeLessThanOrEqual(await one<number>(busy, `SELECT count(*)::int FROM audit_log`));
      } finally {
        await busy.end();
        await target.end();
      }
    },
  );

  it(
    "10. back-copy: what was written on the new database comes back to the old one",
    SLOW,
    async (ctx) => {
      if (!ready) ctx.skip();
      await dst.unsafe(
        `INSERT INTO audit_log (actor_type, entity_type, action, summary)
       VALUES ('system', 'database', 'settings_change', 'Written after the switch')`,
      );
      const v = await verifyDatabases(src, dst);
      expect(v.ok).toBe(false);
      expect(v.mismatched).toEqual(["public.audit_log"]);

      expect((await checkDatabases(dst, src)).target.state).toBe("previousCopy");
      await refusal(copyDatabase(dst, src));
      const back = await copyDatabase(dst, src, { replace: true });
      const after = await verifyDatabases(dst, src);
      expect(after.ok).toBe(true);
      expect(after.targetFingerprint).toBe(back.fingerprint);
      expect(
        await one<number>(
          src,
          `SELECT count(*)::int FROM audit_log WHERE summary = 'Written after the switch'`,
        ),
      ).toBe(1);
    },
  );

  it(
    "11. finish: the source is unchanged, the audit row is written once; a changed source is caught",
    SLOW,
    async (ctx) => {
      if (!ready) ctx.skip();
      const copy = await copyDatabase(src, dst, { replace: true });
      // People use the new database before finish runs.
      await dst.unsafe(
        `INSERT INTO reminder_log (target_type, target_id, kind, sent_on)
       VALUES ('signage_item', gen_random_uuid(), 'due', '2026-10-21')`,
      );
      const summary = (n: number) =>
        `Database moved from Supabase to Neon (London): ${n} rows verified`;
      const first = await finishMove(src, dst, { expect: copy.fingerprint, summary });
      expect(first).toMatchObject({ sourceUnchanged: true, audit: "written" });
      expect(first.warnings).toEqual([]);
      const rows = await dst.unsafe<{ summary: string; organisation_id: string | null }[]>(
        `SELECT summary, organisation_id FROM audit_log
       WHERE entity_type = 'database' AND after->>'fingerprint' = '${copy.fingerprint}'`,
      );
      expect(rows).toEqual([
        { summary: summary(first.totalRows), organisation_id: null }, // two organisations here
      ]);

      expect(await finishMove(src, dst, { expect: copy.fingerprint, summary })).toMatchObject({
        sourceUnchanged: true,
        audit: "already written",
      });

      // A write that reached the old database after the copy.
      await src.unsafe(
        `INSERT INTO audit_log (actor_type, entity_type, action, summary)
       VALUES ('user', 'signage_item', 'update', 'A late write')`,
      );
      const late = await finishMove(src, dst, { expect: copy.fingerprint, summary });
      expect(late.sourceUnchanged).toBe(false);
      expect(late.audit).toBe("not written");
      expect(late.differingTables).toContain("public.audit_log");
    },
  );
});
