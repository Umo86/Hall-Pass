import "server-only";
/**
 * External access (Users → External): who outside the team can see what,
 * the events and companies an invitation can be for, and the rules every
 * partner invitation follows — which company goes with which role, end
 * dates (the end of a London day), duplicates, claiming at sign-in, copying
 * with an event and the audit payload of every grant change. The pure rules
 * are unit tested in tests/unit/partners.test.ts and the database parts in
 * tests/unit/partners.db.test.ts.
 */
import { and, asc, desc, eq, gt, inArray, isNull, or, sql, type SQL } from "drizzle-orm";
import { db as defaultDb, type Db, type Tx } from "@/lib/db/client";
import {
  editions,
  events,
  exhibitors,
  externalGrants,
  memberships,
  sponsors,
  staffInvites,
  suppliers,
  users,
  venues,
} from "@/lib/db/schema";
import {
  can,
  type EditionScope,
  type ExternalActor,
  type ExternalRole,
  type ScopeType,
  type SignageItemCtx,
} from "@/lib/authz";
import { accessEndsAtFromLondonDate, londonDateOfAccessEnd } from "@/lib/access";
import { APPROVED_OR_LATER } from "@/lib/status/signage";
import { writeAudit } from "@/lib/audit";
import { appUrl } from "@/lib/app-url";
import { brandName } from "@/lib/config";
import { roleLabel } from "@/lib/format";
import { generateInviteToken, hashInviteToken } from "@/lib/auth/invite-token";
import { sendAccountEmail } from "@/lib/auth/account-link";
import { sendInviteEmail, type InviteDelivery } from "@/lib/auth/staff-invite";
import { renderNotificationEmail } from "@/lib/email/template";
import { sendEmail } from "@/lib/email/send";
import { activeMembership, memberSeesEditionSql } from "@/lib/users/active";
import { editionScopeSql } from "@/lib/queries/edition-scope";
import { grantStatus, type GrantStatus } from "@/components/portal/summary";

type Grant = typeof externalGrants.$inferSelect;

/** A refusal whose message is safe to show as it is. */
export class PartnerError extends Error {}

// ---------------------------------------------------------------------------
// Pure rules
// ---------------------------------------------------------------------------

/**
 * Which kind of record each partner role is for. Engineers and health and
 * safety review every stand of the event, so their access names no company.
 */
export const PARTNER_SCOPE_FOR: Record<ExternalRole, ScopeType | null> = {
  venue: "venue",
  supplier: "supplier",
  sponsor: "sponsor",
  exhibitor: "exhibitor",
  contractor: "exhibitor",
  structural_engineer: null,
  hs: null,
};

const CHOOSE_SCOPE: Record<ScopeType, string> = {
  venue: "Choose the venue they are from",
  supplier: "Choose the supplier they work for",
  sponsor: "Choose the sponsor they are from",
  exhibitor: "Choose the exhibitor and stand they are for",
};

/**
 * Why this role and company don't go together, or null when they do: a
 * venue role is for a venue, a supplier for a supplier, a sponsor for a
 * sponsor, exhibitors and contractors for an exhibitor, and engineers and
 * health and safety for nobody in particular.
 */
export function partnerScopeRefusal(input: {
  role: ExternalRole;
  scopeType?: ScopeType | null;
  scopeId?: string | null;
}): string | null {
  const want = PARTNER_SCOPE_FOR[input.role];
  const scopeType = input.scopeType ?? null;
  const scopeId = input.scopeId ?? null;
  if (want === null) {
    return scopeType || scopeId
      ? `${roleLabel(input.role)} access covers the whole event — don't choose a company`
      : null;
  }
  if (scopeType !== want || !scopeId) return CHOOSE_SCOPE[want];
  return null;
}

export const PAST_DATE_MESSAGE = "Choose today or a later date";

/**
 * "Access ends" as entered (a London date, or nothing): the end of that day
 * in London, so the partner keeps access all day, whatever the clocks do.
 * Dates before today are refused.
 */
