import "server-only";
/**
 * The Events card's data (Users → Events) for a person's page and the Add
 * forms: the events the viewer may give, in the switcher's order, the
 * event to start from, and how many of the person's events the viewer
 * can't open (counted, never named).
 */
import { cookies } from "next/headers";
import { assignableEditions, seesEdition, type Actor, type StaffActor } from "@/lib/authz";
import {
  eventGroup,
  LAST_EVENT_COOKIE,
  listEditions,
  pickDefaultEdition,
  sortForGroup,
} from "@/lib/queries/editions";
import { todayInLondon } from "@/lib/today";
import { dateRangeWithYear } from "@/components/setup/format";
import type { EventOption } from "@/components/users/person-fields";

export type EventCardData = {
  events: EventOption[];
  /** The viewer sees every event, so they may give "All events". */
  allowAll: boolean;
  /** Of the person's events, how many the viewer can't open. */
  hiddenCount: number;
  /** The person's events the viewer can open (null = every event). */
  visibleIds: string[] | null;
  /** Why the card is read-only for this viewer, or null. */
  readOnly: string | null;
  /** The event last opened, else the next coming up. */
  defaultEditionId: string | null;
  /** Edition id → code for every event the viewer can open (for chips and notes). */
  codes: Record<string, string>;
};

export const ALL_EVENTS_READ_ONLY =
  "All events. Only a super admin or a manager who sees every event can change this.";

export async function eventCardData(
  organisationId: string,
  viewer: StaffActor | Actor,
  person: { editionIds: string[] | null } | null = null,
): Promise<EventCardData> {
  const rows = await listEditions(organisationId, null);
  const today = todayInLondon();
  const giveable = assignableEditions(
    viewer,
    rows.map((r) => r.edition.id),
  );
  const visible = rows.filter((r) => seesEdition(viewer, r.edition.id));
  const events = (["upcoming", "past", "archived"] as const).flatMap((group) =>
    sortForGroup(
      visible
        .filter((r) => eventGroup(r.edition, today) === group)
        .filter((r) => giveable === "all" || giveable.includes(r.edition.id))
        .map((r) => ({
          id: r.edition.id,
          code: r.edition.code,
          name: r.edition.name,
          openStart: r.edition.openStart,
          line: `${r.edition.code} · ${dateRangeWithYear(r.edition.openStart, r.edition.openEnd)} · ${r.venue.name}`,
          archived: r.edition.status === "archived",
        })),
      group,
    ).map(({ id, code, name, line, archived }) => ({ id, code, name, line, archived })),
  );
  const lastCode = (await cookies()).get(LAST_EVENT_COOKIE)?.value ?? null;
  const defaultCode = pickDefaultEdition(
    visible.map((r) => ({
      code: r.edition.code,
      status: r.edition.status,
      openStart: r.edition.openStart,
      openEnd: r.edition.openEnd,
    })),
    { lastCode, today },
  );
  const theirs = person?.editionIds ?? null;
  const allowAll = giveable === "all";
  return {
    events,
    allowAll,
    hiddenCount: theirs ? theirs.filter((id) => !seesEdition(viewer, id)).length : 0,
    visibleIds: theirs ? theirs.filter((id) => seesEdition(viewer, id)) : null,
    // A limited manager can't take anyone off All events (rule 6b).
    readOnly: person && theirs === null && !allowAll ? ALL_EVENTS_READ_ONLY : null,
    defaultEditionId: visible.find((r) => r.edition.code === defaultCode)?.edition.id ?? null,
    codes: Object.fromEntries(visible.map((r) => [r.edition.id, r.edition.code])),
  };
}
