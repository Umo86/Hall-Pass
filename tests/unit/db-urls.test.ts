import { describe, expect, it } from "vitest";
import {
  appDatabaseUrl,
  databaseHostPort,
  databaseProjectOf,
  databaseProviderOf,
  databaseRegionOf,
  databaseTarget,
  isPooledNeonUrl,
  migrationDatabaseUrl,
  moveDatabaseUrls,
  moveTokenSet,
  normaliseDatabaseUrl,
} from "@/lib/db/urls";

const LOCAL = "postgres://postgres:postgres@localhost:5432/hallpass";
const NEON_POOLED =
  "postgresql://neondb_owner:pw@ep-cool-sea-a1b2c3d4-pooler.eu-west-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require";
const NEON_DIRECT =
  "postgresql://neondb_owner:pw@ep-cool-sea-a1b2c3d4.eu-west-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require";
const SUPA_POOLER =
  "postgresql://postgres.uymemosqktczdjxlsryj:pw@aws-0-eu-central-1.pooler.supabase.com:5432/postgres";
const SUPA_TXN =
  "postgresql://postgres.uymemosqktczdjxlsryj:pw@aws-0-eu-central-1.pooler.supabase.com:6543/postgres";
const SUPA_DIRECT = "postgresql://postgres:pw@db.uymemosqktczdjxlsryj.supabase.co:5432/postgres";
const STALE = "postgresql://someone:pw@old-host.example.com:5432/postgres";

describe("databaseTarget", () => {
  it.each([
    [undefined, "auto"],
    ["", "auto"],
    ["  ", "auto"],
    ["auto", "auto"],
    ["neon", "neon"],
    [" Neon ", "neon"],
    ["supabase", "invalid"],
    ["neon-london", "invalid"],
  ])("%j → %s", (value, expected) => {
    expect(databaseTarget({ DATABASE_TARGET: value })).toBe(expected);
  });
});

describe("normaliseDatabaseUrl", () => {
  it("drops channel_binding and keeps sslmode", () => {
    expect(normaliseDatabaseUrl(NEON_DIRECT)).toBe(
      "postgresql://neondb_owner:pw@ep-cool-sea-a1b2c3d4.eu-west-2.aws.neon.tech/neondb?sslmode=require",
    );
    expect(normaliseDatabaseUrl(`${LOCAL}?channel_binding=require`)).toBe(LOCAL);
    expect(normaliseDatabaseUrl(`${LOCAL}?channel_binding=disable&sslmode=disable`)).toBe(
      `${LOCAL}?sslmode=disable`,
    );
  });
  it("trims spaces and wrapping quotes", () => {
    expect(normaliseDatabaseUrl(`  "${LOCAL}"\n`)).toBe(LOCAL);
    expect(normaliseDatabaseUrl(`'${LOCAL}'`)).toBe(LOCAL);
  });
  it("leaves everything else byte for byte", () => {
    const odd = "postgres://u:p%40ss%2Fw0rd@localhost:5432/db?application_name=hall%20pass";
    expect(normaliseDatabaseUrl(odd)).toBe(odd);
  });
});

