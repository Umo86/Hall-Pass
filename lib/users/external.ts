import "server-only";
/**
 * External access (Users → External): who outside the team can see what,
 * and the events and companies an invitation can be for.
 */
import { and, asc, desc, eq, inArray } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import {
  editions,
  events,
  exhibitors,
  externalGrants,
  sponsors,
  suppliers,
  users,
  venues,
} from "@/lib/db/schema";
import { roleLabel } from "@/lib/format";

type Grant = typeof externalGrants.$inferSelect;

/** The name of the company or venue a grant is for, keyed by scope id. */
async function scopeNames(
  db: Db | Tx,
  organisationId: string,
  grants: Pick<Grant, "scopeType" | "scopeId">[],
): Promise<Map<string, string>> {
  const ids = (type: string) =>
    [
      ...new Set(
        grants.filter((g) => g.scopeType === type && g.scopeId).map((g) => g.scopeId as string),
      ),
    ] as string[];
  const [v, s, sp, x] = await Promise.all([
    ids("venue").length
      ? db
          .select({ id: venues.id, name: venues.name })
          .from(venues)
          .where(and(eq(venues.organisationId, organisationId), inArray(venues.id, ids("venue"))))
      : [],
    ids("supplier").length
      ? db
          .select({ id: suppliers.id, name: suppliers.name })
          .from(suppliers)
          .where(
            and(
              eq(suppliers.organisationId, organisationId),
              inArray(suppliers.id, ids("supplier")),
            ),
          )
      : [],
    ids("sponsor").length
      ? db
          .select({ id: sponsors.id, name: sponsors.companyName })
          .from(sponsors)
          .innerJoin(editions, eq(editions.id, sponsors.editionId))
          .innerJoin(events, eq(events.id, editions.eventId))
          .where(
            and(eq(events.organisationId, organisationId), inArray(sponsors.id, ids("sponsor"))),
          )
      : [],
    ids("exhibitor").length
      ? db
          .select({ id: exhibitors.id, name: exhibitors.companyName })
          .from(exhibitors)
          .innerJoin(editions, eq(editions.id, exhibitors.editionId))
          .innerJoin(events, eq(events.id, editions.eventId))
          .where(
            and(
              eq(events.organisationId, organisationId),
              inArray(exhibitors.id, ids("exhibitor")),
            ),
          )
      : [],
  ]);
  return new Map([...v, ...s, ...sp, ...x].map((r) => [r.id, r.name]));
}

/** "Venue – NEC Birmingham": what an external account is for, in words. */
export async function externalAccountLabel(
  db: Db | Tx,
  organisationId: string,
  grant: Pick<Grant, "role" | "scopeType" | "scopeId" | "organisationId">,
): Promise<string> {
  const names =
    grant.organisationId === organisationId
      ? await scopeNames(db, organisationId, [grant])
      : new Map<string, string>();
  const name = grant.scopeId ? names.get(grant.scopeId) : undefined;
  return `${roleLabel(grant.role)}${name ? ` – ${name}` : ""}`;
}

export type ExternalEvent = {
  id: string;
  code: string;
  name: string;
  openStart: string;
  openEnd: string;
  upcoming: boolean;
};

/** This organisation's events, soonest upcoming first, then the past ones newest first. */
export async function externalEvents(
  db: Db | Tx,
  organisationId: string,
  today: string,
): Promise<ExternalEvent[]> {
  const rows = await db
    .select({
      id: editions.id,
      code: editions.code,
      name: editions.name,
      openStart: editions.openStart,
      openEnd: editions.openEnd,
      status: editions.status,
    })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(eq(events.organisationId, organisationId))
    .orderBy(asc(editions.openStart));
  const list = rows.map((r) => ({
    id: r.id,
    code: r.code,
    name: r.name,
    openStart: r.openStart,
    openEnd: r.openEnd,
    upcoming: r.status !== "archived" && r.openEnd >= today,
  }));
  return [
    ...list.filter((e) => e.upcoming),
    ...list.filter((e) => !e.upcoming).sort((a, b) => b.openStart.localeCompare(a.openStart)),
  ];
}

