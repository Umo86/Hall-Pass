import { describe, expect, it } from "vitest";
import { describeLocale, sameCollation, type LocaleFacts } from "@/lib/db/move/check";
import type { MoveSql } from "@/lib/db/move/connect";
import { createDatabaseStatement, prepareTarget } from "@/lib/db/move/prepare";

// Supabase's database (live, 2026-10-21) and Neon's default.
const SUPABASE: LocaleFacts = {
  encoding: "UTF8",
  collate: "en_US.UTF-8",
  ctype: "en_US.UTF-8",
  localeProvider: "i",
  locale: "en-US",
  icuRules: null,
};
const NEON_DEFAULT: LocaleFacts = {
  encoding: "UTF8",
  collate: "C.UTF-8",
  ctype: "C.UTF-8",
  localeProvider: "c",
  locale: null,
  icuRules: null,
};
const NEON_ICU: LocaleFacts = { ...NEON_DEFAULT, localeProvider: "i", locale: "en-US" };

describe("sameCollation", () => {
  it("ICU: the locale decides, not LC_COLLATE", () => {
    expect(sameCollation(SUPABASE, NEON_ICU)).toBe(true);
    expect(sameCollation(SUPABASE, { ...NEON_ICU, locale: "en-GB" })).toBe(false);
    expect(sameCollation(SUPABASE, { ...NEON_ICU, icuRules: "&a < b" })).toBe(false);
  });
  it("a different provider or encoding never matches", () => {
    expect(sameCollation(SUPABASE, NEON_DEFAULT)).toBe(false);
    expect(sameCollation(NEON_DEFAULT, NEON_ICU)).toBe(false);
    expect(sameCollation(NEON_ICU, { ...NEON_ICU, encoding: "LATIN1" })).toBe(false);
  });
  it("libc: LC_COLLATE and LC_CTYPE both", () => {
    expect(sameCollation(NEON_DEFAULT, { ...NEON_DEFAULT })).toBe(true);
    expect(sameCollation(NEON_DEFAULT, { ...NEON_DEFAULT, ctype: "en_US.UTF-8" })).toBe(false);
    expect(sameCollation(NEON_DEFAULT, { ...NEON_DEFAULT, collate: "en_US.UTF-8" })).toBe(false);
  });
  it("describes a locale for people", () => {
    expect(describeLocale(SUPABASE)).toBe("ICU en-US, UTF8");
    expect(describeLocale(NEON_DEFAULT)).toBe("libc C.UTF-8, UTF8");
  });
});

describe("createDatabaseStatement", () => {
  it("ICU, with and without the libc locale", () => {
    expect(createDatabaseStatement("hallpass", SUPABASE, true)).toBe(
      "CREATE DATABASE \"hallpass\" WITH TEMPLATE template0 ENCODING 'UTF8' LOCALE_PROVIDER icu ICU_LOCALE 'en-US' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8'",
    );
    expect(createDatabaseStatement("hallpass", SUPABASE, false)).toBe(
      "CREATE DATABASE \"hallpass\" WITH TEMPLATE template0 ENCODING 'UTF8' LOCALE_PROVIDER icu ICU_LOCALE 'en-US'",
    );
  });
  it("libc always names its locale; builtin its own", () => {
    expect(createDatabaseStatement("x", NEON_DEFAULT, false)).toBe(
      "CREATE DATABASE \"x\" WITH TEMPLATE template0 ENCODING 'UTF8' LOCALE_PROVIDER libc LC_COLLATE 'C.UTF-8' LC_CTYPE 'C.UTF-8'",
    );
    expect(
      createDatabaseStatement(
        "x",
        { ...NEON_DEFAULT, localeProvider: "b", locale: "C.UTF-8" },
        false,
      ),
    ).toBe(
      "CREATE DATABASE \"x\" WITH TEMPLATE template0 ENCODING 'UTF8' LOCALE_PROVIDER builtin BUILTIN_LOCALE 'C.UTF-8'",
    );
  });
  it("refuses odd locale text and custom ICU rules", () => {
    expect(() => createDatabaseStatement("x", { ...SUPABASE, locale: "en'; DROP" }, false)).toThrow(
      /unusual/,
    );
    expect(() => createDatabaseStatement("x", { ...SUPABASE, icuRules: "&a<b" }, false)).toThrow(
      /ICU rules/,
    );
  });
});