describe("appDatabaseUrl", () => {
  it("auto (unset): today's probe order, duplicates once", () => {
    expect(
      appDatabaseUrl({
        DATABASE_URL: STALE,
        DIRECT_DATABASE_URL: SUPA_POOLER,
        POSTGRES_URL: NEON_POOLED,
        DATABASE_URL_UNPOOLED: NEON_DIRECT,
        POSTGRES_URL_NON_POOLING: NEON_DIRECT,
      }),
    ).toEqual({
      kind: "probe",
      candidates: [
        { url: STALE, via: "DATABASE_URL" },
        { url: SUPA_POOLER, via: "DIRECT_DATABASE_URL" },
        { url: normaliseDatabaseUrl(NEON_POOLED), via: "POSTGRES_URL" },
        { url: normaliseDatabaseUrl(NEON_DIRECT), via: "DATABASE_URL_UNPOOLED" },
      ],
    });
  });
  it("auto: the same on 'auto' and on an empty value", () => {
    for (const DATABASE_TARGET of ["auto", ""]) {
      expect(appDatabaseUrl({ DATABASE_TARGET, DATABASE_URL: LOCAL })).toEqual({
        kind: "probe",
        candidates: [{ url: LOCAL, via: "DATABASE_URL" }],
      });
    }
  });
  it("auto with nothing set: none", () => {
    expect(appDatabaseUrl({})).toEqual({ kind: "none", reason: "DATABASE_URL is not set" });
  });
  it("neon: POSTGRES_URL only, normalised, no probing", () => {
    expect(
      appDatabaseUrl({
        DATABASE_TARGET: "neon",
        DATABASE_URL: STALE,
        DIRECT_DATABASE_URL: SUPA_POOLER,
        POSTGRES_URL: NEON_POOLED,
      }),
    ).toEqual({ kind: "single", url: normaliseDatabaseUrl(NEON_POOLED), via: "POSTGRES_URL" });
  });
  it("neon with a Supabase or missing POSTGRES_URL: none, never a fallback", () => {
    const supa = appDatabaseUrl({
      DATABASE_TARGET: "neon",
      POSTGRES_URL: SUPA_TXN,
      DIRECT_DATABASE_URL: SUPA_POOLER,
    });
    expect(supa).toEqual({
      kind: "none",
      reason: "DATABASE_TARGET=neon but POSTGRES_URL is not a Neon URL.",
    });
    expect(appDatabaseUrl({ DATABASE_TARGET: "neon", DATABASE_URL: LOCAL }).kind).toBe("none");
  });
  it("an unknown target: none", () => {
    const r = appDatabaseUrl({ DATABASE_TARGET: "supabase", DATABASE_URL: LOCAL });
    expect(r.kind).toBe("none");
    expect(r.kind === "none" && r.reason).toMatch(/unknown value/);
  });
  it("preview without a target: none; preview with neon: Neon", () => {
    const env = { VERCEL_ENV: "preview", POSTGRES_URL: NEON_POOLED, DATABASE_URL: STALE };
    const none = appDatabaseUrl(env);
    expect(none.kind).toBe("none");
    expect(none.kind === "none" && none.reason).toMatch(/Preview deployments have no database/);
    expect(appDatabaseUrl({ ...env, DATABASE_TARGET: "neon" })).toEqual({
      kind: "single",
      url: normaliseDatabaseUrl(NEON_POOLED),
      via: "POSTGRES_URL",
    });
  });
  it("production without a target: today's probing", () => {
    expect(appDatabaseUrl({ VERCEL_ENV: "production", DATABASE_URL: STALE }).kind).toBe("probe");
  });
});

describe("migrationDatabaseUrl", () => {
  it("auto: today's order (direct first)", () => {
    expect(
      migrationDatabaseUrl({
        DATABASE_URL: LOCAL,
        DIRECT_DATABASE_URL: SUPA_POOLER,
        DATABASE_URL_UNPOOLED: NEON_DIRECT,
      }),
    ).toEqual({ url: SUPA_POOLER, via: "DIRECT_DATABASE_URL" });
    expect(migrationDatabaseUrl({ DATABASE_URL: LOCAL })).toEqual({
      url: LOCAL,
      via: "DATABASE_URL",
    });
    expect(migrationDatabaseUrl({ POSTGRES_URL: LOCAL })).toEqual({
      url: LOCAL,
      via: "POSTGRES_URL",
    });
    expect(migrationDatabaseUrl({})).toBeNull();
  });
  it("neon: DATABASE_URL_UNPOOLED, then POSTGRES_URL_NON_POOLING, never Supabase", () => {
    const base = { DATABASE_TARGET: "neon", DIRECT_DATABASE_URL: SUPA_POOLER, DATABASE_URL: LOCAL };
    expect(
      migrationDatabaseUrl({
        ...base,
        DATABASE_URL_UNPOOLED: NEON_DIRECT,
        POSTGRES_URL_NON_POOLING: STALE,
      }),
    ).toEqual({ url: normaliseDatabaseUrl(NEON_DIRECT), via: "DATABASE_URL_UNPOOLED" });
    expect(migrationDatabaseUrl({ ...base, POSTGRES_URL_NON_POOLING: NEON_DIRECT })).toEqual({
      url: normaliseDatabaseUrl(NEON_DIRECT),
      via: "POSTGRES_URL_NON_POOLING",
    });
    expect(migrationDatabaseUrl(base)).toBeNull();
  });
  it("an unknown target, or a preview without one: none", () => {
    expect(migrationDatabaseUrl({ DATABASE_TARGET: "x", DATABASE_URL: LOCAL })).toBeNull();
    expect(migrationDatabaseUrl({ VERCEL_ENV: "preview", DATABASE_URL: LOCAL })).toBeNull();
  });
});

