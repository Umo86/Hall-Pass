/**
 * The order-by countdown on sponsorship cards: "2 months 5 days left",
 * with a warning once there's under a month to sell. Pure; ISO dates.
 */
import { diffDaysIso } from "@/lib/deadlines";

export type CountdownTone = "ok" | "soon" | "urgent" | "overdue";

export type Countdown = {
  /** Whole months and days left (0 when past). */
  months: number;
  days: number;
  /** Days left in total (negative when past). */
  totalDays: number;
  /** "2 months 5 days left", "Order today", "4 days overdue". */
  label: string;
  tone: CountdownTone;
  /** Shown on unsold items near or past the date. */
  warning: string | null;
};

/** One calendar month after an ISO date (31 Jan → 28/29 Feb). */
function addMonthsIso(iso: string, months: number): string {
  const [y, m, d] = iso.split("-").map(Number);
  const target = new Date(Date.UTC(y, m - 1 + months, 1));
  const lastDay = new Date(
    Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0),
  ).getUTCDate();
  target.setUTCDate(Math.min(d, lastDay));
  return target.toISOString().slice(0, 10);
}

const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? "" : "s"}`;

export function orderCountdown(orderBy: string, today: string, sold: boolean): Countdown {
  const totalDays = diffDaysIso(orderBy, today);
  if (totalDays < 0) {
    return {
      months: 0,
      days: 0,
      totalDays,
      label: `${plural(-totalDays, "day")} overdue`,
      tone: "overdue",
      warning: sold ? null : "Order date has passed",
    };
  }
  let months = 0;
  while (addMonthsIso(today, months + 1) <= orderBy) months++;
  const days = diffDaysIso(orderBy, addMonthsIso(today, months));
  const label =
    totalDays === 0
      ? "Order today"
      : [months > 0 ? plural(months, "month") : null, days > 0 ? plural(days, "day") : null]
          .filter(Boolean)
          .join(" ") + " left";
  const underAMonth = months === 0;
  return {
    months,
    days,
    totalDays,
    label,
    tone: underAMonth ? (sold ? "soon" : "urgent") : "ok",
    warning: underAMonth && !sold ? "Less than 1 month to sell" : null,
  };
}
