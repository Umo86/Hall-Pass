/**
 * Making a database read-only for the move, so no write can land on it
 * after the copy's snapshot (and be lost).
 *
 * Strategy A (the app's role owns every table in public and drizzle): the
 * owner revokes its own INSERT/UPDATE/DELETE/TRUNCATE. It applies at once to
 * every session, pooled ones included; reads keep working.
 * Strategy B (when A is impossible or doesn't take effect, e.g. the role also
 * holds the privileges through another role): the role's sessions default to
 * read-only transactions, and its other sessions are ended so they reconnect
 * read-only.
 * Unfreeze undoes whichever is in place. A session's read-only default is
 * fixed when it starts, so undoing B also ends the role's other sessions
 * (the app's pooled ones, a pooler's server connections), which then
 * reconnect writable.
 */
import type { MoveSql, Queryable } from "./connect";

export type FreezeState = { frozen: boolean; strategy: "A" | "B" | null };

/** Every table in public and drizzle is owned by the connected role. */
export async function ownsAllTables(q: Queryable): Promise<boolean> {
  const [r] = await q.unsafe<{ others: number }[]>(`
    SELECT count(*)::int AS others
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('public','drizzle') AND c.relkind IN ('r','p')
      AND pg_get_userbyid(c.relowner) <> current_user`);
  return Number(r.others) === 0;
}

async function existingSchemas(q: Queryable): Promise<string[]> {
  const rows = await q.unsafe<{ name: string }[]>(
    `SELECT nspname AS name FROM pg_namespace WHERE nspname IN ('public','drizzle') ORDER BY 1`,
  );
  return rows.map((r) => r.name);
}

/** Strategy B is in place: the role's new sessions start read-only (read from the catalog). */
async function roleReadOnly(q: Queryable): Promise<boolean> {
  const [r] = await q.unsafe<{ on: boolean }[]>(`
    SELECT EXISTS (
      SELECT 1 FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole
      WHERE r.rolname = current_user AND s.setdatabase IN (0, (SELECT oid FROM pg_database WHERE datname = current_database()))
        AND 'default_transaction_read_only=on' = ANY (s.setconfig)
    ) AS on`);
  return Boolean(r.on);
}

/** Ends the role's other sessions, so they reconnect with its current settings. */
async function endOtherSessions(q: Queryable): Promise<number> {
  const [r] = await q.unsafe<{ n: number }[]>(`
    SELECT count(*)::int AS n FROM (
      SELECT pg_terminate_backend(pid) FROM pg_stat_activity
      WHERE usename = current_user AND pid <> pg_backend_pid()) s`);
  return Number(r?.n ?? 0);
}

const ROLLBACK = Symbol("rollback");

/**
 * Tries a write that can never succeed (reminder_log needs values) inside a
 * READ WRITE transaction that is always rolled back: permission denied
 * (42501) means strategy A; a NOT NULL error (23502) means the role may
 * write. Strategy B is read from the catalog, not from this session: one
 * opened while B was in place keeps its read-only default after unfreeze.
 * A database without that table is not frozen by strategy A.
 */
export async function isFrozen(sql: MoveSql): Promise<FreezeState> {
  let code: string | null = null;
  try {
    await sql.begin("READ WRITE", async (tx) => {
      try {
        await tx.unsafe(`INSERT INTO public.reminder_log DEFAULT VALUES`);
      } catch (err) {
        code = (err as { code?: string }).code ?? "unknown";
      }
      throw ROLLBACK;
    });
  } catch (err) {
    if (err !== ROLLBACK) throw err;
  }
  if (code === "42501") return { frozen: true, strategy: "A" };
  if (await roleReadOnly(sql)) return { frozen: true, strategy: "B" };
  return { frozen: false, strategy: null };
}

/** Freezes the database (A, else B) and says which strategy ran. */
export async function freeze(
  sql: MoveSql,
): Promise<FreezeState & { note?: string; sessionsEnded?: number }> {
  const schemas = await existingSchemas(sql);
  if (await ownsAllTables(sql)) {
    try {
      // READ WRITE: this session may have started read-only (B already in place).
      await sql.begin("READ WRITE", async (tx) => {
        for (const schema of schemas) {
          await tx.unsafe(
            `REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA "${schema}" FROM CURRENT_USER`,
          );
        }
      });
      const state = await isFrozen(sql);
      if (state.frozen) return state;
    } catch {
      // Refused: fall through to strategy B.
    }
  }
  await sql.begin("READ WRITE", async (tx) => {
    await tx.unsafe(`ALTER ROLE CURRENT_USER SET default_transaction_read_only = on`);
  });
  const ended = await endOtherSessions(sql);
  return {
    frozen: true,
    strategy: "B",
    sessionsEnded: ended,
    note: `Sessions of this role now start read-only; ${ended} open session(s) were ended so they reconnect read-only.`,
  };
}

/** Undoes either strategy; the database is writable again, for sessions already open too. */
export async function unfreeze(
  sql: MoveSql,
): Promise<FreezeState & { undid: ("A" | "B")[]; note?: string; sessionsEnded?: number }> {
  const undid: ("A" | "B")[] = [];
  const wasB = await roleReadOnly(sql);
  if (wasB) {
    await sql.begin("READ WRITE", async (tx) => {
      await tx.unsafe(`ALTER ROLE CURRENT_USER RESET default_transaction_read_only`);
    });
    // This session started read-only too.
    await sql.unsafe(`SET SESSION default_transaction_read_only = off`);
    undid.push("B");
  }
  if (await ownsAllTables(sql)) {
    const schemas = await existingSchemas(sql);
    await sql.begin("READ WRITE", async (tx) => {
      for (const schema of schemas) {
        await tx.unsafe(
          `GRANT INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA "${schema}" TO CURRENT_USER`,
        );
      }
    });
    undid.push("A");
  }
  // Sessions opened while B was in place keep their read-only default until they
  // end: end them (once the privileges are back) so they reconnect writable.
  const ended = wasB ? await endOtherSessions(sql) : null;
  const state = await isFrozen(sql);
  return {
    ...state,
    undid,
    ...(ended === null
      ? {}
      : {
          sessionsEnded: ended,
          note: `Sessions of this role start writable again; ${ended} open session(s) opened during the freeze were ended so they reconnect writable.`,
        }),
  };
}
