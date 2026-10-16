import { describe, expect, it } from "vitest";
import {
  daysBetween,
  insuranceStatus,
  matchesSupplier,
  servicesPreview,
  supplierRemoval,
  type SupplierUsage,
} from "@/components/suppliers/rules";
import { grantStatus, portalSummary, type GrantStatus } from "@/components/portal/summary";

const none: SupplierUsage = {
  liveItems: 0,
  deletedItems: 0,
  snags: 0,
  liveGrants: 0,
  pastGrants: 0,
};

describe("supplierRemoval", () => {
  it("allows a delete only when nothing uses the supplier", () => {
    expect(supplierRemoval("Big Print", none)).toEqual({ canDelete: true, reason: null });
  });

  it.each([
    [
      { liveItems: 3 },
      "Big Print is the supplier on 3 items. Archive it instead — those items keep it.",
    ],
    [
      { liveItems: 1 },
      "Big Print is the supplier on 1 item. Archive it instead — those items keep it.",
    ],
    [
      { deletedItems: 2 },
      "2 deleted items still use Big Print. Archive it instead, or restore those items from the Recycle bin and change the supplier.",
    ],
    [
      { deletedItems: 1 },
      "1 deleted item still uses Big Print. Archive it instead, or restore that item from the Recycle bin and change the supplier.",
    ],
    [{ snags: 1 }, "1 snag is assigned to Big Print. Archive it instead."],
    [
      { liveGrants: 2 },
      "2 people from Big Print have portal access. Revoke it first, or archive Big Print instead.",
    ],
    [
      { pastGrants: 1 },
      "Big Print has had portal access before, so it is kept for the record. Archive it instead.",
    ],
  ])("refuses when %o", (usage, reason) => {
    expect(supplierRemoval("Big Print", { ...none, ...usage })).toEqual({
      canDelete: false,
      reason,
    });
  });

  it("names live items before deleted ones", () => {
    const r = supplierRemoval("X", { ...none, liveItems: 1, deletedItems: 5 });
    expect(r.reason).toMatch(/supplier on 1 item/);
  });
});

describe("insuranceStatus", () => {
  const today = "2026-10-16";
  it("is blank without a date", () => {
    expect(insuranceStatus(null, today).tone).toBe("none");
    expect(insuranceStatus("not a date", today).tone).toBe("none");
  });
  it("is red once the date has passed", () => {
    expect(insuranceStatus("2026-10-15", today)).toEqual({
      tone: "expired",
      label: "Insurance expired",
      days: -1,
    });
  });
  it("is amber within 30 days, with words for today and tomorrow", () => {
    expect(insuranceStatus("2026-10-16", today).label).toBe("Expires today");
    expect(insuranceStatus("2026-10-17", today).label).toBe("Expires tomorrow");
    expect(insuranceStatus("2026-11-15", today)).toEqual({
      tone: "soon",
      label: "Expires in 30 days",
      days: 30,
    });
  });
  it("is fine further out", () => {
    expect(insuranceStatus("2026-11-16", today)).toEqual({ tone: "ok", label: null, days: 31 });
  });
  it("counts whole days across the clock change", () => {
    expect(daysBetween("2026-10-24", "2026-10-26")).toBe(2);
  });
});

describe("supplier list helpers", () => {
  it("shows three services then a count", () => {
    expect(servicesPreview(["a", "b", "c", "d", "e"])).toEqual({ shown: ["a", "b", "c"], more: 2 });
    expect(servicesPreview(["a"])).toEqual({ shown: ["a"], more: 0 });
  });

  const s = {
    name: "Big Print Co",
    contactName: "Petra",
    email: "print@bigprint.test",
    phone: "0121 000",
    serviceIds: ["svc-print"],
  };
  it("searches name, contact, email and phone", () => {
    expect(matchesSupplier(s, { q: "petra", serviceId: "" })).toBe(true);
    expect(matchesSupplier(s, { q: "BIGPRINT.TEST", serviceId: "" })).toBe(true);
    expect(matchesSupplier(s, { q: "0121", serviceId: "" })).toBe(true);
    expect(matchesSupplier(s, { q: "screens", serviceId: "" })).toBe(false);
  });
  it("filters by what they do", () => {
    expect(matchesSupplier(s, { q: "", serviceId: "svc-print" })).toBe(true);
    expect(matchesSupplier(s, { q: "", serviceId: "svc-av" })).toBe(false);
  });
});

describe("portal access", () => {
  const now = new Date("2026-10-16T12:00:00Z");
  it("works out each grant's status", () => {
    const base = { revokedAt: null, expiresAt: null, acceptedAt: null };
    expect(grantStatus(base, now)).toBe("invited");
    expect(grantStatus({ ...base, acceptedAt: now }, now)).toBe("active");
    expect(grantStatus({ ...base, acceptedAt: now, expiresAt: now }, now)).toBe("expired");
    expect(grantStatus({ ...base, revokedAt: now, expiresAt: now }, now)).toBe("revoked");
    expect(grantStatus({ ...base, expiresAt: new Date("2026-10-17T00:00:00Z") }, now)).toBe(
      "invited",
    );
  });

  it("summarises who can sign in, counting people rather than grants", () => {
    const g = (status: GrantStatus, email: string) => ({ status, email });
    expect(portalSummary([])).toBe("No portal access");
    expect(portalSummary([g("revoked", "a@x.test"), g("expired", "b@x.test")])).toBe(
      "No portal access",
    );
    expect(portalSummary([g("active", "a@x.test")])).toBe("1 person can sign in");
    expect(
      portalSummary([g("active", "a@x.test"), g("active", "b@x.test"), g("invited", "c@x.test")]),
    ).toBe("2 people can sign in · 1 invited");
    expect(portalSummary([g("invited", "a@x.test")])).toBe("1 person invited");
    expect(portalSummary([g("invited", "a@x.test"), g("invited", "b@x.test")])).toBe(
      "2 people invited",
    );
    // The same person on several events, or invited again, is one person.
    expect(
      portalSummary([g("active", "a@x.test"), g("active", "A@x.test"), g("invited", "a@x.test")]),
    ).toBe("1 person can sign in");
  });
});
