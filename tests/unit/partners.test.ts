/**
 * Partner (external) access rules, pure (lib/users/external.ts): which
 * company goes with which role, "Access ends" as the end of a London day,
 * end dates moved with a copied event, which organisation and grants a
 * partner's session uses, and when a partner sees artwork under review.
 */
import { describe, expect, it } from "vitest";
import {
  copiedAccessEnd,
  externalSeesArtwork,
  grantAuditPayload,
  grantLive,
  PARTNER_SCOPE_FOR,
  partnerAccessEnd,
  partnerInviteReason,
  partnerScopeRefusal,
  partnerSessionGrants,
  PAST_DATE_MESSAGE,
} from "@/lib/users/external";
import type {
  ExternalActor,
  ExternalRole,
  GrantInfo,
  ScopeType,
  SignageItemCtx,
} from "@/lib/authz";

const ID = "00000000-0000-4000-8000-000000000001";

describe("role and company go together", () => {
  const cases: Array<[ExternalRole, ScopeType | null]> = [
    ["venue", "venue"],
    ["supplier", "supplier"],
    ["sponsor", "sponsor"],
    ["exhibitor", "exhibitor"],
    ["contractor", "exhibitor"],
    ["structural_engineer", null],
    ["hs", null],
  ];

  it("the map covers every partner role", () => {
    expect(Object.keys(PARTNER_SCOPE_FOR).sort()).toEqual(cases.map(([r]) => r).sort());
  });

  it.each(cases)("%s is for %s", (role, scopeType) => {
    expect(PARTNER_SCOPE_FOR[role]).toBe(scopeType);
    expect(partnerScopeRefusal({ role, scopeType, scopeId: scopeType ? ID : null })).toBeNull();
  });

  it("a scoped role needs its company chosen", () => {
    expect(partnerScopeRefusal({ role: "supplier", scopeType: "supplier", scopeId: null })).toBe(
      "Choose the supplier they work for",
    );
    expect(partnerScopeRefusal({ role: "venue" })).toBe("Choose the venue they are from");
    expect(partnerScopeRefusal({ role: "sponsor", scopeType: null, scopeId: ID })).toBe(
      "Choose the sponsor they are from",
    );
  });

  it("refuses a company of the wrong kind", () => {
    expect(partnerScopeRefusal({ role: "venue", scopeType: "supplier", scopeId: ID })).toBe(
      "Choose the venue they are from",
    );
    expect(partnerScopeRefusal({ role: "supplier", scopeType: "sponsor", scopeId: ID })).toBe(
      "Choose the supplier they work for",
    );
    expect(partnerScopeRefusal({ role: "contractor", scopeType: "supplier", scopeId: ID })).toBe(
      "Choose the exhibitor and stand they are for",
    );
    expect(partnerScopeRefusal({ role: "sponsor", scopeType: "exhibitor", scopeId: ID })).toBe(
      "Choose the sponsor they are from",
    );
  });

  it("engineers and health and safety name no company", () => {
    expect(partnerScopeRefusal({ role: "hs", scopeType: "venue", scopeId: ID })).toMatch(
      /covers the whole event/,
    );
    expect(partnerScopeRefusal({ role: "structural_engineer", scopeId: ID })).toMatch(
      /covers the whole event/,
    );
  });
});

describe("Access ends: the end of that day in London", () => {
  const today = "2026-10-16";

  it("no date means no end", () => {
    expect(partnerAccessEnd(null, today)).toEqual({ expiresAt: null });
    expect(partnerAccessEnd("", today)).toEqual({ expiresAt: null });
    expect(partnerAccessEnd(undefined, today)).toEqual({ expiresAt: null });
  });

  it("in summer time it is 22:59:59.999 UTC (not the next London day)", () => {
    const { expiresAt } = partnerAccessEnd("2027-06-10", today);
    expect(expiresAt?.toISOString()).toBe("2027-06-10T22:59:59.999Z");
  });

  it("in winter it is 23:59:59.999 UTC", () => {
    const { expiresAt } = partnerAccessEnd("2027-01-10", today);
    expect(expiresAt?.toISOString()).toBe("2027-01-10T23:59:59.999Z");
  });

  it("on the days the clocks change", () => {
    expect(partnerAccessEnd("2026-10-25", today).expiresAt?.toISOString()).toBe(
      "2026-10-25T23:59:59.999Z",
    );
    expect(partnerAccessEnd("2027-03-28", today).expiresAt?.toISOString()).toBe(
      "2027-03-28T22:59:59.999Z",
    );
  });

  it("today is allowed, yesterday is not", () => {
    expect(partnerAccessEnd(today, today).expiresAt?.toISOString()).toBe(
      "2026-10-16T22:59:59.999Z",
    );
    expect(partnerAccessEnd("2026-10-15", today)).toEqual({ error: PAST_DATE_MESSAGE });
  });

  it("refuses something that isn't a date", () => {
    expect(partnerAccessEnd("16/10/2026", today).error).toBeTruthy();
    expect(partnerAccessEnd("2027-02-30", today).error).toBe("Enter a real date");
  });
});

