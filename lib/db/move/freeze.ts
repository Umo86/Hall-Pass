/**
 * Making a database read-only for the move, so no write can land on it
 * after the copy's snapshot (and be lost).
 *
 * Strategy A (the app's role owns every table in public and drizzle): the
 * owner revokes INSERT/UPDATE/DELETE/TRUNCATE from itself and from every role
 * it is a member of that holds them by its grant (on Supabase, `postgres`
 * inherits them through `service_role`), and from PUBLIC. What it revokes is
 * recorded first (db_move.frozen_grants), so unfreeze grants back exactly
 * that. It applies at once to every session, pooled ones included; reads
 * keep working.
 * Strategy B (when A is impossible or doesn't take effect, e.g. a grant by
 * another role, or a predefined role such as pg_write_all_data): the role's
 * sessions default to read-only transactions, and all its sessions, this
 * one last, are ended so they reconnect read-only (a pooler would otherwise
 * hand this session's backend, started writable, to the app).
 * Unfreeze undoes whichever is in place. A session's read-only default is
 * fixed when it starts, so undoing B also ends the role's sessions (the
 * app's pooled ones, a pooler's server connections, this one last), which
 * then reconnect writable.
 */
import { ident, qualified, type MoveSql, type Queryable } from "./connect";
import { SNAPSHOT_SCHEMA } from "./snapshot";

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

/** How a session the server ended shows up in postgres-js. */
const SESSION_ENDED =
  /^(57P01|CONNECTION_CLOSED|CONNECTION_ENDED|CONNECTION_DESTROYED|ECONNRESET|EPIPE)$/;

/**
 * Ends every client session of the role, this one last and in the same
 * statement (so on a transaction pooler it is the backend that ran it), so
 * all of them reconnect with the role's current settings. Returns how many
 * others there were; the connection reconnects on its next query.
 */
