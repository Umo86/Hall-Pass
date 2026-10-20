/**
 * Comparing two databases for the move: a digest of every table's rows, a
 * signature of the schema (functions, triggers, constraints, indexes, enums,
 * row level security, columns), sequences, and one fingerprint of all the
 * data. Equal data gives equal digests on any server: columns are taken in
 * name order, rows in primary-key order compared as text in the "C"
 * collation, and the session settings that shape text output are pinned.
 * ACLs and owners are left out on purpose (they legitimately differ between
 * providers).
 */
import { createHash } from "node:crypto";
import { readCatalog, tableMap, type TableInfo } from "./catalog";
import { ident, pinSession, qualified, type MoveSql, type Queryable } from "./connect";

export type TableDigest = { n: number; digest: string };

/** Row count and md5 of every row (columns by name), in primary-key order. */
export async function tableDigest(
  q: Queryable,
  table: Pick<TableInfo, "key" | "pk">,
  columns: string[],
): Promise<TableDigest> {
  const cols = [...columns].sort();
  const row = `ROW(${cols.map((c) => `t.${ident(c)}`).join(", ")})::text`;
  const order = (table.pk.length ? table.pk : cols)
    .map((c) => `t.${ident(c)}::text COLLATE "C"`)
    .join(", ");
  const [r] = await q.unsafe<{ n: number; digest: string }[]>(
    `SELECT count(*)::int AS n,
            coalesce(md5(string_agg(md5(${row}), '' ORDER BY ${order})), md5('')) AS digest
     FROM ${qualified(table.key)} t`,
  );
  return { n: Number(r.n), digest: r.digest };
}

/** md5 over "table:count:digest" lines in table order: one value for all the data. */
export function fingerprint(digests: Record<string, TableDigest>): string {
  const lines = Object.keys(digests)
    .sort()
    .map((k) => `${k}:${digests[k].n}:${digests[k].digest}`);
  return createHash("md5").update(lines.join("\n")).digest("hex");
}

/** Digests of every table in the catalog, on one snapshot (pass a transaction). */
export async function digestAll(
  q: Queryable,
  tables: TableInfo[],
): Promise<Record<string, TableDigest>> {
  const out: Record<string, TableDigest> = {};
  for (const t of [...tables].sort((a, b) => (a.key < b.key ? -1 : 1))) {
    out[t.key] = await tableDigest(
      q,
      t,
      t.columns.map((c) => c.name),
    );
  }
  return out;
}

/** Fingerprint of a whole database, read in one REPEATABLE READ READ ONLY snapshot. */
export async function databaseFingerprint(
  sql: MoveSql,
): Promise<{ fingerprint: string; digests: Record<string, TableDigest> }> {
  const catalog = await readCatalog(sql);
  const digests = await sql.begin("ISOLATION LEVEL REPEATABLE READ READ ONLY", async (tx) => {
    await pinSession(tx);
    return digestAll(tx, catalog.tables);
  });
  return { fingerprint: fingerprint(digests), digests };
}

type ListName = "functions" | "triggers" | "constraints" | "indexes" | "enums" | "rls" | "columns";

export type SchemaSignature = {
  functionCount: number;
  triggerCount: number;
  /** By contype; NOT NULL rows (contype 'n', Postgres 18) are left out — columns cover nullability. */
  constraintCounts: Record<string, number>;
  indexCount: number;
  enumCount: number;
  tablesWithRls: number;
  columnCount: number;
} & Record<ListName, string | string[]>;

/** Constraint kinds compared (PG 18's 'n' NOT NULL rows are not: columns carry nullability). */
const CONTYPES = `('c','f','p','u','t','x')`;

/**
 * The schema of `public`, as lists (detail) or md5s of them. Every list is
 * sorted in the "C" collation, so the order can't depend on the server's
 * default collation.
 */
