import "server-only";

/**
 * Turns a database connection error into a safe, human-readable cause with a
 * concrete fix. Never includes credentials: only the host and port are ever
 * echoed back, the raw message is matched against known patterns, and any
 * userinfo in URLs is redacted before display.
 */
export function describeDbError(err: unknown, connectionString?: string): string {
  // Malformed values first — these explain most "host does not resolve" cases.
  const shape = connectionString ? describeConfigShape(connectionString) : null;
  if (shape) return shape;

  const raw = messageOf(err).toLowerCase();
  const target = connectionString ? hostOf(connectionString) : null;
  const at = target ? ` It is trying to reach "${target}".` : "";

  if (raw.includes("password authentication failed") || raw.includes("sasl")) {
    return "Wrong database password — the URI's password does not match. Re-copy it, or reset it in Supabase (Project Settings → Database) and update DATABASE_URL.";
  }
  if (raw.includes("tenant or user not found")) {
    return "The pooler username is wrong — it must be postgres.<project-ref> (e.g. postgres.enspcibuqqscqydmbefq), not just postgres. Re-copy the full URI from Supabase's Connect dialog.";
  }
  if (raw.includes("enotfound") || raw.includes("eai_again") || raw.includes("getaddrinfo")) {
    return `The host name in DATABASE_URL does not exist — it is mistyped or incomplete.${at} Compare it character by character with the Transaction pooler URI in Supabase's Connect dialog (it ends pooler.supabase.com).`;
  }
  if (
    raw.includes("etimedout") ||
    raw.includes("timeout") ||
    raw.includes("econnrefused") ||
    raw.includes("enetunreach")
  ) {
    return `The database host did not answer.${at} Use the pooler URI (…pooler.supabase.com, port 6543), not the direct db.….supabase.co address — the direct one is IPv6-only and unreachable from most hosts.`;
  }
  if (raw.includes("ssl") || raw.includes("tls")) {
    return "TLS negotiation failed — append ?sslmode=require to DATABASE_URL.";
  }
  if (raw.includes("does not exist") && raw.includes("database")) {
    return "The database name in the URI is wrong — it should end in /postgres.";
  }

  const redacted = messageOf(err).replace(/\/\/[^@/\s]+@/g, "//***@").slice(0, 200);
  return redacted ? `Connection failed: ${redacted}` : "Connection failed for an unknown reason.";
}

/** Detects paste mistakes in the value itself, before any network diagnosis. */
export function describeConfigShape(value: string): string | null {
  const trimmed = value.trim();
  if (/^["'`]|["'`]$/.test(trimmed)) {
    return "DATABASE_URL is wrapped in quote marks — edit the variable in Vercel and delete the quotes at the start and end, keeping just the URI.";
  }
  if (value.includes("[YOUR-PASSWORD]") || /\[[^\]]*PASSWORD[^\]]*\]/i.test(value)) {
    return "DATABASE_URL still contains the [YOUR-PASSWORD] placeholder — replace that whole bracketed part with your real database password (no square brackets).";
  }
  if (/\s/.test(trimmed)) {
    return "DATABASE_URL contains a space or line break in the middle — re-paste it as one unbroken line.";
  }
  if (!/^postgres(ql)?:\/\//.test(trimmed)) {
    return "DATABASE_URL does not start with postgresql:// — paste the full connection URI, not just the host or password.";
  }
  const host = hostOf(trimmed);
  if (host && /^db\..+\.supabase\.co(:|$)/.test(host)) {
    return `DATABASE_URL points at the direct address (${host}), which most hosts cannot reach. Use the Transaction pooler URI instead — in Supabase's Connect dialog it ends pooler.supabase.com:6543.`;
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
