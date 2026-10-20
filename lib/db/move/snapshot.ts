/**
 * The per-table digests of each copy's source snapshot, kept on the target
 * in the copy's own transaction (schema `db_move`, outside `public` and
 * `drizzle`, so the copy, verify, backups and the app never see it). `finish`
 * reads them to name exactly the source tables that changed after the copy,
 * whatever the app has written on the target since. Phase 3 drops the schema
 * with the tool.
 */
import type { Queryable } from "./connect";
import type { TableDigest } from "./verify";

export const SNAPSHOT_SCHEMA = "db_move";

/** Records (or refreshes) the snapshot behind `fingerprint`; call inside the target's copy transaction. */
export async function recordSnapshot(
  q: Queryable,
  fingerprint: string,
  digests: Record<string, TableDigest>,
): Promise<void> {
  await q.unsafe(`CREATE SCHEMA IF NOT EXISTS ${SNAPSHOT_SCHEMA}`);
  await q.unsafe(`
    CREATE TABLE IF NOT EXISTS ${SNAPSHOT_SCHEMA}.snapshots (
      fingerprint text PRIMARY KEY,
      digests jsonb NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    )`);
  // Deny by default, like every table (the owner isn't subject to it).
  await q.unsafe(`ALTER TABLE ${SNAPSHOT_SCHEMA}.snapshots ENABLE ROW LEVEL SECURITY`);
  await q.unsafe(
    `INSERT INTO ${SNAPSHOT_SCHEMA}.snapshots (fingerprint, digests) VALUES ($1, $2::text::jsonb)
     ON CONFLICT (fingerprint) DO UPDATE SET digests = EXCLUDED.digests, updated_at = now()`,
    [fingerprint, JSON.stringify(digests)],
  );
}

/** The snapshot a copy with this fingerprint recorded on this database, or null. */
export async function readSnapshot(
  q: Queryable,
  fingerprint: string,
): Promise<Record<string, TableDigest> | null> {
  const [exists] = await q.unsafe<{ t: string | null }[]>(
    `SELECT to_regclass('${SNAPSHOT_SCHEMA}.snapshots')::text AS t`,
  );
  if (!exists?.t) return null;
  const [row] = await q.unsafe<{ digests: string }[]>(
    `SELECT digests::text AS digests FROM ${SNAPSHOT_SCHEMA}.snapshots WHERE fingerprint = $1`,
    [fingerprint],
  );
  return row ? (JSON.parse(row.digests) as Record<string, TableDigest>) : null;
}

/** Tables whose rows differ between two sets of digests (either side may lack one), sorted. */
export function changedTables(
  before: Record<string, TableDigest>,
  now: Record<string, TableDigest>,
): string[] {
  const keys = new Set([...Object.keys(before), ...Object.keys(now)]);
  return [...keys]
    .filter((k) => before[k]?.n !== now[k]?.n || before[k]?.digest !== now[k]?.digest)
    .sort();
}
