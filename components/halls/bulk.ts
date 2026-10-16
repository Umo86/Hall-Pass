/**
 * "Add several at once" for halls: one hall per line, optionally followed by
 * a colon and its locations, comma separated.
 *
 *   Hall 1: Main entrance, Registration
 *   Hall 2
 *
 * Pure, so the page can preview it and the server action can trust it.
 */
export type BulkHall = { name: string; locations: string[] };

export const BULK_MAX_HALLS = 50;
export const BULK_MAX_LOCATIONS = 200;
const MAX_NAME = 120;

export function parseBulkHalls(text: string): BulkHall[] {
  const out: BulkHall[] = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    const colon = line.indexOf(":");
    const name = (colon === -1 ? line : line.slice(0, colon)).trim().slice(0, MAX_NAME);
    if (!name) continue;
    const locs =
      colon === -1
        ? []
        : line
            .slice(colon + 1)
            .split(",")
            .map((l) => l.trim().slice(0, MAX_NAME))
            .filter(Boolean);
    // The same hall twice merges; the same location twice in a hall counts once.
    const existing = out.find((h) => h.name.toLowerCase() === name.toLowerCase());
    const target = existing ?? { name, locations: [] };
    for (const l of locs) {
      if (!target.locations.some((x) => x.toLowerCase() === l.toLowerCase())) {
        target.locations.push(l);
      }
    }
    if (!existing) out.push(target);
  }
  return out;
}

/** "2 halls and 5 locations" for a preview line. */
export function describeBulk(halls: BulkHall[]): string {
  const locs = halls.reduce((n, h) => n + h.locations.length, 0);
  const h = `${halls.length} hall${halls.length === 1 ? "" : "s"}`;
  return locs > 0 ? `${h} and ${locs} location${locs === 1 ? "" : "s"}` : h;
}
