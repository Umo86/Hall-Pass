/**
 * Partner review fixes against a real database (TEST_DATABASE_URL), with
 * the session stubbed:
 * - partners-1: an external comment reaches earlier partner commenters only
 *   while their live grants in this organisation still show them the record
 *   (not after the item's supplier changed, not on a revoked grant while
 *   they keep another, not on a grant in another organisation); the email
 *   dispatcher drops a partner's notification once their access to that
 *   event is gone.
 * - partners-2: the copy form's partner-access count matches what copying
 *   brings across, ended grants included.
 */
import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";
import type { Session } from "@/lib/auth/actor";

const state = vi.hoisted(() => ({
  session: null as unknown,
  sent: [] as Array<{ to: string; subject: string; text: string }>,
}));
vi.mock("@/lib/email/send", () => ({
  sendEmail: async (m: { to: string; subject: string; text: string }) => {
    state.sent.push({ to: m.to, subject: m.subject, text: m.text });
    return true;
  },
}));
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
const n = Date.now() % 1_000_000;
const mail = (k: string) => `${k}-${n}@partners-review.test`;
let orgId: string;
let otherOrgId: string;
let adminId: string;
let venueId: string;
let e1: string;
let e2: string;
let otherEdition: string;
let supA: string;
let supB: string;

async function makeEdition(
  org: string,
  tag: string,
  venue: string,
  dates: { buildStart: string; openStart: string; openEnd: string; breakdownEnd: string },
) {
  const [event] = await db
    .insert(schema.events)
    .values({ organisationId: org, name: `PR ${tag}`, code: `PR${tag}${n}` })
    .returning();
  const [ed] = await db
    .insert(schema.editions)
    .values({
      eventId: event.id,
      venueId: venue,
      name: `PR ${tag}`,
      code: `PRV${tag}${n}`,
      buildStart: dates.buildStart,
      buildEnd: dates.buildStart,
      openStart: dates.openStart,
      openEnd: dates.openEnd,
      breakdownEnd: dates.breakdownEnd,
      status: "planning",
    })
    .returning();
  return ed.id;
}

const later = {
  buildStart: "2027-06-01",
  openStart: "2027-06-02",
  openEnd: "2027-06-04",
  breakdownEnd: "2027-06-05",
};

function staffSession(): Session {
  return {
    actor: { kind: "staff", userId: adminId, organisationId: orgId, role: "admin" },
    user: { id: adminId, email: mail("admin"), fullName: "Admin", isExternal: false },
    organisation: {
      id: orgId,
      brandName: "PR",
      settings: {} as Session["organisation"]["settings"],
    },
  };
}

/** revalidatePath has no request store outside Next; the change is committed before it. */
function expectSaved(r: { ok: boolean; error?: string }) {
  if (!r.ok) expect(r.error).toMatch(/static generation store missing/);
}

async function partner(
  key: string,
  grants: Array<Partial<typeof schema.externalGrants.$inferInsert>>,
) {
  const id = randomUUID();
  await db.insert(schema.users).values({ id, email: mail(key), fullName: key, isExternal: true });
  for (const g of grants) {
    await db.insert(schema.externalGrants).values({
      invitedEmail: mail(key),
      userId: id,
      acceptedAt: new Date(),
      organisationId: orgId,
      editionId: e1,
      role: "supplier",
      scopeType: "supplier",
      scopeId: supA,
      invitedBy: adminId,
      inviteTokenHash: `t-${randomUUID()}`,
      ...g,
    });
  }
  return id;
}

