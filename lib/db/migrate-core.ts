/**
 * Running and listing the repo's drizzle migrations: shared by `pnpm
 * db:migrate` (lib/db/migrate.ts), the "Database migrate" workflow (which
 * runs that script) and the one-off move tool, which builds the target's
 * schema from these files and compares the source's applied rows with them.
 * The route bundles the folder through next.config.ts
 * outputFileTracingIncludes.
 */
import { readFileSync } from "node:fs";
import path from "node:path";
import { drizzle } from "drizzle-orm/postgres-js";
import { readMigrationFiles } from "drizzle-orm/migrator";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";
import { normaliseDatabaseUrl } from "./urls";

export type Sql = ReturnType<typeof postgres>;

/** The migrations folder at run time (repo root locally; the traced copy on Vercel). */
export function defaultMigrationsFolder(): string {
  return path.join(process.cwd(), "lib/db/migrations");
}

/** One bundled migration: its tag, the sha256 drizzle records, and its journal time. */
export type BundledMigration = { tag: string; hash: string; when: number };

/** Every migration in the folder, in journal order, as drizzle would record it once applied. */
export function bundledMigrations(folder = defaultMigrationsFolder()): BundledMigration[] {
  const files = readMigrationFiles({ migrationsFolder: folder });
  const journal = JSON.parse(readFileSync(path.join(folder, "meta/_journal.json"), "utf8")) as {
    entries: { tag: string; when: number }[];
  };
  return files.map((f, i) => ({
    tag: journal.entries[i]?.tag ?? `#${i}`,
    hash: f.hash,
    when: f.folderMillis,
  }));
}

async function appliedCount(sql: Sql): Promise<number> {
  const [exists] = await sql<{ t: string | null }[]>`
    SELECT to_regclass('drizzle.__drizzle_migrations')::text AS t`;
  if (!exists?.t) return 0;
  const [row] = await sql<
    { n: number }[]
  >`SELECT count(*)::int AS n FROM drizzle.__drizzle_migrations`;
  return Number(row?.n ?? 0);
}

/** Applies what's missing on an open connection; `applied` = rows drizzle added. */
export async function runMigrationsOn(
  sql: Sql,
  folder = defaultMigrationsFolder(),
): Promise<{ applied: number; total: number }> {
  const before = await appliedCount(sql);
  await migrate(drizzle(sql), { migrationsFolder: folder });
  const total = await appliedCount(sql);
  return { applied: total - before, total };
}

/** Applies what's missing on the database at `url` (a direct connection: migrations need a session). */
export async function runMigrations(
  url: string,
  folder = defaultMigrationsFolder(),
): Promise<{ applied: number; total: number }> {
  const sql = postgres(normaliseDatabaseUrl(url), {
    max: 1,
    prepare: false,
    onnotice: () => {},
  });
  try {
    return await runMigrationsOn(sql, folder);
  } finally {
    await sql.end({ timeout: 5 });
  }
}
