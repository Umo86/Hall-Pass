import "server-only";
import { appUrl } from "@/lib/app-url";
import { icalToken } from "@/lib/ical";

/** This person's private calendar feed, or null when the site URL isn't set. */
export function calendarFeedUrl(userId: string): string | null {
  try {
    const base = appUrl();
    return base ? `${base}/api/ical/${icalToken(userId)}` : null;
  } catch {
    return null;
  }
}
