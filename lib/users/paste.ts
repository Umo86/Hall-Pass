/**
 * "Add several people": turn what someone pastes (from a spreadsheet or an
 * email) into people to invite. Pure — unit tested in
 * tests/unit/users-paste.test.ts, and the same function runs in the
 * browser (to count rows as they type) and on the server (to check them).
 *
 * One person per line, columns separated by tabs (a spreadsheet) or commas,
 * in the order Name, Email, Job title. A first line that names the columns
 * ("Email, Name, Title") is read as a header and sets the order. Without
 * one, the column with an @ is the email, whatever its place (a line with
 * no @ is read in the usual order, so the check can say what is wrong with
 * it). Emails are
 * compared in lower case; a repeat of an earlier line is kept but marked.
 */

export type PastedPerson = {
  /** The line it came from (1 = the first line pasted). */
  line: number;
  name: string;
  /** Lower case, trimmed; "" when the line has no email at all. */
  email: string;
  jobTitle: string | null;
  /** The name was made from the email because the line had none. */
  nameFromEmail: boolean;
  /** The line this one repeats (same email), if any. */
  duplicateOf: number | null;
};

export type PasteResult = { people: PastedPerson[]; hadHeader: boolean };

/** Most people we can invite in one go. */
export const MAX_PASTED_PEOPLE = 50;

const EMAIL = /^[^\s@<>(),;:"]+@[^\s@<>(),;:"]+\.[^\s@<>(),;:".]{2,}$/;

/** A plausible email address (the server checks again with zod). */
export function looksLikeEmail(value: string): boolean {
  return EMAIL.test(value.trim());
}

type Column = "name" | "email" | "jobTitle";

const HEADER_WORDS: Record<string, Column> = {
  name: "name",
  "full name": "name",
  "first and last name": "name",
  person: "name",
  email: "email",
  "e-mail": "email",
  "email address": "email",
  "e-mail address": "email",
  "job title": "jobTitle",
  title: "jobTitle",
  role: "jobTitle",
  position: "jobTitle",
};

/** Split one line on tabs, else commas (double quotes keep commas in a field). */
function splitLine(line: string): string[] {
  if (line.includes("\t")) return line.split("\t").map(clean);
  const out: string[] = [];
  let field = "";
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (quoted && line[i + 1] === '"') {
        field += '"';
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (ch === "," && !quoted) {
      out.push(field);
      field = "";
    } else {
      field += ch;
    }
  }
  out.push(field);
  return out.map(clean);
}

function clean(value: string): string {
  return value
    .replace(/^\s*"|"\s*$/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

/** "Sam Smith <sam@x.com>" → the email inside the brackets. */
function bracketed(value: string): { name: string; email: string } | null {
  const m = /^(.*)<([^<>]+@[^<>]+)>\s*$/.exec(value);
  return m ? { name: clean(m[1]), email: m[2].trim() } : null;
}

/** The columns a header line names, or null when it isn't a header. */
function headerColumns(fields: string[]): (Column | null)[] | null {
  if (fields.some((f) => f.includes("@"))) return null;
  // Unknown headings are columns to ignore; the email one must be named.
  const cols = fields.map((f) => HEADER_WORDS[f.toLowerCase()] ?? null);
  return cols.includes("email") ? cols : null;
}

/** "sam.smith" → "Sam Smith", for a line with only an email. */
export function nameFromEmail(email: string): string {
  const local = email.split("@")[0] ?? "";
  return local
    .split(/[._-]+/)
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(" ");
}

export function parsePeople(text: string): PasteResult {
  const lines = text.split(/\r?\n/);
  const people: PastedPerson[] = [];
  const firstLine = new Map<string, number>();
  let columns: (Column | null)[] | null = null;
  let hadHeader = false;
  let seenContent = false;

  for (const [i, raw] of lines.entries()) {
    const lineNo = i + 1;
    if (!raw.trim()) continue;
    let fields = splitLine(raw);
    if (!seenContent) {
      seenContent = true;
      const header = headerColumns(fields);
      if (header) {
        columns = header;
        hadHeader = true;
        continue;
      }
    }
    // "Name <email>" in one field, as copied from an email's To line.
    if (fields.length === 1) {
      const b = bracketed(fields[0]);
      if (b) fields = [b.name, b.email];
    }

    let name = "";
    let email = "";
    let jobTitle = "";
    if (columns) {
      const cols = columns;
      fields.forEach((f, idx) => {
        const col = cols[idx];
        if (col === "name" && !name) name = f;
        else if (col === "email" && !email) email = f;
        else if (col === "jobTitle" && !jobTitle) jobTitle = f;
      });
    } else {
      const at = fields.findIndex((f) => f.includes("@"));
      if (at >= 0) {
        const rest = fields.filter((_, idx) => idx !== at && fields[idx] !== "");
        email = fields[at];
        name = rest[0] ?? "";
        jobTitle = rest[1] ?? "";
      } else {
        // No @ anywhere: read it in the usual order, so the check shows what was typed.
        [name = "", email = "", jobTitle = ""] = fields;
      }
    }
    const b = bracketed(email);
    if (b) {
      email = b.email;
      if (!name) name = b.name;
    }
    email = email
      .replace(/^mailto:/i, "")
      .trim()
      .toLowerCase();
    const madeName = !name && looksLikeEmail(email);
    if (madeName) name = nameFromEmail(email);
    const earlier = email ? firstLine.get(email) : undefined;
    if (email && earlier === undefined) firstLine.set(email, lineNo);
    people.push({
      line: lineNo,
      name: name.slice(0, 200),
      email,
      jobTitle: jobTitle ? jobTitle.slice(0, 200) : null,
      nameFromEmail: madeName,
      duplicateOf: earlier ?? null,
    });
  }
  return { people, hadHeader };
}
