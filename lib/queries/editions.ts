import "server-only";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { editionDeadlines, editions, events, venues } from "@/lib/db/schema";
import type { EditionForDeadlines } from "@/lib/deadlines";

/** The organisation's events (editions), earliest build-up first. */
export async function listEditions(organisationId: string) {
  return db
    .select({
      edition: editions,
      event: events,
      venue: venues,
    })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .innerJoin(venues, eq(editions.venueId, venues.id))
    .where(eq(events.organisationId, organisationId))
    .orderBy(editions.buildStart);
}

/** An event by its code — only if it belongs to the given organisation. */
export async function getEditionByCode(code: string, organisationId: string) {
  const [row] = await db
    .select({ edition: editions, event: events, venue: venues })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .innerJoin(venues, eq(editions.venueId, venues.id))
    .where(and(eq(editions.code, code), eq(events.organisationId, organisationId)))
    .limit(1);
  return row ?? null;
}

export async function getEditionDeadlines(editionId: string) {
  return db
    .select()
    .from(editionDeadlines)
    .where(eq(editionDeadlines.editionId, editionId))
    .orderBy(editionDeadlines.daysBeforeBuildStart);
}

export async function editionForDeadlines(editionId: string): Promise<EditionForDeadlines | null> {
  const [edition] = await db.select().from(editions).where(eq(editions.id, editionId)).limit(1);
  if (!edition) return null;
  const rows = await getEditionDeadlines(editionId);
  return {
    buildStart: edition.buildStart,
    deadlines: rows.map((r) => ({
      key: r.key,
      daysBeforeBuildStart: r.daysBeforeBuildStart,
      overrideDate: r.overrideDate,
    })),
  };
}

/** An event logo's URL for an <img>, or null when there is none or it can't be read. */
export async function showLogoUrl(logoPath: string | null | undefined): Promise<string | null> {
  if (!logoPath) return null;
  const { getInlineUrl } = await import("@/lib/storage");
  return getInlineUrl("documents", logoPath).catch(() => null);
}

// ---------------------------------------------------------------------------
// Pure helpers (no database): which event is "current", and where each one is
// in its life. Unit tested in tests/unit/setup-events.test.ts.

export { LAST_EVENT_COOKIE, LAST_EVENT_COOKIE_MAX_AGE } from "@/components/setup/last-event";

type DatedEvent = {
  code: string;
  status: string;
  openStart: string;
  openEnd: string;
};

/**
 * The event pages without one in their address use (nav, switcher): the one
 * last opened, else the earliest that hasn't closed yet, else the most
 * recent past one. Never an archived event while a live one exists.
 */
export function pickDefaultEdition(
  editions: readonly DatedEvent[],
  opts: { lastCode?: string | null; today: string },
): string | null {
  if (editions.length === 0) return null;
  const live = editions.filter((e) => e.status !== "archived");
  const pool = live.length > 0 ? live : editions;
  const last = opts.lastCode
    ? pool.find((e) => e.code.toUpperCase() === opts.lastCode!.toUpperCase())
    : undefined;
  if (last) return last.code;
  const upcoming = pool
    .filter((e) => e.openEnd >= opts.today)
    .sort((a, b) => a.openStart.localeCompare(b.openStart) || a.code.localeCompare(b.code));
  if (upcoming[0]) return upcoming[0].code;
  const past = [...pool].sort(
    (a, b) => b.openEnd.localeCompare(a.openEnd) || a.code.localeCompare(b.code),
  );
  return past[0]?.code ?? null;
}

export type EventPhase = "planning" | "build_up" | "open" | "breakdown" | "finished" | "archived";

export const EVENT_PHASE_LABELS: Record<EventPhase, string> = {
  planning: "Planning",
  build_up: "Build-up",
  open: "Open",
  breakdown: "Breakdown",
  finished: "Finished",
  archived: "Archived",
};

/** Where an event is in its life, from its dates (archived stays archived). */
export function eventPhase(
  e: {
    status: string;
    buildStart: string;
    openStart: string;
    openEnd: string;
    breakdownEnd: string;
  },
  today: string,
): EventPhase {
  if (e.status === "archived") return "archived";
  if (today < e.buildStart) return "planning";
  if (today < e.openStart) return "build_up";
  if (today <= e.openEnd) return "open";
  if (today <= e.breakdownEnd) return "breakdown";
  return "finished";
}

export type EventGroup = "upcoming" | "past" | "archived";

/** Upcoming & live (until breakdown ends), past, or archived. */
export function eventGroup(e: { status: string; breakdownEnd: string }, today: string): EventGroup {
  if (e.status === "archived") return "archived";
  return e.breakdownEnd >= today ? "upcoming" : "past";
}

/**
 * Events for one group in the order people want them: upcoming soonest
 * first, past and archived most recent first.
 */
export function sortForGroup<T extends { openStart: string; code: string }>(
  rows: readonly T[],
  group: EventGroup,
): T[] {
  return [...rows].sort((a, b) =>
    group === "upcoming"
      ? a.openStart.localeCompare(b.openStart) || a.code.localeCompare(b.code)
      : b.openStart.localeCompare(a.openStart) || a.code.localeCompare(b.code),
  );
}
