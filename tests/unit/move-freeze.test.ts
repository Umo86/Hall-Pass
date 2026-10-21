import { describe, expect, it } from "vitest";
import type { MoveSql } from "@/lib/db/move/connect";
import { freeze } from "@/lib/db/move/freeze";

/**
 * A stand-in connection for freeze()'s error handling: the role owns every
 * table, strategy A's transaction fails with `aError`, and everything after
 * it (strategy B) is recorded.
 */
function fakeSql(aError: Error & { code?: string }) {
  const statements: string[] = [];
  let begins = 0;
  const unsafe = async (query: string) => {
    statements.push(query.trim().split("\n")[0]);
    if (query.includes("AS others")) return [{ others: 0 }];
    if (query.includes("AS n, pg_backend_pid() AS me")) return [{ n: 2, me: 10 }];
    if (query.includes("SELECT pg_backend_pid() AS pid")) return [{ pid: 11 }];
    return [];
  };
  const begin = async (_mode: string, fn: (tx: { unsafe: typeof unsafe }) => Promise<unknown>) => {
    begins += 1;
    if (begins === 1) throw aError;
    return fn({ unsafe });
  };
  return { sql: { unsafe, begin } as unknown as MoveSql, statements };
}

describe("freeze: when strategy A fails", () => {
  it.each(["CONNECTION_CLOSED", "57P01", "08006"])(
    "a dropped connection (%s) stops there: no strategy B on the live database",
    async (code) => {
      const { sql, statements } = fakeSql(Object.assign(new Error("connection lost"), { code }));
      await expect(freeze(sql)).rejects.toMatchObject({ code });
      expect(statements.some((s) => s.includes("ALTER ROLE"))).toBe(false);
      expect(statements.some((s) => s.includes("pg_terminate_backend"))).toBe(false);
    },
  );

  it("a refusal falls back to B, says why, and claims no revoke that was rolled back", async () => {
    const { sql, statements } = fakeSql(
      Object.assign(new Error("permission denied for table v_other"), { code: "42501" }),
    );
    const state = await freeze(sql);
    expect(state).toMatchObject({ frozen: true, strategy: "B", sessionsEnded: 2 });
    expect(state.revokedFrom).toBeUndefined();
    expect(state.note).toMatch(
      /^Strategy A did not hold \(42501 permission denied for table v_other\)\. Sessions of this role now start read-only/,
    );
    expect(statements.some((s) => s.includes("ALTER ROLE CURRENT_USER SET"))).toBe(true);
  });
});
