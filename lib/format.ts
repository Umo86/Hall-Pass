/** Display formatting — Europe/London, British English, GBP. */
import { appTimezone } from "./config";

export function formatDate(value: Date | string | null | undefined): string {
  if (!value) return "—";
  const date = typeof value === "string" ? new Date(`${value}T12:00:00Z`) : value;
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: appTimezone,
  }).format(date);
}

export function formatDateTime(value: Date | string | null | undefined): string {
  if (!value) return "—";
  const date = typeof value === "string" ? new Date(value) : value;
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: appTimezone,
  }).format(date);
}

export function formatMoney(value: string | number | null | undefined, currency = "GBP"): string {
  if (value == null || value === "") return "—";
  const n = typeof value === "string" ? Number(value) : value;
  if (Number.isNaN(n)) return "—";
  return new Intl.NumberFormat("en-GB", {
    style: "currency",
    currency,
    maximumFractionDigits: 0,
  }).format(n);
}

export function statusLabel(status: string): string {
  return status.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase());
}

/** Plain names for staff and external roles, as people say them. */
export const ROLE_LABELS: Record<string, string> = {
  admin: "Admin",
  ops: "Operations",
  marketing: "Marketing",
  sales: "Sales",
  event_director: "Senior management",
  viewer: "Viewer (read-only)",
  venue: "Venue",
  structural_engineer: "Structural engineer",
  hs: "Health & safety",
  supplier: "Supplier",
  exhibitor: "Exhibitor",
  contractor: "Contractor",
  sponsor: "Sponsor",
};

export function roleLabel(role: string | null | undefined): string {
  if (!role) return "—";
  return ROLE_LABELS[role] ?? statusLabel(role);
}

export function daysUntil(date: Date | string | null | undefined): number | null {
  if (!date) return null;
  const target = typeof date === "string" ? new Date(`${date}T12:00:00Z`) : date;
  return Math.floor((target.getTime() - Date.now()) / 86_400_000);
}
