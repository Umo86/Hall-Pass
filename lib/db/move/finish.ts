/**
 * The move's last step, run on the switched deployment: nothing reached the
 * (frozen) source after the copy — its fingerprint still equals the one the
 * copy reported — and the target has at least as many rows per table. Then
 * one audit row on the target says so. Running it again writes nothing more.
 * On a mismatch it names the source tables that changed since the copy, from
 * the snapshot the copy kept on the target (./snapshot.ts).
 */
import { and, eq, sql as dsql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import { writeAudit } from "../../audit";
import * as schema from "../schema";
import type { MoveSql } from "./connect";
import { changedTables, readSnapshot } from "./snapshot";
import { databaseFingerprint } from "./verify";

export type FinishReport = {
  sourceUnchanged: boolean;
  sourceFingerprint: string;
  /**
   * On a mismatch, the source tables whose rows changed since the copy's
   * snapshot (absent when no copy with `expect` is recorded on the target).
   */
  differingTables?: string[];
  counts: Record<string, { source: number; target: number }>;
  totalRows: number;
  audit: "written" | "already written" | "not written";
  warnings: string[];
};

const DRIZZLE_TABLE = "drizzle.__drizzle_migrations";

export async function finishMove(
  source: MoveSql,
  target: MoveSql,
  {
    expect,
    summary,
  }: {
    /** The fingerprint `copy` returned. */
    expect: string;
    /** The audit summary, given the number of rows verified. */
    summary: (totalRows: number) => string;
  },
): Promise<FinishReport> {
  const src = await databaseFingerprint(source);
  const dst = await databaseFingerprint(target);
  const counts: Record<string, { source: number; target: number }> = {};
  const warnings: string[] = [];
  for (const key of Object.keys(src.digests).sort()) {
    counts[key] = { source: src.digests[key].n, target: dst.digests[key]?.n ?? 0 };
    if (counts[key].target < counts[key].source) {
      warnings.push(
        `${key}: ${counts[key].target} rows on the target, ${counts[key].source} on the source (fine where the app deletes rows, such as sessions and approvers)`,
      );
    }
  }
  const totalRows = Object.entries(counts)
    .filter(([k]) => k !== DRIZZLE_TABLE)
    .reduce((sum, [, c]) => sum + c.source, 0);

  if (src.fingerprint !== expect) {
    const snapshot = await readSnapshot(target, expect);
    if (!snapshot) {
      return {
        sourceUnchanged: false,
        sourceFingerprint: src.fingerprint,
        counts,
        totalRows,
        audit: "not written",
        warnings: [
          "No copy with this fingerprint is recorded on the target: expect must be the fingerprint the copy returned.",
          ...warnings,
        ],
      };
    }
    return {
      sourceUnchanged: false,
      sourceFingerprint: src.fingerprint,
      differingTables: changedTables(snapshot, src.digests),
      counts,
      totalRows,
      audit: "not written",
      warnings: [
        "The source changed after the copy: writes landed on it after the snapshot (differingTables names the tables).",
        ...warnings,
      ],
    };
  }

  const db = drizzle(target, { schema });
  const audit = await db.transaction(async (tx) => {
    const existing = await tx
      .select({ id: schema.auditLog.id })
      .from(schema.auditLog)
      .where(
        and(
          eq(schema.auditLog.entityType, "database"),
          dsql`${schema.auditLog.after}->>'fingerprint' = ${expect}`,
        ),
      )
      .limit(1);
    if (existing.length) return "already written" as const;
    const orgs = await tx
      .select({ id: schema.organisations.id })
      .from(schema.organisations)
      .limit(2);
    await writeAudit(tx, {
      // The organisation, when there is exactly one (Hall Pass runs one per deployment).
      organisationId: orgs.length === 1 ? orgs[0].id : null,
      actorType: "system",
      entityType: "database",
      action: "settings_change",
      summary: summary(totalRows),
      after: {
        fingerprint: expect,
        rows: Object.fromEntries(Object.entries(counts).map(([k, c]) => [k, c.source])),
      },
    });
    return "written" as const;
  });
  return {
    sourceUnchanged: true,
    sourceFingerprint: src.fingerprint,
    counts,
    totalRows,
    audit,
    warnings,
  };
}
