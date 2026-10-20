/**
 * The catalog facts the move needs, for schemas `public` and `drizzle`
 * only (every other schema — Supabase's auth/storage/extensions, Neon's
 * neon_auth — is ignored): tables, columns, primary keys, foreign keys and
 * sequences. Plain data (no Maps), so a real catalog can be kept as a JSON
 * fixture for the pure planner's tests.
 */
import type { Queryable } from "./connect";

export const MOVE_SCHEMAS = ["public", "drizzle"] as const;

export type ColumnInfo = {
  name: string;
  type: string;
  notNull: boolean;
  generated: boolean;
  /** "a" (always), "d" (by default) or "" (not an identity column). */
  identity: string;
};

export type ForeignKey = {
  name: string;
  /** "schema.table" of the referenced table. */
  ref: string;
  cols: string[];
  /** Every column of the key accepts NULL, so the row can be inserted first and the key filled in later. */
  nullable: boolean;
};

export type TableInfo = {
  /** "schema.table" */
  key: string;
  schema: string;
  name: string;
  rls: boolean;
  columns: ColumnInfo[];
  pk: string[];
  fks: ForeignKey[];
};

export type Catalog = {
  tables: TableInfo[];
  /** "schema.sequence" */
  sequences: string[];
};

const SCHEMAS = `ARRAY['public','drizzle']::text[]`;

export async function readCatalog(q: Queryable): Promise<Catalog> {
  const tables = await q.unsafe<{ schema: string; name: string; rls: boolean }[]>(`
    SELECT n.nspname AS schema, c.relname AS name, c.relrowsecurity AS rls
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind IN ('r','p') AND n.nspname = ANY(${SCHEMAS})
    ORDER BY 1, 2`);
  const columns = await q.unsafe<
    {
      schema: string;
      table: string;
      name: string;
      type: string;
      not_null: boolean;
      generated: boolean;
      identity: string;
    }[]
  >(`
    SELECT n.nspname AS schema, c.relname AS table, a.attname AS name,
           format_type(a.atttypid, a.atttypmod) AS type, a.attnotnull AS not_null,
           a.attgenerated <> '' AS generated, a.attidentity::text AS identity
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind IN ('r','p') AND n.nspname = ANY(${SCHEMAS})
      AND a.attnum > 0 AND NOT a.attisdropped
    ORDER BY 1, 2, a.attnum`);
  const pks = await q.unsafe<{ schema: string; table: string; cols: string[] }[]>(`
    SELECT n.nspname AS schema, c.relname AS table,
           array_agg(a.attname::text ORDER BY k.ord) AS cols
    FROM pg_constraint x
    JOIN pg_class c ON c.oid = x.conrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN LATERAL unnest(x.conkey) WITH ORDINALITY k(attnum, ord) ON true
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = k.attnum
    WHERE x.contype = 'p' AND n.nspname = ANY(${SCHEMAS})
    GROUP BY 1, 2`);
  const fks = await q.unsafe<
    {
      name: string;
      schema: string;
      table: string;
      ref_schema: string;
      ref_table: string;
      cols: string[];
      nullable: boolean;
    }[]
  >(`
    SELECT x.conname AS name, cn.nspname AS schema, c.relname AS table,
           pn.nspname AS ref_schema, p.relname AS ref_table,
           array_agg(a.attname::text ORDER BY k.ord) AS cols,
           bool_and(NOT a.attnotnull) AS nullable
    FROM pg_constraint x
    JOIN pg_class c ON c.oid = x.conrelid
    JOIN pg_namespace cn ON cn.oid = c.relnamespace
    JOIN pg_class p ON p.oid = x.confrelid
    JOIN pg_namespace pn ON pn.oid = p.relnamespace
    JOIN LATERAL unnest(x.conkey) WITH ORDINALITY k(attnum, ord) ON true
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = k.attnum
    WHERE x.contype = 'f' AND cn.nspname = ANY(${SCHEMAS})
    GROUP BY 1, 2, 3, 4, 5
    ORDER BY 2, 3, 1`);
  const sequences = await q.unsafe<{ schema: string; name: string }[]>(`
    SELECT schemaname AS schema, sequencename AS name
    FROM pg_sequences WHERE schemaname = ANY(${SCHEMAS})
    ORDER BY 1, 2`);

  const byKey = new Map<string, TableInfo>();
  for (const t of tables) {
    const key = `${t.schema}.${t.name}`;
    byKey.set(key, {
      key,
      schema: t.schema,
      name: t.name,
      rls: t.rls,
      columns: [],
      pk: [],
      fks: [],
    });
  }
  for (const c of columns) {
    byKey.get(`${c.schema}.${c.table}`)?.columns.push({
      name: c.name,
      type: c.type,
      notNull: c.not_null,
      generated: c.generated,
      identity: c.identity ?? "",
    });
  }
  for (const p of pks) {
    const t = byKey.get(`${p.schema}.${p.table}`);
    if (t) t.pk = [...p.cols];
  }
  for (const f of fks) {
    byKey.get(`${f.schema}.${f.table}`)?.fks.push({
      name: f.name,
      ref: `${f.ref_schema}.${f.ref_table}`,
      cols: [...f.cols],
      nullable: f.nullable,
    });
  }
  return {
    tables: [...byKey.values()],
    sequences: sequences.map((s) => `${s.schema}.${s.name}`),
  };
}

/** Tables by "schema.table". */
export function tableMap(catalog: Pick<Catalog, "tables">): Map<string, TableInfo> {
  return new Map(catalog.tables.map((t) => [t.key, t]));
}
