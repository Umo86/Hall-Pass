/**
 * The words, colours and filters of the Users list (Users → Team). Pure —
 * unit tested in tests/unit/users-list.test.ts — so the list, the person
 * page and the server agree on what "Suspended", "Access ends" or "Last
 * active 3 days ago" mean. Dates are London dates.
 */
import type { ManagerScope, StaffRole } from "@/lib/authz";
import { appTimezone } from "@/lib/config";
import { formatDayMonth } from "@/lib/format";

/** A row's status as the list shows it (one colour each, always with its words). */
export type PersonStatus = "active" | "ending" | "invited" | "expired" | "suspended" | "ended";

export const PERSON_STATUSES: readonly PersonStatus[] = [
  "active",
  "ending",
  "invited",
  "expired",
  "suspended",
  "ended",
];

/** The filter's choices, in its order ("all" is no filter). */
export const STATUS_FILTERS: readonly { value: PersonStatus | ""; label: string }[] = [
  { value: "", label: "All" },
  { value: "active", label: "Active" },
  { value: "invited", label: "Invited" },
  { value: "expired", label: "Invite expired" },
  { value: "suspended", label: "Suspended" },
  { value: "ending", label: "Access ends" },
  { value: "ended", label: "Access ended" },
];

/** What the list needs to know about a person (members and invitations). */
export type ListPerson = {
  kind: "member" | "invite";
  name: string;
  email: string;
  jobTitle: string | null;
  role: StaffRole;
  departmentId: string | null;
  departmentArchived: boolean;
  /** Members: active, suspended or ended; invitations: invited or expired. */
  status: "active" | "invited" | "expired" | "suspended" | "ended";
  managerScope: ManagerScope | null;
  accessEndsAt: Date | null;
  lastSeenAt: Date | null;
};

/** Active with an end date coming reads "Access ends …" (its own colour). */
export function personStatus(p: Pick<ListPerson, "status" | "accessEndsAt">): PersonStatus {
  if (p.status === "active" && p.accessEndsAt) return "ending";
  return p.status;
}

/** Tailwind classes for each status: one colour token each. */
export const PERSON_STATUS_CLASSES: Record<PersonStatus, string> = {
  active: "bg-emerald-50 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300",
  ending: "bg-violet-50 text-violet-800 dark:bg-violet-950 dark:text-violet-300",
  invited: "bg-sky-50 text-sky-800 dark:bg-sky-950 dark:text-sky-300",
  expired: "bg-amber-50 text-amber-900 dark:bg-amber-950 dark:text-amber-300",
  suspended: "bg-rose-50 text-rose-800 dark:bg-rose-950 dark:text-rose-300",
  ended: "bg-neutral-200 text-neutral-700 dark:bg-neutral-700 dark:text-neutral-200",
};

/** YYYY-MM-DD in London. */
function londonDate(at: Date): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: appTimezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(at);
}

function daysBetween(from: string, to: string): number {
  return Math.round((Date.parse(`${to}T12:00:00Z`) - Date.parse(`${from}T12:00:00Z`)) / 86_400_000);
}

/** Whole London days since they were last active (0 = today), or null if never. */
export function daysSinceActive(lastSeenAt: Date | null, now = new Date()): number | null {
  if (!lastSeenAt) return null;
  return Math.max(0, daysBetween(londonDate(lastSeenAt), londonDate(now)));
}

/** "Today", "Yesterday", "3 days ago", "12 Sep" (with the year if not this one) or "Never signed in". */
export function lastActiveText(lastSeenAt: Date | null, now = new Date()): string {
  const days = daysSinceActive(lastSeenAt, now);
  if (days === null) return "Never signed in";
  if (days === 0) return "Today";
  if (days === 1) return "Yesterday";
  if (days < 7) return `${days} days ago`;
  const sameYear = londonDate(lastSeenAt!).slice(0, 4) === londonDate(now).slice(0, 4);
  if (sameYear) return formatDayMonth(lastSeenAt);
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: appTimezone,
  }).format(lastSeenAt!);
}

/** Not signed in for 30 days or more (or never): the "Not active lately" filter. */
export const STALE_DAYS = 30;

export function isStale(p: Pick<ListPerson, "kind" | "lastSeenAt">, now = new Date()): boolean {
  if (p.kind !== "member") return false;
  const days = daysSinceActive(p.lastSeenAt, now);
  return days === null || days >= STALE_DAYS;
}

/** "Manager · Marketing" or "Manager · everyone"; null when they aren't one. */
export function managerBadgeText(
  p: Pick<ListPerson, "managerScope" | "role">,
  departmentName: string | null,
): string | null {
  if (p.role === "admin" || !p.managerScope) return null;
  if (p.managerScope === "everyone") return "Manager · everyone";
  return `Manager · ${departmentName ?? "their department"}`;
}

export type ListFilters = {
  q?: string;
  /** A department id, or "none" for people without a (live) department. */
  dept?: string;
  /** A role, or "manager" for anyone who manages people (not super admins). */
  role?: string;
  status?: PersonStatus;
  /** "stale": members not active for 30 days or more. */
  activity?: "stale";
};

export function parseStatusFilter(raw: string | undefined): PersonStatus | undefined {
  return PERSON_STATUSES.find((s) => s === raw);
}

/** Has no department, or only an archived one. */
export function lacksDepartment(p: Pick<ListPerson, "departmentId" | "departmentArchived">) {
  return !p.departmentId || p.departmentArchived;
}

export function filterPeople<T extends ListPerson>(
  rows: readonly T[],
  f: ListFilters,
  now = new Date(),
): T[] {
  const q = f.q?.trim().toLowerCase();
  return rows.filter((r) => {
    if (q && !`${r.name} ${r.email} ${r.jobTitle ?? ""}`.toLowerCase().includes(q)) return false;
    if (f.dept === "none" ? !lacksDepartment(r) : f.dept && r.departmentId !== f.dept) {
      return false;
    }
    if (f.role === "manager") {
      if (r.role === "admin" || !r.managerScope) return false;
    } else if (f.role && r.role !== f.role) {
      return false;
    }
    // "Active" is everyone with access now, those with an end date ahead included.
    if (f.status === "active" ? r.status !== "active" : f.status && personStatus(r) !== f.status) {
      return false;
    }
    if (f.activity === "stale" && !isStale(r, now)) return false;
    return true;
  });
}
