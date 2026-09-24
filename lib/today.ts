import { appTimezone } from "@/lib/config";

/** Today's date (YYYY-MM-DD) in the app's timezone, whatever the server's is. */
export function todayInLondon(now = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: appTimezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}
