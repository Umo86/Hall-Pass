import "server-only";
import { databaseProviderOf } from "./urls";

/**
 * Turns a database connection error into a safe, human-readable cause with a
 * concrete fix, for whichever host the URL points at (Neon or Supabase; the
 * Supabase hints go once nothing runs on Supabase). Never includes
 * credentials: only the host and port are ever echoed back, the raw message
 * is matched against known patterns, and any userinfo in URLs is redacted
 * before display. `name` is the variable the URL came from.
 */
export function describeDbError(
  err: unknown,
  connectionString?: string,
  name = "DATABASE_URL",
): string {
  // Malformed values first — these explain most "host does not resolve" cases.
  const shape = connectionString ? describeConfigShape(connectionString, name) : null;
  if (shape) return shape;

  const raw = messageOf(err).toLowerCase();
  const target = connectionString ? hostOf(connectionString) : null;
  const at = target ? ` It is trying to reach "${target}".` : "";
  const neon = connectionString ? databaseProviderOf(connectionString) === "neon" : false;

  // Neon's own refusals.
  if (raw.includes("channel_binding")) {
    return `Remove channel_binding from ${name}: the app's Postgres driver can't pass it on (TLS stays on through sslmode=require).`;
  }
  if (raw.includes("compute time quota") || raw.includes("data transfer quota")) {
    return "Neon's Free plan allowance is used up until the 1st of next month, so the database is paused. Upgrading the Neon plan lifts it at once (a paid change: the owner decides).";
  }
  if (raw.includes("endpoint") && raw.includes("disabled")) {
    return "The Neon compute is disabled — enable it in the Neon console (the project → Branches → the branch → Computes).";
  }

  if (raw.includes("password authentication failed") || raw.includes("sasl")) {
    return neon
      ? `Wrong database password — the URI's password does not match. Re-copy ${name} from Vercel → Storage → the Neon database (its .env.local tab).`
      : `Wrong database password — the URI's password does not match. Re-copy it, or reset it in Supabase (Project Settings → Database) and update ${name}.`;
  }
  if (raw.includes("tenant or user not found")) {
    return "The pooler username is wrong — it must be postgres.<project-ref> (e.g. postgres.enspcibuqqscqydmbefq), not just postgres. Re-copy the full URI from Supabase's Connect dialog.";
  }
  if (raw.includes("enotfound") || raw.includes("eai_again") || raw.includes("getaddrinfo")) {
    return neon
      ? `The host name in ${name} does not exist — it is mistyped or incomplete.${at} Re-copy it from Vercel → Storage → the Neon database.`
      : `The host name in ${name} does not exist — it is mistyped or incomplete.${at} Compare it character by character with the Transaction pooler URI in Supabase's Connect dialog (it ends pooler.supabase.com).`;
  }
  if (
    raw.includes("etimedout") ||
    raw.includes("timeout") ||
    raw.includes("econnrefused") ||
    raw.includes("enetunreach")
  ) {
    return neon
      ? `The Neon database did not answer.${at} An idle database wakes within a few seconds, so try again; if it keeps failing, check the project in the Neon console.`
      : `The database host did not answer.${at} Use the pooler URI (…pooler.supabase.com, port 6543), not the direct db.….supabase.co address — the direct one is IPv6-only and unreachable from most hosts.`;
  }
  if (raw.includes("ssl") || raw.includes("tls")) {
    return `TLS negotiation failed — append ?sslmode=require to ${name}.`;
  }
  if (raw.includes("does not exist") && raw.includes("database")) {
    return neon
      ? "The database name in the URI is wrong — Neon's is usually /neondb."
      : "The database name in the URI is wrong — it should end in /postgres.";
  }

  const redacted = messageOf(err)
    .replace(/\/\/[^@/\s]+@/g, "//***@")
    .slice(0, 200);
  return redacted ? `Connection failed: ${redacted}` : "Connection failed for an unknown reason.";
}

/** Detects paste mistakes in the value itself, before any network diagnosis. */
export function describeConfigShape(value: string, name = "DATABASE_URL"): string | null {
  const trimmed = value.trim();
  if (/^["'`]|["'`]$/.test(trimmed)) {
    return `${name} is wrapped in quote marks — edit the variable in Vercel and delete the quotes at the start and end, keeping just the URI.`;
  }
  if (value.includes("[YOUR-PASSWORD]") || /\[[^\]]*PASSWORD[^\]]*\]/i.test(value)) {
    return `${name} still contains the [YOUR-PASSWORD] placeholder — replace that whole bracketed part with your real database password (no square brackets).`;
  }
  if (/\s/.test(trimmed)) {
    return `${name} contains a space or line break in the middle — re-paste it as one unbroken line.`;
  }
  if (!/^postgres(ql)?:\/\//.test(trimmed)) {
    return `${name} does not start with postgresql:// — paste the full connection URI, not just the host or password.`;
  }
  const host = hostOf(trimmed);
  if (host && /^db\..+\.supabase\.co(:|$)/.test(host)) {
    return `${name} points at the direct address (${host}), which most hosts cannot reach. Use the Transaction pooler URI instead — in Supabase's Connect dialog it ends pooler.supabase.com:6543.`;
  }
  if (host && /pooler\.supabase\.co(:|$)/.test(host)) {
    return `The host "${host}" is missing the final "m" — it should end pooler.supabase.com.`;
  }
  return null;
}

function hostOf(connectionString: string): string | null {
  try {
    const url = new URL(connectionString.trim().replace(/^postgres:\/\//, "postgresql://"));
    return url.port ? `${url.hostname}:${url.port}` : url.hostname;
  } catch {
    return null;
  }
}

function messageOf(err: unknown): string {
  if (err instanceof Error) {
    return [err.message, err.cause instanceof Error ? err.cause.message : ""].join(" ");
  }
  return String(err ?? "");
}
