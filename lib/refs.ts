/**
 * Reference generation (brief 4.2): `edition_counters` rows are incremented
 * under `SELECT … FOR UPDATE` inside the caller's transaction, so two
 * concurrent creates can never take the same sequence number. Refs are never
 * reused — the counter only moves forward.
 */
import { sql } from "drizzle-orm";
import type { Tx } from "./db/client";

/** Take the next value of the (edition, key) counter under a row lock. */
export async function nextCounterValue(tx: Tx, editionId: string, key: string): Promise<number> {
  // Ensure the counter row exists (no-op if present).
  await tx.execute(sql`
    INSERT INTO edition_counters (edition_id, key, value)
    VALUES (${editionId}, ${key}, 0)
    ON CONFLICT (edition_id, key) DO NOTHING
  `);
  const rows = await tx.execute(sql`
    SELECT id, value FROM edition_counters
    WHERE edition_id = ${editionId} AND key = ${key}
    FOR UPDATE
  `);
  const row = rows[0] as { id: string; value: number };
  const next = Number(row.value) + 1;
  await tx.execute(sql`UPDATE edition_counters SET value = ${next} WHERE id = ${row.id}`);
  return next;
}

export function formatSignageRef(editionCode: string, seq: number): string {
  return `SIG-${editionCode}-${String(seq).padStart(3, "0")}`;
}

export function formatStandRef(editionCode: string, standNumber: string): string {
  return `STD-${editionCode}-${standNumber}`;
}

export async function nextSignageRef(
  tx: Tx,
  editionId: string,
  editionCode: string,
): Promise<{ ref: string; seq: number }> {
  const seq = await nextCounterValue(tx, editionId, "signage");
  return { ref: formatSignageRef(editionCode, seq), seq };
}