export function partnerAccessEnd(
  date: string | null | undefined,
  today: string,
): { expiresAt: Date | null; error?: never } | { error: string; expiresAt?: never } {
  if (!date) return { expiresAt: null };
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return { error: "Enter the date access ends" };
  if (date < today) return { error: PAST_DATE_MESSAGE };
  try {
    return { expiresAt: accessEndsAtFromLondonDate(date) };
  } catch {
    return { error: "Enter a real date" };
  }
}

/** Live: not revoked, and no end date or one still ahead. */
export function grantLive(
  g: { revokedAt: Date | null; expiresAt: Date | null },
  now: Date = new Date(),
): boolean {
  return !g.revokedAt && (!g.expiresAt || g.expiresAt.getTime() > now.getTime());
}

function daysBetween(a: string, b: string): number {
  return Math.round((Date.parse(`${b}T12:00:00Z`) - Date.parse(`${a}T12:00:00Z`)) / 86_400_000);
}

function addDays(date: string, days: number): string {
  const d = new Date(`${date}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/**
 * The end date a copied grant gets: moved by as many days as the new event
 * is from the old one (last breakdown day to last breakdown day), still the
 * end of a London day. No end date stays none.
 */
export function copiedAccessEnd(
  expiresAt: Date | null,
  fromLastDay: string,
  toLastDay: string,
): Date | null {
  if (!expiresAt) return null;
  const day = londonDateOfAccessEnd(expiresAt);
  return accessEndsAtFromLondonDate(addDays(day, daysBetween(fromLastDay, toLastDay)));
}

/** Every external_grant audit row carries the same description of the grant. */
export function grantAuditPayload(
  g: Pick<Grant, "invitedEmail" | "role" | "scopeType" | "scopeId" | "editionId" | "expiresAt">,
) {
  return {
    email: g.invitedEmail.toLowerCase(),
    role: g.role,
    scopeType: g.scopeType,
    scopeId: g.scopeId,
    editionId: g.editionId,
    expiresAt: g.expiresAt ? g.expiresAt.toISOString() : null,
  };
}

/**
 * The grants a partner's session works with: their live ones, in the
 * organisation of the most recent live grant (so a revoked, ended or older
 * invitation never decides where they land, and two organisations' records
 * never mix in one session). Null when nothing live is left.
 */
export function partnerSessionGrants<
  G extends {
    organisationId: string;
    createdAt: Date;
    revokedAt: Date | null;
    expiresAt: Date | null;
  },
>(grants: readonly G[], now: Date = new Date()): { organisationId: string; grants: G[] } | null {
  const live = grants
    .filter((g) => grantLive(g, now))
    .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  if (live.length === 0) return null;
  const organisationId = live[0].organisationId;
  return { organisationId, grants: live.filter((g) => g.organisationId === organisationId) };
}

/**
 * May this partner see the item's artwork now? Suppliers get it only once
 * it is signed off; anyone shown the item by another live grant (the venue
 * or sponsor of that item) sees the version under review. Decided by the
 * grants that show this item, not by everything the person ever held.
 */
export function externalSeesArtwork(
  actor: ExternalActor,
  item: SignageItemCtx & { status: string },
  now: Date = new Date(),
): boolean {
  if ((APPROVED_OR_LATER as readonly string[]).includes(item.status)) return true;
  const otherwise: ExternalActor = {
    ...actor,
    grants: actor.grants.filter((g) => g.role !== "supplier"),
  };
  return can(otherwise, { type: "signage.view", item }, now);
}

/** "Media10 has given you access to UKCW 2027 for BuildCo (sponsor)." */
export function partnerInviteReason(opts: {
  organisationName: string;
  eventName: string;
  role: ExternalRole;
  scopeName?: string | null;
}): string {
  const role = roleLabel(opts.role).toLowerCase();
  return `${opts.organisationName} has given you access to ${opts.eventName}${opts.scopeName ? ` for ${opts.scopeName}` : ""} (${role}).`;
}

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

/** SQL for live grants (not revoked; no end date or one still ahead). */
export function liveGrantSql(now: Date = new Date()): SQL {
  return and(
    isNull(externalGrants.revokedAt),
    or(isNull(externalGrants.expiresAt), gt(externalGrants.expiresAt, now)),
  )!;
}

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

/** The company or venue one grant is for ("BuildCo"), if it names one. */
export async function grantScopeName(
  db: Db | Tx,
  organisationId: string,
  grant: Pick<Grant, "scopeType" | "scopeId">,
): Promise<string | null> {
  if (!grant.scopeId) return null;
  return (await scopeNames(db, organisationId, [grant])).get(grant.scopeId) ?? null;
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
  /** Archived events take no new invitations. */
  archived: boolean;
};

/** This organisation's events, soonest upcoming first, then the past ones newest first. */
export async function externalEvents(
  db: Db | Tx,
  organisationId: string,
  today: string,
  /** The viewer's events (Users → Events); null = every event. */
  scope: EditionScope,
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
    .where(and(eq(events.organisationId, organisationId), editionScopeSql(scope, editions.id)))
    .orderBy(asc(editions.openStart));
  const list = rows.map((r) => ({
    id: r.id,
    code: r.code,
    name: r.name,
    openStart: r.openStart,
    openEnd: r.openEnd,
    upcoming: r.status !== "archived" && r.openEnd >= today,
    archived: r.status === "archived",
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
  status: GrantStatus;
  expiresAt: Date | null;
  /** The London date access ends on (YYYY-MM-DD), for the end-date control. */
  endsOn: string | null;
  acceptedAt: Date | null;
  revokedAt: Date | null;
  createdAt: Date;
};

/** Every external invitation and grant, newest first, with names resolved. */
export async function listGrants(
  db: Db | Tx,
  organisationId: string,
  /** The viewer's events (Users → Events): partner access in others isn't listed. */
  scope: EditionScope,
): Promise<GrantRow[]> {
  const rows = await db
    .select({ g: externalGrants, name: users.fullName, eventName: editions.name })
    .from(externalGrants)
    .leftJoin(users, eq(externalGrants.userId, users.id))
    .leftJoin(editions, eq(editions.id, externalGrants.editionId))
    .where(
      and(
        eq(externalGrants.organisationId, organisationId),
        editionScopeSql(scope, externalGrants.editionId),
      ),
    )
    .orderBy(desc(externalGrants.createdAt));
  const names = await scopeNames(
    db,
    organisationId,
    rows.map((r) => r.g),
  );
  const now = new Date();
  return rows.map(({ g, name, eventName }) => ({
    id: g.id,
    name: name || null,
    email: g.invitedEmail,
    editionId: g.editionId,
    eventName: eventName ?? "—",
    role: g.role,
    scopeName: g.scopeId ? (names.get(g.scopeId) ?? null) : null,
    status: grantStatus(g, now),
    expiresAt: g.expiresAt,
    endsOn: g.expiresAt ? londonDateOfAccessEnd(g.expiresAt) : null,
    acceptedAt: g.acceptedAt,
    revokedAt: g.revokedAt,
    createdAt: g.createdAt,
  }));
}

/** Who an invitation is for, with the contact already on their record. */
export type ScopeOption = {
  id: string;
  label: string;
  /** Only offered for this event (sponsors, exhibitors, the event's venue). */
  editionId?: string;
  contactName: string | null;
  contactEmail: string | null;
};

/**
 * Who an invitation can be for: each event's own venue, the suppliers
 * still in use, and each event's sponsors and exhibitors — each with the
 * contact on their record, so the invite form can fill it in.
 */
export async function externalScopes(
  db: Db | Tx,
  organisationId: string,
  /** The viewer's events: venues, sponsors and exhibitors of others aren't offered. */
  scope: EditionScope,
) {
  const [venueRows, supplierRows, sponsorRows, exhibitorRows] = await Promise.all([
    db
      .select({
        id: venues.id,
        label: venues.name,
        editionId: editions.id,
        contactName: venues.riggingContactName,
        contactEmail: venues.riggingContactEmail,
      })
      .from(editions)
      .innerJoin(events, eq(events.id, editions.eventId))
      .innerJoin(venues, eq(venues.id, editions.venueId))
      .where(
        and(
          eq(events.organisationId, organisationId),
          eq(venues.organisationId, organisationId),
          editionScopeSql(scope, editions.id),
        ),
      )
      .orderBy(asc(venues.name)),
    db
      .select({
        id: suppliers.id,
        label: suppliers.name,
        contactName: suppliers.contactName,
        contactEmail: suppliers.email,
      })
      .from(suppliers)
      .where(and(eq(suppliers.organisationId, organisationId), eq(suppliers.isArchived, false)))
      .orderBy(asc(suppliers.name)),
    db
      .select({
        id: sponsors.id,
        label: sponsors.companyName,
        editionId: sponsors.editionId,
        contactName: sponsors.contactName,
        contactEmail: sponsors.contactEmail,
      })
      .from(sponsors)
      .innerJoin(editions, eq(editions.id, sponsors.editionId))
      .innerJoin(events, eq(events.id, editions.eventId))
      .where(and(eq(events.organisationId, organisationId), editionScopeSql(scope, editions.id)))
      .orderBy(asc(sponsors.companyName)),
    db
      .select({
        id: exhibitors.id,
        company: exhibitors.companyName,
        stand: exhibitors.standNumber,
        editionId: exhibitors.editionId,
        contactName: exhibitors.contactName,
        contactEmail: exhibitors.contactEmail,
      })
      .from(exhibitors)
      .innerJoin(editions, eq(editions.id, exhibitors.editionId))
      .innerJoin(events, eq(events.id, editions.eventId))
      .where(and(eq(events.organisationId, organisationId), editionScopeSql(scope, editions.id)))
      .orderBy(asc(exhibitors.companyName)),
  ]);
  return {
    venues: venueRows satisfies ScopeOption[],
    suppliers: supplierRows satisfies ScopeOption[],
    sponsors: sponsorRows satisfies ScopeOption[],
    exhibitors: exhibitorRows.map((x): ScopeOption => ({
      id: x.id,
      label: `${x.company} (stand ${x.stand})`,
      editionId: x.editionId,
      contactName: x.contactName,
      contactEmail: x.contactEmail,
    })),
  };
}

/**
 * Portal access per sponsor of this organisation: "access" when someone
 * there has a live, accepted grant, "invited" when only live invitations
 * are waiting; absent when nobody (revoked and ended grants don't count).
 * The one answer for the Sponsors tab and the item page.
 */
export async function sponsorPortalAccess(
  db: Db | Tx,
  organisationId: string,
  sponsorIds: readonly string[],
  now: Date = new Date(),
): Promise<Map<string, "access" | "invited">> {
  const ids = [...new Set(sponsorIds)].filter(Boolean);
  const out = new Map<string, "access" | "invited">();
  if (ids.length === 0) return out;
  const rows = await db
    .select({ scopeId: externalGrants.scopeId, acceptedAt: externalGrants.acceptedAt })
    .from(externalGrants)
    .where(
      and(
        eq(externalGrants.organisationId, organisationId),
        eq(externalGrants.scopeType, "sponsor"),
        inArray(externalGrants.scopeId, ids),
        liveGrantSql(now),
      ),
    );
  for (const r of rows) {
    if (!r.scopeId) continue;
    if (r.acceptedAt) out.set(r.scopeId, "access");
    else if (!out.has(r.scopeId)) out.set(r.scopeId, "invited");
  }
  return out;
}

/**
 * Of these people, those with an active team membership in the
 * organisation — staff. Everyone else (partners, people who left) must not
 * get staff-only comments, emails or staff links, whatever users.is_external
 * says.
 */
export async function staffMemberIds(
  db: Db | Tx,
  organisationId: string,
  userIds: readonly string[],
  /** Only staff who can open this event (Users → Events). */
  opts: { editionId?: string | null } = {},
): Promise<Set<string>> {
  const ids = [...new Set(userIds)].filter(Boolean);
  if (ids.length === 0) return new Set();
  const rows = await db
    .select({ userId: memberships.userId })
    .from(memberships)
    .where(
      and(
        eq(memberships.organisationId, organisationId),
        inArray(memberships.userId, ids),
        activeMembership(),
        opts.editionId ? memberSeesEditionSql(opts.editionId) : undefined,
      ),
    );
  return new Set(rows.map((r) => r.userId));
}

/**
 * Of the people about to be told about a record, the ones who may be:
 * team members here (active), and partners whose live grants in this
 * organisation still show them the record (`sees`, a can() check on it) —
 * never a partner for a staff-only message. Earlier commenters and
 * approvers can lose sight of a record (a supplier moved off an item, a
 * contractor's grant for one stand revoked while they keep another) and
 * must not keep hearing about it (non-negotiable 4).
 */
export async function recipientsWhoCanSee(
  db: Db | Tx,
  organisationId: string,
  userIds: readonly string[],
  opts: {
    staffOnly?: boolean;
    sees: (actor: ExternalActor) => boolean;
    now?: Date;
    /** The record's event: team members are kept only when they can open it. */
    editionId?: string | null;
  },
): Promise<string[]> {
  const ids = [...new Set(userIds)].filter(Boolean);
  if (ids.length === 0) return [];
  const allStaff = await staffMemberIds(db, organisationId, ids);
  const staff = opts.editionId
    ? await staffMemberIds(db, organisationId, ids, { editionId: opts.editionId })
    : allStaff;
  // Team members who can't open the event are neither staff here nor partners.
  const partners = ids.filter((id) => !allStaff.has(id));
  const sees = new Set<string>();
  if (partners.length > 0 && !opts.staffOnly) {
    const now = opts.now ?? new Date();
    const grants = await db
      .select()
      .from(externalGrants)
      .where(
        and(
          eq(externalGrants.organisationId, organisationId),
          inArray(externalGrants.userId, partners),
          liveGrantSql(now),
        ),
      );
    for (const id of partners) {
      const mine = grants.filter((g) => g.userId === id);
      if (mine.length === 0) continue;
      const actor: ExternalActor = {
        kind: "external",
        userId: id,
        organisationId,
        grants: mine.map((g) => ({
          role: g.role,
          editionId: g.editionId,
          scopeType: g.scopeType,
          scopeId: g.scopeId,
          expiresAt: g.expiresAt,
          revokedAt: g.revokedAt,
        })),
      };
      if (opts.sees(actor)) sees.add(id);
    }
  }
  return ids.filter((id) => staff.has(id) || sees.has(id));
}

/** This email's live partner grants in the organisation (for staff invitations). */
export async function livePartnerGrantsFor(
  db: Db | Tx,
  organisationId: string,
  email: string,
  now: Date = new Date(),
): Promise<Grant[]> {
  return db
    .select()
    .from(externalGrants)
    .where(
      and(
        eq(externalGrants.organisationId, organisationId),
        sql`lower(${externalGrants.invitedEmail}) = ${email.trim().toLowerCase()}`,
        liveGrantSql(now),
      ),
    )
    .orderBy(desc(externalGrants.createdAt));
}

/**
 * An open team invitation for this email (not accepted, cancelled or
 * expired), in any organisation. Expired ones don't count: they can't be
 * used.
 */
export async function openTeamInviteFor(
  db: Db | Tx,
  email: string,
  now: Date = new Date(),
): Promise<{ id: string; organisationId: string; fullName: string } | null> {
  const [row] = await db
    .select({
      id: staffInvites.id,
      organisationId: staffInvites.organisationId,
      fullName: staffInvites.fullName,
    })
    .from(staffInvites)
    .where(
      and(
        eq(staffInvites.invitedEmail, email.trim().toLowerCase()),
        isNull(staffInvites.acceptedAt),
        isNull(staffInvites.revokedAt),
        or(isNull(staffInvites.expiresAt), gt(staffInvites.expiresAt, now)),
      ),
    )
    .orderBy(desc(staffInvites.createdAt))
    .limit(1);
  return row ?? null;
}

/**
 * The same access already given (same email, event, role and company), not
 * revoked: the newest one. Inviting again offers Resend or Extend instead
 * of a second row.
 */
export async function findSameGrant(
  db: Db | Tx,
  organisationId: string,
  k: {
    email: string;
    editionId: string;
    role: ExternalRole;
    scopeType: ScopeType | null;
    scopeId: string | null;
  },
): Promise<Grant | null> {
  const [row] = await db
    .select()
    .from(externalGrants)
    .where(
      and(
        eq(externalGrants.organisationId, organisationId),
        sql`lower(${externalGrants.invitedEmail}) = ${k.email.trim().toLowerCase()}`,
        eq(externalGrants.editionId, k.editionId),
        eq(externalGrants.role, k.role),
        k.scopeType ? eq(externalGrants.scopeType, k.scopeType) : isNull(externalGrants.scopeType),
        k.scopeId ? eq(externalGrants.scopeId, k.scopeId) : isNull(externalGrants.scopeId),
        isNull(externalGrants.revokedAt),
      ),
    )
    .orderBy(desc(externalGrants.createdAt))
    .limit(1);
  return row ?? null;
}

// ---------------------------------------------------------------------------
// Changes (each with its audit row, in the caller's transaction)
// ---------------------------------------------------------------------------

/**
 * Claim every open invitation for this email at sign-in — first sign-in or
 * the hundredth: not yet linked to anyone, not revoked, not ended. Each
 * claimed grant is audited in its own organisation. A partner account is
 * marked external (so staff-only comments and emails never reach it).
 * Nobody with a team membership claims partner access.
 */
export async function claimOpenGrants(
  user: { id: string; email: string; isExternal: boolean },
  opts: { db?: Db; now?: Date } = {},
): Promise<Grant[]> {
  const exec = opts.db ?? defaultDb;
  const now = opts.now ?? new Date();
  const email = user.email.trim().toLowerCase();
  // Most page loads have nothing to claim: one cheap look before a transaction.
  if (user.isExternal) {
    const [open] = await exec
      .select({ id: externalGrants.id })
      .from(externalGrants)
      .where(
        and(
          sql`lower(${externalGrants.invitedEmail}) = ${email}`,
          isNull(externalGrants.userId),
          liveGrantSql(now),
        ),
      )
      .limit(1);
    if (!open) return [];
  }
  return exec.transaction(async (tx) => {
    const [member] = await tx
      .select({ id: memberships.id })
      .from(memberships)
      .where(eq(memberships.userId, user.id))
      .limit(1);
    if (member) return [];
    const claimed = await tx
      .update(externalGrants)
      .set({ userId: user.id, acceptedAt: now, updatedAt: now })
      .where(
        and(
          sql`lower(${externalGrants.invitedEmail}) = ${email}`,
          isNull(externalGrants.userId),
          liveGrantSql(now),
        ),
      )
      .returning();
    for (const g of claimed) {
      await writeAudit(tx, {
        organisationId: g.organisationId,
        editionId: g.editionId,
        actorUserId: user.id,
        entityType: "external_grant",
        entityId: g.id,
        action: "invite",
        after: { ...grantAuditPayload(g), acceptedAt: now.toISOString(), how: "sign-in" },
        summary: `${email} accepted their invitation as ${roleLabel(g.role)} (signed in)`,
        subjectUserId: user.id,
        subjectEmail: email,
      });
    }
    if (!user.isExternal) {
      const [latest] = claimed.length
        ? [claimed[0]]
        : await tx
            .select()
            .from(externalGrants)
            .where(eq(externalGrants.userId, user.id))
            .orderBy(desc(externalGrants.createdAt))
            .limit(1);
      if (latest) {
        await tx
          .update(users)
          .set({ isExternal: true, updatedAt: now })
          .where(eq(users.id, user.id));
        await writeAudit(tx, {
          organisationId: latest.organisationId,
          actorUserId: user.id,
          entityType: "user",
          entityId: user.id,
          action: "update",
          before: { isExternal: false },
          after: { isExternal: true },
          summary: `${email} is a partner account (portal access, no team membership)`,
          subjectUserId: user.id,
          subjectEmail: email,
        });
      }
    }
    return claimed;
  });
}

/**
 * A new invitation link for a grant nobody has accepted yet (the old link
 * stops working). Refused once accepted, revoked or ended.
 */
export async function renewGrantInviteTx(
  tx: Tx,
  opts: { organisationId: string; actorUserId: string; grantId: string; now?: Date },
): Promise<{ grant: Grant; inviteUrl: string }> {
  const now = opts.now ?? new Date();
  const [current] = await tx
    .select()
    .from(externalGrants)
    .where(
      and(
        eq(externalGrants.id, opts.grantId),
        eq(externalGrants.organisationId, opts.organisationId),
      ),
    )
    .for("update");
  if (!current) throw new PartnerError("That invitation no longer exists — reload the page");
  if (current.revokedAt) {
    throw new PartnerError("That access was revoked — invite them again instead");
  }
  if (current.acceptedAt) {
    throw new PartnerError("They have already accepted — they sign in with their email");
  }
  if (!grantLive(current, now)) {
    throw new PartnerError("Their access has ended — give it a new end date first");
  }
  const token = generateInviteToken();
  const [grant] = await tx
    .update(externalGrants)
    .set({ inviteTokenHash: hashInviteToken(token), updatedAt: now })
    .where(eq(externalGrants.id, current.id))
    .returning();
  await writeAudit(tx, {
    organisationId: opts.organisationId,
    editionId: grant.editionId,
    actorUserId: opts.actorUserId,
    entityType: "external_grant",
    entityId: grant.id,
    action: "invite",
    after: { ...grantAuditPayload(grant), resent: true },
    summary: `Invitation sent again to ${grant.invitedEmail}`,
    subjectUserId: grant.userId,
    subjectEmail: grant.invitedEmail,
  });
  return { grant, inviteUrl: `${appUrl()}/invite/${token}` };
}

/**
 * Is the person a grant is for on this organisation's team (by account, or
 * an account with the invited email)? Their partner access is then never
 * extended or copied: team members see everything already, and the grant
 * would sign them in to the portal once they leave the team.
 */
export async function isTeamMember(
  db: Db | Tx,
  organisationId: string,
  grant: Pick<Grant, "userId" | "invitedEmail">,
): Promise<boolean> {
  const email = grant.invitedEmail.trim().toLowerCase();
  const [member] = await db
    .select({ id: memberships.id })
    .from(memberships)
    .innerJoin(users, eq(users.id, memberships.userId))
    .where(
      and(
        eq(memberships.organisationId, organisationId),
        grant.userId
          ? or(eq(memberships.userId, grant.userId), sql`lower(${users.email}) = ${email}`)
          : sql`lower(${users.email}) = ${email}`,
      ),
    )
    .limit(1);
  return Boolean(member);
}

/** Change when a grant ends (or take the end date away), audited before and after. */
export async function setGrantEndTx(
  tx: Tx,
  opts: {
    organisationId: string;
    actorUserId: string;
    grantId: string;
    expiresAt: Date | null;
    now?: Date;
  },
): Promise<{ before: Grant; after: Grant }> {
  const now = opts.now ?? new Date();
  const [before] = await tx
    .select()
    .from(externalGrants)
    .where(
      and(
        eq(externalGrants.id, opts.grantId),
        eq(externalGrants.organisationId, opts.organisationId),
      ),
    )
    .for("update");
  if (!before) throw new PartnerError("That access no longer exists — reload the page");
  if (before.revokedAt) {
    throw new PartnerError("That access was revoked — invite them again instead");
  }
  // Someone on the team holds no live partner access here (partner
  // invitations refuse team members too): it may be ended, never extended.
  const keepsAccess = opts.expiresAt == null || opts.expiresAt.getTime() > now.getTime();
  if (keepsAccess && (await isTeamMember(tx, opts.organisationId, before))) {
    throw new PartnerError(
      "They're on your team now and already see everything — revoke this partner access instead",
    );
  }
  const [after] = await tx
    .update(externalGrants)
    .set({ expiresAt: opts.expiresAt, updatedAt: now })
    .where(eq(externalGrants.id, before.id))
    .returning();
  const when = opts.expiresAt ? londonDateOfAccessEnd(opts.expiresAt) : null;
  await writeAudit(tx, {
    organisationId: opts.organisationId,
    editionId: after.editionId,
    actorUserId: opts.actorUserId,
    entityType: "external_grant",
    entityId: after.id,
    action: "update",
    before: grantAuditPayload(before),
    after: grantAuditPayload(after),
    summary: when
      ? `Access for ${after.invitedEmail} now ends ${when}`
      : `Access for ${after.invitedEmail} no longer has an end date`,
    subjectUserId: after.userId,
    subjectEmail: after.invitedEmail,
  });
  return { before, after };
}

// ---------------------------------------------------------------------------
// Delivery
// ---------------------------------------------------------------------------

/**
 * Tell someone who already has an account that they have new access: our
 * own email with the reason (Supabase could only send a plain sign-in
 * link). Signing in adds the access to their account.
 */
async function sendNewAccessEmail(opts: {
  to: string;
  name?: string | null;
  inviterName: string;
  reason: string;
  inviteUrl: string;
  grantId: string;
}): Promise<boolean> {
  const { html, text } = await renderNotificationEmail({
    brandName,
    title: `${opts.inviterName} has given you more access in ${brandName}`,
    bodyText: [
      opts.name ? `Hi ${opts.name.split(" ")[0]},` : "Hello,",
      opts.reason,
      "Sign in with this email address as usual and it is there.",
    ].join(" "),
    ctaLabel: `Open ${brandName}`,
    ctaUrl: opts.inviteUrl,
  });
  return sendEmail({
    to: opts.to,
    subject: `New access in ${brandName}`,
    html,
    text,
    template: "partner_access",
    entityType: "external_grant",
    entityId: opts.grantId,
  }).catch(() => false);
}

/**
 * Get a partner invitation to the person. Someone new: Supabase's email to
 * create their account (with the reason in its metadata), else our own
 * invitation email. Someone with an account already: our own email saying
 * what is new, else a sign-in link (signing in claims it). Failing all
 * that, the link is handed back to pass on by hand.
 */
export async function deliverPartnerInvite(opts: {
  email: string;
  name?: string | null;
  inviterName: string;
  reason: string;
  inviteUrl: string;
  grantId: string;
  db?: Db;
}): Promise<InviteDelivery> {
  const exec = opts.db ?? defaultDb;
  const email = opts.email.trim().toLowerCase();
  const [existing] = await exec
    .select({ id: users.id })
    .from(users)
    .where(sql`lower(${users.email}) = ${email}`)
    .limit(1);
  if (existing) {
    const viaEmail = await sendNewAccessEmail({
      to: email,
      name: opts.name,
      inviterName: opts.inviterName,
      reason: opts.reason,
      inviteUrl: opts.inviteUrl,
      grantId: opts.grantId,
    });
    if (viaEmail) return { emailed: true };
    const viaSupabase = await sendAccountEmail(email, { fullName: opts.name, reason: opts.reason });
    return viaSupabase !== "not_sent"
      ? { emailed: true }
      : { emailed: false, fallbackUrl: opts.inviteUrl };
  }
  const viaSupabase = await sendAccountEmail(email, { fullName: opts.name, reason: opts.reason });
  if (viaSupabase !== "not_sent") return { emailed: true };
  const viaEmail = await sendInviteEmail({
    to: email,
    name: opts.name,
    inviterName: opts.inviterName,
    reason: opts.reason,
    inviteUrl: opts.inviteUrl,
    inviteId: opts.grantId,
  });
  return viaEmail ? { emailed: true } : { emailed: false, fallbackUrl: opts.inviteUrl };
}