d("partner review fixes", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    const [org, other] = await db
      .insert(schema.organisations)
      .values([
        { name: "PR Org", slug: `pr-${n}` },
        { name: "PR Other", slug: `pr-other-${n}` },
      ])
      .returning();
    orgId = org.id;
    otherOrgId = other.id;
    adminId = randomUUID();
    await db.insert(schema.users).values({ id: adminId, email: mail("admin"), fullName: "Admin" });
    await db
      .insert(schema.memberships)
      .values({ userId: adminId, organisationId: orgId, role: "admin" });
    const [v, ov] = await db
      .insert(schema.venues)
      .values([
        { organisationId: orgId, name: "PR Hall", code: `PRH${n}` },
        { organisationId: otherOrgId, name: "PR Other Hall", code: `PRO${n}` },
      ])
      .returning();
    venueId = v.id;
    e1 = await makeEdition(orgId, "A", v.id, later);
    e2 = await makeEdition(orgId, "B", v.id, later);
    otherEdition = await makeEdition(otherOrgId, "C", ov.id, later);
    const [a, b] = await db
      .insert(schema.suppliers)
      .values([
        { organisationId: orgId, name: "Printer A" },
        { organisationId: orgId, name: "Printer B" },
      ])
      .returning();
    supA = a.id;
    supB = b.id;
  });

  afterAll(async () => {
    await client?.end();
  });

  it("partners-1: external comments reach only partners who can still see the item", async () => {
    const { addComment } = await import("@/app/actions/comments");
    const { sessionForUserId } = await import("@/lib/auth/actor");
    const [item] = await db
      .insert(schema.signageItems)
      .values({
        editionId: e1,
        ref: `SIG-PRA${n}-001`,
        seq: 1,
        name: "Entrance banner",
        supplierId: supA,
        ownerUserId: adminId,
        ownerRole: "ops",
        createdBy: adminId,
      })
      .returning();
    // P1 works for Printer A. P2 also has a grant on another event. P3 also
    // has a grant in another organisation. P4 stays on the item.
    const p1 = await partner("p1", [{}]);
    const p2 = await partner("p2", [{}, { editionId: e2 }]);
    // (The other organisation's grant is the older one, so P3 signs in here.)
    const p3 = await partner("p3", [
      {
        organisationId: otherOrgId,
        editionId: otherEdition,
        scopeId: null,
        scopeType: null,
        role: "hs",
      },
      {},
    ]);
    const p4 = await partner("p4", [{ scopeId: supB }]);
    for (const p of [p1, p2, p3]) {
      state.session = await sessionForUserId(p);
      expectSaved(
        await addComment({
          entityType: "signage_item",
          entityId: item.id,
          body: `hello from ${p}`,
          isInternal: false,
        }),
      );
    }
    // The item moves to Printer B; P2's and P3's access to this event is revoked.
    await db
      .update(schema.signageItems)
      .set({ supplierId: supB })
      .where(eq(schema.signageItems.id, item.id));
    for (const p of [p2, p3]) {
      await db
        .update(schema.externalGrants)
        .set({ revokedAt: new Date() })
        .where(and(eq(schema.externalGrants.userId, p), eq(schema.externalGrants.editionId, e1)));
    }
    // P4 (Printer B's contact) commented too, after the move.
    state.session = await sessionForUserId(p4);
    expectSaved(
      await addComment({
        entityType: "signage_item",
        entityId: item.id,
        body: "Printer B here",
        isInternal: false,
      }),
    );

    state.session = staffSession();
    expectSaved(
      await addComment({
        entityType: "signage_item",
        entityId: item.id,
        body: "Printer B: your quote of £4,200 is accepted",
        isInternal: false,
      }),
    );
    const rows = await db
      .select()
      .from(schema.notifications)
      .where(
        and(eq(schema.notifications.entityId, item.id), eq(schema.notifications.kind, "comment")),
      );
    const told = rows.filter((r) => r.body?.includes("£4,200")).map((r) => r.userId);
    expect(told).toContain(p4);
    for (const p of [p1, p2, p3]) expect(told).not.toContain(p);

    // A staff-only comment never reaches a partner, even one who can see the item.
    expectSaved(
      await addComment({
        entityType: "signage_item",
        entityId: item.id,
        body: "internal note on margins",
        isInternal: true,
      }),
    );
    const internal = await db
      .select()
      .from(schema.notifications)
      .where(and(eq(schema.notifications.entityId, item.id), eq(schema.notifications.userId, p4)));
    expect(internal.some((r) => r.body?.includes("margins"))).toBe(false);
  });

  it("partners-1: a contractor taken off one stand stops hearing about its thread", async () => {
    const { addComment } = await import("@/app/actions/comments");
    const { sessionForUserId } = await import("@/lib/auth/actor");
    const mk = async (stand: string) => {
      const [x] = await db
        .insert(schema.exhibitors)
        .values({ editionId: e1, companyName: `Exhibitor ${stand}`, standNumber: stand })
        .returning();
      const [sub] = await db
        .insert(schema.standSubmissions)
        .values({ editionId: e1, exhibitorId: x.id, ref: `STD-PR${n}-${stand}` })
        .returning();
      return { x, sub };
    };
    const X = await mk("X1");
    const Y = await mk("Y1");
    const c = await partner("contractor", [
      { role: "contractor", scopeType: "exhibitor", scopeId: X.x.id },
      { role: "contractor", scopeType: "exhibitor", scopeId: Y.x.id },
    ]);
    state.session = await sessionForUserId(c);
    expectSaved(
      await addComment({
        entityType: "stand_submission",
        entityId: X.sub.id,
        body: "C here",
        isInternal: false,
      }),
    );
    await db
      .update(schema.externalGrants)
      .set({ revokedAt: new Date() })
      .where(and(eq(schema.externalGrants.userId, c), eq(schema.externalGrants.scopeId, X.x.id)));
    state.session = staffSession();
    expectSaved(
      await addComment({
        entityType: "stand_submission",
        entityId: X.sub.id,
        body: "New contractor: budget raised to £18k",
        isInternal: false,
      }),
    );
    const rows = await db
      .select()
      .from(schema.notifications)
      .where(and(eq(schema.notifications.entityId, X.sub.id), eq(schema.notifications.userId, c)));
    expect(rows.some((r) => r.body?.includes("£18k"))).toBe(false);
  });

  it("partners-1: notify keeps a partner only with a live grant in the record's organisation and event", async () => {
    const { activeRecipientIds } = await import("@/lib/notify");
    const elsewhere = await partner("elsewhere", [
      {
        organisationId: otherOrgId,
        editionId: otherEdition,
        scopeId: null,
        scopeType: null,
        role: "hs",
      },
    ]);
    const otherEvent = await partner("other-event", [{ editionId: e2 }]);
    const here = await partner("here", [{}]);
    expect(await activeRecipientIds(db, [elsewhere, otherEvent, here])).toEqual(
      new Set([elsewhere, otherEvent, here]),
    );
    expect(
      await activeRecipientIds(db, [elsewhere, otherEvent, here], {
        organisationId: orgId,
        editionId: e1,
      }),
    ).toEqual(new Set([here]));
  });

  it("partners-1: an email waiting for a partner isn't sent once their access to that event is gone", async () => {
    const [item] = await db
      .insert(schema.signageItems)
      .values({
        editionId: e1,
        ref: `SIG-PRA${n}-002`,
        seq: 2,
        name: "Hall sign",
        supplierId: supA,
        ownerUserId: adminId,
        ownerRole: "ops",
        createdBy: adminId,
      })
      .returning();
    // Still live on another event, so the general "any live grant" check passes.
    const p = await partner("mailed", [{}, { editionId: e2 }]);
    const [row] = await db
      .insert(schema.notifications)
      .values({
        userId: p,
        kind: "comment",
        title: `Comment on ${item.ref}`,
        body: "secret terms",
        entityType: "signage_item",
        entityId: item.id,
      })
      .returning();
    await db
      .update(schema.externalGrants)
      .set({ revokedAt: new Date() })
      .where(and(eq(schema.externalGrants.userId, p), eq(schema.externalGrants.editionId, e1)));
    const key = process.env.RESEND_API_KEY;
    process.env.RESEND_API_KEY = "re_test";
    try {
      const { dispatchNotificationEmails } = await import("@/lib/email/dispatch");
      state.sent.length = 0;
      await dispatchNotificationEmails({ ids: [row.id] });
      expect(state.sent.filter((m) => m.to === mail("mailed"))).toEqual([]);
      const [after] = await db
        .select()
        .from(schema.notifications)
        .where(eq(schema.notifications.id, row.id));
      expect(after.emailedAt).not.toBeNull(); // settled, never retried
    } finally {
      if (key === undefined) delete process.env.RESEND_API_KEY;
      else process.env.RESEND_API_KEY = key;
    }
  });

  it("partners-2: the copy form counts ended partner access that copying brings across", async () => {
    const { copySourceCounts } = await import("@/lib/queries/setup");
    const { copiedAccessCount } = await import("@/lib/copy-access");
    const { accessEndsAtFromLondonDate } = await import("@/lib/access");
    const { todayInLondon } = await import("@/lib/today");
    const past = await makeEdition(orgId, "P", venueId, {
      buildStart: "2026-05-30",
      openStart: "2026-06-02",
      openEnd: "2026-06-04",
      breakdownEnd: "2026-06-05",
    });
    const [s] = await db
      .insert(schema.suppliers)
      .values({ organisationId: orgId, name: "Last Year Printers" })
      .returning();
    // Every grant on last year's event ended with it.
    const ended = accessEndsAtFromLondonDate("2026-06-05");
    const pat = await partner("pat", [
      { editionId: past, scopeId: s.id, expiresAt: ended },
      { editionId: past, role: "venue", scopeType: "venue", scopeId: venueId, expiresAt: ended },
    ]);
    const counts = (await copySourceCounts(orgId))(past);
    expect(counts.access).toBe(2);
    // Copied to next year's dates: both come across (live again), so the box says 2…
    const nextYear = "2027-06-04";
    expect(
      copiedAccessCount(counts.accessGrants, {
        breakdownEnd: nextYear,
        sameVenue: true,
        today: todayInLondon(),
      }),
    ).toBe(2);
    // …to another venue only the supplier's; to a date already past, none.
    expect(
      copiedAccessCount(counts.accessGrants, {
        breakdownEnd: nextYear,
        sameVenue: false,
        today: todayInLondon(),
      }),
    ).toBe(1);
    expect(
      copiedAccessCount(counts.accessGrants, {
        breakdownEnd: "2026-06-05",
        sameVenue: true,
        today: todayInLondon(),
      }),
    ).toBe(0);

    // And that is what the copy does.
    state.session = staffSession();
    const { cloneEdition } = await import("@/app/actions/editions");
    const res = await cloneEdition({
      sourceEditionId: past,
      name: "PR copy 2027",
      code: `PRC${n}`,
      openStart: "2027-06-01",
      openEnd: "2027-06-03",
      breakdownEnd: nextYear,
      include: { halls: false, deadlines: false, sponsors: false, items: false, access: true },
    }).catch((e: Error) => ({ ok: false as const, error: e.message }));
    if (!res.ok) expect(res.error).toMatch(/static generation store missing|cookies/);
    const [target] = await db
      .select()
      .from(schema.editions)
      .where(eq(schema.editions.code, `PRC${n}`));
    const copied = await db
      .select()
      .from(schema.externalGrants)
      .where(
        and(eq(schema.externalGrants.editionId, target.id), eq(schema.externalGrants.userId, pat)),
      );
    expect(copied).toHaveLength(2);
  });
});