/**
 * The event to start with: the one last opened (cookie, by code or id),
 * else the next upcoming one, else the most recent.
 */
export function defaultEventId(list: ExternalEvent[], lastEvent?: string | null): string | null {
  if (lastEvent) {
    const hit = list.find((e) => e.code === lastEvent || e.id === lastEvent);
    if (hit) return hit.id;
  }
  return list.find((e) => e.upcoming)?.id ?? list[0]?.id ?? null;
}

export type GrantRow = {
  id: string;
  name: string | null;
  email: string;
  editionId: string;
  eventName: string;
  role: string;
  scopeName: string | null;
  status: "invited" | "active" | "expired" | "revoked";
  expiresAt: Date | null;
  acceptedAt: Date | null;
  revokedAt: Date | null;
  createdAt: Date;
};

/** Every external invitation and grant, newest first, with names resolved. */
export async function listGrants(db: Db | Tx, organisationId: string): Promise<GrantRow[]> {
  const rows = await db
    .select({ g: externalGrants, name: users.fullName, eventName: editions.name })
    .from(externalGrants)
    .leftJoin(users, eq(externalGrants.userId, users.id))
    .leftJoin(editions, eq(editions.id, externalGrants.editionId))
    .where(eq(externalGrants.organisationId, organisationId))
    .orderBy(desc(externalGrants.createdAt));
  const names = await scopeNames(
    db,
    organisationId,
    rows.map((r) => r.g),
  );
  const now = Date.now();
  return rows.map(({ g, name, eventName }) => ({
    id: g.id,
    name: name || null,
    email: g.invitedEmail,
    editionId: g.editionId,
    eventName: eventName ?? "—",
    role: g.role,
    scopeName: g.scopeId ? (names.get(g.scopeId) ?? null) : null,
    status: g.revokedAt
      ? "revoked"
      : g.expiresAt && g.expiresAt.getTime() <= now
        ? "expired"
        : g.acceptedAt
          ? "active"
          : "invited",
    expiresAt: g.expiresAt,
    acceptedAt: g.acceptedAt,
    revokedAt: g.revokedAt,
    createdAt: g.createdAt,
  }));
}

/** Who an invitation can be for: venues, suppliers, and each event's sponsors and exhibitors. */
export async function externalScopes(db: Db | Tx, organisationId: string) {
  const [venueRows, supplierRows, sponsorRows, exhibitorRows] = await Promise.all([
    db
      .select({ id: venues.id, label: venues.name })
      .from(venues)
      .where(and(eq(venues.organisationId, organisationId), eq(venues.isArchived, false)))
      .orderBy(asc(venues.name)),
    db
      .select({ id: suppliers.id, label: suppliers.name })
      .from(suppliers)
      .where(and(eq(suppliers.organisationId, organisationId), eq(suppliers.isArchived, false)))
      .orderBy(asc(suppliers.name)),
    db
      .select({ id: sponsors.id, label: sponsors.companyName, editionId: sponsors.editionId })
      .from(sponsors)
      .innerJoin(editions, eq(editions.id, sponsors.editionId))
      .innerJoin(events, eq(events.id, editions.eventId))
      .where(eq(events.organisationId, organisationId))
      .orderBy(asc(sponsors.companyName)),
    db
      .select({
        id: exhibitors.id,
        company: exhibitors.companyName,
        stand: exhibitors.standNumber,
        editionId: exhibitors.editionId,
      })
      .from(exhibitors)
      .innerJoin(editions, eq(editions.id, exhibitors.editionId))
      .innerJoin(events, eq(events.id, editions.eventId))
      .where(eq(events.organisationId, organisationId))
      .orderBy(asc(exhibitors.companyName)),
  ]);
  return {
    venues: venueRows,
    suppliers: supplierRows,
    sponsors: sponsorRows,
    exhibitors: exhibitorRows.map((x) => ({
      id: x.id,
      label: `${x.company} (stand ${x.stand})`,
      editionId: x.editionId,
    })),
  };
}
