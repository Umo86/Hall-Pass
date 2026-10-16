import Link from "next/link";
import { Lock } from "lucide-react";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { events } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { addDaysIso } from "@/lib/deadlines";
import { todayInLondon } from "@/lib/today";
import { listEditions } from "@/lib/queries/editions";
import {
  copySourceCounts,
  countActiveEvents,
  setupContacts,
  venuesForPicker,
} from "@/lib/queries/setup";
import { Page, PageHeader } from "@/components/page-header";
import { EmptyState } from "@/components/empty-state";
import { Button } from "@/components/ui/button";
import { AskContacts, NoEventsYet } from "@/components/setup/no-events-state";
import { CreateEventForm, type CopySource } from "@/components/setup/create-event-form";

export const metadata = { title: "Create your event" };
export const dynamic = "force-dynamic";

/** About 18 months: a recent event is worth copying. */
const RECENT_DAYS = 548;

function monthYear(iso: string) {
  return new Intl.DateTimeFormat("en-GB", {
    month: "short",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(`${iso}T12:00:00Z`));
}

export default async function StartPage({
  searchParams,
}: {
  searchParams: Promise<{ mode?: string }>;
}) {
  const session = await requireStaffSession();
  const orgId = session.organisation.id;
  if (!can(session.actor, { type: "events.create" })) {
    const [active, contacts] = await Promise.all([countActiveEvents(orgId), setupContacts(orgId)]);
    return (
      <Page width="narrow">
        <PageHeader title="Create your event" />
        {active === 0 ? (
          <NoEventsYet brandName={session.organisation.brandName} contacts={contacts} />
        ) : (
          <EmptyState
            icon={Lock}
            title="Only admins and Operations create events"
            description={<AskContacts contacts={contacts} suffix="if you need a new one" />}
            action={
              <Button asChild variant="outline">
                <Link href="/events">See all events</Link>
              </Button>
            }
          />
        )}
      </Page>
    );
  }
  const { mode } = await searchParams;
  const [rows, venueRows, seriesRows, countsFor] = await Promise.all([
    listEditions(orgId),
    venuesForPicker(orgId),
    db.select().from(events).where(eq(events.organisationId, orgId)).orderBy(events.name),
    copySourceCounts(orgId),
  ]);
  const today = todayInLondon();
  const canCopyAccess = can(session.actor, { type: "partners.invite" });

  // Newest first; archived events can still be copied, after the others.
  const sources: CopySource[] = [...rows]
    .sort(
      (a, b) =>
        Number(a.edition.status === "archived") - Number(b.edition.status === "archived") ||
        b.edition.openStart.localeCompare(a.edition.openStart),
    )
    .map((r) => ({
      id: r.edition.id,
      name: r.edition.name,
      code: r.edition.code,
      label: `${r.edition.name} · ${r.venue.name} · ${monthYear(r.edition.openStart)}${r.edition.status === "archived" ? " (archived)" : ""}`,
      venueId: r.edition.venueId,
      venueName: r.venue.name,
      dates: {
        buildStart: r.edition.buildStart,
        buildEnd: r.edition.buildEnd,
        openStart: r.edition.openStart,
        openEnd: r.edition.openEnd,
        breakdownEnd: r.edition.breakdownEnd,
      },
      counts: countsFor(r.edition.id),
    }));
  const recent = rows.some((r) => r.edition.openStart >= addDaysIso(today, -RECENT_DAYS));
  const initialMode =
    sources.length === 0
      ? "fresh"
      : mode === "copy" || mode === "fresh"
        ? mode
        : recent
          ? "copy"
          : "fresh";

  return (
    <Page width="narrow" className="max-w-2xl pb-28 sm:pb-6">
      <PageHeader
        title="Create your event"
        description="Start with the basics — you'll add halls, deadlines and people next."
        back={rows.length > 0 ? { href: "/events", label: "Events" } : undefined}
      />
      <CreateEventForm
        initialMode={initialMode}
        sources={sources}
        venues={venueRows}
        series={seriesRows.map((s) => ({ id: s.id, name: s.name }))}
        takenCodes={rows.map((r) => r.edition.code)}
        canCopyAccess={canCopyAccess}
      />
    </Page>
  );
}
