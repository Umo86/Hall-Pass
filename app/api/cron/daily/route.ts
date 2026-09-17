import { NextResponse } from "next/server";

/**
 * Daily scheduler entry point, called by Vercel Cron at 07:00 Europe/London.
 * The jobs (reminders, escalation, chasers, expiry, digest) are built in
 * Phase 2; until then this endpoint only validates the secret and reports
 * that no jobs are registered. Idempotency is enforced per job via
 * reminder_log once the jobs exist.
 */
function isAuthorised(request: Request): boolean {
  const secret = process.env.CRON_SECRET;
  if (!secret) return false;
  return request.headers.get("authorization") === `Bearer ${secret}`;
}

async function run(request: Request) {
  if (!isAuthorised(request)) {
    return NextResponse.json({ error: "Unauthorised" }, { status: 401 });
  }
  return NextResponse.json({ ok: true, jobs: [], note: "Scheduler jobs arrive in Phase 2" });
}

// Vercel Cron invokes with GET; POST is kept for manual triggering per the brief.
export const GET = run;
export const POST = run;