async function endAllSessions(sql: MoveSql): Promise<number> {
  const [r] = await sql.unsafe<{ n: number; me: number }[]>(`
    SELECT count(*)::int AS n, pg_backend_pid() AS me FROM pg_stat_activity
    WHERE usename = current_user AND backend_type = 'client backend' AND pid <> pg_backend_pid()`);
  const ended = (err: unknown) => SESSION_ENDED.test((err as { code?: string }).code ?? "");
  try {
    await sql.unsafe(`
      SELECT pg_terminate_backend(pid) FROM pg_stat_activity
      WHERE usename = current_user AND backend_type = 'client backend'
      ORDER BY pid = pg_backend_pid()`);
  } catch (err) {
    if (!ended(err)) throw err;
  }
  // The server ends this session a moment later: wait until queries run on a
  // fresh one, so the caller's next query doesn't meet the old one's end.
  for (let i = 0; i < 100; i++) {
    try {
      // A session ending under it can answer with no row at all: ask again.
      const [now] = await sql.unsafe<{ pid: number }[]>(`SELECT pg_backend_pid() AS pid`);
      if (now && Number(now.pid) !== Number(r.me)) break;
    } catch (err) {
      if (!ended(err)) throw err;
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  return Number(r?.n ?? 0);
}

const GRANTS = `${SNAPSHOT_SCHEMA}.frozen_grants`;

/**
 * Write privileges on tables in public and drizzle that reach the connected
 * role by its own grant (as owner): its own, a role's it is a member of,
 * PUBLIC's. Others' grants it can't revoke (the probe then finds it writable).
 */
const HELD_WRITES = `
  SELECT n.nspname || '.' || c.relname AS table_key,
         CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END AS grantee,
         a.privilege_type AS privilege, a.is_grantable AS grantable
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  CROSS JOIN LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
  WHERE n.nspname IN ('public','drizzle') AND c.relkind IN ('r','p')
    AND a.privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE')
    AND a.grantor = (SELECT oid FROM pg_roles WHERE rolname = current_user)
    AND CASE WHEN a.grantee = 0 THEN true ELSE pg_has_role(current_user, a.grantee, 'MEMBER') END`;

const granteeSql = (name: string) => (name === "PUBLIC" ? "PUBLIC" : ident(name));

/** How many revoked privileges a freeze recorded (0 when none, or no record table). */
async function grantsRecorded(q: Queryable): Promise<number> {
  const [r] = await q.unsafe<{ t: string | null }[]>(`SELECT to_regclass('${GRANTS}')::text AS t`);
  if (!r?.t) return 0;
  const [c] = await q.unsafe<{ n: number }[]>(`SELECT count(*)::int AS n FROM ${GRANTS}`);
  return Number(c?.n ?? 0);
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
): Promise<FreezeState & { note?: string; sessionsEnded?: number; revokedFrom?: string[] }> {
  const schemas = await existingSchemas(sql);
  let revokedFrom: string[] = [];
  if (await ownsAllTables(sql)) {
    try {
      // READ WRITE: this session may have started read-only (B already in place).
      await sql.begin("READ WRITE", async (tx) => {
        // Recorded before revoking; a second freeze keeps the first record.
        await tx.unsafe(`CREATE SCHEMA IF NOT EXISTS ${SNAPSHOT_SCHEMA}`);
        await tx.unsafe(`
          CREATE TABLE IF NOT EXISTS ${GRANTS} (
            table_key text NOT NULL,
            grantee text NOT NULL,
            privilege text NOT NULL,
            grantable boolean NOT NULL,
            frozen_at timestamptz NOT NULL DEFAULT now(),
            PRIMARY KEY (table_key, grantee, privilege)
          )`);
        await tx.unsafe(`ALTER TABLE ${GRANTS} ENABLE ROW LEVEL SECURITY`);
        await tx.unsafe(`
          INSERT INTO ${GRANTS} (table_key, grantee, privilege, grantable)
          ${HELD_WRITES}
          ON CONFLICT DO NOTHING`);
        const grantees = await tx.unsafe<{ grantee: string }[]>(
          `SELECT DISTINCT grantee FROM (${HELD_WRITES}) h ORDER BY 1`,
        );
        revokedFrom = grantees.map((g) => g.grantee).sort();
        for (const schema of schemas) {
          for (const grantee of ["CURRENT_USER", ...revokedFrom.map(granteeSql)]) {
            await tx.unsafe(
              `REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA ${ident(schema)} FROM ${grantee}`,
            );
          }
        }
      });
      const state = await isFrozen(sql);
      if (state.frozen) return { ...state, revokedFrom };
    } catch {
      // Refused: fall through to strategy B.
    }
  }
  await sql.begin("READ WRITE", async (tx) => {
    await tx.unsafe(`ALTER ROLE CURRENT_USER SET default_transaction_read_only = on`);
  });
  const ended = await endAllSessions(sql);
  return {
    frozen: true,
    strategy: "B",
    ...(revokedFrom.length ? { revokedFrom } : {}),
    sessionsEnded: ended,
    note: `Sessions of this role now start read-only; ${ended} other open session(s) and this one were ended so they reconnect read-only.`,
  };
}

/** Undoes either strategy; the database is writable again, for sessions already open too. */
export async function unfreeze(sql: MoveSql): Promise<
  FreezeState & {
    undid: ("A" | "B")[];
    note?: string;
    sessionsEnded?: number;
    restoredTo?: string[];
  }
> {
  const undid: ("A" | "B")[] = [];
  const wasB = await roleReadOnly(sql);
  if (wasB) {
    await sql.begin("READ WRITE", async (tx) => {
      await tx.unsafe(`ALTER ROLE CURRENT_USER RESET default_transaction_read_only`);
    });
    undid.push("B");
  }
  let restoredTo: string[] = [];
  const recorded = (await grantsRecorded(sql)) > 0;
  if (recorded || (await ownsAllTables(sql))) {
    const schemas = await existingSchemas(sql);
    await sql.begin("READ WRITE", async (tx) => {
      const rows = recorded
        ? await tx.unsafe<
            { table_key: string; grantee: string; grantable: boolean; privileges: string[] }[]
          >(`
            SELECT g.table_key, g.grantee, g.grantable,
                   array_agg(g.privilege ORDER BY g.privilege) AS privileges
            FROM ${GRANTS} g
            WHERE to_regclass(quote_ident(split_part(g.table_key, '.', 1)) || '.' ||
                              quote_ident(split_part(g.table_key, '.', 2))) IS NOT NULL
              AND (g.grantee = 'PUBLIC' OR EXISTS (SELECT 1 FROM pg_roles r WHERE r.rolname = g.grantee))
            GROUP BY 1, 2, 3 ORDER BY 1, 2, 3`)
        : [];
      if (rows.length) {
        // Exactly what freeze revoked.
        for (const r of rows) {
          await tx.unsafe(
            `GRANT ${r.privileges.join(", ")} ON ${qualified(r.table_key)} TO ${granteeSql(r.grantee)}${r.grantable ? " WITH GRANT OPTION" : ""}`,
          );
        }
        restoredTo = [...new Set(rows.map((r) => r.grantee))].sort();
      } else {
        // Nothing recorded (a freeze from before grants were recorded): the owner's own.
        for (const schema of schemas) {
          await tx.unsafe(
            `GRANT INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA ${ident(schema)} TO CURRENT_USER`,
          );
        }
      }
      if (recorded) await tx.unsafe(`DELETE FROM ${GRANTS}`);
    });
    undid.push("A");
  }
  // Sessions opened while B was in place keep their read-only default until they
  // end: end them all, this one last (once the privileges are back), so they
  // reconnect writable. The probe below runs on a fresh session.
  const ended = wasB ? await endAllSessions(sql) : null;
  const state = await isFrozen(sql);
  return {
    ...state,
    undid,
    ...(restoredTo.length ? { restoredTo } : {}),
    ...(ended === null
      ? {}
      : {
          sessionsEnded: ended,
          note: `Sessions of this role start writable again; ${ended} other open session(s) and this one were ended so they reconnect writable.`,
        }),
  };
}
