/**
 * The copy: every row of `public` and `drizzle` from source to target,
 * all or nothing.
 *
 * 1. The read-only preflight must pass (checkDatabases); a previous copy is
 *    only replaced with `replace`.
 * 2. The target's schema is built from this release's migrations (nothing
 *    to do on a previous copy); its tables and columns must then match the
 *    source's.
 * 3. The source is read in one REPEATABLE READ READ ONLY snapshot and the
 *    target written in one transaction: TRUNCATE everything, insert table by
 *    table in foreign-key order, fill in the deferred cycle columns with the
 *    table's user triggers off (so updated_at is kept), set the sequences.
 * 4. Before committing, every table's digest on the target must equal the
 *    source's in the same snapshot; any difference rolls both back.
 *
 * Rows travel as JSON text (json_agg → json_populate_record), never
 * through JavaScript values, so microsecond timestamps, numeric scale and
 * bigints arrive exactly. json and jsonb columns travel as their own text
 * (cast back on the target), because JSON can't tell a JSON null from SQL
 * NULL. The source must be frozen when the app runs on it (`liveSource`).
 * The snapshot's per-table digests are kept on the target (./snapshot.ts)
 * for `finish`.
 */
import { defaultMigrationsFolder, runMigrationsOn } from "../migrate-core";
import { readCatalog, tableMap, type ColumnInfo, type TableInfo } from "./catalog";
import { checkDatabases, type CheckReport } from "./check";
import { ident, MoveRefused, pinSession, qualified, type MoveSql, type Queryable } from "./connect";
import { describeDeferred, planCopy } from "./plan";
import { recordSnapshot } from "./snapshot";
import { digestAll, fingerprint, type TableDigest } from "./verify";

export type CopyOptions = {
  /** Overwrite a previous copy that already holds rows. */
  replace?: boolean;
  /** Rows per batch (default 500). */
  batchRows?: number;
  /** Give up (and roll back) after this long (default 270 s, inside Vercel's 300 s). */
  budgetMs?: number;
  folder?: string;
  /**
   * The source's name when the app runs on it: then it must be frozen, or writes
   * made after the snapshot would be lost.
   */
  liveSource?: string;
  /** Copy from the live source even so (contingency C2: freezing was refused). */
  allowUnfrozenSource?: boolean;
  /** Test only: throw after inserting this table's rows, to prove nothing is kept. */
  failAfterTable?: string;
};

export type CopyReport = {
  order: string[];
  deferred: string[];
  rows: Record<string, number>;
  totalRows: number;
  /** Fingerprint of the source snapshot that was copied (finish compares against it). */
  fingerprint: string;
  ms: number;
  /** Rows in the target's drizzle.__drizzle_migrations after the copy. */
  migrationsApplied: number;
  /** Migrations run on the target before the copy (0 on a previous copy). */
  migrationsRun: number;
  check: Pick<CheckReport, "readyToCopy" | "warnings"> & { targetState: string };
};

const DRIZZLE_TABLE = "drizzle.__drizzle_migrations";

/** json, jsonb and arrays of them: carried as text, so a JSON null stays apart from SQL NULL. */
export const carriedAsText = (c: Pick<ColumnInfo, "type">): boolean =>
  /^jsonb?(\[\])*$/.test(c.type);

const literal = (s: string): string => `'${s.replaceAll("'", "''")}'`;

function sameColumns(a: TableInfo, b: TableInfo): string | null {
  const names = (t: TableInfo) => t.columns.filter((c) => !c.generated).map((c) => c.name);
  const missing = names(a).filter((c) => !names(b).includes(c));
  const extra = names(b).filter((c) => !names(a).includes(c));
  if (missing.length) return `the target's ${a.key} lacks ${missing.join(", ")}`;
  if (extra.length) return `the target's ${a.key} has extra columns ${extra.join(", ")}`;
  return null;
}

/** One page of rows (as JSON text) after `after`, in primary-key order. */
async function readPage(
  src: Queryable,
  table: TableInfo,
  selectList: string,
  where: string[],
  after: string[] | null,
  limit: number,
): Promise<{ rows: string | null; n: number; last: string[] | null }> {
  const pk = table.pk.map(ident);
  const conditions = [...where];
  if (after) {
    conditions.push(
      `(${pk.map((c) => `t.${c}`).join(", ")}) > (${pk.map((_, i) => `$${i + 1}`).join(", ")})`,
    );
  }
  const [page] = await src.unsafe<{ rows: string | null; n: number; last: string[] | null }[]>(
    `SELECT json_agg(r)::text AS rows, count(*)::int AS n,
            (array_agg(to_json(ARRAY[${pk.map((c) => `r.${c}::text`).join(", ")}])))[count(*)] AS last
     FROM (SELECT ${selectList} FROM ${qualified(table.key)} t
           ${conditions.length ? `WHERE ${conditions.join(" AND ")}` : ""}
           ORDER BY ${pk.map((c) => `t.${c}`).join(", ")} LIMIT ${limit}) r`,
    after ?? [],
  );
  return { rows: page.rows, n: Number(page.n), last: page.last };
}

