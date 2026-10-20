import "server-only";
import { sql } from "drizzle-orm";
import type { DatabaseInfo } from "./client";
import { schemaState, type SchemaState } from "./schema-state";
import { databaseTarget, type DatabaseTarget } from "./urls";

/**
 * The database as this deployment sees it — for /api/health, the login
 * page's setup panel and Settings → System. Always about the connection
 * actually used (lib/db/client.ts:databaseInfo), never a variable that
 * merely happens to be set. No credentials: errors go through
 * describeDbError, which only ever echoes the host.
 */
export type DatabaseCheck = {
  info: DatabaseInfo | null;
  target: DatabaseTarget;
  state: "ok" | "unreachable" | "unconfigured";
  /** Why it is unreachable or unconfigured; in auto mode, also the fallback note. */
  error?: string;
  /** Unconfigured on purpose or by mistake (DATABASE_TARGET unknown, a preview), not merely unset. */
  misconfigured: boolean;
  seeded: boolean;
  schema: SchemaState;
};

/**
 * `depth: "ping"` only checks the connection (SELECT 1); `"full"` (the
 * default) reads the organisations count — that query answering is what
 * "ok" means — and the newest applied migration.
 */
export async function checkDatabase({
  depth = "full",
}: { depth?: "ping" | "full" } = {}): Promise<DatabaseCheck> {
  const client = await import("./client");
  const target = databaseTarget(process.env);
  const info = client.databaseInfo;
  if (!info) {
    const reason = client.databaseUnavailableReason ?? "No database is configured";
    return {
      info: null,
      target,
      state: "unconfigured",
      error: reason,
      misconfigured: target !== "auto" || process.env.VERCEL_ENV === "preview",
      seeded: false,
      schema: "unknown",
    };
  }
  let seeded = false;
  let schema: SchemaState = "unknown";
  try {
    if (depth === "ping") {
      await client.db.execute(sql`SELECT 1`);
    } else {
      const rows = await client.db.execute<{ n: number }>(
        sql`SELECT count(*)::int AS n FROM organisations`,
      );
      seeded = Number(rows[0]?.n ?? 0) > 0;
      // Has the migration for this release run? (README → Releasing.)
      try {
        const applied = await client.db.execute<{ at: string | number | null }>(
          sql`SELECT max(created_at) AS at FROM drizzle.__drizzle_migrations`,
        );
        const at = applied[0]?.at;
        schema = schemaState(at == null ? null : Number(at));
      } catch {
        schema = "unknown";
      }
    }
  } catch (err) {
    const { describeDbError } = await import("./diagnose");
    return {
      info,
      target,
      state: "unreachable",
      error: describeDbError(err, client.databaseUrlInUse() ?? undefined, info.via),
      misconfigured: false,
      seeded: false,
      schema: "unknown",
    };
  }
  return {
    info,
    target,
    state: "ok",
    ...(info.note ? { error: info.note } : {}),
    misconfigured: false,
    seeded,
    schema,
  };
}
