/**
 * The move's last step, run on the switched deployment: nothing reached the
 * (frozen) source after the copy — its fingerprint still equals the one the
 * copy reported — and the target has at least as many rows per table. Then
 * one audit row on the target says so. Running it again writes nothing more.
 */
import { and, eq, sql as dsql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import { writeAudit } from "../../audit";
import * as schema from "../schema";
import type { MoveSql } from "./connect";
import { databaseFingerprint } from "./verify";

export type FinishReport = {
  sourceUnchanged: boolean;
  sourceFingerprint: string;
  /** Tables whose digests differ between the two now (after the switch, either side may have changed). */
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
    const differingTables = Object.keys(src.digests)
      .filter((k) => src.digests[k].digest !== dst.digests[k]?.digest)
      .sort();
    return {
      sourceUnchanged: false,
      sourceFingerprint: src.fingerprint,
      differingTables,
      counts,
      totalRows,
      audit: "not written",
      warnings: [
        "The source changed after the copy (or expect is not the copy's fingerprint): writes may have landed on the source after the snapshot.",
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
