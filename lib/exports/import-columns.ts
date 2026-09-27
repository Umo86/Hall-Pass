/** The import sheet's columns, in the order the template lays them out. */
export const IMPORT_COLUMNS = [
  "Ref",
  "Name",
  "Type",
  "Hall",
  "Location",
  "Stand no.",
  "Width mm",
  "Height mm",
  "Quantity",
  "Sided",
  "Material",
  "Finish",
  "Fixing",
  "Sponsor",
  "Supplier",
  "Requires venue approval",
  "Cost estimate",
  "Install date",
  "Install slot",
  "Description",
  "Category",
] as const;

export type ImportColumn = (typeof IMPORT_COLUMNS)[number];

/** Where each column sat before "Stand no." was added, for older sheets. */
const OLD_ORDER = IMPORT_COLUMNS.filter((c) => c !== "Stand no.");

const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, "");
/** Other ways people head the same column. */
const ALIASES: Record<string, string> = { standnumber: "standno", stand: "standno" };

/**
 * Find each column by its heading (any case or punctuation), so sheets with
 * or without "Stand no." both import. A heading that can't be found falls
 * back to where it was in the original template; "Stand no." has no old
 * place, so it's simply left out.
 */
export function importColumnFinder(headings: string[]): (name: ImportColumn) => number | null {
  const found = new Map<string, number>();
  headings.forEach((h, i) => {
    const key = ALIASES[norm(h)] ?? norm(h);
    if (key && !found.has(key)) found.set(key, i + 1);
  });
  return (name) => {
    const at = found.get(norm(name));
    if (at) return at;
    const old = OLD_ORDER.indexOf(name as (typeof OLD_ORDER)[number]);
    return old === -1 ? null : old + 1;
  };
}
