/**
 * The move's read-only preflight: what each database is (version, encoding,
 * collation, owner, frozen or not, rows per table), whether the source's
 * applied migrations are exactly the ones bundled with this release, and
 * whether the target is empty, a previous copy, or something else. Nothing
 * is written (the frozen probe is rolled back).
 */
import { bundledMigrations, defaultMigrationsFolder, type BundledMigration } from "../migrate-core";
import { readCatalog, type Catalog } from "./catalog";
import { qualified, type MoveSql, type Queryable } from "./connect";
import { isFrozen, ownsAllTables } from "./freeze";

export type SideFacts = {
  version: string;
  versionNum: number;
  encoding: string;
  collate: string;
  ctype: string;
  localeProvider: string;
  locale: string | null;
  timezone: string;
  user: string;
  frozen: boolean;
  freezeStrategy: "A" | "B" | null;
  /** Tables in public. */
  tables: number;
  ownsAllTables: boolean;
  /** Schemas other than public and drizzle (ignored by the move). */
  otherSchemas: string[];
  /** Objects in public that belong to, or use, an extension (the target wouldn't have them). */
  extensionDependencies: number;
  /** Table privileges in public held by client roles (anon, authenticated, anonymous). */
  clientGrants: Record<string, number>;
  canCreate: boolean;
};

export type TargetState = "empty" | "previousCopy" | "foreign";

export type MigrationsCheck = {
  bundled: number;
  latest: string | null;
  source: number;
  match: boolean;
  mismatches: { tag: string; problem: string }[];
};

export type CheckReport = {
  source: SideFacts & { rows: Record<string, number> };
  target: SideFacts & {
    state: TargetState;
    publicTables: number;
    nonEmptyTables: string[];
    migrationsMatch: boolean;
  };
  migrations: MigrationsCheck;
  collationMatch: boolean;
  readyToCopy: boolean;
  /** Why not ready, in words. */
  blockers: string[];
  warnings: string[];
};

async function sideFacts(sql: MoveSql): Promise<SideFacts> {
  const [db] = await sql.unsafe<
    {
      version: string;
      version_num: string;
      encoding: string;
      timezone: string;
      user: string;
      d: Record<string, unknown>;
      tables: number;
      can_create: boolean | null;
    }[]
  >(`
    SELECT current_setting('server_version') AS version,
           current_setting('server_version_num') AS version_num,
           pg_encoding_to_char(d.encoding) AS encoding,
           current_setting('TimeZone') AS timezone,
           current_user AS user,
           to_jsonb(d) AS d,
           (SELECT count(*)::int FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'public' AND c.relkind IN ('r','p')) AS tables,
           has_database_privilege(current_database(), 'CREATE')
             AND coalesce((SELECT has_schema_privilege(n.oid, 'CREATE') FROM pg_namespace n
                           WHERE n.nspname = 'public'), false) AS can_create
    FROM pg_database d WHERE d.datname = current_database()`);
  const others = await sql.unsafe<{ name: string }[]>(`
    SELECT nspname AS name FROM pg_namespace
    WHERE nspname NOT IN ('public','drizzle','information_schema','pg_catalog','pg_toast')
      AND nspname NOT LIKE 'pg\\_temp\\_%' AND nspname NOT LIKE 'pg\\_toast\\_temp\\_%'
    ORDER BY 1`);
  const [ext] = await sql.unsafe<{ n: number }[]>(`
    SELECT (
      (SELECT count(*) FROM pg_depend d
        JOIN pg_proc p ON d.classid = 'pg_proc'::regclass AND d.objid = p.oid
        WHERE d.deptype = 'e' AND p.pronamespace = 'public'::regnamespace)
    + (SELECT count(*) FROM pg_depend d
        JOIN pg_type t ON d.classid = 'pg_type'::regclass AND d.objid = t.oid
        WHERE d.deptype = 'e' AND t.typnamespace = 'public'::regnamespace)
    + (SELECT count(*) FROM pg_depend d
        JOIN pg_class c ON d.classid = 'pg_class'::regclass AND d.objid = c.oid
        WHERE d.deptype = 'e' AND c.relnamespace = 'public'::regnamespace)
    + (SELECT count(*) FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_depend d ON d.classid = 'pg_type'::regclass AND d.objid = a.atttypid AND d.deptype = 'e'
        WHERE c.relnamespace = 'public'::regnamespace AND a.attnum > 0 AND NOT a.attisdropped)
    + (SELECT count(*) FROM pg_attrdef ad
        JOIN pg_class c ON c.oid = ad.adrelid
        JOIN pg_depend d ON d.classid = 'pg_attrdef'::regclass AND d.objid = ad.oid
                         AND d.refclassid = 'pg_proc'::regclass
        JOIN pg_depend e ON e.classid = 'pg_proc'::regclass AND e.objid = d.refobjid AND e.deptype = 'e'
        WHERE c.relnamespace = 'public'::regnamespace)
    )::int AS n`);
  const grants = await sql.unsafe<{ grantee: string; n: number }[]>(`
    SELECT r.rolname AS grantee, count(*)::int AS n
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    CROSS JOIN LATERAL aclexplode(c.relacl) a
    JOIN pg_roles r ON r.oid = a.grantee
    WHERE n.nspname = 'public' AND c.relkind IN ('r','p')
      AND r.rolname IN ('anon','authenticated','anonymous')
    GROUP BY 1 ORDER BY 1`);
  const frozen = await isFrozen(sql);
  const d = db.d;
  const str = (k: string) => (typeof d[k] === "string" ? (d[k] as string) : null);
  return {
    version: db.version,
    versionNum: Number(db.version_num),
    encoding: db.encoding,
    collate: str("datcollate") ?? "",
    ctype: str("datctype") ?? "",
    localeProvider: str("datlocprovider") ?? "c",
    // Postgres 17 renamed daticulocale to datlocale.
    locale: str("datlocale") ?? str("daticulocale"),
    timezone: db.timezone,
    user: db.user,
    frozen: frozen.frozen,
    freezeStrategy: frozen.strategy,
    tables: Number(db.tables),
    ownsAllTables: await ownsAllTables(sql),
    otherSchemas: others.map((o) => o.name),
    extensionDependencies: Number(ext.n),
    clientGrants: Object.fromEntries(grants.map((g) => [g.grantee, Number(g.n)])),
    canCreate: Boolean(db.can_create),
  };
}

