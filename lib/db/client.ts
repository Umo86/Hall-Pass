import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";

/**
 * Server-only Postgres client. Works with any plain Postgres: Vercel
 * Postgres/Neon (whose integration injects POSTGRES_URL and friends),
 * Supabase poolers, or a local database. Candidates are tried in order and
 * the first reachable one wins, so one mistyped or stale URI does not take
 * the platform down. Lazily initialised so importing this module during a
 * build without any database variables does not crash; the first query
 * needs one set.
 */
type DrizzleDb = ReturnType<typeof drizzle<typeof schema>>;

// Priority order: our own names first, then what Vercel's database
// integrations inject automatically.
const CANDIDATE_VARS = [
  "DATABASE_URL",
  "DIRECT_DATABASE_URL",
  "POSTGRES_URL",
  "DATABASE_URL_UNPOOLED",
  "POSTGRES_URL_NON_POOLING",
] as const;

export type DatabaseSource = (typeof CANDIDATE_VARS)[number];

async function reachable(url: string): Promise<boolean> {
  const probe = postgres(url, { max: 1, prepare: false, connect_timeout: 8 });
  try {
    await probe`SELECT 1`;
    return true;
  } catch {
    return false;
  } finally {
    await probe.end({ timeout: 2 }).catch(() => {});
  }
}

async function resolveConnection(): Promise<{ url: string; source: DatabaseSource } | null> {
  const candidates: Array<{ url: string; source: DatabaseSource }> = [];
  for (const name of CANDIDATE_VARS) {
    const url = process.env[name];
    if (url && !candidates.some((c) => c.url === url)) candidates.push({ url, source: name });
  }
  if (candidates.length === 0) return null;
  if (candidates.length === 1) return candidates[0];
  for (const candidate of candidates) {
    if (await reachable(candidate.url)) {
      if (candidate !== candidates[0]) {
        console.warn(
          `${candidates[0].source} is unreachable — running on ${candidate.source} instead. Fix or remove the stale variable when convenient.`,
        );
      }
      return candidate;
    }
  }
  // Nothing answers: keep the first so its error surfaces in diagnostics.
  return candidates[0];
}

const resolved = await resolveConnection();

/** Which environment variable the live connection came from, for /api/health. */
export const databaseVia: DatabaseSource | null = resolved?.source ?? null;

let _db: DrizzleDb | null = null;

function getDb(): DrizzleDb {
  if (_db) return _db;
  if (!resolved) {
    throw new Error("DATABASE_URL is not set");
  }
  // Transaction-mode poolers do not support prepared statements.
  const client = postgres(resolved.url, { prepare: false });
  _db = drizzle(client, { schema });
  return _db;
}

export const db: DrizzleDb = new Proxy({} as DrizzleDb, {
  get(_target, prop, receiver) {
    const real = getDb() as unknown as Record<string | symbol, unknown>;
    const value = Reflect.get(real, prop, receiver);
    return typeof value === "function" ? (value as (...a: unknown[]) => unknown).bind(real) : value;
  },
});

export type Db = DrizzleDb;
export type Tx = Parameters<Parameters<DrizzleDb["transaction"]>[0]>[0];
