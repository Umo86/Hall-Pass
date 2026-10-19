/**
 * Users → Events, statically: every staff-facing caller of a record loader
 * passes who is asking, every list of events passes a scope, and an event
 * found by its code is checked against the session — so a new caller can't
 * forget and show someone an event they haven't been given. Like
 * phone-layout.test.ts, this reads the source.
 */
import { readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

const ROOT = path.resolve(__dirname, "../..");

function walk(dir: string): string[] {
  const abs = path.join(ROOT, dir);
  return readdirSync(abs).flatMap((name) => {
    const rel = path.join(dir, name);
    return statSync(path.join(ROOT, rel)).isDirectory()
      ? walk(rel)
      : /\.(ts|tsx)$/.test(name)
        ? [rel]
        : [];
  });
}

/** Each call of `fn(` in `src`, with its arguments up to the matching bracket. */
function calls(src: string, fn: string): string[] {
  const out: string[] = [];
  const re = new RegExp(`(?<![\\w.])${fn}\\(`, "g");
  for (const m of src.matchAll(re)) {
    let depth = 1;
    let i = m.index + m[0].length;
    const start = i;
    while (i < src.length && depth > 0) {
      if (src[i] === "(") depth += 1;
      else if (src[i] === ")") depth -= 1;
      i += 1;
    }
    out.push(src.slice(start, i - 1));
  }
  return out;
}

/** Top-level arguments of a call (commas inside brackets don't split). */
function args(inner: string): string[] {
  const out: string[] = [];
  let depth = 0;
  let cur = "";
  for (const ch of inner) {
    if ("([{".includes(ch)) depth += 1;
    if (")]}".includes(ch)) depth -= 1;
    if (ch === "," && depth === 0) {
      out.push(cur.trim());
      cur = "";
    } else cur += ch;
  }
  if (cur.trim()) out.push(cur.trim());
  return out;
}

const isDefinition = (src: string, fn: string, inner: string) =>
  new RegExp(`function ${fn}\\(${inner.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\)`).test(src);

const STAFF_DIRS = ["app/actions", "app/(app)", "app/api", "app/q"];
const staffFiles = STAFF_DIRS.flatMap(walk);
const allFiles = ["app", "lib", "components"].flatMap(walk);

describe("event scope guard", () => {
  it("found some files to check", () => {
    expect(staffFiles.length).toBeGreaterThan(50);
  });

  it("loadItemBundle / loadStandBundle under staff routes pass the actor", () => {
    const missing: string[] = [];
    for (const file of staffFiles) {
      const src = readFileSync(path.join(ROOT, file), "utf8");
      for (const fn of ["loadItemBundle", "loadStandBundle"]) {
        for (const inner of calls(src, fn)) {
          if (isDefinition(src, fn, inner)) continue;
          const a = args(inner);
          const third = a[2] ?? "";
          if (!/actorScope\(|session\.actor|\bactor\b/.test(third)) {
            missing.push(`${file}: ${fn}(${inner})`);
          }
        }
      }
    }
    expect(missing).toEqual([]);
  });

  it("ownEdition under staff routes is given the actor", () => {
    const missing: string[] = [];
    for (const file of staffFiles) {
      const src = readFileSync(path.join(ROOT, file), "utf8");
      for (const inner of calls(src, "ownEdition")) {
        if (isDefinition(src, "ownEdition", inner)) continue;
        // halls.ts's local helper takes the session itself.
        if (!/actorScope\(|session\.actor|\bactor\b|^session\b|^g\.session\b/.test(inner)) {
          missing.push(`${file}: ownEdition(${inner})`);
        }
      }
    }
    expect(missing).toEqual([]);
  });

  it("ownSponsor is given the actor and exportEdition the session", () => {
    const missing: string[] = [];
    for (const file of staffFiles) {
      const src = readFileSync(path.join(ROOT, file), "utf8");
      for (const inner of calls(src, "ownSponsor")) {
        if (isDefinition(src, "ownSponsor", inner)) continue;
        if (!/\bactor\b/.test(args(inner)[2] ?? "")) missing.push(`${file}: ownSponsor(${inner})`);
      }
      for (const inner of calls(src, "exportEdition")) {
        if (!/^session\b/.test(args(inner)[0] ?? "")) {
          missing.push(`${file}: exportEdition(${inner})`);
        }
      }
    }
    expect(missing).toEqual([]);
  });

  it("ownPackage is given the actor", () => {
    const missing: string[] = [];
    let seen = 0;
    for (const file of staffFiles) {
      const src = readFileSync(path.join(ROOT, file), "utf8");
      for (const inner of calls(src, "ownPackage")) {
        if (isDefinition(src, "ownPackage", inner)) continue;
        seen += 1;
        if (!/\bactor\b/.test(args(inner)[3] ?? "")) missing.push(`${file}: ownPackage(${inner})`);
      }
    }
    expect(seen).toBeGreaterThan(0);
    expect(missing).toEqual([]);
  });

  it("every listEditions passes a scope", () => {
    const missing: string[] = [];
    for (const file of allFiles) {
      const src = readFileSync(path.join(ROOT, file), "utf8");
      for (const inner of calls(src, "listEditions")) {
        if (isDefinition(src, "listEditions", inner)) continue;
        if (args(inner).length < 2) missing.push(`${file}: listEditions(${inner})`);
      }
    }
    expect(missing).toEqual([]);
  });

  it("every list that can name other events is given the viewer's scope", () => {
    // Function → how many arguments a call needs (the scope is the last).
    const scoped: Record<string, number> = {
      hallCopySources: 3,
      externalEvents: 4,
      listGrants: 3,
      externalScopes: 3,
      countItemsInSignoff: 2,
      countEvents: 2,
      countActiveEvents: 2,
      portalGrantsByScope: 3,
    };
    const missing: string[] = [];
    let seen = 0;
    for (const file of allFiles) {
      const src = readFileSync(path.join(ROOT, file), "utf8");
      for (const [fn, n] of Object.entries(scoped)) {
        for (const inner of calls(src, fn)) {
          if (isDefinition(src, fn, inner)) continue;
          seen += 1;
          const a = args(inner);
          if (a.length < n || !/scope|Scope/.test(a[n - 1] ?? "")) {
            missing.push(`${file}: ${fn}(${inner})`);
          }
        }
      }
    }
    expect(seen).toBeGreaterThan(8);
    expect(missing).toEqual([]);
  });

  it("every getEditionByCode takes the session", () => {
    const missing: string[] = [];
    for (const file of allFiles) {
      const src = readFileSync(path.join(ROOT, file), "utf8");
      for (const inner of calls(src, "getEditionByCode")) {
        if (isDefinition(src, "getEditionByCode", inner)) continue;
        const a = args(inner);
        if (a.length < 2 || !/session/.test(a[1]))
          missing.push(`${file}: getEditionByCode(${inner})`);
      }
    }
    expect(missing).toEqual([]);
  });
});
