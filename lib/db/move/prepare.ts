/**
 * Makes the target database the move copies into, on the same Neon server,
 * with the source's collation: Neon's own database ("neondb") is C.UTF-8,
 * Supabase's is ICU en-US, and a database's collation can't change once it
 * exists. Idempotent: an existing database with the same collation is kept,
 * one with another is refused (never dropped). Never writes to the source.
 */
import { ident, MoveRefused, type MoveSql } from "./connect";
import { describeLocale, localeFactsOf, sameCollation, type LocaleFacts } from "./check";

export type PrepareReport = {
  database: string;
  created: boolean;
  source: string;
  target: string;
  collationMatch: boolean;
  warnings: string[];
};

const LOCALE_TEXT = /^[A-Za-z0-9_.@-]{1,100}$/;

const messageOf = (err: unknown) => (err instanceof Error ? err.message : String(err));

function literal(value: string, what: string): string {
  if (!LOCALE_TEXT.test(value)) throw new MoveRefused(`The source's ${what} is unusual: ${value}`);
  return `'${value}'`;
}

async function localeOf(sql: MoveSql, database: string): Promise<LocaleFacts | null> {
  const [row] = await sql.unsafe<{ d: Record<string, unknown>; encoding: string }[]>(
    `SELECT to_jsonb(d) AS d, pg_encoding_to_char(d.encoding) AS encoding
     FROM pg_database d WHERE d.datname = $1`,
    [database],
  );
  return row ? localeFactsOf(row.d, row.encoding) : null;
}

/** CREATE DATABASE … with the source's collation; with its LC_* too when `withLibc`. */
export function createDatabaseStatement(name: string, src: LocaleFacts, withLibc: boolean): string {
  const parts = [
    `CREATE DATABASE ${ident(name)} WITH TEMPLATE template0`,
    `ENCODING ${literal(src.encoding, "encoding")}`,
  ];
  if (src.localeProvider === "i") {
    parts.push(`LOCALE_PROVIDER icu ICU_LOCALE ${literal(src.locale ?? "", "ICU locale")}`);
    if (src.icuRules)
      throw new MoveRefused("The source uses custom ICU rules; create the database by hand");
  } else if (src.localeProvider === "b") {
    parts.push(
      `LOCALE_PROVIDER builtin BUILTIN_LOCALE ${literal(src.locale ?? "", "builtin locale")}`,
    );
  } else {
    parts.push("LOCALE_PROVIDER libc");
    withLibc = true;
  }
  if (withLibc) {
    parts.push(`LC_COLLATE ${literal(src.collate, "LC_COLLATE")}`);
    parts.push(`LC_CTYPE ${literal(src.ctype, "LC_CTYPE")}`);
  }
  return parts.join(" ");
}

/**
 * `source` is the database the move copies from; `server` a connection to
 * another database on the target server (the integration's own). `name` is
 * the database to make there.
 */
export async function prepareTarget(
  source: MoveSql,
  server: MoveSql,
  name: string,
): Promise<PrepareReport> {
  const [cur] = await source.unsafe<{ db: string }[]>(`SELECT current_database() AS db`);
  const src = await localeOf(source, cur.db);
  if (!src) throw new MoveRefused("Could not read the source database's collation");
  const warnings: string[] = [];

  let created = false;
  let dst = await localeOf(server, name);
  if (!dst) {
    try {
      // The source's LC_COLLATE/LC_CTYPE too, when the server has them (Neon has few libc locales).
      await server.unsafe(createDatabaseStatement(name, src, true));
    } catch (err) {
      if (src.localeProvider === "c") throw err;
      try {
        await server.unsafe(createDatabaseStatement(name, src, false));
      } catch (second) {
        throw new MoveRefused(
          `Could not create ${name}: ${messageOf(err)}; then ${messageOf(second)}`,
        );
      }
      warnings.push(
        `The server has no ${src.ctype} libc locale (${messageOf(err)}): ${name} keeps its default LC_COLLATE/LC_CTYPE, and text sorts by ${describeLocale(src)} all the same`,
      );
    }
    created = true;
    dst = await localeOf(server, name);
    if (!dst) throw new MoveRefused(`${name} was created but can't be read back`);
  }

  const collationMatch = sameCollation(src, dst);
  if (!collationMatch) {
    throw new MoveRefused(
      `${name} already exists with another collation (${describeLocale(dst)}; the source is ${describeLocale(src)}). Delete it in the Neon console, or choose another NEON_DATABASE.`,
    );
  }
  return {
    database: name,
    created,
    source: describeLocale(src),
    target: describeLocale(dst),
    collationMatch,
    warnings,
  };
}
