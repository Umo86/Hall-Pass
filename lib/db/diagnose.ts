import "server-only";

/**
 * Turns a database connection error into a safe, human-readable cause with a
 * concrete fix. Never includes credentials: the raw message is only matched
 * against known patterns, and any userinfo in URLs is redacted before display.
 */
export function describeDbError(err: unknown): string {
  const raw = messageOf(err).toLowerCase();

  if (raw.includes("password authentication failed") || raw.includes("sasl")) {
    return "Wrong database password — the URI's password does not match. Re-copy it, or reset it in Supabase (Project Settings → Database) and update DATABASE_URL.";
  }
  if (raw.includes("tenant or user not found")) {
    return "The pooler username is wrong — it must be postgres.<project-ref> (e.g. postgres.enspcibuqqscqydmbefq), not just postgres. Re-copy the full URI from Supabase's Connect dialog.";
  }
  if (raw.includes("enotfound") || raw.includes("eai_again") || raw.includes("getaddrinfo")) {
    return "The host name in DATABASE_URL does not resolve — it is mistyped or incomplete. Re-copy the full pooler URI from Supabase's Connect dialog.";
  }
  if (raw.includes("etimedout") || raw.includes("timeout") || raw.includes("econnrefused") || raw.includes("enetunreach")) {
    return "The database host did not answer. Use the pooler URI (…pooler.supabase.com), not the direct db.….supabase.co address — the direct one is IPv6-only and unreachable from most hosts. Also check the port (6543).";
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

function messageOf(err: unknown): string {
  if (err instanceof Error) {
    return [err.message, err.cause instanceof Error ? err.cause.message : ""].join(" ");
  }
  return String(err ?? "");
}
