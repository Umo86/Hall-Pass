import "server-only";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { editionDeadlines, editions, events, venues } from "@/lib/db/schema";
import type { EditionForDeadlines } from "@/lib/deadlines";

export async function listEditions() {
  return db
    .select({
      edition: editions,
      event: events,
      venue: venues,
    })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .innerJoin(venues, eq(editions.venueId, venues.id))
    .orderBy(editions.buildStart);
}

export async function getEditionByCode(code: string) {
  const [row] = await db
    .select({ edition: editions, event: events, venue: venues })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .innerJoin(venues, eq(editions.venueId, venues.id))
    .where(eq(editions.code, code))
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
