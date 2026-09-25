import "server-only";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { editionDeadlines, editions, events, venues } from "@/lib/db/schema";
import type { EditionForDeadlines } from "@/lib/deadlines";

/** The organisation's editions, earliest build first. */
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

/** A show by its code — only if it belongs to the given organisation. */
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

/** A show logo's URL for an <img>, or null when there is none or it can't be read. */
export async function showLogoUrl(logoPath: string | null | undefined): Promise<string | null> {
  if (!logoPath) return null;
  const { getInlineUrl } = await import("@/lib/storage");
  return getInlineUrl("documents", logoPath).catch(() => null);
}