describe("live grants", () => {
  const now = new Date("2026-10-16T12:00:00Z");
  it("revoked or ended grants are not live; an end still ahead is", () => {
    expect(grantLive({ revokedAt: null, expiresAt: null }, now)).toBe(true);
    expect(grantLive({ revokedAt: null, expiresAt: new Date("2026-10-16T12:00:01Z") }, now)).toBe(
      true,
    );
    expect(grantLive({ revokedAt: null, expiresAt: now }, now)).toBe(false);
    expect(grantLive({ revokedAt: new Date("2026-10-01"), expiresAt: null }, now)).toBe(false);
  });
});

describe("copying an event moves end dates with it", () => {
  it("by the days between the two events' last breakdown days, still end of a London day", () => {
    // Ended 9 Oct 2026 (BST); the new event breaks down a year and a day later.
    const end = new Date("2026-10-09T22:59:59.999Z");
    const moved = copiedAccessEnd(end, "2026-10-08", "2027-10-09");
    expect(moved?.toISOString()).toBe("2027-10-10T22:59:59.999Z");
  });

  it("across a clock change it stays the end of the London day", () => {
    // 20 Oct (BST) moved by 14 days lands on 3 Nov (GMT).
    const end = new Date("2026-10-20T22:59:59.999Z");
    expect(copiedAccessEnd(end, "2026-10-01", "2026-10-15")?.toISOString()).toBe(
      "2026-11-03T23:59:59.999Z",
    );
  });

  it("no end date stays none, and an earlier event moves it back", () => {
    expect(copiedAccessEnd(null, "2026-10-08", "2027-10-09")).toBeNull();
    const end = new Date("2027-01-10T23:59:59.999Z");
    expect(copiedAccessEnd(end, "2027-01-08", "2027-01-01")?.toISOString()).toBe(
      "2027-01-03T23:59:59.999Z",
    );
  });
});

describe("which grants a partner's session uses", () => {
  const now = new Date("2026-10-16T12:00:00Z");
  const g = (
    id: string,
    organisationId: string,
    createdAt: string,
    over: { revokedAt?: Date | null; expiresAt?: Date | null } = {},
  ) => ({
    id,
    organisationId,
    createdAt: new Date(createdAt),
    revokedAt: over.revokedAt ?? null,
    expiresAt: over.expiresAt ?? null,
  });

  it("the organisation of the newest live grant, and only its live grants", () => {
    const picked = partnerSessionGrants(
      [
        g("a1", "org-a", "2026-01-01"),
        g("b1", "org-b", "2026-09-01"),
        g("b2", "org-b", "2026-03-01", { expiresAt: new Date("2026-04-01") }),
        g("b3", "org-b", "2026-02-01"),
      ],
      now,
    );
    expect(picked?.organisationId).toBe("org-b");
    expect(picked?.grants.map((x) => x.id)).toEqual(["b1", "b3"]);
  });

  it("a revoked or ended newest grant never decides where they land", () => {
    const picked = partnerSessionGrants(
      [
        g("a1", "org-a", "2026-01-01"),
        g("b1", "org-b", "2026-09-01", { revokedAt: new Date("2026-09-02") }),
        g("b2", "org-b", "2026-08-01", { expiresAt: new Date("2026-10-01") }),
      ],
      now,
    );
    expect(picked?.organisationId).toBe("org-a");
    expect(picked?.grants.map((x) => x.id)).toEqual(["a1"]);
  });

  it("nothing live left: null (they are told their access has ended)", () => {
    expect(
      partnerSessionGrants(
        [g("a1", "org-a", "2026-01-01", { revokedAt: new Date("2026-02-01") })],
        now,
      ),
    ).toBeNull();
    expect(partnerSessionGrants([], now)).toBeNull();
  });
});

