/**
 * A worksheet name Excel will accept: no \ / : ? * [ ], at most 31
 * characters, not "History" (reserved), and unique ignoring case. `used`
 * holds the lower-cased names already taken and is updated.
 */
export function safeSheetName(raw: string, used: Set<string>): string {
  let base = raw.replace(/[\\/:?*[\]]/g, "-").replace(/^'+|'+$/g, "").trim();
  if (!base || base.toLowerCase() === "history") base = base ? `${base} (1)` : "Sheet";
  base = base.slice(0, 31);
  let name = base;
  for (let n = 2; used.has(name.toLowerCase()); n++) {
    const suffix = ` (${n})`;
    name = `${base.slice(0, 31 - suffix.length)}${suffix}`;
  }
  used.add(name.toLowerCase());
  return name;
}
