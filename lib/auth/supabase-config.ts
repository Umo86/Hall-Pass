import { databaseProjectRef, keyProjectRef, supabaseProjectRef } from "./supabase-diagnostics";

/** Same variables, same order, as lib/db/client.ts. */
const DATABASE_VARS = [
  "DATABASE_URL",
  "DIRECT_DATABASE_URL",
  "POSTGRES_URL",
  "DATABASE_URL_UNPOOLED",
  "POSTGRES_URL_NON_POOLING",
] as const;

type Env = Record<string, string | undefined>;

/** The Supabase project the app's database lives in, if it's a Supabase database. */
export function databaseSupabaseRef(env: Env = process.env): string | null {
  for (const name of DATABASE_VARS) {
    const ref = databaseProjectRef(env[name]?.trim());
    if (/^[a-z0-9]{15,30}$/.test(ref)) return ref;
  }
  return null;
}

/** Tidy a hand-typed Supabase URL: spaces, quotes, missing https://, extra path. */
function tidy(raw: string | undefined): URL | null {
  const v = raw
    ?.trim()
    .replace(/^["']|["']$/g, "")
    .trim();
  if (!v) return null;
  try {
    const u = new URL(/^https?:\/\//i.test(v) ? v : `https://${v}`);
    return new URL(`${u.protocol}//${u.host}`);
  } catch {
    return null;
  }
}

export type SupabaseUrlResolution = {
  url: string | null;
  source: "env" | "derived from database" | "not set";
  /** Why the configured value wasn't used, for logs and /api/health. */
  note?: string;
};

/**
 * The Supabase URL sign-in should use. Sign-in has to use the same project
 * as the database (a person's account id is their row id), so when the
 * database is a Supabase project and NEXT_PUBLIC_SUPABASE_URL is missing,
 * mistyped, the database host, or another project, the database's project
 * is used instead. A custom domain set on purpose is kept.
 */
export function resolveSupabaseUrl(env: Env = process.env): SupabaseUrlResolution {
  const configured = tidy(env.NEXT_PUBLIC_SUPABASE_URL);
  const dbRef = databaseSupabaseRef(env);
  if (!dbRef) {
    return configured
      ? { url: configured.origin, source: "env" }
      : { url: null, source: "not set" };
  }
  const derived = `https://${dbRef}.supabase.co`;
  if (!configured) {
    return {
      url: derived,
      source: "derived from database",
      note: env.NEXT_PUBLIC_SUPABASE_URL
        ? "NEXT_PUBLIC_SUPABASE_URL is not a valid URL"
        : undefined,
    };
  }
  const host = configured.hostname.toLowerCase();
  const isSupabaseHost = host.endsWith(".supabase.co") || host.endsWith(".supabase.com");
  if (!isSupabaseHost) return { url: configured.origin, source: "env" };
  if (host === `${dbRef}.supabase.co` && configured.protocol === "https:") {
    return { url: derived, source: "env" };
  }
  return {
    url: derived,
    source: "derived from database",
    note: `NEXT_PUBLIC_SUPABASE_URL (${host}) is not the database's project (${dbRef})`,
  };
}

let warned = false;

/** The Supabase URL to use everywhere (server, proxy, browser via props). */
export function supabaseUrl(): string | undefined {
  const r = resolveSupabaseUrl();
  if (r.note && !warned) {
    warned = true;
    console.warn(`Supabase: ${r.note} — using ${r.url}. Update the variable on Vercel.`);
  }
  return r.url ?? undefined;
}

/**
 * The public (anon / publishable) key to use. A legacy anon key names its
 * project; when it belongs to a different project than the one sign-in uses
 * and a publishable key is also set, the publishable key is used instead.
 */
export function resolveSupabaseKey(env: Env = process.env): string | undefined {
  const anon = env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim() || undefined;
  const publishable = env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY?.trim() || undefined;
  if (anon && publishable) {
    const urlRef = supabaseProjectRef(resolveSupabaseUrl(env).url ?? undefined);
    const anonRef = keyProjectRef(anon);
    if (anonRef !== "unknown" && anonRef !== urlRef) return publishable;
  }
  return anon ?? publishable;
}