/** Applied rows of drizzle.__drizzle_migrations, oldest first (empty when the table is missing). */
export async function appliedMigrations(q: Queryable): Promise<{ hash: string; when: number }[]> {
  const [exists] = await q.unsafe<{ t: string | null }[]>(
    `SELECT to_regclass('drizzle.__drizzle_migrations')::text AS t`,
  );
  if (!exists.t) return [];
  const rows = await q.unsafe<{ hash: string; created_at: string | null }[]>(
    `SELECT hash, created_at::text AS created_at FROM drizzle.__drizzle_migrations ORDER BY created_at, id`,
  );
  return rows.map((r) => ({ hash: r.hash, when: Number(r.created_at) }));
}

/** Applied rows compared with the bundled journal: every entry applied with the same hash, nothing else. */
export function compareMigrations(
  applied: { hash: string; when: number }[],
  bundled: BundledMigration[],
): { match: boolean; mismatches: { tag: string; problem: string }[] } {
  const mismatches: { tag: string; problem: string }[] = [];
  for (const b of bundled) {
    const row = applied.find((a) => a.when === b.when);
    if (!row) mismatches.push({ tag: b.tag, problem: "not applied" });
    else if (row.hash !== b.hash) mismatches.push({ tag: b.tag, problem: "hash differs" });
  }
  for (const a of applied) {
    if (!bundled.some((b) => b.when === a.when)) {
      mismatches.push({ tag: String(a.when), problem: "applied but not in this release" });
    }
  }
  return { match: mismatches.length === 0 && applied.length === bundled.length, mismatches };
}

async function exactCounts(q: Queryable, catalog: Catalog): Promise<Record<string, number>> {
  const out: Record<string, number> = {};
  for (const t of catalog.tables) {
    const [r] = await q.unsafe<{ n: number }[]>(
      `SELECT count(*)::int AS n FROM ${qualified(t.key)}`,
    );
    out[t.key] = Number(r.n);
  }
  return out;
}

