import { NextResponse } from "next/server";
import { authBaseURL, authConfigured, devAuthEnabled } from "@/lib/auth/config";
import { emailConfigured } from "@/lib/email/dispatch";
import { blobEnabled, s3Enabled, s3Probe, storageBackend } from "@/lib/storage";
import { latestMigration, schemaState, type SchemaState } from "@/lib/db/schema-state";

export const dynamic = "force-dynamic";

/** Who hosts the database, from its host name (never the credentials). */
function databaseProvider(url: string | undefined): string {
  if (!url) return "not set";
  try {
    const host = new URL(url).hostname.toLowerCase();
    if (host.endsWith(".supabase.co") || host.endsWith(".supabase.com")) return "supabase";
    if (host.endsWith(".neon.tech")) return "neon";
    if (host.endsWith(".vercel-storage.com")) return "vercel-postgres";
    if (host === "localhost" || host === "127.0.0.1") return "local";
    return "other";
  } catch {
    return "invalid URL";
  }
}

/**
 * Deployment health: configuration booleans only, no secrets. Used to verify
 * a deployment is fully wired without needing to sign in.
 */
export async function GET() {
  let database: "ok" | "unreachable" | "unconfigured" = "unconfigured";
  let databaseError: string | undefined;
  let seeded = false;
  let schema: SchemaState = "unknown";
  if (process.env.DATABASE_URL) {
    try {
      const { sql } = await import("drizzle-orm");
      const { db, databaseVia } = await import("@/lib/db/client");
      const rows = await db.execute<{ n: number }>(
        sql`SELECT count(*)::int AS n FROM organisations`,
      );
      database = "ok";
      seeded = Number(rows[0]?.n ?? 0) > 0;
      // Has `pnpm db:migrate` run for this release? (README → Releasing.)
      try {
        const applied = await db.execute<{ at: string | number | null }>(
          sql`SELECT max(created_at) AS at FROM drizzle.__drizzle_migrations`,
        );
        const at = applied[0]?.at;
        schema = schemaState(at == null ? null : Number(at));
      } catch {
        schema = "unknown";
      }
      if (databaseVia && databaseVia !== "DATABASE_URL") {
        databaseError = `Running on ${databaseVia} because an earlier database variable is unreachable — everything works, but remove or fix the stale variable when convenient.`;
      }
    } catch (err) {
      database = "unreachable";
      const { describeDbError } = await import("@/lib/db/diagnose");
      databaseError = describeDbError(err, process.env.DATABASE_URL);
    }
  }
  // Real sign-in wins the label; demo sign-in is reported on its own.
  const auth = authConfigured() ? "better-auth" : devAuthEnabled() ? "demo" : "none";
  const ok = database === "ok" && seeded && auth !== "none" && schema !== "behind";
  return NextResponse.json(
    {
      ok,
      database,
      ...(databaseError ? { databaseError } : {}),
      seeded,
      // "behind": this code expects migrations the database hasn't had yet.
      schema,
      ...(schema === "behind"
        ? { schemaNote: `Run pnpm db:migrate (expects ${latestMigration().tag})` }
        : {}),
      auth,
      demoSignIn: devAuthEnabled(),
      // The host sign-in links point at (public: it's in every link).
      authBaseUrl: new URL(authBaseURL()).host,
      databaseProvider: databaseProvider(process.env.DATABASE_URL),
      storage: storageBackend(),
      // A live call to the bucket, so a wrong key or endpoint shows up here.
      ...(s3Enabled() ? { storageCheck: await s3Probe() } : {}),
      // Both set = files not yet copied to the bucket still read from Blob.
      ...(s3Enabled() && blobEnabled() ? { storageNote: "migrating from vercel-blob" } : {}),
      email: emailConfigured() ? "resend" : "logged-only",
      cron: Boolean(process.env.CRON_SECRET),
    },
    { status: ok ? 200 : 503 },
  );
}
