/**
 * Making a database read-only for the move, so no write can land on it
 * after the copy's snapshot (and be lost).
 *
 * Strategy A (the app's role owns every table in public and drizzle): the
 * owner revokes its own INSERT/UPDATE/DELETE/TRUNCATE. It applies at once to
 * every session, pooled ones included; reads keep working.
 * Strategy B (when A is impossible or refused): the role's sessions default
 * to read-only transactions, and its other sessions are ended so they
 * reconnect read-only.
 * Unfreeze undoes whichever is in place.
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

/** Strategy B is in place: the role's new sessions start read-only. */
async function roleReadOnly(q: Queryable): Promise<boolean> {
  const [r] = await q.unsafe<{ on: boolean }[]>(`
    SELECT EXISTS (
      SELECT 1 FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole
      WHERE r.rolname = current_user AND s.setdatabase IN (0, (SELECT oid FROM pg_database WHERE datname = current_database()))
        AND 'default_transaction_read_only=on' = ANY (s.setconfig)
    ) AS on`);
  return Boolean(r.on);
}

const ROLLBACK = Symbol("rollback");

/**
 * Tries a write that can never succeed (reminder_log needs values) inside a
 * transaction that is always rolled back: permission denied (42501) or a
 * read-only transaction (25006) means frozen; a NOT NULL error (23502) means
 * writable. A database without that table is not frozen by strategy A.
 */
export async function isFrozen(sql: MoveSql): Promise<FreezeState> {
  let code: string | null = null;
  try {
    await sql.begin(async (tx) => {
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
  if (code === "25006") return { frozen: true, strategy: "B" };
  return { frozen: false, strategy: null };
}

/** Freezes the database (A, else B) and says which strategy ran. */
export async function freeze(sql: MoveSql): Promise<FreezeState & { note?: string }> {
  const schemas = await existingSchemas(sql);
  if (await ownsAllTables(sql)) {
    try {
      await sql.begin(async (tx) => {
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
  await sql.unsafe(`ALTER ROLE CURRENT_USER SET default_transaction_read_only = on`);
  const ended = await sql.unsafe<{ n: number }[]>(`
    SELECT count(*)::int AS n FROM (
      SELECT pg_terminate_backend(pid) FROM pg_stat_activity
      WHERE usename = current_user AND pid <> pg_backend_pid()) s`);
  return {
    frozen: true,
    strategy: "B",
    note: `Sessions of this role now start read-only; ${ended[0]?.n ?? 0} open session(s) were ended so they reconnect read-only.`,
  };
}

/** Undoes either strategy; the database is writable again. */
export async function unfreeze(sql: MoveSql): Promise<FreezeState & { undid: ("A" | "B")[] }> {
  const undid: ("A" | "B")[] = [];
  if (await roleReadOnly(sql)) {
    await sql.begin("READ WRITE", async (tx) => {
      await tx.unsafe(`ALTER ROLE CURRENT_USER RESET default_transaction_read_only`);
    });
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
  const state = await isFrozen(sql);
  return { ...state, undid };
}
