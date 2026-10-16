/**
 * Pure helpers for naming a new event: its reference code, next year's name
 * and the series it belongs to. Shared by the create form (live preview) and
 * the server action (defaults), so both agree.
 */

/** Reference codes: letters, numbers and dashes, 2–20 long. */
export const CODE_PATTERN = /^[A-Z0-9-]{2,20}$/;

const YEAR = /\b(19|20)\d{2}\b/g;

/**
 * Suggest a short code from an event name: "UKCW London 2027" → "UKCWLON27".
 * Short words are kept whole, longer ones give three letters, and the year
 * gives its last two digits. A code already in `taken` gets "-2", "-3"…
 */
export function suggestCode(name: string, taken: readonly string[] = []): string {
  const words = name.toUpperCase().match(/[A-Z0-9]+/g) ?? [];
  const year = words.find((w) => /^(19|20)\d{2}$/.test(w));
  const letters = words
    .filter((w) => w !== year)
    .map((w) => (w.length <= 4 ? w : w.slice(0, 3)))
    .join("")
    .slice(0, 10);
  const base = `${letters}${year ? year.slice(2) : ""}` || "EVENT";
  const padded = base.length < 2 ? `${base}1` : base;
  const used = new Set(taken.map((c) => c.toUpperCase()));
  if (!used.has(padded)) return padded;
  for (let n = 2; ; n++) {
    const next = `${padded.slice(0, 17)}-${n}`;
    if (!used.has(next)) return next;
  }
}

/** Next year's name: the last year in it moves on by one ("… 2027" → "… 2028"). */
export function bumpYear(name: string): string {
  const matches = [...name.matchAll(YEAR)];
  const last = matches.at(-1);
  if (!last || last.index === undefined) return name;
  const next = String(Number(last[0]) + 1);
  return `${name.slice(0, last.index)}${next}${name.slice(last.index + last[0].length)}`;
}

/**
 * The series an event belongs to when nobody picks one: its name without
 * the year ("UKCW London 2027" → "UKCW London").
 */
export function seriesNameFor(eventName: string): string {
  const stripped = eventName
    .replace(YEAR, " ")
    .replace(/\s+/g, " ")
    .replace(/[\s\-–—·,:]+$/g, "")
    .replace(/^[\s\-–—·,:]+/g, "")
    .trim();
  return stripped || eventName.trim();
}

/** What the first sign of an event with this code is called. */
export function exampleSignRef(code: string): string {
  return `SIG-${code || "CODE"}-001`;
}
