import { NextResponse } from "next/server";
import { devAuthEnabled } from "@/lib/auth/actor";
import { supabaseConfigured } from "@/lib/auth/supabase-server";

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
      if (databaseVia === "DIRECT_DATABASE_URL") {
        databaseError =
          "Running on DIRECT_DATABASE_URL because DATABASE_URL is unreachable — sign-in works, but fix DATABASE_URL (transaction pooler, port 6543) when convenient.";
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
      storage: Boolean(
        process.env.SUPABASE_SERVICE_ROLE_KEY ?? process.env.SUPABASE_SECRET_KEY,
      )
        ? "supabase"
        : "local",
      email: process.env.RESEND_API_KEY ? "resend" : "logged-only",
      cron: Boolean(process.env.CRON_SECRET),
    },
    { status: ok ? 200 : 503 },
  );
}