export async function schemaSignature(
  q: Queryable,
  { detail = false }: { detail?: boolean } = {},
): Promise<SchemaSignature> {
  const [r] = await q.unsafe<
    (Record<ListName, string[] | null> & { counts: Record<string, number> | null })[]
  >(`
    SELECT
      (SELECT json_agg(x ORDER BY x COLLATE "C") FROM (
         SELECT p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')=' || md5(p.prosrc) AS x
         FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public') s) AS functions,
      (SELECT json_agg(x ORDER BY x COLLATE "C") FROM (
         SELECT c.relname || '.' || t.tgname || ':' || t.tgenabled::text || ':' || pg_get_triggerdef(t.oid) AS x
         FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'public' AND NOT t.tgisinternal) s) AS triggers,
      (SELECT json_object_agg(contype, n) FROM (
         SELECT x.contype::text AS contype, count(*)::int AS n
         FROM pg_constraint x JOIN pg_namespace n ON n.oid = x.connamespace
         WHERE n.nspname = 'public' AND x.contype IN ${CONTYPES}
         GROUP BY 1 ORDER BY 1) s) AS counts,
      (SELECT json_agg(x ORDER BY x COLLATE "C") FROM (
         SELECT c.relname || '.' || x.conname || '=' || pg_get_constraintdef(x.oid) AS x
         FROM pg_constraint x JOIN pg_class c ON c.oid = x.conrelid JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'public' AND x.contype IN ${CONTYPES}) s) AS constraints,
      (SELECT json_agg(x ORDER BY x COLLATE "C") FROM (
         SELECT indexname || '=' || indexdef AS x FROM pg_indexes WHERE schemaname = 'public') s) AS indexes,
      (SELECT json_agg(x ORDER BY x COLLATE "C") FROM (
         SELECT t.typname || '=' || coalesce((SELECT string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder)
                                              FROM pg_enum e WHERE e.enumtypid = t.oid), '') AS x
         FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
         WHERE n.nspname = 'public' AND t.typtype = 'e') s) AS enums,
      (SELECT json_agg(x ORDER BY x COLLATE "C") FROM (
         SELECT c.relname || ':' || c.relrowsecurity::text || ':' || c.relforcerowsecurity::text AS x
         FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'public' AND c.relkind IN ('r','p')) s) AS rls,
      (SELECT json_agg(x ORDER BY x COLLATE "C") FROM (
         SELECT table_name || '.' || column_name || ':' || data_type || ':' || udt_name || ':'
                || is_nullable || ':' || coalesce(column_default, '') AS x
         FROM information_schema.columns WHERE table_schema = 'public') s) AS columns
  `);
  const list = (name: ListName): string[] => (r[name] ?? []) as string[];
  const shown = (name: ListName): string | string[] =>
    detail ? list(name) : createHash("md5").update(list(name).join("\n")).digest("hex");
  return {
    functionCount: list("functions").length,
    triggerCount: list("triggers").length,
    constraintCounts: r.counts ?? {},
    indexCount: list("indexes").length,
    enumCount: list("enums").length,
    tablesWithRls: list("rls").filter((x) => x.includes(":true:")).length,
    columnCount: list("columns").length,
    functions: shown("functions"),
    triggers: shown("triggers"),
    constraints: shown("constraints"),
    indexes: shown("indexes"),
    enums: shown("enums"),
    rls: shown("rls"),
    columns: shown("columns"),
  };
}

/** Names of the signature fields that differ. */
export function signatureDifferences(a: SchemaSignature, b: SchemaSignature): string[] {
  const keys = Object.keys(a) as (keyof SchemaSignature)[];
  return keys.filter((k) => JSON.stringify(a[k]) !== JSON.stringify(b[k]));
}

export type TableComparison = {
  source: number | null;
  target: number | null;
  match: boolean;
  note?: string;
};

export type VerifyReport = {
  ok: boolean;
  tables: Record<string, TableComparison>;
  mismatched: string[];
  sequences: Record<string, { source: string | null; target: string | null; match: boolean }>;
  schema: {
    match: boolean;
    differences: string[];
    source: SchemaSignature;
    target: SchemaSignature;
  };
  sourceFingerprint: string;
  targetFingerprint: string;
};

