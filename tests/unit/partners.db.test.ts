/**
 * Partner access against a real database (TEST_DATABASE_URL), with the
 * session stubbed for actions:
 * - P4.0: a returning partner gets a later invitation at their next sign-in
 *   (claimed and audited once), not only on their first.
 * - P4.1: accounts that come in through the account email are external;
 *   team members never claim partner access.
 * - P4.9: the session uses the organisation of the newest live grant.
 * - P4.4–P4.6, P4.12, P4.13: the company has to go with the role and the
 *   event, end dates are the end of a London day and never past, the same
 *   access offers Resend or Extend instead of a second row, team invitations
 *   block partner ones (expired ones don't), every change is audited with
 *   who it is about.
 * - P4.7, P0.12: copying an event moves partner end dates, audits each
 *   copied grant and hands items of people who can't work them to the copier.
 * - P4.2: a sponsor uploads artwork for their own item, it goes for sign-off
 *   and the item's owner is told.
 */
import { randomUUID } from "node:crypto";
import { and, desc, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";
import type { Session } from "@/lib/auth/actor";
import type { ExternalActor, StaffRole } from "@/lib/authz";

const state = vi.hoisted(() => ({ session: null as unknown }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn(), revalidateTag: vi.fn() }));
vi.mock("next/headers", () => ({
  cookies: async () => ({ get: () => undefined, set: () => {}, delete: () => {} }),
  headers: async () => new Headers(),
}));
vi.mock("@/lib/auth/actor", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/auth/actor")>();
  return {
    ...actual,
    requireSession: async () => state.session,
    requireStaffSession: async () => state.session,
  };
});

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let actorMod: typeof import("@/lib/auth/actor");
let settings: typeof import("@/app/actions/settings");
let editionsActions: typeof import("@/app/actions/editions");
let artwork: typeof import("@/app/actions/artwork");
let external: typeof import("@/lib/users/external");
let signageDomain: typeof import("@/lib/domain/signage");

const n = Date.now() % 1_000_000;
const mail = (k: string) => `${k}-${n}@partners.test`;
let orgId: string;
let otherOrgId: string;
let e1: string; // planning, at venue V
let e2: string; // planning, at venue V
let archivedEd: string;
let venueId: string;
let otherVenueId: string;
let supplierId: string;
let archivedSupplierId: string;
let sponsorId: string; // sponsor of e1
let otherSponsorId: string; // another sponsor of e1
let e2SponsorId: string; // sponsor of e2
let workflowId: string;
let hallId: string;
let locationId: string;
let typeId: string;
const people: Record<string, { id: string; role: StaffRole; email: string }> = {};
let seq = 0;

function staffSession(key: string): Session {
  const p = people[key];
  return {
    actor: {
      kind: "staff",
      userId: p.id,
      organisationId: orgId,
      role: p.role,
      signoffDepartmentIds: [],
    },
    user: { id: p.id, email: p.email, fullName: key, isExternal: false },
    organisation: {
      id: orgId,
      brandName: "Partners Org",
      settings: {} as Session["organisation"]["settings"],
    },
  };
}
const as = (key: string) => {
  state.session = staffSession(key);
};

async function addStaff(key: string, role: StaffRole, extra: { suspendedAt?: Date } = {}) {
  const id = randomUUID();
  const email = mail(key);
  await db.insert(schema.users).values({ id, email, fullName: key });
  await db
    .insert(schema.memberships)
    .values({ userId: id, organisationId: orgId, role, suspendedAt: extra.suspendedAt ?? null });
  people[key] = { id, role, email };
  return id;
}

async function makeEdition(
  org: string,
  tag: string,
  venue: string,
  dates: { openStart: string; openEnd: string; breakdownEnd: string },
  status: "planning" | "archived" = "planning",
) {
  const [event] = await db
    .insert(schema.events)
    .values({ organisationId: org, name: `Partners ${tag}`, code: `PE${tag}${n}` })
    .returning();
  const [edition] = await db
    .insert(schema.editions)
    .values({
      eventId: event.id,
      venueId: venue,
      name: `Partners ${tag}`,
      code: `PTN${tag}${n}`,
      buildStart: dates.openStart,
      buildEnd: dates.openStart,
      openStart: dates.openStart,
      openEnd: dates.openEnd,
      breakdownEnd: dates.breakdownEnd,
      status,
    })
    .returning();
  return edition.id;
}

async function grant(over: Partial<typeof schema.externalGrants.$inferInsert>) {
  const [row] = await db
    .insert(schema.externalGrants)
    .values({
      invitedEmail: mail(`g${randomUUID().slice(0, 6)}`),
      organisationId: orgId,
      editionId: e1,
      role: "supplier",
      scopeType: "supplier",
      scopeId: supplierId,
      invitedBy: people.admin.id,
      inviteTokenHash: `t-${randomUUID()}`,
      ...over,
    })
    .returning();
  return row;
}

