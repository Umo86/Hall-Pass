"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq, isNull, sql } from "drizzle-orm";
import { unstable_rethrow } from "next/navigation";
import { db } from "@/lib/db/client";
import {
  editions,
  events,
  exhibitors,
  externalGrants,
  memberships,
  sponsors,
  suppliers,
  users,
  venues,
} from "@/lib/db/schema";
import { can, missingAbilityMessage, opensEdition, type Actor, type ScopeType } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession, type Session } from "@/lib/auth/actor";
import { editionScopeSql, sessionScope } from "@/lib/queries/edition-scope";
import { generateInviteToken, hashInviteToken } from "@/lib/auth/invite-token";
import { appUrl } from "@/lib/app-url";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { formatDate, formatDayMonth, roleLabel } from "@/lib/format";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { londonDateOfAccessEnd } from "@/lib/access";
import { todayInLondon } from "@/lib/today";
import { grantStatus } from "@/components/portal/summary";
import {
  deliverPartnerInvite,
  findSameGrant,
  grantAuditPayload,
  grantScopeName,
  openTeamInviteFor,
  partnerAccessEnd,
  partnerInviteReason,
  partnerScopeRefusal,
  PartnerError,
  renewGrantInviteTx,
  setGrantEndTx,
} from "@/lib/users/external";

const PARTNER_ROLES = [
  "venue",
  "structural_engineer",
  "hs",
  "supplier",
  "exhibitor",
  "contractor",
  "sponsor",
] as const;

const inviteSchema = z.object({
  email: z.string().trim().toLowerCase().email("Enter a valid email address"),
  /** Their name, when known (the contact on the company's record): greets them. */
  fullName: z.string().trim().max(200).optional().nullable(),
  editionId: z.string().uuid(),
  role: z.enum(PARTNER_ROLES),
  scopeType: z.enum(["venue", "supplier", "exhibitor", "sponsor"]).optional().nullable(),
  scopeId: z.string().uuid().optional().nullable(),
  /** A London date; access lasts to the end of that day. */
  expiresAt: z.string().date("Enter the date access ends").optional().nullable(),
});

/** The same access was already given: what to offer instead of a second invitation. */
export type SameAccess = {
  grantId: string;
  /** invited: offer Resend; active: nothing to do; expired: offer a new end date. */
  status: "invited" | "active" | "expired";
  /** The London date it ends (or ended) on, if it has one. */
  endsOn: string | null;
};

export type InviteExternalResult = { inviteUrl: string; same?: SameAccess };

type EditionRow = { id: string; name: string; venueId: string; status: string };

/** The event, if it's this organisation's and the actor can open it (Users → Events). */
async function ownEdition(
  orgId: string,
  editionId: string,
  actor: Actor,
): Promise<EditionRow | null> {
  const [row] = await db
    .select({
      id: editions.id,
      name: editions.name,
      venueId: editions.venueId,
      status: editions.status,
    })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(editions.id, editionId), eq(events.organisationId, orgId)))
    .limit(1);
  if (!row || !opensEdition(actor, row.id)) return null;
  return row;
}

/**
 * The company or venue the invitation is for, checked on the server: the
 * event's own venue, a supplier still in use, a sponsor or exhibitor of
 * that event. Its name, or why not.
 */
