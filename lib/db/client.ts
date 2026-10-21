import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";
import {
  appDatabaseUrl,
  databaseNameOf,
  databaseProjectOf,
  databaseProviderOf,
  databaseRegionOf,
  databaseTarget,
  type DatabaseProvider,
  type DatabaseTarget,
} from "./urls";

/**
 * Server-only Postgres client. Which URL it uses is decided by
 * lib/db/urls.ts:appDatabaseUrl:
 * - DATABASE_TARGET=neon: the Neon integration's pooled POSTGRES_URL, with
 *   no probing and no fallback;
 * - otherwise (local development, CI): the candidate variables in order,
 *   and the first reachable one wins, so one mistyped or stale URI does not
 *   take the platform down. On Vercel a Neon URL is never a candidate here
 *   (Neon only through the switch), and Preview deployments get no database
 *   unless DATABASE_TARGET is set for Preview.
 * Lazily initialised so importing this module during a build without any
 * database variables does not crash; the first query needs one set.
 */
type DrizzleDb = ReturnType<typeof drizzle<typeof schema>>;

/** Where the live connection points (no credentials), for /api/health and Settings → System. */
export type DatabaseInfo = {
  /** The environment variable the URL came from. */
  via: string;
  provider: DatabaseProvider;
  project: string | null;
  region: string | null;
  /** The database's name on its server (NEON_DATABASE on Neon, when set). */
  name: string | null;
  target: Exclude<DatabaseTarget, "invalid">;
  /** Auto mode only: an earlier variable was unreachable, so a later one is used. */
  note?: string;
};

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

type Resolved = { url: string; via: string; note?: string } | { reason: string };

async function resolveConnection(): Promise<Resolved> {
  const choice = appDatabaseUrl(process.env);
  if (choice.kind === "none") return { reason: choice.reason };
  if (choice.kind === "single") return { url: choice.url, via: choice.via };
  const { candidates } = choice;
  if (candidates.length === 1) return candidates[0];
  for (const candidate of candidates) {
    if (await reachable(candidate.url)) {
      if (candidate === candidates[0]) return candidate;
      const note = `Running on ${candidate.via} because an earlier database variable (${candidates[0].via}) is unreachable — everything works, but remove or fix the stale variable when convenient.`;
      console.warn(note);
      return { ...candidate, note };
    }
  }
  // Nothing answers: keep the first so its error surfaces in diagnostics.
  return candidates[0];
}

const resolved = await resolveConnection();

/** The connection actually used (no credentials), or null when there is none. */
export const databaseInfo: DatabaseInfo | null =
  "url" in resolved
    ? {
        via: resolved.via,
        provider: databaseProviderOf(resolved.url),
        project: databaseProjectOf(resolved.url, process.env),
        region: databaseRegionOf(resolved.url),
        name: databaseNameOf(resolved.url),
        target: databaseTarget(process.env) === "neon" ? "neon" : "auto",
        ...(resolved.note ? { note: resolved.note } : {}),
      }
    : null;

/** Why there is no database connection, when there is none. */
export const databaseUnavailableReason: string | null =
  "reason" in resolved ? resolved.reason : null;

/** Which environment variable the live connection came from. Kept for one release; use databaseInfo. */
export const databaseVia: string | null = databaseInfo?.via ?? null;

/** The URL in use, for describeDbError only (server-side; never sent to a browser). */
export function databaseUrlInUse(): string | null {
  return "url" in resolved ? resolved.url : null;
}

let _db: DrizzleDb | null = null;

function getDb(): DrizzleDb {
  if (_db) return _db;
  if (!("url" in resolved)) throw new Error(resolved.reason);
  // Transaction-mode poolers do not support prepared statements. On Neon,
  // idle function instances let go of their connections quickly (the Free
  // plan counts compute time) and a cold endpoint gets time to wake up.
  const client =
    databaseProviderOf(resolved.url) === "neon"
      ? postgres(resolved.url, { prepare: false, max: 5, idle_timeout: 20, connect_timeout: 15 })
      : postgres(resolved.url, { prepare: false });
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