async function nonEmpty(q: Queryable, catalog: Catalog): Promise<string[]> {
  const out: string[] = [];
  for (const t of catalog.tables) {
    const [r] = await q.unsafe<{ any: boolean }[]>(
      `SELECT EXISTS (SELECT 1 FROM ${qualified(t.key)}) AS any`,
    );
    if (r.any) out.push(t.key);
  }
  return out;
}

const DRIZZLE_TABLE = "drizzle.__drizzle_migrations";

/** Read-only preflight of a copy from `source` into `target`. */
export async function checkDatabases(
  source: MoveSql,
  target: MoveSql,
  { folder = defaultMigrationsFolder() }: { folder?: string } = {},
): Promise<CheckReport> {
  const bundled = bundledMigrations(folder);
  const srcFacts = await sideFacts(source);
  const dstFacts = await sideFacts(target);
  const srcCat = await readCatalog(source);
  const dstCat = await readCatalog(target);
  const rows = await exactCounts(source, srcCat);

  const srcApplied = await appliedMigrations(source);
  const srcMig = compareMigrations(srcApplied, bundled);
  const dstMig = compareMigrations(await appliedMigrations(target), bundled);

  const publicNames = (c: Catalog) =>
    c.tables
      .filter((t) => t.schema === "public")
      .map((t) => t.key)
      .sort()
      .join(",");
  const dstPublic = dstCat.tables.filter((t) => t.schema === "public").length;
  const state: TargetState =
    dstPublic === 0
      ? "empty"
      : publicNames(dstCat) === publicNames(srcCat) && dstMig.match
        ? "previousCopy"
        : "foreign";
  const nonEmptyTables = (await nonEmpty(target, dstCat)).filter((k) => k !== DRIZZLE_TABLE);

  const collationMatch =
    srcFacts.collate === dstFacts.collate &&
    srcFacts.ctype === dstFacts.ctype &&
    srcFacts.localeProvider === dstFacts.localeProvider &&
    (srcFacts.localeProvider === "c" || srcFacts.locale === dstFacts.locale);

  const blockers: string[] = [];
  const warnings: string[] = [];
  if (dstFacts.versionNum < 160000) blockers.push("The target is older than Postgres 16");
  if (Math.floor(dstFacts.versionNum / 10000) !== Math.floor(srcFacts.versionNum / 10000)) {
    warnings.push(
      `Different Postgres major versions (source ${srcFacts.version}, target ${dstFacts.version}): verify compares the schema text, and detail=1 lists any difference.`,
    );
  }
  if (state === "foreign") {
    blockers.push(
      "The target holds other tables or another migration history (state foreign): it is not empty and not a previous copy",
    );
  }
  if (!srcMig.match) {
    blockers.push(
      `The source's applied migrations differ from this release's (${srcMig.mismatches
        .map((m) => `${m.tag}: ${m.problem}`)
        .join("; ")})`,
    );
  }
  if (!collationMatch) blockers.push("The two databases sort text differently (collation)");
  if (!dstFacts.ownsAllTables) blockers.push("The target's tables are not all owned by its user");
  if (!dstFacts.canCreate) blockers.push("The target's user can't create tables");
  if (dstFacts.frozen) blockers.push("The target is frozen: unfreeze it first");
  if (srcFacts.extensionDependencies > 0) {
    blockers.push("The source's public schema uses extension objects the target won't have");
  }
  for (const [side, facts] of [
    ["source", srcFacts],
    ["target", dstFacts],
  ] as const) {
    const grants = Object.entries(facts.clientGrants);
    if (grants.length) {
      warnings.push(
        `Client roles hold table privileges on the ${side} (${grants
          .map(([r, n]) => `${r}: ${n}`)
          .join(", ")}); row level security with no policies still denies them`,
      );
    }
  }

  return {
    source: { ...srcFacts, rows },
    target: {
      ...dstFacts,
      state,
      publicTables: dstPublic,
      nonEmptyTables,
      migrationsMatch: dstMig.match,
    },
    migrations: {
      bundled: bundled.length,
      latest: bundled.at(-1)?.tag ?? null,
      source: srcApplied.length,
      match: srcMig.match,
      mismatches: srcMig.mismatches,
    },
    collationMatch,
    readyToCopy: blockers.length === 0,
    blockers,
    warnings,
  };
}