async function checkScope(
  orgId: string,
  edition: EditionRow,
  scopeType: ScopeType | null,
  scopeId: string | null,
): Promise<{ name: string | null; error?: never } | { error: string; name?: never }> {
  if (!scopeType || !scopeId) return { name: null };
  switch (scopeType) {
    case "venue": {
      if (scopeId !== edition.venueId) {
        return { error: `That venue isn't where ${edition.name} is held — choose its venue` };
      }
      const venue = await db.query.venues.findFirst({
        where: and(eq(venues.id, scopeId), eq(venues.organisationId, orgId)),
      });
      return venue ? { name: venue.name } : { error: "That venue no longer exists" };
    }
    case "supplier": {
      const supplier = await db.query.suppliers.findFirst({
        where: and(eq(suppliers.id, scopeId), eq(suppliers.organisationId, orgId)),
      });
      if (!supplier) return { error: "That supplier no longer exists" };
      if (supplier.isArchived) {
        return { error: `${supplier.name} is archived — restore it in Suppliers first` };
      }
      return { name: supplier.name };
    }
    case "sponsor": {
      const sponsor = await db.query.sponsors.findFirst({
        where: and(eq(sponsors.id, scopeId), eq(sponsors.editionId, edition.id)),
      });
      return sponsor
        ? { name: sponsor.companyName }
        : { error: `That sponsor isn't one of ${edition.name}'s sponsors` };
    }
    case "exhibitor": {
      const exhibitor = await db.query.exhibitors.findFirst({
        where: and(eq(exhibitors.id, scopeId), eq(exhibitors.editionId, edition.id)),
      });
      return exhibitor
        ? { name: exhibitor.companyName }
        : { error: `That exhibitor isn't at ${edition.name}` };
    }
  }
}

/**
 * Invite someone from outside the team (Users → External, or a supplier's
 * or venue's portal access) to one event, for the venue or company their
 * role goes with. Refused for team members and anyone with a team
 * invitation waiting; when the same access was already given, nothing new
 * is created and the result says whether to resend or extend it. Returns
 * the link to share when email isn't set up.
 */
export async function inviteExternal(input: unknown): Promise<ActionResult<InviteExternalResult>> {
  const parsed = inviteSchema.safeParse(input);
  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    return fail(issue.message, { [String(issue.path[0] ?? "email")]: issue.message });
  }
  const session = await requireSession();
  if (!can(session.actor, { type: "partners.invite" })) {
    return fail(missingAbilityMessage("partners.invite"));
  }
  const data = parsed.data;
  const orgId = session.organisation.id;
  const scopeType = data.scopeType ?? null;
  const scopeId = data.scopeId ?? null;

  // The company has to go with the role (checked here, not only in the form).
  const scopeProblem = partnerScopeRefusal({ role: data.role, scopeType, scopeId });
  if (scopeProblem) return fail(scopeProblem, { scopeId: scopeProblem });
  const end = partnerAccessEnd(data.expiresAt, todayInLondon());
  if (end.error !== undefined) return fail(end.error, { expiresAt: end.error });

  const edition = await ownEdition(orgId, data.editionId, session.actor);
  if (!edition) return fail("That event no longer exists — reload the page");
  if (editionIsReadOnly(edition.status)) return fail(EDITION_LOCKED_MESSAGE);

  // Someone on a team already sees everything; a grant would be ignored.
  const [member] = await db
    .select({ organisationId: memberships.organisationId })
    .from(memberships)
    .innerJoin(users, eq(users.id, memberships.userId))
    .where(sql`lower(${users.email}) = ${data.email}`)
    .limit(1);
  if (member) {
    return fail(
      member.organisationId === orgId
        ? "That person is on your team and already sees everything"
        : "That email is used by a team account elsewhere — use a different email",
      { email: "Already on a team" },
    );
  }
  // A team invitation waiting would win at sign-in and this access would never apply.
  const teamInvite = await openTeamInviteFor(db, data.email);
  if (teamInvite) {
    return fail(
      teamInvite.organisationId === orgId
        ? `${data.email} has a team invitation waiting — cancel it in Users first, or use a different email`
        : "That email has a team invitation elsewhere — use a different email",
      { email: "Invited to a team" },
    );
  }

  const scope = await checkScope(orgId, edition, scopeType, scopeId);
  if (scope.error !== undefined) return fail(scope.error, { scopeId: scope.error });

  // The same access already given: resend or extend that instead.
  const same = await findSameGrant(db, orgId, {
    email: data.email,
    editionId: edition.id,
    role: data.role,
    scopeType,
    scopeId,
  });
  if (same) {
    const status = grantStatus(same);
    if (status !== "revoked") {
      const endsOn = same.expiresAt ? londonDateOfAccessEnd(same.expiresAt) : null;
      const what = `${roleLabel(data.role)}${scope.name ? ` – ${scope.name}` : ""}`;
      const message =
        status === "active"
          ? `${data.email} already has this access (${what}) for ${edition.name}`
          : status === "invited"
            ? `${data.email} was already invited on ${formatDayMonth(same.createdAt)} and hasn't signed in yet`
            : `${data.email}'s access to ${edition.name} ended on ${formatDayMonth(same.expiresAt)}`;
      return success({ inviteUrl: "", same: { grantId: same.id, status, endsOn } }, message);
    }
  }

  const token = generateInviteToken();
  try {
    const grant = await db.transaction(async (tx) => {
      const [row] = await tx
        .insert(externalGrants)
        .values({
          invitedEmail: data.email,
          organisationId: orgId,
          editionId: edition.id,
          role: data.role,
          scopeType,
          scopeId,
          expiresAt: end.expiresAt,
          invitedBy: session.user.id,
          inviteTokenHash: hashInviteToken(token),
        })
        .returning();
      await writeAudit(tx, {
        organisationId: orgId,
        editionId: edition.id,
        actorUserId: session.user.id,
        entityType: "external_grant",
        entityId: row.id,
        action: "invite",
        after: grantAuditPayload(row),
        summary: `Invited ${data.email} as ${roleLabel(data.role)}${scope.name ? ` – ${scope.name}` : ""} to ${edition.name}`,
        subjectEmail: data.email,
      });
      return row;
    });
    const name = data.fullName?.trim() || null;
    const inviteUrl = `${appUrl()}/invite/${token}${name ? `?name=${encodeURIComponent(name)}` : ""}`;
    const delivery = await deliverPartnerInvite({
      email: data.email,
      name,
      inviterName: session.user.fullName || session.user.email,
      reason: partnerInviteReason({
        organisationName: session.organisation.brandName,
        eventName: edition.name,
        role: data.role,
        scopeName: scope.name,
      }),
      inviteUrl,
      grantId: grant.id,
    });
    revalidatePath("/", "layout");
    return delivery.emailed
      ? success({ inviteUrl: "" }, `Invitation emailed to ${data.email}`)
      : success(
          { inviteUrl: delivery.fallbackUrl! },
          "Invitation created — email isn't set up here, so send them the link yourself",
        );
  } catch (err) {
    unstable_rethrow(err);
    console.error("inviteExternal", err);
    return fail("Could not send the invitation — please try again");
  }
}

