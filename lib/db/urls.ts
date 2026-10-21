/**
 * Which database URL each part of the app uses. Pure functions of the
 * environment (no network, no secrets returned beyond the URL itself), so
 * they are table-tested in tests/unit/db-urls.test.ts and shared by the app
 * client, migrations, the seed, drizzle-kit and the one-off move tool.
 *
 * DATABASE_TARGET is the switch:
 * - "neon": the app uses the Neon integration's pooled POSTGRES_URL only, and
 *   migrations its direct DATABASE_URL_UNPOOLED (then POSTGRES_URL_NON_POOLING).
 *   No probing and no fallback to another database (fail closed, never split-brain).
 * - unset, "" or "auto": today's behaviour, the first reachable of the candidate
 *   variables (local development, CI and production before the move). Preview
 *   deployments get no database in this mode: the Neon integration injects the
 *   production URLs into Preview too. On Vercel a Neon URL is never a
 *   candidate in this mode: an instance whose Supabase probe failed would
 *   otherwise run on Neon while the move tool treats Supabase as live.
 * - anything else: no database, with a reason.
 *
 * NEON_DATABASE names the database inside the Neon project when it isn't the
 * integration's own (its URLs all name "neondb", made with Neon's default
 * C.UTF-8 collation): every Neon URL then names it instead. The move creates
 * it with the source's collation (step=prepare), as a database's collation
 * can't change once it's made.
 *
 * Imported by drizzle.config.ts, so it only uses relative imports (none).
 */
export type Env = Record<string, string | undefined>;
export type DatabaseTarget = "neon" | "auto" | "invalid";
export type DatabaseProvider =
  "neon" | "supabase" | "vercel-postgres" | "local" | "other" | "invalid URL";

/** Candidate variables in auto mode, in priority order (unchanged from before the switch). */
export const AUTO_CANDIDATE_VARS = [
  "DATABASE_URL",
  "DIRECT_DATABASE_URL",
  "POSTGRES_URL",
  "DATABASE_URL_UNPOOLED",
  "POSTGRES_URL_NON_POOLING",
] as const;

/** Migration variables in auto mode, in priority order (unchanged from before the switch). */
export const AUTO_MIGRATION_VARS = [
  "DIRECT_DATABASE_URL",
  "DATABASE_URL_UNPOOLED",
  "POSTGRES_URL_NON_POOLING",
  "DATABASE_URL",
  "POSTGRES_URL",
] as const;

/** Neon's direct (unpooled) variables, in priority order. */
export const NEON_DIRECT_VARS = ["DATABASE_URL_UNPOOLED", "POSTGRES_URL_NON_POOLING"] as const;

const NEON_DATABASE_REASON =
  "NEON_DATABASE is not a valid database name (lower-case letters, digits and _, starting with a letter or _).";
const PREVIEW_REASON =
  "Preview deployments have no database unless DATABASE_TARGET is set for Preview (the Neon integration would otherwise give them production data).";
const INVALID_REASON = "DATABASE_TARGET has an unknown value: use neon, or leave it unset.";
const NEON_AUTO_REASON =
  "Only Neon database variables are set, and on Vercel the app runs on Neon only with DATABASE_TARGET=neon.";

/** "neon" | unset, "" or "auto" → "auto" | anything else → "invalid". */
export function databaseTarget(env: Env): DatabaseTarget {
  const value = (env.DATABASE_TARGET ?? "").trim().toLowerCase();
  if (value === "neon") return "neon";
  if (value === "" || value === "auto") return "auto";
  return "invalid";
}

/** A variable's value, or null when it is unset or blank. */
function read(env: Env, name: string): string | null {
  const value = env[name];
  return value && value.trim() ? value : null;
}

/**
 * Trims spaces and wrapping quote marks, and drops `channel_binding` from the
 * query string: postgres-js forwards unknown URL parameters to the server as
 * settings, and `channel_binding=require` (in every Neon URL) then fails with
 * "unrecognized configuration parameter". TLS stays on through `sslmode`.
 * Everything else is kept byte for byte (the URL is never re-serialised).
 */
