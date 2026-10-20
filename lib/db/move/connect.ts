/**
 * Connections for the one-off database move (app/api/admin/move-database):
 * one per database per request, a single session each (the copy holds one
 * snapshot on the source and one transaction on the target), no prepared
 * statements (poolers), Neon's channel_binding dropped. Callers `end()` them
 * in `finally`.
 */
import postgres from "postgres";
import { normaliseDatabaseUrl } from "../urls";

export type MoveSql = postgres.Sql;
/** Anything that runs a query: a connection or a transaction on it. */
export type Queryable = Pick<postgres.Sql, "unsafe">;

export function connectForMove(url: string): MoveSql {
  return postgres(normaliseDatabaseUrl(url), {
    max: 1,
    prepare: false,
    connect_timeout: 15,
    onnotice: () => {},
  });
}

/** A refusal the caller can act on (HTTP 409): nothing was changed. */
export class MoveRefused extends Error {
  readonly reasons: string[];
  constructor(message: string, reasons: string[] = []) {
    super(message);
    this.name = "MoveRefused";
    this.reasons = reasons;
  }
}

/** Quotes an identifier ("schema.table" → "schema"."table" via qualified()). */
export const ident = (s: string): string => `"${s.replaceAll('"', '""')}"`;
export const qualified = (key: string): string => key.split(".").map(ident).join(".");

/**
 * Session settings pinned in every move transaction, so text output (and so
 * every digest) is the same on any server: UTC, ISO dates.
 */
export const SESSION_SETTINGS = [
  "SET LOCAL TimeZone = 'UTC'",
  "SET LOCAL DateStyle = 'ISO, YMD'",
  "SET LOCAL IntervalStyle = 'postgres'",
  "SET LOCAL extra_float_digits = 1",
  "SET LOCAL bytea_output = 'hex'",
];

export async function pinSession(q: Queryable): Promise<void> {
  for (const statement of SESSION_SETTINGS) await q.unsafe(statement);
}
