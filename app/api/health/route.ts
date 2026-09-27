import { NextResponse } from "next/server";
import { devAuthEnabled } from "@/lib/auth/actor";
import { supabaseConfigured, supabasePublicKey } from "@/lib/auth/supabase-server";
import {
  checkAuthService,
  databaseProjectRef,
  supabaseProjectRef,
} from "@/lib/auth/supabase-diagnostics";

export const dynamic = "force-dynamic";

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
      // Sign-in and the database must use the same project.
      supabaseProject: supabaseProjectRef(process.env.NEXT_PUBLIC_SUPABASE_URL),
      databaseProject: databaseProjectRef(process.env.DATABASE_URL),
      authService: await checkAuthService(
        process.env.NEXT_PUBLIC_SUPABASE_URL,
        supabasePublicKey(),
      ),
      storage: process.env.BLOB_READ_WRITE_TOKEN
        ? "vercel-blob"
        : Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY ?? process.env.SUPABASE_SECRET_KEY)
          ? "supabase"
          : "local",
      email: process.env.RESEND_API_KEY ? "resend" : "logged-only",
      cron: Boolean(process.env.CRON_SECRET),
    },
    { status: ok ? 200 : 503 },
  );
}
