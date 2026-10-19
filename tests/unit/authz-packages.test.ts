/**
 * Sponsorship packages add no action, ability or section: managing and
 * selling a package is sponsorship.sell, seeing its prices is costs.view —
 * both for the event. These pin how those resolve so the package actions,
 * page, dashboard and export can rely on them.
 */
import { describe, expect, it } from "vitest";
import {
  can,
  hasFeature,
  type ExternalActor,
  type PermissionOverrides,
  type StaffActor,
  type StaffRole,
} from "@/lib/authz";

const ORG = "org-1";
const A = "ed-a";
const B = "ed-b";

function staff(role: StaffRole, extra: Partial<StaffActor> = {}): StaffActor {
  return { kind: "staff", userId: `${role}-me`, organisationId: ORG, role, ...extra };
}

const sell = (editionId = A) => ({ type: "sponsorship.sell" as const, editionId });
const prices = (editionId = A) => ({ type: "costs.view" as const, editionId });
const report = (editionId = A) => ({
  type: "export.run" as const,
  kind: "sponsor_report",
  editionId,
});

describe("who manages and sells packages", () => {
  it("packages are managed and sold with sponsorship.sell: super admins, Operations and Sales by default", () => {
    for (const role of ["admin", "ops", "sales"] as const) {
      expect(can(staff(role), sell()), role).toBe(true);
      // Anyone who can sell can always see the prices they sell at.
      expect(can(staff(role), prices()), role).toBe(true);
    }
  });

  it("marketing, event directors and viewers can't, unless given sponsorship.sell", () => {
    for (const role of ["marketing", "event_director", "viewer"] as const) {
      expect(can(staff(role), sell()), role).toBe(false);
      const given: PermissionOverrides = { "sponsorship.sell": true };
      expect(can(staff(role, { overrides: given }), sell()), `${role} given`).toBe(true);
    }
  });

  it("a stored costs.view false stops selling packages and hides package prices", () => {
    const noCosts = staff("sales", { overrides: { "costs.view": false } });
    expect(can(noCosts, prices())).toBe(false);
    expect(can(noCosts, sell())).toBe(false);
    // Still sees the Sponsorship section (names, counts, lines).
    expect(hasFeature(noCosts, "sponsorship")).toBe(true);
  });

  it("a stored sponsorship.sell false stops selling but leaves prices", () => {
    const noSell = staff("ops", { overrides: { "sponsorship.sell": false } });
    expect(can(noSell, sell())).toBe(false);
    expect(can(noSell, prices())).toBe(true);
  });

  it("switching off Sponsorship stops package changes for everyone but super admins", () => {
    const sectionsWithout = { features: ["signage" as const] };
    for (const role of ["ops", "sales"] as const) {
      const off = staff(role, sectionsWithout);
      expect(hasFeature(off, "sponsorship"), role).toBe(false);
      expect(can(off, sell()), role).toBe(false);
    }
    const admin = staff("admin", sectionsWithout);
    expect(hasFeature(admin, "sponsorship")).toBe(true);
    expect(can(admin, sell())).toBe(true);
  });

  it("partners never manage packages or see prices, even a sponsor with a live grant", () => {
    const sponsor: ExternalActor = {
      kind: "external",
      userId: "partner",
      organisationId: ORG,
      grants: [
        {
          role: "sponsor",
          editionId: A,
          scopeType: "sponsor",
          scopeId: "sp-1",
          expiresAt: null,
          revokedAt: null,
        },
      ],
    };
    expect(can(sponsor, sell())).toBe(false);
    expect(can(sponsor, prices())).toBe(false);
    expect(can(sponsor, report())).toBe(false);
    expect(hasFeature(sponsor, "sponsorship")).toBe(false);
  });

  it("a seller limited to event A can't sell or see prices in B", () => {
    const limited = staff("sales", { editionIds: [A] });
    expect(can(limited, sell(A))).toBe(true);
    expect(can(limited, prices(A))).toBe(true);
    expect(can(limited, sell(B))).toBe(false);
    expect(can(limited, prices(B))).toBe(false);
    expect(can(limited, report(B))).toBe(false);
    // Super admins are never limited.
    expect(can(staff("admin"), sell(B))).toBe(true);
  });
});