describe("provider, project and region", () => {
  it.each([
    [NEON_POOLED, "neon", "ep-cool-sea-a1b2c3d4", "aws-eu-west-2"],
    [NEON_DIRECT, "neon", "ep-cool-sea-a1b2c3d4", "aws-eu-west-2"],
    [
      "postgresql://u:p@ep-x-123.westus3.azure.neon.tech/neondb",
      "neon",
      "ep-x-123",
      "azure-westus3",
    ],
    [SUPA_POOLER, "supabase", "uymemosqktczdjxlsryj", "aws-eu-central-1"],
    [SUPA_TXN, "supabase", "uymemosqktczdjxlsryj", "aws-eu-central-1"],
    [SUPA_DIRECT, "supabase", "uymemosqktczdjxlsryj", null],
    [LOCAL, "local", null, null],
    ["postgres://u:p@127.0.0.1/x", "local", null, null],
    ["postgres://u:p@x.vercel-storage.com/x", "vercel-postgres", null, null],
    [STALE, "other", null, null],
    ["not a url", "invalid URL", null, null],
  ])("%s", (url, provider, project, region) => {
    expect(databaseProviderOf(url)).toBe(provider);
    expect(databaseProjectOf(url)).toBe(project);
    expect(databaseRegionOf(url)).toBe(region);
  });
  it("Neon's project id comes from NEON_PROJECT_ID when the integration sets it", () => {
    expect(databaseProjectOf(NEON_POOLED, { NEON_PROJECT_ID: "odd-tree-67238637" })).toBe(
      "odd-tree-67238637",
    );
    // …but not for a database somewhere else.
    expect(databaseProjectOf(LOCAL, { NEON_PROJECT_ID: "odd-tree-67238637" })).toBeNull();
  });
  it("pooled Neon hosts are told apart; host:port never has credentials", () => {
    expect(isPooledNeonUrl(NEON_POOLED)).toBe(true);
    expect(isPooledNeonUrl(NEON_DIRECT)).toBe(false);
    expect(databaseHostPort(NEON_DIRECT)).toBe("ep-cool-sea-a1b2c3d4.eu-west-2.aws.neon.tech:5432");
    expect(databaseHostPort(SUPA_TXN)).toBe("aws-0-eu-central-1.pooler.supabase.com:6543");
  });
});

describe("moveDatabaseUrls", () => {
  const env = { DIRECT_DATABASE_URL: SUPA_POOLER, DATABASE_URL_UNPOOLED: NEON_DIRECT };
  it("Supabase is DIRECT_DATABASE_URL, Neon its direct URL; live follows DATABASE_TARGET", () => {
    const r = moveDatabaseUrls(env);
    expect(r.supabase).toEqual({
      url: SUPA_POOLER,
      host: "aws-0-eu-central-1.pooler.supabase.com:5432",
    });
    expect(r.neon).toEqual({
      url: normaliseDatabaseUrl(NEON_DIRECT),
      host: "ep-cool-sea-a1b2c3d4.eu-west-2.aws.neon.tech:5432",
    });
    expect(r.live).toBe("supabase");
    expect(moveDatabaseUrls({ ...env, DATABASE_TARGET: "neon" }).live).toBe("neon");
    expect(moveDatabaseUrls({ ...env, DATABASE_TARGET: "auto" }).live).toBe("supabase");
  });
  it("falls back to POSTGRES_URL_NON_POOLING for Neon", () => {
    const r = moveDatabaseUrls({
      DIRECT_DATABASE_URL: SUPA_POOLER,
      POSTGRES_URL_NON_POOLING: NEON_DIRECT,
    });
    expect("url" in r.neon).toBe(true);
  });
  it("rejects a pooled Neon URL", () => {
    const r = moveDatabaseUrls({ ...env, DATABASE_URL_UNPOOLED: NEON_POOLED });
    expect(r.neon).toEqual({ error: expect.stringMatching(/pooled/) });
  });
  it("rejects a DIRECT_DATABASE_URL that isn't Supabase, and a Neon URL that isn't Neon", () => {
    const r = moveDatabaseUrls({ DIRECT_DATABASE_URL: LOCAL, DATABASE_URL_UNPOOLED: LOCAL });
    expect(r.supabase).toEqual({ error: "DIRECT_DATABASE_URL is not a Supabase database" });
    expect(r.neon).toEqual({ error: expect.stringMatching(/not a Neon host/) });
    expect(moveDatabaseUrls({}).supabase).toEqual({ error: "DIRECT_DATABASE_URL is not set" });
  });
});

describe("moveTokenSet", () => {
  it.each([
    [undefined, false],
    ["", false],
    ["off", false],
    [" OFF ", false],
    ["x".repeat(64), true],
    ["short", true],
  ])("%j → %s", (value, expected) => {
    expect(moveTokenSet({ MOVE_DATABASE_TOKEN: value })).toBe(expected);
  });
});
