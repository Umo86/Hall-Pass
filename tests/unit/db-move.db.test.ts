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
 *
 * TEST_TARGET_DATABASE_URL (optional, same rights) puts the targets on
 * another server: Postgres 17 as the source and 18 as the target, as
 * Supabase and Neon are. Both servers need the same default collation.
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
const targetUrl = process.env.TEST_TARGET_DATABASE_URL || url;
const twoServers = targetUrl !== url;
const d = describe.skipIf(!url);

const RUN = `${process.pid}_${Date.now() % 100_000}`;
const SRC_ROLE = `hp_move_src_${RUN}`;
const DST_ROLE = `hp_move_dst_${RUN}`;
const SRC_DB = `hp_move_src_${RUN}`;
const DST_DB = `hp_move_dst_${RUN}`;
const BUSY_DB = `hp_move_busy_${RUN}`;
// Case 13's own owner, group and database (freezing with strategy B ends the role's sessions).
const FRZ_ROLE = `hp_move_frz_${RUN}`;
const FRZ_GROUP = `hp_move_frz_group_${RUN}`;
const FRZ_DB = `hp_move_frz_${RUN}`;
const PASSWORD = randomBytes(16).toString("hex");
const SLOW = { timeout: 120_000 };

function urlFor(database: string, role?: string, server = url!): string {
  const u = new URL(server);
  u.pathname = `/${database}`;
  if (role) {
    u.username = role;
    u.password = PASSWORD;
  }
  return u.toString();
}

/** A database on the target's server. */
const targetFor = (database: string, role?: string) => urlFor(database, role, targetUrl!);

/** Check's notice when the servers' major versions differ, expected only with two servers. */
const VERSIONS_DIFFER = /^Different Postgres major versions/;
const besidesVersions = (warnings: string[]) =>
  twoServers ? warnings.filter((w) => !VERSIONS_DIFFER.test(w)) : warnings;

