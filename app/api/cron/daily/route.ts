import { NextResponse } from "next/server";
import { runDailyJobs } from "@/lib/cron/jobs";
import { dispatchNotificationEmails } from "@/lib/email/dispatch";

export const dynamic = "force-dynamic";
export const maxDuration = 300;

function isAuthorised(request: Request): boolean {
  const secret = process.env.CRON_SECRET;
  if (!secret) return false;
  return request.headers.get("authorization") === `Bearer ${secret}`;
}

/** Today's date in Europe/London, whatever timezone the runtime uses. */
function todayInLondon(): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: process.env.APP_TIMEZONE ?? "Europe/London",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

/**
 * Daily scheduler (brief 7.2), called by Vercel Cron at 07:00 Europe/London
 * (scheduled in UTC; "today" computed here so BST/GMT changes don't break
 * it). Idempotent: every send checks reminder_log first.
 */
async function run(request: Request) {
  if (!isAuthorised(request)) {
    return NextResponse.json({ error: "Unauthorised" }, { status: 401 });
  }
  const url = new URL(request.url);
  const today = url.searchParams.get("today") ?? todayInLondon();
  const jobs = await runDailyJobs(today);
  const emailed = await dispatchNotificationEmails({ limit: 500 });
  return NextResponse.json({ ok: true, today, jobs, emailed });
}

// Vercel Cron invokes with GET; POST kept for manual runs per the brief.
export const GET = run;
export const POST = run;
