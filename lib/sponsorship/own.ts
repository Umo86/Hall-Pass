import "server-only";
/**
 * Loaders for the package and sponsor actions: a record of this
 * organisation's events that the actor can open (Users → Events), else
 * null / "not found" — nothing reveals another event's records.
 */
import { and, eq } from "drizzle-orm";
import { db as defaultDb, type Db, type Tx } from "@/lib/db/client";
import { editions, events, sponsors, sponsorshipPackages } from "@/lib/db/schema";
import { opensEdition, type Actor } from "@/lib/authz";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";

type PackageRecord = typeof sponsorshipPackages.$inferSelect;
type SponsorRecord = typeof sponsors.$inferSelect;
type EditionRecord = typeof editions.$inferSelect;

/**
 * A package of one of this organisation's events that the actor can open
 * (Users → Events), with its event; null otherwise ("Package not found").
 */
export async function ownPackage(
  exec: Db | Tx,
  organisationId: string,
  packageId: string,
  actor: Actor,
): Promise<{ package: PackageRecord; edition: EditionRecord } | null> {
  const [row] = await exec
    .select({ package: sponsorshipPackages, edition: editions })
    .from(sponsorshipPackages)
    .innerJoin(editions, eq(sponsorshipPackages.editionId, editions.id))
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(sponsorshipPackages.id, packageId), eq(events.organisationId, organisationId)))
    .limit(1);
  if (!row || !opensEdition(actor, row.edition.id)) return null;
  return row;
}

export type FoundSponsor =
  | { error: string; sponsor?: never; edition?: never }
  | { error?: never; sponsor: SponsorRecord; edition: EditionRecord };

/**
 * A sponsor of one of this organisation's events that the actor can open
 * (Users → Events), if it may be changed now.
 */
export async function ownSponsor(
  sponsorId: string,
  organisationId: string,
  actor: Actor,
  exec: Db | Tx = defaultDb,
): Promise<FoundSponsor> {
  const [row] = await exec
    .select({ sponsor: sponsors, edition: editions })
    .from(sponsors)
    .innerJoin(editions, eq(sponsors.editionId, editions.id))
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(sponsors.id, sponsorId), eq(events.organisationId, organisationId)))
    .limit(1);
  if (!row || !opensEdition(actor, row.edition.id)) return { error: "Sponsor not found" };
  if (editionIsReadOnly(row.edition.status)) return { error: EDITION_LOCKED_MESSAGE };
  return row;
}