async function partnerSession(): Promise<Session | null> {
  const session = await requireSession();
  return can(session.actor, { type: "partners.invite" }) ? session : null;
}

/** A partner's access in this organisation, on an event the actor can open (Users → Events). */
async function grantInOrg(orgId: string, grantId: string, actor: Actor) {
  const grant = await db.query.externalGrants.findFirst({
    where: and(eq(externalGrants.id, grantId), eq(externalGrants.organisationId, orgId)),
  });
  return grant && opensEdition(actor, grant.editionId) ? grant : undefined;
}

export async function revokeGrant(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ grantId: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await partnerSession();
  if (!session) return fail(missingAbilityMessage("partners.invite"));
  try {
    const grant = await db.transaction(async (tx) => {
      const now = new Date();
      const [row] = await tx
        .update(externalGrants)
        .set({ revokedAt: now, updatedAt: now })
        .where(
          and(
            eq(externalGrants.id, parsed.data.grantId),
            eq(externalGrants.organisationId, session.organisation.id),
            isNull(externalGrants.revokedAt),
            // Users → Events: only on events they can open.
            editionScopeSql(sessionScope(session), externalGrants.editionId),
          ),
        )
        .returning();
      if (!row) return null;
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: row.editionId,
        actorUserId: session.user.id,
        entityType: "external_grant",
        entityId: row.id,
        action: "grant_revoke",
        before: grantAuditPayload(row),
        after: { revokedAt: now.toISOString() },
        summary: `Revoked ${roleLabel(row.role)} access for ${row.invitedEmail}`,
        subjectUserId: row.userId,
        subjectEmail: row.invitedEmail,
      });
      return row;
    });
    revalidatePath("/", "layout");
    if (!grant) return fail("That access was already revoked — reload the page");
    return success(undefined, `Access revoked for ${grant.invitedEmail} — effective immediately`);
  } catch (err) {
    unstable_rethrow(err);
    console.error("revokeGrant", err);
    return fail("Could not revoke — please try again");
  }
}