export async function copyDatabase(
  source: MoveSql,
  target: MoveSql,
  options: CopyOptions = {},
): Promise<CopyReport> {
  const started = Date.now();
  const batchRows = options.batchRows ?? 500;
  const budgetMs = options.budgetMs ?? 270_000;
  const folder = options.folder ?? defaultMigrationsFolder();
  const overBudget = () => {
    if (Date.now() - started > budgetMs) {
      throw new MoveRefused(
        `The copy took longer than ${Math.round(budgetMs / 1000)} s and was rolled back; nothing was written. Try a smaller batch.`,
      );
    }
  };

  // 1. Preflight.
  const check = await checkDatabases(source, target, { folder, liveSource: options.liveSource });
  if (!check.readyToCopy) {
    throw new MoveRefused(`Not ready to copy: ${check.blockers.join("; ")}`, check.blockers);
  }
  if (options.liveSource && !check.source.frozen && !options.allowUnfrozenSource) {
    const db = options.liveSource;
    throw new MoveRefused(
      `Refused: ${db} is the live database and isn't frozen, so writes made after the snapshot would be lost. Freeze it first (step=freeze&db=${db}&confirm=freeze); add unfrozen=1 only if it can't be frozen.`,
    );
  }
  if (
    check.target.state === "previousCopy" &&
    check.target.nonEmptyTables.length &&
    !options.replace
  ) {
    throw new MoveRefused(
      `Target is not empty (${check.target.nonEmptyTables.length} tables hold rows, e.g. ${check.target.nonEmptyTables
        .slice(0, 3)
        .join(", ")}); pass replace=1 to overwrite the previous copy`,
    );
  }

  // Rows are paged and compared in primary-key order (every table has one today),
  // and the foreign keys must allow an insert order: both refused before any write.
  const srcCat = await readCatalog(source);
  const noKey = srcCat.tables.filter((t) => t.pk.length === 0).map((t) => t.key);
  if (noKey.length) throw new MoveRefused(`Tables without a primary key: ${noKey.join(", ")}`);
  planCopy(srcCat);

  // 2. Target schema from this release's migrations.
  const { applied: migrationsRun } = await runMigrationsOn(target, folder);
  const dstCat = await readCatalog(target);
  const srcTables = tableMap(srcCat);
  const dstTables = tableMap(dstCat);
  const missing = [...srcTables.keys()].filter((k) => !dstTables.has(k));
  const extra = [...dstTables.keys()].filter((k) => !srcTables.has(k));
  if (missing.length || extra.length) {
    throw new MoveRefused(
      `After migrating, the target's tables differ from the source's (missing: ${missing.join(", ") || "none"}; extra: ${extra.join(", ") || "none"})`,
    );
  }
  for (const [key, t] of srcTables) {
    const problem = sameColumns(t, dstTables.get(key)!);
    if (problem) throw new MoveRefused(`After migrating, ${problem}`);
  }
  const plan = planCopy(srcCat);
  const rows: Record<string, number> = {};
  let sourceDigests: Record<string, TableDigest> = {};

  // 3–4. One snapshot, one target transaction, checked before commit.
  await source.begin("ISOLATION LEVEL REPEATABLE READ READ ONLY", async (src) => {
    await pinSession(src);
    await src.unsafe(`SET LOCAL statement_timeout = '120s'`);
    await target.begin(async (dst) => {
      await pinSession(dst);
      await dst.unsafe(`SET LOCAL statement_timeout = 0`);
      // Also clears the drizzle rows step 2 wrote; they come back from the source
      // (whose rows were checked equal to this release's journal).
      await dst.unsafe(`TRUNCATE ${plan.order.map(qualified).join(", ")} RESTART IDENTITY`);

      for (const key of plan.order) {
        const t = srcTables.get(key)!;
        const cols = t.columns.filter((c) => !c.generated);
        const nullFirst = new Set(
          plan.deferred.filter((d) => d.table === key).flatMap((d) => d.cols),
        );
        const colList = cols.map((c) => ident(c.name)).join(", ");
        const selectList = cols
          .map((c) =>
            nullFirst.has(c.name)
              ? `NULL AS ${ident(c.name)}`
              : carriedAsText(c)
                ? `t.${ident(c.name)}::text AS ${ident(c.name)}`
                : `t.${ident(c.name)}`,
          )
          .join(", ");
        // Each row's JSON object: typed by the table's row type, except the
        // columns carried as text, which are cast back from it.
        const insertList = cols
          .map((c) =>
            carriedAsText(c) ? `(e.v->>${literal(c.name)})::${c.type}` : `r.${ident(c.name)}`,
          )
          .join(", ");
        const overriding = t.columns.some((c) => c.identity === "a")
          ? "OVERRIDING SYSTEM VALUE"
          : "";
        let after: string[] | null = null;
        let n = 0;
        for (;;) {
          const page = await readPage(src, t, selectList, [], after, batchRows);
          if (!page.n) break;
          await dst.unsafe(
            `INSERT INTO ${qualified(key)} (${colList}) ${overriding}
             SELECT ${insertList}
             FROM json_array_elements($1::text::json) AS e(v),
                  json_populate_record(NULL::${qualified(key)}, e.v) AS r`,
            [page.rows!],
          );
          n += page.n;
          after = page.last;
          overBudget();
          if (page.n < batchRows) break;
        }
        rows[key] = n;
        if (options.failAfterTable === key) {
          throw new Error(`Stopped after ${key} (test)`);
        }
      }

      // Deferred cycle columns, with the table's own triggers off so the
      // UPDATE doesn't touch updated_at (FK triggers are internal and stay on).
      const byTable = new Map<string, string[]>();
      for (const d of plan.deferred)
        byTable.set(d.table, [...(byTable.get(d.table) ?? []), ...d.cols]);
      for (const [key, deferredCols] of byTable) {
        const t = srcTables.get(key)!;
        const cols = [...new Set(deferredCols)];
        const pk = t.pk.map(ident);
        await dst.unsafe(`ALTER TABLE ${qualified(key)} DISABLE TRIGGER USER`);
        let after: string[] | null = null;
        for (;;) {
          const page = await readPage(
            src,
            t,
            [...t.pk, ...cols.filter((c) => !t.pk.includes(c))]
              .map((c) => `t.${ident(c)}`)
              .join(", "),
            [`(${cols.map((c) => `t.${ident(c)} IS NOT NULL`).join(" OR ")})`],
            after,
            batchRows,
          );
          if (!page.n) break;
          await dst.unsafe(
            `UPDATE ${qualified(key)} AS t SET ${cols.map((c) => `${ident(c)} = v.${ident(c)}`).join(", ")}
             FROM json_populate_recordset(NULL::${qualified(key)}, $1::text::json) AS v
             WHERE ${pk.map((c) => `t.${c} = v.${c}`).join(" AND ")}`,
            [page.rows!],
          );
          after = page.last;
          overBudget();
          if (page.n < batchRows) break;
        }
        await dst.unsafe(`ALTER TABLE ${qualified(key)} ENABLE TRIGGER USER`);
      }

      // Sequences: the same next value as the source.
      for (const seq of srcCat.sequences) {
        const [v] = await src.unsafe<{ v: string; called: boolean }[]>(
          `SELECT last_value::text AS v, is_called AS called FROM ${qualified(seq)}`,
        );
        await dst.unsafe(`SELECT setval($1::regclass, $2::bigint, $3)`, [
          qualified(seq),
          v.v,
          v.called,
        ]);
      }

      // In-snapshot check before commit: any difference rolls both back.
      sourceDigests = await digestAll(src, srcCat.tables);
      // The same columns and keys on both sides (checked after migrating).
      const targetDigests = await digestAll(dst, srcCat.tables);
      const differing = Object.keys(sourceDigests).filter(
        (k) =>
          sourceDigests[k].n !== targetDigests[k]?.n ||
          sourceDigests[k].digest !== targetDigests[k]?.digest,
      );
      if (differing.length) {
        throw new Error(
          `The copy does not match its snapshot (${differing
            .map((k) => `${k}: ${sourceDigests[k].n}/${targetDigests[k]?.n ?? "?"} rows`)
            .join("; ")}); nothing was written`,
        );
      }
      // Kept with the copy, for finish to name the source tables changed since.
      await recordSnapshot(dst, fingerprint(sourceDigests), sourceDigests);
      overBudget();
    });
  });

  return {
    order: plan.order,
    deferred: plan.deferred.map(describeDeferred),
    rows,
    totalRows: Object.entries(rows)
      .filter(([k]) => k !== DRIZZLE_TABLE)
      .reduce((sum, [, n]) => sum + n, 0),
    fingerprint: fingerprint(sourceDigests),
    ms: Date.now() - started,
    migrationsApplied: rows[DRIZZLE_TABLE] ?? 0,
    migrationsRun,
    check: { readyToCopy: true, warnings: check.warnings, targetState: check.target.state },
  };
}
