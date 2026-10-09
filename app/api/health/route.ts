import { NextResponse } from "next/server";
import { devAuthEnabled } from "@/lib/auth/actor";
import { supabaseConfigured, supabasePublicKey } from "@/lib/auth/supabase-server";
import {
  checkAuthService,
  databaseProjectRef,
  keyProjectRef,
  supabaseProjectRef,
} from "@/lib/auth/supabase-diagnostics";
import { resolveSupabaseUrl } from "@/lib/auth/supabase-config";
import { blobEnabled, s3Enabled, storageBackend } from "@/lib/storage";

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
  if (process.env.DATABASE_URL) {
    try {
      const { sql } = await import("drizzle-orm");
      const { db, databaseVia } = await import("@/lib/db/client");
      const rows = await db.execute<{ n: number }>(
        sql`SELECT count(*)::int AS n FROM organisations`,
      );
      database = "ok";
      seeded = Number(rows[0]?.n ?? 0) > 0;
      if (databaseVia && databaseVia !== "DATABASE_URL") {
        databaseError = `Running on ${databaseVia} because an earlier database variable is unreachable — everything works, but remove or fix the stale variable when convenient.`;
      }
    } catch (err) {
      database = "unreachable";
      const { describeDbError } = await import("@/lib/db/diagnose");
      databaseError = describeDbError(err, process.env.DATABASE_URL);
    }
  }
  const supabase = resolveSupabaseUrl();
  const auth = devAuthEnabled() ? "demo" : supabaseConfigured() ? "supabase" : "none";
  const ok = database === "ok" && seeded && auth !== "none";
  return NextResponse.json(
    {
      ok,
      database,
      ...(databaseError ? { databaseError } : {}),
      seeded,
      auth,
      // Project ids are public (they're in every page's sign-in requests).
      // When the database is itself a Supabase project, sign-in must use the
      // same one; a Neon (or other) database pairs with any Supabase project.
      supabaseProject: supabaseProjectRef(supabase.url ?? undefined),
      supabaseUrlSource: supabase.source,
      ...(supabase.note ? { supabaseUrlNote: supabase.note } : {}),
      supabaseKeyProject: keyProjectRef(supabasePublicKey()),
      databaseProvider: databaseProvider(process.env.DATABASE_URL),
      databaseProject: databaseProjectRef(process.env.DATABASE_URL),
      authService: await checkAuthService(supabase.url ?? undefined, supabasePublicKey()),
      storage: storageBackend(),
      // Both set = files not yet copied to the bucket still read from Blob.
      ...(s3Enabled() && blobEnabled() ? { storageNote: "migrating from vercel-blob" } : {}),
      email: process.env.RESEND_API_KEY ? "resend" : "logged-only",
      cron: Boolean(process.env.CRON_SECRET),
    },
    { status: ok ? 200 : 503 },
  );
}
