/**
 * Account access (Users v2): a team member is active, suspended (paused by a
 * super admin or their manager; everything they had comes back when
 * reactivated) or ended (their access end date has passed). Only active
 * people sign in, are told about anything or can be handed sign-offs. Pure —
 * unit tested in tests/unit/access-state.test.ts; the matching SQL condition
 * is activeMembership() in lib/users/active.ts.
 */
import { signoffPaused, type PermissionOverrides, type StaffRole } from "./authz";
import { appTimezone } from "./config";

export type AccessState = "active" | "suspended" | "ended";

export type AccessFields = {
  suspendedAt?: Date | null;
  accessEndsAt?: Date | null;
};

/** Suspension is named first; an end date at or before now has ended. */
export function accessState(m: AccessFields, now = new Date()): AccessState {
  if (m.suspendedAt) return "suspended";
  if (m.accessEndsAt && m.accessEndsAt.getTime() <= now.getTime()) return "ended";
  return "active";
}

export function accessLive(m: AccessFields, now = new Date()): boolean {
  return accessState(m, now) === "active";
}

/**
 * Can this team member be handed a sign-off (delegation, hand-over, being an
 * approver)? Active, not a viewer, and their sign-off not paused.
 */
export function canReceiveSignoff(
  p: AccessFields & { role: StaffRole; overrides?: PermissionOverrides | null },
  now = new Date(),
): boolean {
  return accessLive(p, now) && p.role !== "viewer" && !signoffPaused(p.overrides);
}

/** Why a person who signed in is turned away, and who they should ask. */
export type AccessBlock = { state: Exclude<AccessState, "active">; askName: string | null };

/** "Your access is paused — ask Sam Smith". */
export function accessBlockMessage(block: AccessBlock): string {
  const who = block.askName?.trim() || "a super admin";
  return block.state === "suspended"
    ? `Your access is paused — ask ${who}`
    : `Your access has ended — ask ${who}`;
}

/** The UTC time of a wall-clock reading in the app's timezone (London). */
function wallClockMs(at: number): number {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-GB", {
      timeZone: appTimezone,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    })
      .formatToParts(new Date(at))
      .map((p) => [p.type, p.value]),
  );
  return Date.UTC(
    Number(parts.year),
    Number(parts.month) - 1,
    Number(parts.day),
    Number(parts.hour),
    Number(parts.minute),
    Number(parts.second),
  );
}

/** The instant London's clocks read midnight at the start of this date. */
function londonMidnight(y: number, m: number, d: number): number {
  const target = Date.UTC(y, m - 1, d);
  let t = target;
  for (let i = 0; i < 3; i++) t += target - wallClockMs(t);
  return t;
}

/**
 * Access end dates are entered as a London date and mean the end of that
 * day there (23:59:59.999 London time), so the person keeps access all day.
 */
export function accessEndsAtFromLondonDate(date: string): Date {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  if (!match) throw new Error(`Not a date: ${date}`);
  const [y, m, d] = [Number(match[1]), Number(match[2]), Number(match[3])];
  const check = new Date(Date.UTC(y, m - 1, d));
  if (check.getUTCFullYear() !== y || check.getUTCMonth() !== m - 1 || check.getUTCDate() !== d) {
    throw new Error(`Not a date: ${date}`);
  }
  const next = new Date(Date.UTC(y, m - 1, d + 1));
  return new Date(
    londonMidnight(next.getUTCFullYear(), next.getUTCMonth() + 1, next.getUTCDate()) - 1,
  );
}

/** The London date (YYYY-MM-DD) an access end time falls on, for forms and lists. */
export function londonDateOfAccessEnd(at: Date): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: appTimezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(at);
}

/** Days between two London dates (YYYY-MM-DD). */
function daysBetween(a: string, b: string): number {
  return Math.round((Date.parse(`${b}T12:00:00Z`) - Date.parse(`${a}T12:00:00Z`)) / 86_400_000);
}

export type AccessEndRow = {
  id: string;
  accessEndsAt: Date | null;
  suspendedAt: Date | null;
  /** When "Access ended" was last recorded for this membership, if ever. */
  endedRecordedAt: Date | null;
};

/**
 * What the daily job does about access end dates (pure; `today` is the
 * London date): record "Access ended" once for each end that has passed
 * (again only if the date was later moved and passed again), and warn a
 * week before an end date for people who still have access.
 */
export function accessEndPlan(
  rows: readonly AccessEndRow[],
  opts: { now: Date; today: string },
): { ended: string[]; warn: string[] } {
  const ended: string[] = [];
  const warn: string[] = [];
  for (const r of rows) {
    if (!r.accessEndsAt) continue;
    if (r.accessEndsAt.getTime() <= opts.now.getTime()) {
      const recorded = r.endedRecordedAt && r.endedRecordedAt.getTime() >= r.accessEndsAt.getTime();
      if (!recorded) ended.push(r.id);
    } else if (
      !r.suspendedAt &&
      daysBetween(opts.today, londonDateOfAccessEnd(r.accessEndsAt)) === 7
    ) {
      warn.push(r.id);
    }
  }
  return { ended, warn };
}