describe("when a partner sees artwork under review", () => {
  const now = new Date("2026-10-16T12:00:00Z");
  const grant = (over: Partial<GrantInfo>): GrantInfo => ({
    role: "supplier",
    editionId: "ed-1",
    scopeType: "supplier",
    scopeId: "sup-1",
    expiresAt: null,
    revokedAt: null,
    ...over,
  });
  const actor = (...grants: GrantInfo[]): ExternalActor => ({
    kind: "external",
    userId: "p",
    organisationId: "org-1",
    grants,
  });
  const item = (status: string, over: Partial<SignageItemCtx> = {}) => ({
    organisationId: "org-1",
    editionId: "ed-1",
    venueId: "v-1",
    supplierId: "sup-1",
    sponsorId: "sp-1",
    requiresVenueApproval: true,
    status,
    ...over,
  });
  const supplier = grant({});
  const sponsor = grant({ role: "sponsor", scopeType: "sponsor", scopeId: "sp-1" });

  it("a supplier only once it is signed off", () => {
    expect(externalSeesArtwork(actor(supplier), item("in_review"), now)).toBe(false);
    expect(externalSeesArtwork(actor(supplier), item("approved"), now)).toBe(true);
    expect(externalSeesArtwork(actor(supplier), item("in_production"), now)).toBe(true);
  });

  it("a supplier who is also this item's sponsor sees it under review", () => {
    expect(externalSeesArtwork(actor(supplier, sponsor), item("in_review"), now)).toBe(true);
  });

  it("a sponsor or venue grant for another item or event doesn't release it", () => {
    const otherEvent = grant({
      role: "sponsor",
      scopeType: "sponsor",
      scopeId: "sp-1",
      editionId: "ed-2",
    });
    const otherSponsor = grant({ role: "sponsor", scopeType: "sponsor", scopeId: "sp-2" });
    expect(externalSeesArtwork(actor(supplier, otherEvent), item("in_review"), now)).toBe(false);
    expect(externalSeesArtwork(actor(supplier, otherSponsor), item("in_review"), now)).toBe(false);
  });

  it("an ended or revoked sponsor grant doesn't release it", () => {
    const ended = { ...sponsor, expiresAt: new Date("2026-10-01") };
    const revoked = { ...sponsor, revokedAt: new Date("2026-10-01") };
    expect(externalSeesArtwork(actor(supplier, ended), item("in_review"), now)).toBe(false);
    expect(externalSeesArtwork(actor(supplier, revoked), item("in_review"), now)).toBe(false);
  });

  it("the venue of an item it approves sees it under review", () => {
    const venue = grant({ role: "venue", scopeType: "venue", scopeId: "v-1" });
    expect(externalSeesArtwork(actor(venue), item("in_review"), now)).toBe(true);
    expect(
      externalSeesArtwork(actor(venue), item("in_review", { requiresVenueApproval: false }), now),
    ).toBe(false);
  });
});

describe("what partners are told and what is audited", () => {
  it("the invitation says which event, company and role", () => {
    expect(
      partnerInviteReason({
        organisationName: "Media10",
        eventName: "UKCW 2027",
        role: "sponsor",
        scopeName: "BuildCo",
      }),
    ).toBe("Media10 has given you access to UKCW 2027 for BuildCo (sponsor).");
    expect(
      partnerInviteReason({ organisationName: "Media10", eventName: "UKCW 2027", role: "hs" }),
    ).toBe("Media10 has given you access to UKCW 2027 (health & safety).");
  });

  it("every grant audit row describes the grant the same way", () => {
    expect(
      grantAuditPayload({
        invitedEmail: "Ben@BuildCo.test",
        role: "sponsor",
        scopeType: "sponsor",
        scopeId: ID,
        editionId: "ed-1",
        expiresAt: new Date("2027-06-10T22:59:59.999Z"),
      }),
    ).toEqual({
      email: "ben@buildco.test",
      role: "sponsor",
      scopeType: "sponsor",
      scopeId: ID,
      editionId: "ed-1",
      expiresAt: "2027-06-10T22:59:59.999Z",
    });
  });
});
