import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";

/**
 * Server-only Postgres client. Prefers DATABASE_URL (the pooled, transaction
 * mode connection) but self-heals: when DATABASE_URL and DIRECT_DATABASE_URL
 * are both set and only the direct one is reachable, it runs on the direct
 * connection instead, so one mistyped URI does not take the platform down.
 * Lazily initialised so importing this module during a build without any
 * database variables does not crash; the first query needs one set.
 */
type DrizzleDb = ReturnType<typeof drizzle<typeof schema>>;

export type DatabaseSource = "DATABASE_URL" | "DIRECT_DATABASE_URL";

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
  const primary = process.env.DATABASE_URL;
  const fallback = process.env.DIRECT_DATABASE_URL;
  if (!primary) return fallback ? { url: fallback, source: "DIRECT_DATABASE_URL" } : null;
  if (!fallback || fallback === primary) return { url: primary, source: "DATABASE_URL" };
  if (await reachable(primary)) return { url: primary, source: "DATABASE_URL" };
  if (await reachable(fallback)) {
    console.warn(
      "DATABASE_URL is unreachable — falling back to DIRECT_DATABASE_URL. Fix DATABASE_URL (Supabase transaction pooler, port 6543) for pooled connections.",
    );
    return { url: fallback, source: "DIRECT_DATABASE_URL" };
  }
  // Neither answers: keep the primary so its error surfaces in diagnostics.
  return { url: primary, source: "DATABASE_URL" };
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
