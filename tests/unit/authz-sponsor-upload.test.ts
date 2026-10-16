/**
 * Sponsors upload their own artwork in the portal (P4.2). Written before the
 * rule: an external sponsor with a live grant for that event, scoped to the
 * item's sponsor, may upload artwork while the item is waiting for it
 * (draft, needs artwork, changes requested) — and nothing more: no deleting,
 * no sending other items, no costs, no editing. Staff answers are held by the
 * frozen snapshot in authz-abilities.test.ts and must not move.
 */
import { describe, expect, it } from "vitest";
import {
  can,
  SPONSOR_UPLOAD_STATUSES,
  type ExternalActor,
  type GrantInfo,
  type SignageItemCtx,
  type StaffActor,
} from "@/lib/authz";

const ORG = "org-1";
const NOW = new Date("2026-10-16T12:00:00Z");

const grant = (over: Partial<GrantInfo> = {}): GrantInfo => ({
  role: "sponsor",
  editionId: "ed-1",
  scopeType: "sponsor",
  scopeId: "sp-1",
  expiresAt: null,
  revokedAt: null,
  ...over,
});

const sponsor = (...grants: GrantInfo[]): ExternalActor => ({
  kind: "external",
  userId: "partner",
  organisationId: ORG,
  grants: grants.length ? grants : [grant()],
});

const item = (over: Partial<SignageItemCtx> = {}): SignageItemCtx => ({
  organisationId: ORG,
  editionId: "ed-1",
  venueId: "v-1",
  kind: "signage",
  sponsorId: "sp-1",
  status: "awaiting_artwork",
  ...over,
});

const upload = (actor: ExternalActor | StaffActor, ctx: SignageItemCtx) =>
  can(actor, { type: "artwork.upload", item: ctx }, NOW);

describe("a sponsor may upload artwork for their own items", () => {
  it.each(["draft", "awaiting_artwork", "changes_requested"])("while the item is %s", (status) => {
    expect(upload(sponsor(), item({ status }))).toBe(true);
  });

  it("on sponsorship items they bought as well as sponsor signage", () => {
    expect(upload(sponsor(), item({ kind: "sponsorship_item" }))).toBe(true);
    expect(upload(sponsor(), item({ kind: undefined }))).toBe(true);
  });

  it("names exactly the statuses that take artwork", () => {
    expect([...SPONSOR_UPLOAD_STATUSES].sort()).toEqual(
      ["awaiting_artwork", "changes_requested", "draft"].sort(),
    );
  });

  it("with an end date still ahead", () => {
    const later = grant({ expiresAt: new Date("2026-10-17T00:00:00Z") });
    expect(upload(sponsor(later), item())).toBe(true);
  });

  it("when one of several grants is theirs for this item", () => {
    const other = grant({ scopeId: "sp-2", editionId: "ed-2" });
    expect(upload(sponsor(other, grant()), item())).toBe(true);
  });
});

