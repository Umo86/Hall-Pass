import { NextResponse } from "next/server";
import { authBaseURL, authConfigured, devAuthEnabled } from "@/lib/auth/config";
import { emailConfigured } from "@/lib/email/dispatch";
import { blobEnabled, s3Enabled, s3Probe, storageBackend } from "@/lib/storage";
import { latestMigration } from "@/lib/db/schema-state";
import { checkDatabase } from "@/lib/db/status";

export const dynamic = "force-dynamic";

/**
 * Deployment health: configuration booleans only, no secrets. Used to verify
 * a deployment is fully wired without needing to sign in. The database
 * fields describe the connection actually used (lib/db/client.ts), never
 * just a variable that is set.
 */
export async function GET() {
  const db = await checkDatabase();
  // Real sign-in wins the label; demo sign-in is reported on its own.
  const auth = authConfigured() ? "better-auth" : devAuthEnabled() ? "demo" : "none";
  const ok = db.state === "ok" && db.seeded && auth !== "none" && db.schema !== "behind";
  return NextResponse.json(
    {
      ok,
      database: db.state,
      // Why it's unreachable or unconfigured; in auto mode also "Running on X because…".
      ...(db.error ? { databaseError: db.error } : {}),
      seeded: db.seeded,
      // "behind": this code expects migrations the database hasn't had yet.
      schema: db.schema,
      ...(db.schema === "behind"
        ? {
            schemaNote: `Run the "Database migrate" workflow, or pnpm db:migrate (expects ${latestMigration().tag})`,
          }
        : {}),
      auth,
      demoSignIn: devAuthEnabled(),
      // The host sign-in links point at (public: it's in every link).
      authBaseUrl: new URL(authBaseURL()).host,
      // "neon" (DATABASE_TARGET=neon), "auto" (first reachable variable) or "invalid".
      databaseTarget: db.info?.target ?? db.target,
      databaseProvider: db.info?.provider ?? "not set",
      databaseProject: db.info?.project ?? null,
      databaseRegion: db.info?.region ?? null,
      databaseName: db.info?.name ?? null,
      databaseVia: db.info?.via ?? null,
      functionRegion: process.env.VERCEL_REGION ?? null,
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