const grantRow = async (id: string) =>
  (await db.select().from(schema.externalGrants).where(eq(schema.externalGrants.id, id)))[0];
const auditFor = (entityId: string) =>
  db
    .select()
    .from(schema.auditLog)
    .where(eq(schema.auditLog.entityId, entityId))
    .orderBy(desc(schema.auditLog.createdAt));

d("partner access", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    actorMod = await import("@/lib/auth/actor");
    settings = await import("@/app/actions/settings");
    editionsActions = await import("@/app/actions/editions");
    artwork = await import("@/app/actions/artwork");
    external = await import("@/lib/users/external");
    signageDomain = await import("@/lib/domain/signage");

    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Partners Org", slug: `partners-${n}` })
      .returning();
    orgId = org.id;
    const [other] = await db
      .insert(schema.organisations)
      .values({ name: "Other Partners Org", slug: `partners-other-${n}` })
      .returning();
    otherOrgId = other.id;
    await addStaff("admin", "admin");
    await addStaff("ops", "ops");
    await addStaff("gone", "marketing", { suspendedAt: new Date("2026-01-01") });

    const [v] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Partner Hall", code: `PV${n}` })
      .returning();
    venueId = v.id;
    const [v2] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Elsewhere Hall", code: `PV2${n}` })
      .returning();
    otherVenueId = v2.id;
    const [ov] = await db
      .insert(schema.venues)
      .values({ organisationId: otherOrgId, name: "Other Org Hall", code: `POV${n}` })
      .returning();
    // Last year's event (copied below) and next year's.
    e1 = await makeEdition(orgId, "A", venueId, {
      openStart: "2026-06-02",
      openEnd: "2026-06-04",
      breakdownEnd: "2026-06-05",
    });
    e2 = await makeEdition(orgId, "B", venueId, {
      openStart: "2027-06-01",
      openEnd: "2027-06-03",
      breakdownEnd: "2027-06-04",
    });
    archivedEd = await makeEdition(
      orgId,
      "C",
      venueId,
      { openStart: "2025-06-01", openEnd: "2025-06-03", breakdownEnd: "2025-06-04" },
      "archived",
    );
    await makeEdition(otherOrgId, "D", ov.id, {
      openStart: "2027-06-01",
      openEnd: "2027-06-03",
      breakdownEnd: "2027-06-04",
    });
    const [s] = await db
      .insert(schema.suppliers)
      .values({ organisationId: orgId, name: "Print Partners", email: mail("print") })
      .returning();
    supplierId = s.id;
    const [sa] = await db
      .insert(schema.suppliers)
      .values({ organisationId: orgId, name: "Old Printers", isArchived: true })
      .returning();
    archivedSupplierId = sa.id;
    const [sp] = await db
      .insert(schema.sponsors)
      .values({ editionId: e1, companyName: "BuildCo Partners", contactEmail: mail("sponsor") })
      .returning();
    sponsorId = sp.id;
    const [sp2] = await db
      .insert(schema.sponsors)
      .values({ editionId: e1, companyName: "Rival Sponsor" })
      .returning();
    otherSponsorId = sp2.id;
    const [sp3] = await db
      .insert(schema.sponsors)
      .values({ editionId: e2, companyName: "BuildCo Partners" })
      .returning();
    e2SponsorId = sp3.id;

    // For the upload tests: a hall, location, type and a one-step workflow.
    const [hall] = await db
      .insert(schema.halls)
      .values({ editionId: e1, name: "Hall 1" })
      .returning();
    hallId = hall.id;
    const [loc] = await db
      .insert(schema.locations)
      .values({ hallId, name: "Entrance" })
      .returning();
    locationId = loc.id;
    const [type] = await db
      .insert(schema.itemTypes)
      .values({ organisationId: orgId, name: "Banner", code: `PB${n}`, kind: "signage" })
      .returning();
    typeId = type.id;
    const [wf] = await db
      .insert(schema.workflows)
      .values({ organisationId: orgId, name: "Signage", appliesTo: "signage", isDefault: true })
      .returning();
    workflowId = wf.id;
    await db.insert(schema.workflowSteps).values({
      workflowId,
      sortOrder: 1,
      parallelGroup: 1,
      name: "Operations sign-off",
      kind: "approval",
      approverType: "role",
      approverRole: "ops",
      conditions: ["always"],
      slaDays: 3,
      invalidateOnNewVersion: true,
      restartFromHereOnChanges: true,
    });
  });

  afterAll(async () => {
    await client?.end();
  });

  describe("claiming at sign-in (P4.0)", () => {
    it("a returning partner gets a later invitation at their next sign-in, audited once", async () => {
      const id = randomUUID();
      const email = mail("returning");
      await db.insert(schema.users).values({ id, email, fullName: "Rita", isExternal: true });
      const first = await grant({
        invitedEmail: email,
        userId: id,
        acceptedAt: new Date("2026-01-02"),
        createdAt: new Date("2026-01-01"),
      });

      as("admin");
      const res = await settings.inviteExternal({
        email,
        editionId: e2,
        role: "supplier",
        scopeType: "supplier",
        scopeId: supplierId,
      });
      expect(res.ok).toBe(true);
      const [later] = await db
        .select()
        .from(schema.externalGrants)
        .where(
          and(
            eq(schema.externalGrants.invitedEmail, email),
            eq(schema.externalGrants.editionId, e2),
          ),
        );
      expect(later.userId).toBeNull();

      const session = await actorMod.sessionForUserId(id);
      expect(session?.actor.kind).toBe("external");
      const editions = (session!.actor as ExternalActor).grants.map((g) => g.editionId).sort();
      expect(editions).toEqual([e1, e2].sort());
      const claimed = await grantRow(later.id);
      expect(claimed.userId).toBe(id);
      expect(claimed.acceptedAt).not.toBeNull();
      const rows = await auditFor(later.id);
      const accepted = rows.filter((r) => /accepted their invitation/.test(r.summary));
      expect(accepted).toHaveLength(1);
      expect(accepted[0].subjectUserId).toBe(id);
      expect(accepted[0].subjectEmail).toBe(email);
      expect(accepted[0].organisationId).toBe(orgId);

      // A second sign-in claims nothing more and writes nothing more.
      await actorMod.sessionForUserId(id);
      expect((await auditFor(later.id)).filter((r) => /accepted/.test(r.summary))).toHaveLength(1);
      expect((await grantRow(first.id)).userId).toBe(id);
    });

    it("revoked and ended invitations are never claimed", async () => {
      const id = randomUUID();
      const email = mail("dead");
      await db.insert(schema.users).values({ id, email, isExternal: true });
      const live = await grant({ invitedEmail: email });
      const revoked = await grant({ invitedEmail: email, revokedAt: new Date() });
      const ended = await grant({ invitedEmail: email, expiresAt: new Date(Date.now() - 1000) });
      await actorMod.sessionForUserId(id);
      expect((await grantRow(live.id)).userId).toBe(id);
      expect((await grantRow(revoked.id)).userId).toBeNull();
      expect((await grantRow(ended.id)).userId).toBeNull();
    });
  });

  describe("who is external (P4.1)", () => {
    it("someone who arrived through the account email is marked external at sign-in", async () => {
      // completeAccount inserts the user without is_external, as Supabase's invite does.
      const id = randomUUID();
      const email = mail("supabase");
      await db.insert(schema.users).values({ id, email, fullName: "Sam" });
      const g = await grant({
        invitedEmail: email,
        role: "sponsor",
        scopeType: "sponsor",
        scopeId: sponsorId,
      });
      const session = await actorMod.sessionForUserId(id);
      expect(session?.actor.kind).toBe("external");
      const [user] = await db.select().from(schema.users).where(eq(schema.users.id, id));
      expect(user.isExternal).toBe(true);
      const flagged = await db
        .select()
        .from(schema.auditLog)
        .where(and(eq(schema.auditLog.entityId, id), eq(schema.auditLog.entityType, "user")));
      expect(flagged.some((r) => /partner account/.test(r.summary))).toBe(true);
      expect((await grantRow(g.id)).userId).toBe(id);

      // So a staff-only comment is never sent to them.
      const recipients = signageDomain.commentRecipients({
        authorId: people.ops.id,
        ownerId: people.ops.id,
        createdBy: null,
        priorAuthors: [{ id, isExternal: user.isExternal }],
        isInternal: true,
      });
      expect(recipients).not.toContain(id);
    });

    it("a team member never claims partner access, and stays staff", async () => {
      const id = await addStaff("member", "marketing");
      const g = await grant({ invitedEmail: people.member.email });
      const claimed = await external.claimOpenGrants(
        { id, email: people.member.email, isExternal: false },
        { db: db as never },
      );
      expect(claimed).toEqual([]);
      const session = await actorMod.sessionForUserId(id);
      expect(session?.actor.kind).toBe("staff");
      expect((await grantRow(g.id)).userId).toBeNull();
      const [user] = await db.select().from(schema.users).where(eq(schema.users.id, id));
      expect(user.isExternal).toBe(false);
    });

    it("staffMemberIds names only active members of this organisation", async () => {
      const partner = randomUUID();
      await db.insert(schema.users).values({ id: partner, email: mail("notstaff") });
      const ids = await external.staffMemberIds(db as never, orgId, [
        people.ops.id,
        people.gone.id,
        partner,
      ]);
      expect([...ids]).toEqual([people.ops.id]);
      expect([
        ...(await external.staffMemberIds(db as never, otherOrgId, [people.ops.id])),
      ]).toEqual([]);
    });
  });

  describe("the session's organisation (P4.9)", () => {
    it("is the newest live grant's, with only that organisation's grants", async () => {
      const id = randomUUID();
      const email = mail("twoorgs");
      await db.insert(schema.users).values({ id, email, isExternal: true });
      const [otherEd] = await db
        .select({ id: schema.editions.id })
        .from(schema.editions)
        .where(eq(schema.editions.code, `PTND${n}`));
      await grant({
        invitedEmail: email,
        userId: id,
        acceptedAt: new Date(),
        organisationId: orgId,
        createdAt: new Date("2026-01-01"),
      });
      // Newer, but revoked: it doesn't decide where they land.
      await grant({
        invitedEmail: email,
        userId: id,
        acceptedAt: new Date(),
        organisationId: otherOrgId,
        editionId: otherEd.id,
        scopeId: null,
        scopeType: null,
        role: "hs",
        createdAt: new Date("2026-05-01"),
        revokedAt: new Date("2026-05-02"),
      });
      const session = await actorMod.sessionForUserId(id);
      expect(session?.organisation.id).toBe(orgId);
      const grants = (session!.actor as ExternalActor).grants;
      expect(grants.every((g) => g.editionId === e1 && !g.revokedAt)).toBe(true);
    });

    it("nothing live left: no session (sign-in says their access has ended)", async () => {
      const id = randomUUID();
      const email = mail("ended");
      await db.insert(schema.users).values({ id, email, isExternal: true });
      await grant({
        invitedEmail: email,
        userId: id,
        acceptedAt: new Date(),
        expiresAt: new Date(Date.now() - 60_000),
      });
      expect(await actorMod.sessionForUserId(id)).toBeNull();
    });
  });

  describe("inviting (P4.4–P4.6, P4.12, P4.13)", () => {
    const base = () => ({
      email: mail(`inv${randomUUID().slice(0, 6)}`),
      editionId: e1,
      role: "supplier" as const,
      scopeType: "supplier" as const,
      scopeId: supplierId,
    });

    it("needs “Invite partners”", async () => {
      as("ops");
      const res = await settings.inviteExternal(base());
      expect(res.ok).toBe(false);
      if (!res.ok) expect(res.error).toMatch(/Invite partners/);
    });

    it("refuses a company that doesn't go with the role or the event", async () => {
      as("admin");
      const cases: Array<[Record<string, unknown>, RegExp]> = [
        [{ role: "venue", scopeType: "supplier", scopeId: supplierId }, /Choose the venue/],
        [{ role: "supplier", scopeType: "supplier", scopeId: null }, /Choose the supplier/],
        [{ role: "venue", scopeType: "venue", scopeId: otherVenueId }, /isn't where/],
        [{ scopeId: archivedSupplierId }, /archived/],
        [{ role: "sponsor", scopeType: "sponsor", scopeId: e2SponsorId }, /isn't one of/],
        [{ role: "hs", scopeType: "venue", scopeId: venueId }, /whole event/],
        [{ editionId: archivedEd }, /archived/],
      ];
      for (const [over, message] of cases) {
        const res = await settings.inviteExternal({ ...base(), ...over });
        expect(res.ok, JSON.stringify(over)).toBe(false);
        if (!res.ok) expect(res.error).toMatch(message);
      }
      // The event's own venue is fine.
      const ok = await settings.inviteExternal({
        ...base(),
        role: "venue",
        scopeType: "venue",
        scopeId: venueId,
      });
      expect(ok.ok).toBe(true);
    });

    it("stores Access ends as the end of that London day, refuses past dates, audits it", async () => {
      as("admin");
      const input = { ...base(), expiresAt: "2027-06-10" };
      const res = await settings.inviteExternal(input);
      expect(res.ok).toBe(true);
      const [row] = await db
        .select()
        .from(schema.externalGrants)
        .where(eq(schema.externalGrants.invitedEmail, input.email));
      expect(row.expiresAt?.toISOString()).toBe("2027-06-10T22:59:59.999Z");
      const [audit] = await auditFor(row.id);
      expect(audit.action).toBe("invite");
      expect(audit.subjectEmail).toBe(input.email);
      expect(audit.after).toMatchObject({
        email: input.email,
        role: "supplier",
        scopeType: "supplier",
        scopeId: supplierId,
        editionId: e1,
        expiresAt: "2027-06-10T22:59:59.999Z",
      });

      const past = await settings.inviteExternal({ ...base(), expiresAt: "2020-01-01" });
      expect(past.ok).toBe(false);
      if (!past.ok) expect(past.error).toBe(external.PAST_DATE_MESSAGE);
    });

    it("team members and open team invitations block it; an expired team invitation doesn't", async () => {
      as("admin");
      const member = await settings.inviteExternal({ ...base(), email: people.ops.email });
      expect(member.ok).toBe(false);
      if (!member.ok) expect(member.error).toMatch(/on your team/);

      const waiting = mail("teamwaiting");
      await db.insert(schema.staffInvites).values({
        organisationId: orgId,
        invitedEmail: waiting,
        role: "viewer",
        inviteTokenHash: `si-${randomUUID()}`,
        expiresAt: new Date(Date.now() + 86_400_000),
      });
      const blocked = await settings.inviteExternal({ ...base(), email: waiting });
      expect(blocked.ok).toBe(false);
      if (!blocked.ok) expect(blocked.error).toMatch(/team invitation waiting/);

      const elsewhere = mail("teamelsewhere");
      await db.insert(schema.staffInvites).values({
        organisationId: otherOrgId,
        invitedEmail: elsewhere,
        role: "viewer",
        inviteTokenHash: `si-${randomUUID()}`,
      });
      const other = await settings.inviteExternal({ ...base(), email: elsewhere });
      expect(other.ok).toBe(false);
      if (!other.ok) expect(other.error).toMatch(/elsewhere/);

      const lapsed = mail("teamlapsed");
      await db.insert(schema.staffInvites).values({
        organisationId: orgId,
        invitedEmail: lapsed,
        role: "viewer",
        inviteTokenHash: `si-${randomUUID()}`,
        expiresAt: new Date(Date.now() - 86_400_000),
      });
      expect((await settings.inviteExternal({ ...base(), email: lapsed })).ok).toBe(true);
    });

    it("the same access again offers Resend; Resend makes a new link, audited", async () => {
      as("admin");
      const input = base();
      expect((await settings.inviteExternal(input)).ok).toBe(true);
      const again = await settings.inviteExternal({ ...input, email: input.email.toUpperCase() });
      expect(again.ok).toBe(true);
      if (!again.ok) return;
      expect(again.data?.same?.status).toBe("invited");
      const rows = await db
        .select()
        .from(schema.externalGrants)
        .where(eq(schema.externalGrants.invitedEmail, input.email));
      expect(rows).toHaveLength(1);
      const before = rows[0].inviteTokenHash;

      const resent = await settings.resendPartnerInvite({ grantId: rows[0].id });
      expect(resent.ok).toBe(true);
      if (resent.ok) expect(resent.data?.inviteUrl).toMatch(/\/invite\//);
      const after = await grantRow(rows[0].id);
      expect(after.inviteTokenHash).not.toBe(before);
      const [audit] = await auditFor(rows[0].id);
      expect(audit.summary).toMatch(/sent again/);
      expect(audit.subjectEmail).toBe(input.email);

      // Another event or company is a new invitation, not the same access.
      const otherEvent = await settings.inviteExternal({ ...input, editionId: e2 });
      expect(otherEvent.ok && !otherEvent.data?.same).toBe(true);
    });

    it("accepted access says so; ended access is extended instead, audited before and after", async () => {
      as("admin");
      const active = await grant({ userId: people.admin.id, acceptedAt: new Date() });
      const res = await settings.inviteExternal({
        ...base(),
        email: active.invitedEmail,
      });
      expect(res.ok && res.data?.same?.status).toBe("active");
      const resend = await settings.resendPartnerInvite({ grantId: active.id });
      expect(resend.ok).toBe(false);

      const ended = await grant({ expiresAt: new Date("2026-06-05T22:59:59.999Z") });
      const again = await settings.inviteExternal({ ...base(), email: ended.invitedEmail });
      expect(again.ok && again.data?.same?.status).toBe("expired");
      expect(again.ok && again.data?.same?.endsOn).toBe("2026-06-05");

      const past = await settings.setPartnerAccessEnd({ grantId: ended.id, date: "2026-01-01" });
      expect(past.ok).toBe(false);
      const ok = await settings.setPartnerAccessEnd({ grantId: ended.id, date: "2027-01-10" });
      expect(ok.ok).toBe(true);
      expect((await grantRow(ended.id)).expiresAt?.toISOString()).toBe("2027-01-10T23:59:59.999Z");
      const [audit] = await auditFor(ended.id);
      expect(audit.action).toBe("update");
      expect(audit.subjectEmail).toBe(ended.invitedEmail);
      expect((audit.before as { expiresAt: string }).expiresAt).toBe("2026-06-05T22:59:59.999Z");
      expect((audit.after as { expiresAt: string }).expiresAt).toBe("2027-01-10T23:59:59.999Z");

      const none = await settings.setPartnerAccessEnd({ grantId: ended.id, date: null });
      expect(none.ok).toBe(true);
      expect((await grantRow(ended.id)).expiresAt).toBeNull();
    });

    it("can't touch another organisation's grants; revoking is audited with the grant", async () => {
      as("admin");
      const [otherEd] = await db
        .select({ id: schema.editions.id })
        .from(schema.editions)
        .where(eq(schema.editions.code, `PTND${n}`));
      const foreign = await grant({
        organisationId: otherOrgId,
        editionId: otherEd.id,
        role: "hs",
        scopeType: null,
        scopeId: null,
      });
      expect((await settings.setPartnerAccessEnd({ grantId: foreign.id, date: null })).ok).toBe(
        false,
      );
      expect((await settings.resendPartnerInvite({ grantId: foreign.id })).ok).toBe(false);
      expect((await settings.revokeGrant({ grantId: foreign.id })).ok).toBe(false);

      const mine = await grant({});
      expect((await settings.revokeGrant({ grantId: mine.id })).ok).toBe(true);
      const [audit] = await auditFor(mine.id);
      expect(audit.action).toBe("grant_revoke");
      expect(audit.subjectEmail).toBe(mine.invitedEmail);
      expect(audit.before).toMatchObject({ email: mine.invitedEmail, role: "supplier" });
    });
  });

  describe("one answer for whether a sponsor or person has portal access (P4.15, P4.12)", () => {
    it("sponsorPortalAccess: accepted and live is access, waiting is invited, ended or revoked is none", async () => {
      const [accessSp] = await db
        .insert(schema.sponsors)
        .values({ editionId: e2, companyName: "Access Ltd" })
        .returning();
      const [invitedSp] = await db
        .insert(schema.sponsors)
        .values({ editionId: e2, companyName: "Invited Ltd" })
        .returning();
      const [endedSp] = await db
        .insert(schema.sponsors)
        .values({ editionId: e2, companyName: "Ended Ltd" })
        .returning();
      const sponsorGrant = (scopeId: string, over: Record<string, unknown> = {}) =>
        grant({ editionId: e2, role: "sponsor", scopeType: "sponsor", scopeId, ...over });
      await sponsorGrant(accessSp.id, { userId: people.admin.id, acceptedAt: new Date() });
      await sponsorGrant(accessSp.id);
      await sponsorGrant(invitedSp.id);
      await sponsorGrant(endedSp.id, {
        userId: people.admin.id,
        acceptedAt: new Date(),
        expiresAt: new Date(Date.now() - 1000),
      });
      await sponsorGrant(endedSp.id, { revokedAt: new Date() });
      const map = await external.sponsorPortalAccess(db as never, orgId, [
        accessSp.id,
        invitedSp.id,
        endedSp.id,
      ]);
      expect(map.get(accessSp.id)).toBe("access");
      expect(map.get(invitedSp.id)).toBe("invited");
      expect(map.has(endedSp.id)).toBe(false);
      // Another organisation asking sees nothing.
      expect(
        (await external.sponsorPortalAccess(db as never, otherOrgId, [accessSp.id])).size,
      ).toBe(0);
    });

    it("livePartnerGrantsFor finds only live grants in this organisation", async () => {
      const email = mail("livecheck");
      await grant({ invitedEmail: email, expiresAt: new Date(Date.now() - 1000) });
      await grant({ invitedEmail: email, revokedAt: new Date() });
      expect(await external.livePartnerGrantsFor(db as never, orgId, email)).toHaveLength(0);
      const live = await grant({ invitedEmail: email });
      const found = await external.livePartnerGrantsFor(db as never, orgId, email.toUpperCase());
      expect(found.map((g) => g.id)).toEqual([live.id]);
      expect(await external.livePartnerGrantsFor(db as never, otherOrgId, email)).toHaveLength(0);
    });
  });

  describe("copying an event (P4.7, P0.12)", () => {
    it("moves partner end dates, audits each copied grant, and hands inactive owners' items to the copier", async () => {
      // Partner access on last year's event.
      const venueGrant = await grant({
        role: "venue",
        scopeType: "venue",
        scopeId: venueId,
        userId: people.admin.id,
        acceptedAt: new Date("2026-01-01"),
        // Ended with last year's event (end of 5 June, London).
        expiresAt: new Date("2026-06-05T22:59:59.999Z"),
      });
      const openSupplier = await grant({});
      const longGone = await grant({ expiresAt: new Date("2025-01-01T23:59:59.999Z") });
      const revoked = await grant({ revokedAt: new Date() });
      const sponsorGrant = await grant({
        role: "sponsor",
        scopeType: "sponsor",
        scopeId: sponsorId,
      });

      // Items: one with an active owner, one with a suspended owner.
      const mk = async (owner: string, name: string) => {
        seq += 1;
        const [row] = await db
          .insert(schema.signageItems)
          .values({
            editionId: e1,
            ref: `SIG-PTNA${n}-${String(seq).padStart(3, "0")}`,
            seq,
            name,
            ownerUserId: owner,
            ownerRole: "marketing",
            createdBy: people.ops.id,
          })
          .returning();
        return row;
      };
      await mk(people.ops.id, "Kept owner");
      await mk(people.gone.id, "Suspended owner");

      as("admin");
      const code = `PCP${n}`;
      const res = await editionsActions.cloneEdition({
        sourceEditionId: e1,
        name: "Partners copy",
        code,
        openStart: "2027-06-01",
        openEnd: "2027-06-03",
        breakdownEnd: "2027-06-04",
        include: { halls: true, deadlines: true, sponsors: false, items: true, access: true },
      });
      expect(res.ok, res.ok ? "" : res.error).toBe(true);
      if (!res.ok) return;
      expect(res.data?.counts.ownersReplaced).toBe(1);
      expect(res.message).toMatch(/yours now/);
      const [target] = await db
        .select()
        .from(schema.editions)
        .where(eq(schema.editions.code, code));

      const copied = await db
        .select()
        .from(schema.externalGrants)
        .where(eq(schema.externalGrants.editionId, target.id));
      const byEmail = new Map(copied.map((g) => [g.invitedEmail, g]));
      // 5 June 2026 + 364 days (5 June 2026 → 4 June 2027 breakdown) = 4 June 2027, end of day.
      expect(byEmail.get(venueGrant.invitedEmail)?.expiresAt?.toISOString()).toBe(
        "2027-06-04T22:59:59.999Z",
      );
      expect(byEmail.get(venueGrant.invitedEmail)?.acceptedAt).not.toBeNull();
      expect(byEmail.get(openSupplier.invitedEmail)?.expiresAt).toBeNull();
      expect(byEmail.has(longGone.invitedEmail)).toBe(false);
      expect(byEmail.has(revoked.invitedEmail)).toBe(false);
      expect(byEmail.has(sponsorGrant.invitedEmail)).toBe(false);
      expect(res.data?.counts.accessEnded).toBeGreaterThanOrEqual(1);

      for (const g of copied) {
        const [audit] = await auditFor(g.id);
        expect(audit?.action).toBe("invite");
        expect(audit?.subjectEmail).toBe(g.invitedEmail);
        expect((audit?.after as { copiedFrom?: string }).copiedFrom).toBeTruthy();
      }

      const items = await db
        .select()
        .from(schema.signageItems)
        .where(eq(schema.signageItems.editionId, target.id));
      expect(items.find((i) => i.name === "Kept owner")?.ownerUserId).toBe(people.ops.id);
      expect(items.find((i) => i.name === "Suspended owner")?.ownerUserId).toBe(people.admin.id);
    });
  });

  describe("a sponsor uploads their own artwork (P4.2)", () => {
    const PNG = Buffer.from(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
      "base64",
    );
    let sponsorUser: string;

    function sponsorSession(grants: ExternalActor["grants"]) {
      state.session = {
        actor: { kind: "external", userId: sponsorUser, organisationId: orgId, grants },
        user: { id: sponsorUser, email: mail("ben"), fullName: "Ben", isExternal: true },
        organisation: {
          id: orgId,
          brandName: "Partners Org",
          settings: {} as Session["organisation"]["settings"],
        },
      } satisfies Session;
    }
    const liveSponsorGrant = {
      role: "sponsor" as const,
      editionId: "",
      scopeType: "sponsor" as const,
      scopeId: "",
      expiresAt: null,
      revokedAt: null,
    };

    async function sponsorItem(over: Partial<typeof schema.signageItems.$inferInsert> = {}) {
      seq += 1;
      const [row] = await db
        .insert(schema.signageItems)
        .values({
          editionId: e1,
          ref: `SIG-PTNU${n}-${String(seq).padStart(3, "0")}`,
          seq,
          name: `Sponsor banner ${seq}`,
          workflowId,
          hallId,
          locationId,
          itemTypeId: typeId,
          widthMm: 1000,
          heightMm: 500,
          quantity: 1,
          fixingMethod: "wall_mounted",
          sponsorId,
          ownerUserId: people.ops.id,
          createdBy: people.ops.id,
          ...over,
        })
        .returning();
      return row;
    }
    const upload = (itemId: string) => {
      const fd = new FormData();
      fd.set("itemId", itemId);
      fd.set("file", new File([PNG], "logo.png", { type: "image/png" }));
      fd.set("notes", "Our logo");
      return artwork.uploadArtwork(fd);
    };

    beforeAll(async () => {
      sponsorUser = randomUUID();
      await db
        .insert(schema.users)
        .values({ id: sponsorUser, email: mail("ben"), fullName: "Ben", isExternal: true });
    });

    it("a complete draft goes for sign-off and its owner is told", async () => {
      const item = await sponsorItem({ status: "draft" });
      sponsorSession([{ ...liveSponsorGrant, editionId: e1, scopeId: sponsorId }]);
      const res = await upload(item.id);
      expect(res.ok, res.ok ? "" : res.error).toBe(true);
      if (!res.ok) return;
      expect(res.data?.status).toBe("in_review");
      expect(res.message).toMatch(/sent for sign-off/);
      // Nothing internal (who it waits on) in what the sponsor is told.
      expect(res.message).not.toMatch(/waiting on/);
      const [after] = await db
        .select()
        .from(schema.signageItems)
        .where(eq(schema.signageItems.id, item.id));
      expect(after.status).toBe("in_review");
      const [version] = await db
        .select()
        .from(schema.artworkVersions)
        .where(eq(schema.artworkVersions.signageItemId, item.id));
      expect(version.uploadedBy).toBe(sponsorUser);
      const told = await db
        .select()
        .from(schema.notifications)
        .where(
          and(
            eq(schema.notifications.entityId, item.id),
            eq(schema.notifications.userId, people.ops.id),
            eq(schema.notifications.kind, "artwork_uploaded"),
          ),
        );
      expect(told.map((t) => t.title)).toContain(
        `BuildCo Partners uploaded artwork for ${item.name} (${item.ref})`,
      );
      const audits = await db
        .select()
        .from(schema.auditLog)
        .where(and(eq(schema.auditLog.entityId, item.id), eq(schema.auditLog.action, "upload")));
      expect(audits[0].actorUserId).toBe(sponsorUser);
      expect(audits[0].summary).toMatch(/by the sponsor/);
    });

    it("an item waiting for artwork starts its sign-off", async () => {
      const item = await sponsorItem({ status: "awaiting_artwork" });
      sponsorSession([{ ...liveSponsorGrant, editionId: e1, scopeId: sponsorId }]);
      const res = await upload(item.id);
      expect(res.ok && res.data?.status).toBe("in_review");
    });

    it("an incomplete draft stays with the team, who are told to finish it", async () => {
      const item = await sponsorItem({ status: "draft", fixingMethod: null });
      sponsorSession([{ ...liveSponsorGrant, editionId: e1, scopeId: sponsorId }]);
      const res = await upload(item.id);
      expect(res.ok).toBe(true);
      if (!res.ok) return;
      expect(res.data?.status).toBe("draft");
      expect(res.message).toMatch(/team will send it for sign-off once its details are complete/);
    });

    it("refused for another sponsor's item, in sign-off, another event or with a revoked grant", async () => {
      const rival = await sponsorItem({ status: "draft", sponsorId: otherSponsorId });
      const reviewing = await sponsorItem({ status: "in_review" });
      const mine = await sponsorItem({ status: "draft" });
      sponsorSession([{ ...liveSponsorGrant, editionId: e1, scopeId: sponsorId }]);
      for (const id of [rival.id, reviewing.id]) {
        const res = await upload(id);
        expect(res.ok).toBe(false);
      }
      sponsorSession([{ ...liveSponsorGrant, editionId: e2, scopeId: sponsorId }]);
      expect((await upload(mine.id)).ok).toBe(false);
      sponsorSession([
        { ...liveSponsorGrant, editionId: e1, scopeId: sponsorId, revokedAt: new Date() },
      ]);
      expect((await upload(mine.id)).ok).toBe(false);
      sponsorSession([
        {
          ...liveSponsorGrant,
          editionId: e1,
          scopeId: sponsorId,
          expiresAt: new Date(Date.now() - 1000),
        },
      ]);
      expect((await upload(mine.id)).ok).toBe(false);
      const versions = await db
        .select()
        .from(schema.artworkVersions)
        .where(eq(schema.artworkVersions.signageItemId, mine.id));
      expect(versions).toHaveLength(0);
    });
  });
});
