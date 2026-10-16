/**
 * Pure rules for Suppliers (no database, no React): when a supplier can be
 * deleted outright rather than archived, and how an install contractor's
 * insurance date reads. Unit tested in tests/unit/suppliers-rules.test.ts.
 */
import { plural } from "@/lib/format";

/** Everything that refers to a supplier (counts). */
export type SupplierUsage = {
  /** Items not deleted, on any event. */
  liveItems: number;
  /** Items in the recycle bin. They come back with their supplier when restored. */
  deletedItems: number;
  /** Snags assigned to the supplier. */
  snags: number;
  /** Portal access that is still current (invited or active). */
  liveGrants: number;
  /** Portal access that was revoked or has expired. Kept for the record. */
  pastGrants: number;
};

export type SupplierRemoval =
  { canDelete: true; reason: null } | { canDelete: false; reason: string };

/**
 * A supplier can be deleted only when nothing — live or deleted — uses it.
 * Otherwise it can only be archived, and the reason says why in plain words.
 */
export function supplierRemoval(name: string, usage: SupplierUsage): SupplierRemoval {
  if (usage.liveItems > 0) {
    return {
      canDelete: false,
      reason: `${name} is the supplier on ${plural(usage.liveItems, "item")}. Archive it instead — those items keep it.`,
    };
  }
  if (usage.deletedItems > 0) {
    const n = usage.deletedItems;
    return {
      canDelete: false,
      reason: `${plural(n, "deleted item")} still ${n === 1 ? "uses" : "use"} ${name}. Archive it instead, or restore ${n === 1 ? "that item" : "those items"} from the Recycle bin and change the supplier.`,
    };
  }
  if (usage.snags > 0) {
    return {
      canDelete: false,
      reason: `${plural(usage.snags, "snag")} ${usage.snags === 1 ? "is" : "are"} assigned to ${name}. Archive it instead.`,
    };
  }
  if (usage.liveGrants > 0) {
    const n = usage.liveGrants;
    return {
      canDelete: false,
      reason: `${n === 1 ? "1 person" : `${n} people`} from ${name} ${n === 1 ? "has" : "have"} portal access. Revoke it first, or archive ${name} instead.`,
    };
  }
  if (usage.pastGrants > 0) {
    return {
      canDelete: false,
      reason: `${name} has had portal access before, so it is kept for the record. Archive it instead.`,
    };
  }
  return { canDelete: true, reason: null };
}

export type InsuranceStatus =
  | { tone: "none"; label: null; days: null }
  | { tone: "ok"; label: null; days: number }
  | { tone: "soon" | "expired"; label: string; days: number };

/** Days from `today` to `date`, both plain YYYY-MM-DD dates. */
export function daysBetween(today: string, date: string): number {
  const a = Date.parse(`${today}T12:00:00Z`);
  const b = Date.parse(`${date}T12:00:00Z`);
  return Math.round((b - a) / 86_400_000);
}

/** How soon cover runs out: expired (red), within 30 days (amber), or fine. */
export function insuranceStatus(
  expiry: string | null | undefined,
  today: string,
  warnWithinDays = 30,
): InsuranceStatus {
  if (!expiry || !/^\d{4}-\d{2}-\d{2}$/.test(expiry))
    return { tone: "none", label: null, days: null };
  const days = daysBetween(today, expiry);
  if (days < 0) return { tone: "expired", label: "Insurance expired", days };
  if (days <= warnWithinDays) {
    const label =
      days === 0 ? "Expires today" : days === 1 ? "Expires tomorrow" : `Expires in ${days} days`;
    return { tone: "soon", label, days };
  }
  return { tone: "ok", label: null, days };
}

/** The first few things a supplier does, then "+n" (for a table cell). */
export function servicesPreview(names: string[], max = 3): { shown: string[]; more: number } {
  return { shown: names.slice(0, max), more: Math.max(0, names.length - max) };
}

/** Search and "What they do" filter for the supplier list. */
export function matchesSupplier(
  s: {
    name: string;
    contactName: string | null;
    email: string | null;
    phone: string | null;
    serviceIds: string[];
  },
  filter: { q: string; serviceId: string },
): boolean {
  if (filter.serviceId && !s.serviceIds.includes(filter.serviceId)) return false;
  const needle = filter.q.trim().toLowerCase();
  if (!needle) return true;
  return [s.name, s.contactName ?? "", s.email ?? "", s.phone ?? ""]
    .join(" ")
    .toLowerCase()
    .includes(needle);
}
