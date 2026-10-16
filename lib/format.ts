/** Display formatting — Europe/London, British English, GBP. */
import { appTimezone } from "./config";

export function formatDate(value: Date | string | null | undefined): string {
  if (!value) return "—";
  // Plain dates ("2027-03-12") are read at midday so no timezone shifts the day;
  // full timestamps are used as they are.
  const date =
    typeof value === "string"
      ? new Date(/^\d{4}-\d{2}-\d{2}$/.test(value) ? `${value}T12:00:00Z` : value)
      : value;
  if (Number.isNaN(date.getTime())) return "—";
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

/**
 * The words people see for each status (decided once for the whole app),
 * and labels that plain "replace the underscores" gets wrong. Item
 * statuses first, then sign-off step states.
 */
const STATUS_LABELS: Record<string, string> = {
  // Items (signs, sponsorship items, stands and panels)
  draft: "Draft",
  awaiting_artwork: "Needs artwork",
  in_review: "In sign-off",
  changes_requested: "Changes requested",
  approved: "Approved",
  approved_with_conditions: "Approved (conditions)",
  in_production: "Sent to print",
  delivered: "Delivered",
  installed: "Installed",
  snagged: "Snagged",
  closed: "Complete",
  on_hold: "On hold",
  rejected: "Rejected",
  // Sign-off steps ("pending" reads better with a name: see stepStatusLabel)
  pending: "Their turn",
  waiting: "Not started",
  invalidated: "Superseded",
  skipped: "Skipped",
  // Snags
  wont_fix: "Won't fix",
};

export function statusLabel(status: string): string {
  return STATUS_LABELS[status] ?? status.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase());
}

/**
 * A sign-off step's state, naming who it waits on when that is known:
 * "Waiting on Operations", else "Their turn"; every other state as usual.
 */
export function stepStatusLabel(status: string, who?: string | null): string {
  if (status === "pending" && who?.trim()) return `Waiting on ${who.trim()}`;
  return statusLabel(status);
}

/** Install slots as people write them. */
export function slotLabel(slot: string | null | undefined): string {
  return slot ? ({ am: "AM", pm: "PM", overnight: "Overnight" }[slot] ?? statusLabel(slot)) : "";
}

/** "1 item", "12 items". */
export function plural(n: number, one: string, many = `${one}s`): string {
  return `${n.toLocaleString("en-GB")} ${n === 1 ? one : many}`;
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

/** One line per staff role, shown under each choice when adding or editing a user. */
export const ROLE_DESCRIPTIONS: Record<string, string> = {
  admin: "Everything, including users and settings",
  ops: "Runs events: signage, stands, onsite, costs and setup",
  marketing: "Adds signage and uploads artwork",
  sales: "Sponsorship items and sponsor signage",
  event_director: "Sees everything and signs off when asked",
  viewer: "Can look but not change anything",
};

/** "3 Oct" — a short date for lists where the year is obvious. */
export function formatDayMonth(value: Date | string | null | undefined): string {
  if (!value) return "—";
  const date = typeof value === "string" ? new Date(value) : value;
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    timeZone: appTimezone,
  }).format(date);
}

export function daysUntil(date: Date | string | null | undefined): number | null {
  if (!date) return null;
  const target = typeof date === "string" ? new Date(`${date}T12:00:00Z`) : date;
  return Math.floor((target.getTime() - Date.now()) / 86_400_000);
}