let admin: postgres.Sql;
/** The target server's superuser connection (the same as `admin` with one server). */
let targetAdmin: postgres.Sql;
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
    targetAdmin = twoServers
      ? postgres(targetFor("postgres"), { max: 1, prepare: false, onnotice: () => {} })
      : admin;
    try {
      for (const [server, role] of [
        [admin, SRC_ROLE],
        [targetAdmin, DST_ROLE],
      ] as const) {
        await server.unsafe(
          `CREATE ROLE "${role}" LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '${PASSWORD}'`,
        );
      }
      await admin.unsafe(`CREATE DATABASE "${SRC_DB}" OWNER "${SRC_ROLE}"`);
      await targetAdmin.unsafe(`CREATE DATABASE "${DST_DB}" OWNER "${DST_ROLE}"`);
      await targetAdmin.unsafe(`CREATE DATABASE "${BUSY_DB}" OWNER "${DST_ROLE}"`);
    } catch (err) {
      console.warn(`db-move: skipped, can't create roles or databases (${(err as Error).message})`);
      return;
    }
    for (const [database, role] of [
      [urlFor(SRC_DB), SRC_ROLE],
      [targetFor(DST_DB), DST_ROLE],
      [targetFor(BUSY_DB), DST_ROLE],
    ]) {
      const c = postgres(database, { max: 1, onnotice: () => {} });
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
    dst = connectForMove(targetFor(DST_DB, DST_ROLE));
    await src.unsafe(FIXTURE);
    ready = true;
  }, 180_000);

  afterAll(async () => {
    await src?.end({ timeout: 5 });
    await dst?.end({ timeout: 5 });
    if (targetAdmin && twoServers) {
      for (const database of [DST_DB, BUSY_DB]) {
        await targetAdmin
          .unsafe(`DROP DATABASE IF EXISTS "${database}" WITH (FORCE)`)
          .catch(() => {});
      }
      await targetAdmin.unsafe(`DROP ROLE IF EXISTS "${DST_ROLE}"`).catch(() => {});
      await targetAdmin.end({ timeout: 5 });
    }
    if (admin) {
      for (const database of [SRC_DB, DST_DB, BUSY_DB, FRZ_DB]) {
        await admin.unsafe(`DROP DATABASE IF EXISTS "${database}" WITH (FORCE)`).catch(() => {});
      }
      for (const role of [SRC_ROLE, DST_ROLE, FRZ_ROLE, FRZ_GROUP]) {
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
      expect(besidesVersions(report.warnings)).toEqual([]);
      // Check names a difference in major versions exactly when there is one.
      const [srcMajor, dstMajor] = [report.source, report.target].map((s) =>
        Math.floor(s.versionNum / 10000),
      );
      if (!twoServers) expect(dstMajor).toBe(srcMajor);
      expect(report.warnings.some((w) => VERSIONS_DIFFER.test(w))).toBe(srcMajor !== dstMajor);
      // When the app runs on the source, check says it must be frozen before the copy.
      const live = await checkDatabases(src, dst, { liveSource: "supabase" });
      expect(live.readyToCopy).toBe(true);
      expect(besidesVersions(live.warnings)).toEqual([
        expect.stringMatching(/^supabase is the live database and isn't frozen: copy refuses/),
      ]);
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
      // The database the app runs on is copied only once it is frozen (or when told it can't be).
      const before = (await databaseFingerprint(dst)).fingerprint;
      const live = await refusal(copyDatabase(src, dst, { replace: true, liveSource: "supabase" }));
      expect(live.message).toMatch(
        /supabase is the live database and isn't frozen.*step=freeze&db=supabase/,
      );
      expect((await databaseFingerprint(dst)).fingerprint).toBe(before);
      const told = await copyDatabase(src, dst, {
        replace: true,
        liveSource: "supabase",
        allowUnfrozenSource: true,
      });
      expect(told.fingerprint).toBe(firstCopy.fingerprint);

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
        const copy = await copyDatabase(src, dst, { replace: true, liveSource: "supabase" });
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
      const target = connectForMove(targetFor(BUSY_DB, DST_ROLE));
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

      // A write that reached the old database after the copy: only that table is named,
      // not the ones the app (reminder_log) and finish (audit_log) wrote on the new one.
      await src.unsafe(
        `UPDATE users SET full_name = full_name || ' (late)' WHERE id = 'f1000000-0000-4000-8000-000000000011'`,
      );
      const late = await finishMove(src, dst, { expect: copy.fingerprint, summary });
      expect(late.sourceUnchanged).toBe(false);
      expect(late.audit).toBe("not written");
      expect(late.differingTables).toEqual(["public.users"]);

      // A mistyped expect is said to be one, rather than blamed on the data.
      const typo = await finishMove(src, dst, { expect: "0".repeat(32), summary });
      expect(typo.sourceUnchanged).toBe(false);
      expect(typo.differingTables).toBeUndefined();
      expect(typo.warnings[0]).toMatch(/No copy with this fingerprint/);
    },
  );

  it("12. a top-level JSON null stays a JSON null, apart from SQL NULL", SLOW, async (ctx) => {
    if (!ready) ctx.skip();
    const ORG = "f1000000-0000-4000-8000-000000000001";
    const settings = await one<string>(
      src,
      `SELECT settings::text FROM organisations WHERE id = '${ORG}'`,
    );
    await src.unsafe(
      `INSERT INTO audit_log (actor_type, entity_type, action, summary, before, after)
         VALUES ('system', 'database', 'settings_change', 'JSON null', 'null'::jsonb, NULL)`,
    );
    // A NOT NULL jsonb column holding JSON null (only SQL run by hand can do this).
    await src.unsafe(`UPDATE organisations SET settings = 'null'::jsonb WHERE id = '${ORG}'`);
    try {
      const copy = await copyDatabase(src, dst, { replace: true });
      const v = await verifyDatabases(src, dst);
      expect(v.mismatched).toEqual([]);
      expect(v.targetFingerprint).toBe(copy.fingerprint);
      expect(
        await one<string>(
          dst,
          `SELECT jsonb_typeof(before) || '|' || (after IS NULL)::text FROM audit_log WHERE summary = 'JSON null'`,
        ),
      ).toBe("null|true");
      expect(
        await one<string>(dst, `SELECT settings::text FROM organisations WHERE id = '${ORG}'`),
      ).toBe("null");
    } finally {
      await src.unsafe(`UPDATE organisations SET settings = $1::jsonb WHERE id = '${ORG}'`, [
        settings,
      ]);
    }
  });

  it(
    "13. freeze A takes the writes a role inherits too (as postgres through service_role on Supabase) and gives back exactly those; B ends every session, the tool's own too",
    SLOW,
    async (ctx) => {
      if (!ready) ctx.skip();
      await admin.unsafe(
        `CREATE ROLE "${FRZ_ROLE}" LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '${PASSWORD}'`,
      );
      await admin.unsafe(`CREATE ROLE "${FRZ_GROUP}" NOLOGIN`);
      await admin.unsafe(`GRANT "${FRZ_GROUP}" TO "${FRZ_ROLE}"`);
      await admin.unsafe(`CREATE DATABASE "${FRZ_DB}" OWNER "${FRZ_ROLE}"`);
      const setup = postgres(urlFor(FRZ_DB), { max: 1, onnotice: () => {} });
      await setup.unsafe(`ALTER SCHEMA public OWNER TO "${FRZ_ROLE}"`);
      await setup.end();

      const sessions: MoveSql[] = [];
      // The tool's connections (one session each), and the app's pooled client.
      const session = () => {
        const s = connectForMove(urlFor(FRZ_DB, FRZ_ROLE));
        sessions.push(s);
        return s;
      };
      const app = postgres(urlFor(FRZ_DB, FRZ_ROLE), { prepare: false, onnotice: () => {} });
      sessions.push(app);
      const write = (s: MoveSql, kind: string) =>
        s.unsafe(`INSERT INTO reminder_log (kind) VALUES ('${kind}')`);
      const pid = (s: MoveSql) => one<number>(s, `SELECT pg_backend_pid()`);
      // The server ends a session a moment after pg_terminate_backend returns.
      const ended = async (backend: number) => {
        for (let i = 0; i < 50; i++) {
          const [r] = await admin.unsafe<{ n: number }[]>(
            `SELECT count(*)::int AS n FROM pg_stat_activity WHERE pid = $1`,
            [backend],
          );
          if (Number(r.n) === 0) return true;
          await new Promise((resolve) => setTimeout(resolve, 100));
        }
        return false;
      };
      // A pooled connection the server ended fails its next query once, as in the app.
      const ENDED =
        /^(57P01|CONNECTION_CLOSED|CONNECTION_ENDED|CONNECTION_DESTROYED|ECONNRESET|EPIPE)$/;
      const afterReconnect = async <T>(run: () => Promise<T>): Promise<T> => {
        try {
          return await run();
        } catch (err) {
          if (!ENDED.test((err as { code?: string }).code ?? "")) throw err;
          return run();
        }
      };
      // Effective privileges per table and grantee (relacl, or the owner's default when unset).
      const privileges = (s: MoveSql) =>
        s.unsafe<{ t: string; who: string; p: string; g: boolean }[]>(`
          SELECT c.relname AS t, CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END AS who,
                 a.privilege_type AS p, a.is_grantable AS g
          FROM pg_class c CROSS JOIN LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
          WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'r'
          ORDER BY 1, 2, 3`);
      try {
        const tool = session();
        await tool.unsafe(`CREATE TABLE reminder_log (id serial PRIMARY KEY, kind text NOT NULL)`);
        await tool.unsafe(`CREATE TABLE plain (id int PRIMARY KEY)`); // relacl unset
        // Privileges held through role membership and through PUBLIC: revoking the
        // owner's own isn't enough (Supabase: postgres inherits service_role's).
        await tool.unsafe(`GRANT ALL ON reminder_log TO "${FRZ_GROUP}"`);
        await tool.unsafe(`GRANT SELECT, INSERT ON reminder_log TO PUBLIC`);
        await tool.unsafe(`GRANT UPDATE ON reminder_log TO "${FRZ_GROUP}" WITH GRANT OPTION`);
        const before = await privileges(tool);

        const frozenA = await freeze(tool);
        expect(frozenA).toMatchObject({ frozen: true, strategy: "A" });
        expect(frozenA.revokedFrom).toEqual(["PUBLIC", FRZ_ROLE, FRZ_GROUP].sort());
        await expect(write(app, "during A")).rejects.toMatchObject({ code: "42501" });
        await expect(write(tool, "during A")).rejects.toMatchObject({ code: "42501" });
        // Reads keep working.
        expect(await one<number>(app, `SELECT count(*)::int FROM reminder_log`)).toBe(0);
        expect(await isFrozen(session())).toEqual({ frozen: true, strategy: "A" });

        const undoneA = await unfreeze(session());
        expect(undoneA).toMatchObject({ frozen: false, undid: ["A"] });
        expect(undoneA.restoredTo).toEqual(["PUBLIC", FRZ_ROLE, FRZ_GROUP].sort());
        // Exactly the privileges there were, grant options included.
        expect(await privileges(tool)).toEqual(before);
        expect(await one<number>(tool, `SELECT count(*)::int FROM db_move.frozen_grants`)).toBe(0);
        await write(app, "after A");

        // A table the role doesn't own: strategy B.
        await tool.unsafe(`CREATE TABLE not_ours (id int PRIMARY KEY)`);
        await tool.unsafe(`GRANT CREATE ON SCHEMA public TO "${FRZ_GROUP}"`);
        await tool.unsafe(`ALTER TABLE not_ours OWNER TO "${FRZ_GROUP}"`);
        const appBefore = await pid(app);
        const toolBefore = await pid(tool);
        const frozenB = await freeze(tool);
        expect(frozenB).toMatchObject({ frozen: true, strategy: "B" });
        // Every session of the role was ended, the tool's own too (a pooler would
        // otherwise hand that backend, started writable, to the app).
        expect(await ended(appBefore)).toBe(true);
        expect(await ended(toolBefore)).toBe(true);
        await expect(afterReconnect(() => write(app, "during B"))).rejects.toMatchObject({
          code: "25006",
        });
        await expect(afterReconnect(() => write(tool, "during B"))).rejects.toMatchObject({
          code: "25006",
        });
        const appDuringFreeze = await pid(app);

        // The next route call opens a new (read-only) session and unfreezes.
        const route = session();
        expect(await isFrozen(route)).toEqual({ frozen: true, strategy: "B" });
        const routeBefore = await pid(route);
        const undoneB = await unfreeze(route);
        expect(undoneB).toMatchObject({ frozen: false, strategy: null, undid: ["B"] });
        expect(undoneB.sessionsEnded).toBeGreaterThanOrEqual(2); // the app's and the tool's
        // The sessions from the freeze were ended, the route's own last; all reconnect writable.
        expect(await ended(appDuringFreeze)).toBe(true);
        expect(await ended(routeBefore)).toBe(true);
        await afterReconnect(() => write(app, "after B"));
        expect(await one<string>(app, `SHOW default_transaction_read_only`)).toBe("off");
        await afterReconnect(() => write(route, "route"));
        expect(await isFrozen(session())).toEqual({ frozen: false, strategy: null });
        expect(await one<number>(app, `SELECT count(*)::int FROM reminder_log`)).toBe(3);
      } finally {
        await Promise.all(sessions.map((s) => s.end({ timeout: 5 }).catch(() => {})));
      }
    },
  );
});