/** A stand-in connection: pg_database rows by name, CREATE DATABASE recorded (or refused). */
function fakeServer(
  databases: Map<string, LocaleFacts>,
  onCreate: (statement: string) => LocaleFacts | Error,
): { sql: MoveSql; statements: string[] } {
  const statements: string[] = [];
  const unsafe = async (query: string, params?: unknown[]) => {
    if (query.startsWith("SELECT current_database()")) return [{ db: "postgres" }];
    if (query.includes("FROM pg_database")) {
      const facts = databases.get(String(params?.[0]));
      if (!facts) return [];
      return [
        {
          encoding: facts.encoding,
          d: {
            datcollate: facts.collate,
            datctype: facts.ctype,
            datlocprovider: facts.localeProvider,
            datlocale: facts.locale,
            daticurules: facts.icuRules,
          },
        },
      ];
    }
    statements.push(query);
    const made = onCreate(query);
    if (made instanceof Error) throw made;
    databases.set(/CREATE DATABASE "([^"]+)"/.exec(query)![1], made);
    return [];
  };
  return { sql: { unsafe } as unknown as MoveSql, statements };
}

describe("prepareTarget", () => {
  const source = () => fakeServer(new Map([["postgres", SUPABASE]]), () => new Error("no")).sql;

  it("makes the database with the source's collation", async () => {
    const server = fakeServer(new Map(), () => ({ ...SUPABASE }));
    const report = await prepareTarget(source(), server.sql, "hallpass");
    expect(report).toMatchObject({ database: "hallpass", created: true, collationMatch: true });
    expect(report.warnings).toEqual([]);
    expect(server.statements).toHaveLength(1);
  });

  it("without the source's libc locale on the server: ICU all the same, with a warning", async () => {
    const server = fakeServer(new Map(), (statement) =>
      statement.includes("LC_COLLATE")
        ? Object.assign(new Error('invalid LC_COLLATE locale name: "en_US.UTF-8"'), {
            code: "22023",
          })
        : { ...NEON_ICU },
    );
    const report = await prepareTarget(source(), server.sql, "hallpass");
    expect(report).toMatchObject({
      created: true,
      collationMatch: true,
      target: "ICU en-US, UTF8",
    });
    expect(report.warnings[0]).toMatch(/no en_US.UTF-8 libc locale/);
    expect(server.statements).toHaveLength(2);
  });

  it("keeps a database that is already right, refuses one that isn't, never drops", async () => {
    const right = fakeServer(new Map([["hallpass", NEON_ICU]]), () => new Error("no create"));
    expect(await prepareTarget(source(), right.sql, "hallpass")).toMatchObject({ created: false });
    expect(right.statements).toEqual([]);

    const wrong = fakeServer(new Map([["hallpass", NEON_DEFAULT]]), () => new Error("no create"));
    await expect(prepareTarget(source(), wrong.sql, "hallpass")).rejects.toThrow(
      /already exists with another collation \(libc C.UTF-8, UTF8; the source is ICU en-US, UTF8\)/,
    );
    expect(wrong.statements).toEqual([]);
  });

  it("both attempts failing is a refusal naming both reasons", async () => {
    const server = fakeServer(new Map(), () => new Error("permission denied to create database"));
    await expect(prepareTarget(source(), server.sql, "hallpass")).rejects.toThrow(
      /Could not create hallpass: permission denied to create database; then permission denied/,
    );
  });
});
