import { NextResponse } from "next/server";
import { eq, inArray, isNotNull, and } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { editionDeadlines, editions, signageItems } from "@/lib/db/schema";
import { sessionForUserId } from "@/lib/auth/actor";
import { effectiveDeadline, type DeadlineKey } from "@/lib/deadlines";
import { buildCalendar, verifyIcalToken, type CalendarEvent } from "@/lib/ical";
import { pendingInstancesForUser } from "@/lib/queries/approvals";
import { appUrl } from "@/lib/app-url";

export const dynamic = "force-dynamic";

/**
 * Tokenised read-only calendar feed: edition deadlines and install dates for
 * staff, plus the caller's own pending sign-off due dates. The token is an
 * HMAC-signed user id, so the feed carries exactly what that user may see.
 */
export async function GET(_req: Request, ctx: { params: Promise<{ token: string }> }) {
  const { token } = await ctx.params;
  const userId = verifyIcalToken(token);
  if (!userId) return new NextResponse("Not found", { status: 404 });
  const session = await sessionForUserId(userId);
  if (!session) return new NextResponse("Not found", { status: 404 });

  const base = appUrl();
  const events: CalendarEvent[] = [];

  if (session.actor.kind === "staff") {
    const eds = await db.select().from(editions);
    const dls = eds.length
      ? await db
          .select()
          .from(editionDeadlines)
          .where(inArray(editionDeadlines.editionId, eds.map((e) => e.id)))
      : [];
    for (const ed of eds) {
      const rows = dls.filter((d) => d.editionId === ed.id);
      for (const row of rows) {
        const date = effectiveDeadline(
          {
            buildStart: ed.buildStart,
            deadlines: rows.map((r) => ({
              key: r.key as DeadlineKey,
              daysBeforeBuildStart: r.daysBeforeBuildStart,
              overrideDate: r.overrideDate,
            })),
          },
          row.key as DeadlineKey,
        );
        if (!date) continue;
        events.push({
          uid: `deadline-${row.id}@hallpass`,
          date,
          title: `${ed.code}: ${row.label}`,
          url: base ? `${base}/${ed.code}/dashboard` : undefined,
        });
      }
      const items = await db
        .select({
          ref: signageItems.ref,
          name: signageItems.name,
          installDate: signageItems.installDate,
        })
        .from(signageItems)
        .where(and(eq(signageItems.editionId, ed.id), isNotNull(signageItems.installDate)));
      for (const item of items) {
        events.push({
          uid: `install-${item.ref}@hallpass`,
          date: item.installDate!,
          title: `Install ${item.ref} — ${item.name}`,
          url: base ? `${base}/${ed.code}/signage/${item.ref}` : undefined,
        });
      }
    }
  }

  for (const pending of await pendingInstancesForUser(session)) {
    if (!pending.raw.dueAt) continue;
    const ref = pending.isSignage
      ? (pending.bundle as { item: { ref: string } }).item.ref
      : "stand submission";
    events.push({
      uid: `signoff-${pending.raw.id}@hallpass`,
      date: pending.raw.dueAt.toISOString().slice(0, 10),
      title: `Sign-off due: ${pending.raw.stepNameSnapshot} (${ref})`,
      url: base
        ? session.actor.kind === "staff"
          ? `${base}/approvals`
          : `${base}/portal/approvals`
        : undefined,
    });
  }

  const body = buildCalendar(`${session.organisation.brandName} deadlines`, events);
  return new NextResponse(body, {
    headers: {
      "Content-Type": "text/calendar; charset=utf-8",
      "Cache-Control": "private, max-age=300",
      "Content-Disposition": 'inline; filename="hallpass.ics"',
    },
  });
}