describe("a sponsor may not upload", () => {
  it("for another sponsor's item", () => {
    expect(upload(sponsor(), item({ sponsorId: "sp-2" }))).toBe(false);
  });

  it("for an item with no sponsor", () => {
    expect(upload(sponsor(), item({ sponsorId: null }))).toBe(false);
    expect(upload(sponsor(), item({ sponsorId: undefined }))).toBe(false);
  });

  it("for the same sponsor at another event", () => {
    expect(upload(sponsor(), item({ editionId: "ed-2" }))).toBe(false);
  });

  it("in another organisation", () => {
    expect(upload(sponsor(), item({ organisationId: "org-2" }))).toBe(false);
  });

  it("once their grant is revoked", () => {
    const revoked = grant({ revokedAt: new Date("2026-10-01T00:00:00Z") });
    expect(upload(sponsor(revoked), item())).toBe(false);
  });

  it("once their access has ended", () => {
    const ended = grant({ expiresAt: new Date("2026-10-16T11:59:59Z") });
    expect(upload(sponsor(ended), item())).toBe(false);
    const exactlyNow = grant({ expiresAt: NOW });
    expect(upload(sponsor(exactlyNow), item())).toBe(false);
  });

  it.each([
    "in_review",
    "approved",
    "approved_with_conditions",
    "in_production",
    "delivered",
    "installed",
    "snagged",
    "closed",
    "rejected",
    "on_hold",
  ])("while the item is %s", (status) => {
    expect(upload(sponsor(), item({ status }))).toBe(false);
  });

  it("when the status isn't known", () => {
    expect(upload(sponsor(), item({ status: undefined }))).toBe(false);
  });

  it("for feature stands or stand panels", () => {
    expect(upload(sponsor(), item({ kind: "stand_design" }))).toBe(false);
    expect(upload(sponsor(), item({ kind: "stand_panel" }))).toBe(false);
  });

  it("with a grant that isn't a sponsor grant for that sponsor", () => {
    // Role sponsor without the sponsor scope, or another role scoped to it.
    expect(upload(sponsor(grant({ scopeType: null, scopeId: null })), item())).toBe(false);
    expect(upload(sponsor(grant({ scopeType: "supplier", scopeId: "sp-1" })), item())).toBe(false);
    expect(upload(sponsor(grant({ role: "supplier", scopeType: "sponsor" })), item())).toBe(false);
    expect(
      upload(sponsor(grant({ role: "venue", scopeType: "venue", scopeId: "v-1" })), item()),
    ).toBe(false);
  });
});

describe("uploading gives a sponsor nothing else", () => {
  const mine = item();
  it("cannot send items for sign-off themselves (the upload does it), theirs or others'", () => {
    expect(can(sponsor(), { type: "signage.submit", item: mine }, NOW)).toBe(false);
    expect(can(sponsor(), { type: "signage.submit", item: item({ sponsorId: "sp-2" }) }, NOW)).toBe(
      false,
    );
  });

  it("cannot delete, edit, restore or change the item's lifecycle", () => {
    for (const type of [
      "signage.delete",
      "signage.restore",
      "signage.hold",
      "signage.resume",
      "signage.reopen",
      "signage.close",
    ] as const) {
      expect(can(sponsor(), { type }, NOW)).toBe(false);
    }
    expect(can(sponsor(), { type: "signage.edit", item: mine }, NOW)).toBe(false);
  });

  it("cannot see or change costs", () => {
    expect(can(sponsor(), { type: "costs.view" }, NOW)).toBe(false);
    expect(can(sponsor(), { type: "costs.edit", item: mine }, NOW)).toBe(false);
    expect(can(sponsor(), { type: "costs.edit" }, NOW)).toBe(false);
  });

  it("still sees their own item and nobody else's", () => {
    expect(can(sponsor(), { type: "signage.view", item: mine }, NOW)).toBe(true);
    expect(can(sponsor(), { type: "signage.view", item: item({ sponsorId: "sp-2" }) }, NOW)).toBe(
      false,
    );
  });
});

describe("other partners and staff are unchanged", () => {
  it("suppliers and venues still never upload", () => {
    const supplier: ExternalActor = {
      ...sponsor(grant({ role: "supplier", scopeType: "supplier", scopeId: "sup-1" })),
    };
    const venue: ExternalActor = {
      ...sponsor(grant({ role: "venue", scopeType: "venue", scopeId: "v-1" })),
    };
    const theirs = item({ supplierId: "sup-1", requiresVenueApproval: true });
    expect(upload(supplier, theirs)).toBe(false);
    expect(upload(venue, theirs)).toBe(false);
  });

  it("staff keep their own rules (marketing yes, viewer no) whatever the status", () => {
    const staff = (role: StaffActor["role"]): StaffActor => ({
      kind: "staff",
      userId: "me",
      organisationId: ORG,
      role,
    });
    expect(upload(staff("marketing"), item({ status: "approved" }))).toBe(true);
    expect(upload(staff("viewer"), item())).toBe(false);
    expect(upload(staff("sales"), item({ status: "in_review" }))).toBe(true);
  });
});
