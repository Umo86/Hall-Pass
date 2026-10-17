import Link from "next/link";
import { CalendarPlus, Copy, Plus } from "lucide-react";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { todayInLondon } from "@/lib/today";
import {
  EVENT_PHASE_LABELS,
  eventGroup,
  eventPhase,
  listEditions,
  showLogoUrl,
  sortForGroup,
  type EventGroup,
} from "@/lib/queries/editions";
import { getSetupSummaries, setupContacts, setupPermissionsFor } from "@/lib/queries/setup";
import { Page, PageHeader } from "@/components/page-header";
import { EmptyState } from "@/components/empty-state";
import { SegmentedLinks } from "@/components/ui/segmented";
import { Button } from "@/components/ui/button";
import { EventsList, type EventCard } from "@/components/editions/events-list";
import { NoEventsYet } from "@/components/setup/no-events-state";
import { dateRangeWithYear } from "@/components/setup/format";

export const metadata = { title: "Events" };
export const dynamic = "force-dynamic";

const VIEWS: { id: EventGroup; label: string }[] = [
  { id: "upcoming", label: "Upcoming & live" },
  { id: "past", label: "Past" },
  { id: "archived", label: "Archived" },
];

const EMPTY_TEXT: Record<EventGroup, string> = {
  upcoming: "Nothing coming up. Past events are under Past.",
  past: "No past events yet.",
  archived: "Nothing archived. A super admin archives an event once it's finished with.",
};

export default async function EventsPage({
  searchParams,
}: {
  searchParams: Promise<{ view?: string }>;
}) {
  const session = await requireStaffSession();
  const orgId = session.organisation.id;
  const { view: rawView } = await searchParams;
  const view: EventGroup = VIEWS.some((v) => v.id === rawView)
    ? (rawView as EventGroup)
    : "upcoming";
  const canCreate = can(session.actor, { type: "events.create" });
  const canSetup = can(session.actor, { type: "event.setup" });
  const canArchive = can(session.actor, { type: "events.archive" });
  const rows = await listEditions(orgId);

  if (rows.length === 0) {
    return (
      <Page>
        <PageHeader
          title="Events"
          description="Each event has its own signage, sponsorship, sign-offs and deadlines."
        />
        {canCreate ? (
          <EmptyState
            icon={CalendarPlus}
            title="Create your first event"
            description="Start with its name, dates and venue — halls, deadlines and people come next, one step at a time."
            action={
              <Button asChild size="lg">
                <Link href="/start">Create your event</Link>
              </Button>
            }
          />
        ) : (
          <NoEventsYet
            brandName={session.organisation.brandName}
            contacts={await setupContacts(orgId)}
          />
        )}
      </Page>
    );
  }

  const today = todayInLondon();
  const grouped = new Map<EventGroup, typeof rows>(VIEWS.map((v) => [v.id, []]));
  for (const r of rows) grouped.get(eventGroup(r.edition, today))!.push(r);
  const inView = sortForGroup(
    grouped.get(view)!.map((r) => ({ ...r, openStart: r.edition.openStart, code: r.edition.code })),
    view,
  );
  const [summaries, logos] = await Promise.all([
    // Setup progress only matters for events still to come.
    canSetup && view === "upcoming"
      ? getSetupSummaries(
          inView.filter((r) => r.edition.status !== "archived").map((r) => r.edition),
          orgId,
          setupPermissionsFor(session.actor),
        )
      : Promise.resolve(new Map<string, { done: number; total: number; complete: boolean }>()),
    Promise.all(inView.map((r) => showLogoUrl(r.edition.logoPath))),
  ]);

  const cards: EventCard[] = inView.map((r, i) => {
    const phase = eventPhase(r.edition, today);
    const summary = summaries.get(r.edition.id);
    const incomplete = summary && !summary.complete;
    return {
      id: r.edition.id,
      code: r.edition.code,
      name: r.edition.name,
      href: incomplete ? `/${r.edition.code}/setup` : `/${r.edition.code}/dashboard`,
      line: `Open ${dateRangeWithYear(r.edition.openStart, r.edition.openEnd)} · ${r.venue.name}`,
      series: r.event.name,
      phase,
      phaseLabel: EVENT_PHASE_LABELS[phase],
      setup: summary ? { done: summary.done, total: summary.total } : null,
      logoUrl: logos[i],
      archived: r.edition.status === "archived",
    };
  });

  return (
    <Page>
      <PageHeader
        title="Events"
        description="Each event has its own signage, sponsorship, sign-offs and deadlines."
        actions={
          canCreate ? (
            <>
              <Button asChild variant="outline">
                <Link href="/start?mode=copy">
                  <Copy aria-hidden /> Copy an event
                </Link>
              </Button>
              <Button asChild>
                <Link href="/start">
                  <Plus aria-hidden /> New event
                </Link>
              </Button>
            </>
          ) : undefined
        }
      />
      <SegmentedLinks
        label="Which events"
        className="self-start"
        items={VIEWS.map((v) => ({
          label: v.label,
          href: v.id === "upcoming" ? "/events" : `/events?view=${v.id}`,
          active: v.id === view,
          count: grouped.get(v.id)!.length,
        }))}
      />
      <EventsList
        key={view}
        events={cards}
        canSetup={canSetup}
        canArchive={canArchive}
        emptyText={EMPTY_TEXT[view]}
      />
    </Page>
  );
}