async function sequenceState(q: Queryable, key: string): Promise<string> {
  const [r] = await q.unsafe<{ v: string; called: boolean }[]>(
    `SELECT last_value::text AS v, is_called AS called FROM ${qualified(key)}`,
  );
  return `${r.v}:${r.called}`;
}

/**
 * Live comparison of two databases, each read in its own REPEATABLE READ
 * READ ONLY transaction: per-table counts and digests, sequences, the schema
 * signature and both fingerprints.
 */
export async function verifyDatabases(
  source: MoveSql,
  target: MoveSql,
  { detail = false }: { detail?: boolean } = {},
): Promise<VerifyReport> {
  const [srcCat, dstCat] = [await readCatalog(source), await readCatalog(target)];
  const srcTables = tableMap(srcCat);
  const dstTables = tableMap(dstCat);
  const report: VerifyReport = {
    ok: true,
    tables: {},
    mismatched: [],
    sequences: {},
    schema: {
      match: false,
      differences: [],
      source: undefined as unknown as SchemaSignature,
      target: undefined as unknown as SchemaSignature,
    },
    sourceFingerprint: "",
    targetFingerprint: "",
  };
  const srcDigests: Record<string, TableDigest> = {};
  const dstDigests: Record<string, TableDigest> = {};
  await source.begin("ISOLATION LEVEL REPEATABLE READ READ ONLY", async (src) => {
    await pinSession(src);
    await target.begin("ISOLATION LEVEL REPEATABLE READ READ ONLY", async (dst) => {
      await pinSession(dst);
      const keys = [...new Set([...srcTables.keys(), ...dstTables.keys()])].sort();
      for (const key of keys) {
        const s = srcTables.get(key);
        const t = dstTables.get(key);
        if (s)
          srcDigests[key] = await tableDigest(
            src,
            s,
            s.columns.map((c) => c.name),
          );
        if (t)
          dstDigests[key] = await tableDigest(
            dst,
            t,
            t.columns.map((c) => c.name),
          );
        let match = Boolean(s && t);
        let note: string | undefined;
        if (!s) note = "only on the target";
        else if (!t) note = "missing on the target";
        else {
          const a = s.columns
            .map((c) => c.name)
            .sort()
            .join(",");
          const b = t.columns
            .map((c) => c.name)
            .sort()
            .join(",");
          if (a !== b) {
            match = false;
            note = "the columns differ";
          } else {
            match =
              srcDigests[key].n === dstDigests[key].n &&
              srcDigests[key].digest === dstDigests[key].digest;
            if (!match) note = "the rows differ";
          }
        }
        report.tables[key] = {
          source: srcDigests[key]?.n ?? null,
          target: dstDigests[key]?.n ?? null,
          match,
          ...(note ? { note } : {}),
        };
        if (!match) report.mismatched.push(key);
      }
      const seqs = [...new Set([...srcCat.sequences, ...dstCat.sequences])].sort();
      for (const key of seqs) {
        const a = srcCat.sequences.includes(key) ? await sequenceState(src, key) : null;
        const b = dstCat.sequences.includes(key) ? await sequenceState(dst, key) : null;
        report.sequences[key] = { source: a, target: b, match: a !== null && a === b };
      }
      const sigA = await schemaSignature(src, { detail });
      const sigB = await schemaSignature(dst, { detail });
      const differences = signatureDifferences(sigA, sigB);
      report.schema = { match: differences.length === 0, differences, source: sigA, target: sigB };
    });
  });
  report.sourceFingerprint = fingerprint(srcDigests);
  report.targetFingerprint = fingerprint(dstDigests);
  report.ok =
    report.mismatched.length === 0 &&
    report.schema.match &&
    Object.values(report.sequences).every((s) => s.match);
  return report;
}