/**
 * Send a waiting partner invitation again with a fresh link (the old one
 * stops working). With `linkOnly`, nothing is emailed: the link comes back
 * to pass on by hand (Copy link, when email isn't set up).
 */
export async function resendPartnerInvite(
  input: unknown,
): Promise<ActionResult<{ inviteUrl: string }>> {
  const parsed = z
    .object({ grantId: z.string().uuid(), linkOnly: z.boolean().optional() })
    .strict()
    .safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await partnerSession();
  if (!session) return fail(missingAbilityMessage("partners.invite"));
  const orgId = session.organisation.id;
  const existing = await grantInOrg(orgId, parsed.data.grantId, session.actor);
  if (!existing) return fail("That invitation no longer exists — reload the page");
  const edition = await ownEdition(orgId, existing.editionId, session.actor);
  if (!edition) return fail("That event no longer exists — reload the page");
  if (editionIsReadOnly(edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  try {
    const { grant, inviteUrl } = await db.transaction((tx) =>
      renewGrantInviteTx(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        grantId: existing.id,
      }),
    );
    revalidatePath("/", "layout");
    if (parsed.data.linkOnly) {
      return success({ inviteUrl }, "New link ready — the earlier one no longer works");
    }
    const scopeName = await grantScopeName(db, orgId, grant);
    const delivery = await deliverPartnerInvite({
      email: grant.invitedEmail,
      inviterName: session.user.fullName || session.user.email,
      reason: partnerInviteReason({
        organisationName: session.organisation.brandName,
        eventName: edition.name,
        role: grant.role,
        scopeName,
      }),
      inviteUrl,
      grantId: grant.id,
    });
    return delivery.emailed
      ? success({ inviteUrl: "" }, `Invitation sent again to ${grant.invitedEmail}`)
      : success(
          { inviteUrl: delivery.fallbackUrl! },
          "New link ready — email isn't set up here, so send it to them yourself",
        );
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof PartnerError) return fail(err.message);
    console.error("resendPartnerInvite", err);
    return fail("Could not send it again — please try again");
  }
}

/**
 * Set when a partner's access ends (a London date: the end of that day),
 * or take the end date away. Also how ended access is extended.
 */
export async function setPartnerAccessEnd(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({
      grantId: z.string().uuid(),
      date: z.string().date("Enter the date access ends").nullable(),
    })
    .strict()
    .safeParse(input);
  if (!parsed.success) {
    const message = parsed.error.issues[0]?.message ?? "Invalid request";
    return fail(message, { date: message });
  }
  const session = await partnerSession();
  if (!session) return fail(missingAbilityMessage("partners.invite"));
  const orgId = session.organisation.id;
  const end = partnerAccessEnd(parsed.data.date, todayInLondon());
  if (end.error !== undefined) return fail(end.error, { date: end.error });
  const existing = await grantInOrg(orgId, parsed.data.grantId, session.actor);
  if (!existing) return fail("That access no longer exists — reload the page");
  const edition = await ownEdition(orgId, existing.editionId, session.actor);
  if (!edition) return fail("That event no longer exists — reload the page");
  if (editionIsReadOnly(edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  try {
    const { after } = await db.transaction((tx) =>
      setGrantEndTx(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        grantId: existing.id,
        expiresAt: end.expiresAt,
      }),
    );
    revalidatePath("/", "layout");
    return success(
      undefined,
      parsed.data.date
        ? `${after.invitedEmail} has access to ${edition.name} until the end of ${formatDate(parsed.data.date)}`
        : `${after.invitedEmail}'s access to ${edition.name} no longer has an end date`,
    );
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof PartnerError) return fail(err.message);
    console.error("setPartnerAccessEnd", err);
    return fail("Could not change the end date — please try again");
  }
}
