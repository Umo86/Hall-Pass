/**
 * step=prepare against real databases: the source is ICU en-US like
 * Supabase's, the "server" database stands in for Neon's neondb (libc
 * C.UTF-8), and its owner can create databases but is no superuser, like
 * neondb_owner. Needs TEST_DATABASE_URL with a user that can CREATE ROLE and
 * CREATE DATABASE (local and CI Postgres run as the superuser); skips
 * otherwise.
 */
import { randomBytes } from "node:crypto";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { checkDatabases } from "@/lib/db/move/check";
import { connectForMove, MoveRefused, type MoveSql } from "@/lib/db/move/connect";
import { prepareTarget } from "@/lib/db/move/prepare";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);

const RUN = `${process.pid}_${Date.now() % 100_000}`;
const OWNER = `hp_prep_owner_${RUN}`;
const SRC_DB = `hp_prep_src_${RUN}`;
const SERVER_DB = `hp_prep_server_${RUN}`;
const MADE_DB = `hp_prep_made_${RUN}`;
const WRONG_DB = `hp_prep_wrong_${RUN}`;
const PASSWORD = randomBytes(16).toString("hex");

function urlFor(database: string, role?: string): string {
  const u = new URL(url!);
  u.pathname = `/${database}`;
  if (role) {
    u.username = role;
    u.password = PASSWORD;
  }
  return u.toString();
}

const SORT = `SELECT string_agg(x, ',' ORDER BY x) AS s FROM (VALUES ('alice'), ('Bob'), ('Émile'), ('zed')) v(x)`;

async function sortedIn(sql: MoveSql): Promise<string> {
  const [r] = await sql.unsafe<{ s: string }[]>(SORT);
  return r.s;
}

let admin: postgres.Sql;
let src: MoveSql;
let server: MoveSql;
const opened: MoveSql[] = [];
let ready = false;

d("database move: prepare the target with the source's collation", () => {
  beforeAll(async () => {
    admin = postgres(urlFor("postgres"), { max: 1, prepare: false, onnotice: () => {} });
    try {
      await admin.unsafe(
        `CREATE ROLE "${OWNER}" LOGIN NOSUPERUSER CREATEDB NOCREATEROLE PASSWORD '${PASSWORD}'`,
      );
      await admin.unsafe(
        `CREATE DATABASE "${SRC_DB}" TEMPLATE template0 ENCODING 'UTF8' LOCALE_PROVIDER icu ICU_LOCALE 'en-US' LOCALE 'C.UTF-8'`,
      );
      await admin.unsafe(
        `CREATE DATABASE "${SERVER_DB}" OWNER "${OWNER}" TEMPLATE template0 ENCODING 'UTF8' LOCALE_PROVIDER libc LOCALE 'C.UTF-8'`,
      );
    } catch (err) {
      console.warn(`db-move-prepare: skipped (${(err as Error).message})`);
      return;
    }
    src = connectForMove(urlFor(SRC_DB));
    server = connectForMove(urlFor(SERVER_DB, OWNER));
    ready = true;
  }, 60_000);

  afterAll(async () => {
    await Promise.all(
      [src, server, ...opened].filter(Boolean).map((s) => s.end({ timeout: 5 }).catch(() => {})),
    );
    if (admin) {
      for (const database of [SRC_DB, SERVER_DB, MADE_DB, WRONG_DB]) {
        await admin.unsafe(`DROP DATABASE IF EXISTS "${database}" WITH (FORCE)`).catch(() => {});
      }
      await admin.unsafe(`DROP ROLE IF EXISTS "${OWNER}"`).catch(() => {});
      await admin.end({ timeout: 5 });
    }
  });

  it("the server's own database sorts differently from the source (why prepare exists)", async (ctx) => {
    if (!ready) ctx.skip();
    expect(await sortedIn(src)).toBe("alice,Bob,Émile,zed");
    expect(await sortedIn(server)).toBe("Bob,alice,zed,Émile");
    const report = await checkDatabases(src, server);
    expect(report.collationMatch).toBe(false);
    expect(report.blockers.join(" ")).toMatch(
      /sort text differently \(collation: source ICU en-US, UTF8, target libc C.UTF-8, UTF8\); on Neon, set NEON_DATABASE and run step=prepare/,
    );
  });

  it("makes the database as the server's owner, with the source's ICU locale; then check agrees", async (ctx) => {
    if (!ready) ctx.skip();
    const report = await prepareTarget(src, server, MADE_DB);
    expect(report).toMatchObject({
      database: MADE_DB,
      created: true,
      collationMatch: true,
      source: "ICU en-US, UTF8",
      target: "ICU en-US, UTF8",
    });
    const made = connectForMove(urlFor(MADE_DB, OWNER));
    opened.push(made);
    expect(await sortedIn(made)).toBe("alice,Bob,Émile,zed");
    const [owner] = await made.unsafe<{ o: string }[]>(
      `SELECT pg_get_userbyid(datdba) AS o FROM pg_database WHERE datname = current_database()`,
    );
    expect(owner.o).toBe(OWNER);
    const check = await checkDatabases(src, made);
    expect(check.collationMatch).toBe(true);
    expect(check.target.canCreate).toBe(true);
    expect(check.target.state).toBe("empty");
    expect(check.blockers.join(" ")).not.toMatch(/collation/);
  });

  it("run again: kept as it is", async (ctx) => {
    if (!ready) ctx.skip();
    expect(await prepareTarget(src, server, MADE_DB)).toMatchObject({
      created: false,
      collationMatch: true,
    });
  });

  it("a database of that name with another collation is refused and left alone", async (ctx) => {
    if (!ready) ctx.skip();
    await admin.unsafe(
      `CREATE DATABASE "${WRONG_DB}" OWNER "${OWNER}" TEMPLATE template0 ENCODING 'UTF8' LOCALE 'C.UTF-8'`,
    );
    const err = await prepareTarget(src, server, WRONG_DB).catch((e) => e);
    expect(err).toBeInstanceOf(MoveRefused);
    expect((err as Error).message).toMatch(/already exists with another collation/);
    const [still] = await admin.unsafe<{ n: number }[]>(
      `SELECT count(*)::int AS n FROM pg_database WHERE datname = $1`,
      [WRONG_DB],
    );
    expect(still.n).toBe(1);
  });
});
