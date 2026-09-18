import { createHmac, timingSafeEqual } from "node:crypto";

/**
 * Tokenised iCal feed support. Tokens are HMAC-signed user ids — no secret
 * lands in the database and revocation is rotating the signing secret.
 * The calendar builder is pure so it is unit-testable.
 */

function signingSecret(): string {
  const s = process.env.ICAL_SECRET ?? process.env.CRON_SECRET;
  if (!s) throw new Error("Set CRON_SECRET (or ICAL_SECRET) to enable calendar feeds");
  return s;
}

export function icalToken(userId: string): string {
  const sig = createHmac("sha256", signingSecret()).update(userId).digest("hex").slice(0, 32);
  return `${userId}.${sig}`;
}

export function verifyIcalToken(token: string): string | null {
  const dot = token.lastIndexOf(".");
  if (dot <= 0) return null;
  const userId = token.slice(0, dot);
  let expected: string;
  try {
    expected = icalToken(userId);
  } catch {
    return null;
  }
  const a = Buffer.from(token);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  return userId;
}

export type CalendarEvent = {
  uid: string;
  title: string;
  /** All-day events: ISO yyyy-MM-dd. */
  date: string;
  description?: string;
  url?: string;
};

function escapeText(value: string): string {
  return value
    .replace(/\\/g, "\\\\")
    .replace(/;/g, "\\;")
    .replace(/,/g, "\\,")
    .replace(/\r?\n/g, "\\n");
}

function foldLine(line: string): string {
  // RFC 5545: content lines over 75 octets are folded with CRLF + space.
  const out: string[] = [];
  let rest = line;
  while (rest.length > 74) {
    out.push(rest.slice(0, 74));
    rest = " " + rest.slice(74);
  }
  out.push(rest);
  return out.join("\r\n");
}

export function buildCalendar(
  name: string,
  events: CalendarEvent[],
  stamp: Date = new Date(),
): string {
  const dtstamp = stamp.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
  const lines: string[] = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Hall Pass//Deadline feed//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    `X-WR-CALNAME:${escapeText(name)}`,
  ];
  for (const ev of events) {
    const day = ev.date.replace(/-/g, "");
    lines.push(
      "BEGIN:VEVENT",
      `UID:${escapeText(ev.uid)}`,
      `DTSTAMP:${dtstamp}`,
      `DTSTART;VALUE=DATE:${day}`,
      `SUMMARY:${escapeText(ev.title)}`,
    );
    if (ev.description) lines.push(`DESCRIPTION:${escapeText(ev.description)}`);
    if (ev.url) lines.push(`URL:${escapeText(ev.url)}`);
    lines.push("END:VEVENT");
  }
  lines.push("END:VCALENDAR");
  return lines.map(foldLine).join("\r\n") + "\r\n";
}
