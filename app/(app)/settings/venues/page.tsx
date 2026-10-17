import { cookies } from "next/headers";
import { asc, desc, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { editions, events, venues } from "@/lib/db/schema";
import { todayInLondon } from "@/lib/today";
import { formatDate } from "@/lib/format";
import { invitesCanBeEmailed } from "@/lib/users/email";
import { PageHeader } from "@/components/page-header";
import { LAST_EVENT_COOKIE } from "@/components/setup/last-event";
import { SectionLocked, settingsAccess } from "@/components/settings/access";
import { VenuesView, type VenueRow } from "@/components/settings/venues-view";
import { portalGrantsByScope } from "@/components/portal/grants";

export const metadata = { title: "Venues · Settings" };
export const dynamic = "force-dynamic";

export default async function VenuesPage() {
  const { session, canOpen, canManage, canInvite } = await settingsAccess();
  const header = (
    <PageHeader
      title="Venues"
      description="Places you run events. You choose one when you create an event; archiving a venue stops it being offered."
    />
  );
  if (!canOpen("venues")) {
    return (
      <>
        {header}
        <SectionLocked id="venues" />
      </>
    );
  }
  const orgId = session.organisation.id;
  const today = todayInLondon();
  const [venueRows, editionRows, seriesRows, grants] = await Promise.all([
    db.select().from(venues).where(eq(venues.organisationId, orgId)).orderBy(asc(venues.name)),
    db
      .select({
        id: editions.id,
        code: editions.code,
        name: editions.name,
        venueId: editions.venueId,
        eventId: editions.eventId,
        status: editions.status,
        openStart: editions.openStart,
        openEnd: editions.openEnd,
      })
      .from(editions)
      .innerJoin(events, eq(editions.eventId, events.id))
      .where(eq(events.organisationId, orgId))
      .orderBy(desc(editions.openStart)),
    db.select().from(events).where(eq(events.organisationId, orgId)).orderBy(asc(events.name)),
    portalGrantsByScope(orgId, "venue"),
  ]);
  const lastCode = (await cookies()).get(LAST_EVENT_COOKIE)?.value?.toUpperCase() ?? null;

  const rows: VenueRow[] = venueRows.map((v) => {
    const here = editionRows.filter((e) => e.venueId === v.id);
    // Archived events take no new invitations (the server refuses them too).
    const list = here
      .filter((e) => e.status !== "archived")
      .map((e) => ({
        id: e.id,
        code: e.code,
        label: `${e.name} · ${formatDate(e.openStart)}`,
        upcoming: e.openEnd >= today,
        openStart: e.openStart,
      }));
    // Upcoming soonest first, then past newest first.
    const upcoming = list
      .filter((e) => e.upcoming)
      .sort((a, b) => a.openStart.localeCompare(b.openStart));
    const past = list.filter((e) => !e.upcoming);
    const inviteEvents = [...upcoming, ...past];
    const defaultEventId =
      inviteEvents.find((e) => e.code === lastCode)?.id ?? upcoming[0]?.id ?? past[0]?.id ?? null;
    return {
      id: v.id,
      name: v.name,
      address: v.address,
      riggingContactName: v.riggingContactName,
      riggingContactEmail: v.riggingContactEmail,
      isArchived: v.isArchived,
      eventCodes: here.map((e) => e.code),
      grants: grants.get(v.id) ?? [],
      inviteEvents: inviteEvents.map(({ id, label, upcoming }) => ({ id, label, upcoming })),
      defaultEventId,
    };
  });
  const seriesCount = new Map<string, number>();
  for (const e of editionRows) seriesCount.set(e.eventId, (seriesCount.get(e.eventId) ?? 0) + 1);

  return (
    <>
      {header}
      <VenuesView
        venues={rows}
        series={seriesRows.map((s) => ({
          id: s.id,
          name: s.name,
          eventCount: seriesCount.get(s.id) ?? 0,
        }))}
        canEdit={canManage}
        canInvite={canInvite}
        emailOn={invitesCanBeEmailed()}
      />
    </>
  );
}