export function normaliseDatabaseUrl(url: string): string {
  let value = url.trim();
  while (value.length >= 2 && /^["'`]/.test(value) && value.at(-1) === value[0]) {
    value = value.slice(1, -1).trim();
  }
  const q = value.indexOf("?");
  if (q === -1) return value;
  const base = value.slice(0, q);
  const kept = value
    .slice(q + 1)
    .split("&")
    .filter((p) => p !== "" && !/^channel_binding(=|$)/i.test(p));
  return kept.length ? `${base}?${kept.join("&")}` : base;
}

/** The URL with another database in its path; credentials, host and query untouched. */
export function withDatabaseName(url: string, name: string): string {
  const m = /^([a-z][a-z0-9+.-]*:\/\/[^/?#]*)(?:\/[^?#]*)?(.*)$/i.exec(url);
  return m ? `${m[1]}/${encodeURIComponent(name)}${m[2]}` : url;
}

/**
 * A Neon URL pointed at NEON_DATABASE (unchanged when it's unset, or for
 * any other host). Null when NEON_DATABASE isn't a plain database name.
 */
export function withNeonDatabase(url: string, env: Env): string | null {
  const name = read(env, "NEON_DATABASE")?.trim();
  if (!name || databaseProviderOf(url) !== "neon") return url;
  if (neonDatabaseInvalid(env)) return null;
  return withDatabaseName(url, name);
}

/** NEON_DATABASE is set to something that isn't a plain database name. */
function neonDatabaseInvalid(env: Env): boolean {
  const name = read(env, "NEON_DATABASE")?.trim();
  return Boolean(name) && !/^[a-z_][a-z0-9_]{0,62}$/.test(name!);
}

/** Host name of a database URL, lower-case, or null when it isn't a URL. */
export function databaseHostOf(url: string): string | null {
  try {
    return new URL(normaliseDatabaseUrl(url).replace(/^postgres:\/\//, "postgresql://")).hostname
      .toLowerCase()
      .replace(/\.$/, "");
  } catch {
    return null;
  }
}

/** `host:port` (never credentials) for messages and reports. */
export function databaseHostPort(url: string): string | null {
  try {
    const u = new URL(normaliseDatabaseUrl(url).replace(/^postgres:\/\//, "postgresql://"));
    return `${u.hostname.toLowerCase()}:${u.port || "5432"}`;
  } catch {
    return null;
  }
}

/** Database name in the URL's path (default "postgres"), or null when it isn't a URL. */
export function databaseNameOf(url: string): string | null {
  try {
    const u = new URL(normaliseDatabaseUrl(url).replace(/^postgres:\/\//, "postgresql://"));
    return decodeURIComponent(u.pathname.replace(/^\//, "")) || "postgres";
  } catch {
    return null;
  }
}

/** Who hosts the database, from its host name (never the credentials). */
export function databaseProviderOf(url: string): DatabaseProvider {
  const host = databaseHostOf(url);
  if (host === null) return "invalid URL";
  if (host.endsWith(".supabase.co") || host.endsWith(".supabase.com")) return "supabase";
  if (host.endsWith(".neon.tech")) return "neon";
  if (host.endsWith(".vercel-storage.com")) return "vercel-postgres";
  if (host === "localhost" || host === "127.0.0.1" || host === "::1" || host === "[::1]") {
    return "local";
  }
  return "other";
}

/** Neon's pooled hosts carry "-pooler" in the endpoint name. */
export function isPooledNeonUrl(url: string): boolean {
  const host = databaseHostOf(url);
  return host !== null && host.endsWith(".neon.tech") && host.split(".")[0].endsWith("-pooler");
}

/**
 * The project the database belongs to: Neon's NEON_PROJECT_ID (set by the
 * integration) or else the endpoint id ("ep-…"); Supabase's project ref
 * (from db.<ref>.supabase.co, or the pooler user postgres.<ref>). Null
 * elsewhere.
 */
export function databaseProjectOf(url: string, env: Env = {}): string | null {
  const provider = databaseProviderOf(url);
  const host = databaseHostOf(url);
  if (!host) return null;
  if (provider === "neon") {
    const fromEnv = read(env, "NEON_PROJECT_ID");
    if (fromEnv) return fromEnv.trim();
    const endpoint = host.split(".")[0].replace(/-pooler$/, "");
    return endpoint.startsWith("ep-") ? endpoint : null;
  }
  if (provider === "supabase") {
    const direct = /^db\.([a-z0-9]+)\.supabase\.co$/.exec(host);
    if (direct) return direct[1];
    try {
      const user = decodeURIComponent(
        new URL(normaliseDatabaseUrl(url).replace(/^postgres:\/\//, "postgresql://")).username,
      );
      const pooled = /^[^.]+\.([a-z0-9]+)$/.exec(user);
      return pooled ? pooled[1] : null;
    } catch {
      return null;
    }
  }
  return null;
}

/**
 * The cloud region in the host: "ep-x(-pooler).eu-west-2.aws.neon.tech" (or,
 * on newer Neon cells, "ep-x.c-2.eu-west-2.aws.neon.tech") → "aws-eu-west-2";
 * Supabase's pooler "aws-0-eu-central-1.pooler.supabase.com" →
 * "aws-eu-central-1". Null when the host doesn't say.
 */
export function databaseRegionOf(url: string): string | null {
  const host = databaseHostOf(url);
  if (!host) return null;
  const neon = /^[^.]+\.(?:c-\d+\.)?([a-z0-9-]+)\.(aws|azure|gcp)\.neon\.tech$/.exec(host);
  if (neon) return `${neon[2]}-${neon[1]}`;
  const supabase = /^(aws|gcp|azure)-\d+-([a-z0-9-]+)\.pooler\.supabase\.com$/.exec(host);
  if (supabase) return `${supabase[1]}-${supabase[2]}`;
  return null;
}

const REGION_NAMES: Record<string, string> = {
  "aws-eu-west-2": "London",
  "aws-eu-west-1": "Ireland",
  "aws-eu-west-3": "Paris",
  "aws-eu-central-1": "Frankfurt",
  "aws-eu-central-2": "Zurich",
  "aws-eu-north-1": "Stockholm",
  "aws-us-east-1": "North Virginia",
  "aws-us-east-2": "Ohio",
  "aws-us-west-1": "North California",
  "aws-us-west-2": "Oregon",
  "aws-ca-central-1": "Montreal",
  "aws-sa-east-1": "São Paulo",
  "aws-ap-south-1": "Mumbai",
  "aws-ap-southeast-1": "Singapore",
  "aws-ap-southeast-2": "Sydney",
  "aws-ap-northeast-1": "Tokyo",
  "aws-ap-northeast-2": "Seoul",
};

/** The city a cloud region is in ("aws-eu-west-2" → "London"), or null when unknown. */
export function regionCity(region: string | null | undefined): string | null {
  return region ? (REGION_NAMES[region] ?? null) : null;
}

/** The provider's name for people ("neon" → "Neon"). */
export function providerName(provider: DatabaseProvider | string | null | undefined): string {
  switch (provider) {
    case "neon":
      return "Neon";
    case "supabase":
      return "Supabase";
    case "vercel-postgres":
      return "Vercel Postgres";
    case "local":
      return "a database on this computer";
    default:
      return "a Postgres database";
  }
}

export type AppDatabaseUrl =
  | { kind: "single"; url: string; via: "POSTGRES_URL" }
  | { kind: "probe"; candidates: { url: string; via: string }[] }
  | { kind: "none"; reason: string };

/** The connection the app itself runs on (lib/db/client.ts). */
export function appDatabaseUrl(env: Env): AppDatabaseUrl {
  const target = databaseTarget(env);
  if (target === "invalid") return { kind: "none", reason: INVALID_REASON };
  if (target === "neon") {
    const raw = read(env, "POSTGRES_URL");
    if (!raw) return { kind: "none", reason: "DATABASE_TARGET=neon but POSTGRES_URL is not set." };
    const url = normaliseDatabaseUrl(raw);
    if (databaseProviderOf(url) !== "neon") {
      return { kind: "none", reason: "DATABASE_TARGET=neon but POSTGRES_URL is not a Neon URL." };
    }
    const named = withNeonDatabase(url, env);
    if (named === null) return { kind: "none", reason: NEON_DATABASE_REASON };
    return { kind: "single", url: named, via: "POSTGRES_URL" };
  }
  if (env.VERCEL_ENV === "preview") return { kind: "none", reason: PREVIEW_REASON };
  // On Vercel, Neon is reached only through the switch (never split-brain): before
  // Release A its URLs could never connect here (channel_binding), and they mustn't now.
  const onVercel = read(env, "VERCEL_ENV") !== null;
  const candidates: { url: string; via: string }[] = [];
  let skippedNeon = false;
  for (const name of AUTO_CANDIDATE_VARS) {
    const raw = read(env, name);
    if (!raw) continue;
    const url = withNeonDatabase(normaliseDatabaseUrl(raw), env);
    if (url === null || (onVercel && databaseProviderOf(url) === "neon")) {
      skippedNeon = true;
      continue;
    }
    if (!candidates.some((c) => c.url === url)) candidates.push({ url, via: name });
  }
  if (candidates.length === 0) {
    return { kind: "none", reason: skippedNeon ? NEON_AUTO_REASON : "DATABASE_URL is not set" };
  }
  return { kind: "probe", candidates };
}

/** The direct connection migrations, the seed and drizzle-kit use. Null when there is none. */
export function migrationDatabaseUrl(env: Env): { url: string; via: string } | null {
  const target = databaseTarget(env);
  if (target === "invalid") return null;
  const names: readonly string[] = target === "neon" ? NEON_DIRECT_VARS : AUTO_MIGRATION_VARS;
  if (target === "auto" && env.VERCEL_ENV === "preview") return null;
  for (const name of names) {
    const raw = read(env, name);
    if (!raw) continue;
    const url = withNeonDatabase(normaliseDatabaseUrl(raw), env);
    return url === null ? null : { url, via: name };
  }
  return null;
}

/** Why migrationDatabaseUrl() found nothing, in words. */
export function migrationDatabaseMissingReason(env: Env): string {
  const target = databaseTarget(env);
  if (target === "invalid") return INVALID_REASON;
  if (neonDatabaseInvalid(env)) return NEON_DATABASE_REASON;
  if (target === "neon") {
    return "DATABASE_TARGET=neon but neither DATABASE_URL_UNPOOLED nor POSTGRES_URL_NON_POOLING is set.";
  }
  if (env.VERCEL_ENV === "preview") return PREVIEW_REASON;
  return "DIRECT_DATABASE_URL (or DATABASE_URL) is not set";
}

export type MoveEnd =
  | {
      url: string;
      host: string;
      /** Neon with NEON_DATABASE: the integration's own database, to create it from (step=prepare). */
      serverUrl?: string;
    }
  | { error: string };

/**
 * The two databases the one-off move tool (app/api/admin/move-database) works
 * between: "supabase" is DIRECT_DATABASE_URL and must be a Supabase host;
 * "neon" is Neon's direct URL (never the "-pooler" host: the copy needs a
 * session), naming NEON_DATABASE when that is set. They must be different
 * databases. `live` is the one the app runs on, which the tool never writes
 * into.
 */
export function moveDatabaseUrls(env: Env): {
  supabase: MoveEnd;
  neon: MoveEnd;
  live: "supabase" | "neon";
} {
  const live = databaseTarget(env) === "neon" ? "neon" : "supabase";

  let supabase: MoveEnd;
  const rawSupabase = read(env, "DIRECT_DATABASE_URL");
  if (!rawSupabase) supabase = { error: "DIRECT_DATABASE_URL is not set" };
  else {
    const url = normaliseDatabaseUrl(rawSupabase);
    supabase =
      databaseProviderOf(url) === "supabase"
        ? { url, host: databaseHostPort(url) ?? "?" }
        : { error: "DIRECT_DATABASE_URL is not a Supabase database" };
  }

  let neon: MoveEnd;
  const rawNeon = read(env, "DATABASE_URL_UNPOOLED") ?? read(env, "POSTGRES_URL_NON_POOLING");
  if (!rawNeon)
    neon = { error: "Neither DATABASE_URL_UNPOOLED nor POSTGRES_URL_NON_POOLING is set" };
  else {
    const url = normaliseDatabaseUrl(rawNeon);
    if (databaseProviderOf(url) !== "neon")
      neon = { error: "The Neon direct URL is not a Neon host" };
    else if (isPooledNeonUrl(url)) {
      neon = {
        error: "The Neon direct URL is the pooled (-pooler) host; the copy needs a session",
      };
    } else {
      const named = withNeonDatabase(url, env);
      if (named === null) neon = { error: NEON_DATABASE_REASON };
      else {
        neon = { url: named, host: databaseHostPort(named) ?? "?" };
        if (databaseNameOf(named) !== databaseNameOf(url)) neon.serverUrl = url;
      }
    }
  }

  if ("url" in supabase && "url" in neon) {
    const same =
      databaseHostPort(supabase.url) === databaseHostPort(neon.url) &&
      databaseNameOf(supabase.url) === databaseNameOf(neon.url);
    if (same) neon = { error: "The Neon URL names the same database as DIRECT_DATABASE_URL" };
  }
  return { supabase, neon, live };
}

/**
 * The move tool (and the orphan-artwork sweep pause) is armed while
 * MOVE_DATABASE_TOKEN is set to anything but "off".
 */
export function moveTokenSet(env: Env): boolean {
  const value = (env.MOVE_DATABASE_TOKEN ?? "").trim();
  return value !== "" && value.toLowerCase() !== "off";
}
