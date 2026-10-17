/**
 * Wording guard: people see an "Event" (the dated occurrence, `editions` in
 * the database) and an "Event series" (`events`), never a "show" or an
 * "edition". This reads every string literal, template literal and piece of
 * JSX text in app/, components/ and lib/ (not the seed) and fails on
 * Show/show/Shows/shows/Edition/edition/Editions/editions used as a noun.
 *
 * What is not checked: comments and identifiers (they aren't strings),
 * import paths, `sql` queries, and code-like strings without spaces such as
 * "editionId", "show" (a query key) or "/signage?show=needs_artwork".
 * "Show" as a verb ("Show more", "Show them", "show all", "shows as") is
 * allowed through VERB_USES below.
 */
import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import ts from "typescript";
import { describe, expect, it } from "vitest";

const ROOT = path.resolve(__dirname, "../..");
const DIRS = ["app", "components", "lib"];
const SKIP_DIRS = new Set([path.join(ROOT, "lib/db/seed")]);

const WORD = /\b(Show|Shows|show|shows|Edition|Editions|edition|editions)\b/g;

/**
 * "show" followed by one of these is the verb. `{}` stands for an
 * interpolated value ("Show {n} more", "Show v{n} only").
 */
const VERB_USES =
  /^shows? (more|fewer|less|all|every|everyone|everyone's|everyone&apos;s|everything|them|their|the|menu|password|columns|as|on|only|items|stands|tasks|deleted|what|wherever|v?\{\})(?!\w)/i;

/**
 * Leftovers in files someone else is changing at the moment. Each entry is
 * "file: text" and must still occur — remove it once the wording is fixed.
 */
const KNOWN_LEFTOVERS = new Set<string>([]);

type Hit = { file: string; line: number; text: string };

function sourceFiles(dir: string, out: string[] = []): string[] {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (!SKIP_DIRS.has(full) && entry.name !== "node_modules") sourceFiles(full, out);
    } else if (/\.tsx?$/.test(entry.name) && !entry.name.endsWith(".d.ts")) {
      out.push(full);
    }
  }
  return out;
}

/** Strings without a space that don't start with a capital are code, not copy. */
function looksLikeCode(text: string): boolean {
  return !/\s/.test(text) && !/^[A-Z]/.test(text);
}

/** The noun uses of show/edition in one piece of text. */
function nounUses(text: string): string[] {
  const t = text.replace(/\s+/g, " ").trim();
  if (!t || looksLikeCode(t)) return [];
  // A lone "Show" labels a choice ("Show: All | Mine").
  if (t === "Show") return [];
  const found: string[] = [];
  for (const m of t.matchAll(WORD)) {
    const word = m[0].toLowerCase();
    if ((word === "show" || word === "shows") && VERB_USES.test(t.slice(m.index))) continue;
    found.push(m[0]);
  }
  return found;
}

function isSqlTag(node: ts.TaggedTemplateExpression): boolean {
  const tag = node.tag.getText();
  return tag === "sql" || tag.startsWith("sql.");
}

/** Template literal text with each `${…}` as "{}". */
function templateText(node: ts.TemplateExpression): string {
  return node.head.text + node.templateSpans.map((s) => `{}${s.literal.text}`).join("");
}

/** JSX children as one sentence, each `{…}` or child element as "{}". */
function jsxText(children: ts.NodeArray<ts.JsxChild>): string {
  return children.map((c) => (ts.isJsxText(c) ? c.text : " {} ")).join("");
}

function scan(file: string): Hit[] {
  const source = readFileSync(file, "utf8");
  const sf = ts.createSourceFile(
    file,
    source,
    ts.ScriptTarget.Latest,
    true,
    file.endsWith(".tsx") ? ts.ScriptKind.TSX : ts.ScriptKind.TS,
  );
  const rel = path.relative(ROOT, file);
  const hits: Hit[] = [];
  const check = (node: ts.Node, text: string) => {
    if (nounUses(text).length === 0) return;
    const line = sf.getLineAndCharacterOfPosition(node.getStart(sf)).line + 1;
    hits.push({ file: rel, line, text: text.replace(/\s+/g, " ").trim() });
  };
  const visit = (node: ts.Node): void => {
    if (ts.isImportDeclaration(node) || ts.isExportDeclaration(node)) return;
    if (ts.isTaggedTemplateExpression(node) && isSqlTag(node)) return;
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) {
      check(node, node.text);
      return;
    }
    if (ts.isTemplateExpression(node)) {
      check(node, templateText(node));
      // The interpolated expressions can hold strings of their own.
      for (const span of node.templateSpans) visit(span.expression);
      return;
    }
    if (ts.isJsxElement(node) || ts.isJsxFragment(node)) {
      check(node, jsxText(node.children));
      if (ts.isJsxElement(node)) visit(node.openingElement);
      for (const child of node.children) if (!ts.isJsxText(child)) visit(child);
      return;
    }
    ts.forEachChild(node, visit);
  };
  visit(sf);
  return hits;
}

/**
 * The admin role is shown as "Super admin" (DECISIONS, "Words"), and who
 * may do something comes from the abilities registry (missingAbilityMessage),
 * so copy never says "admins" or "an admin" on its own.
 */
const ADMIN_WORD = /(?<!super[ -])\badmins?\b/gi;

/** "file: text" for copy that must keep the word (none at the moment). */
const ADMIN_ALLOWED = new Set<string>([]);

function adminUses(text: string): string[] {
  const t = text.replace(/\s+/g, " ").trim();
  if (!t || looksLikeCode(t)) return [];
  return [...t.matchAll(ADMIN_WORD)].map((m) => m[0]);
}

function scanAdmin(file: string): Hit[] {
  const source = readFileSync(file, "utf8");
  const sf = ts.createSourceFile(
    file,
    source,
    ts.ScriptTarget.Latest,
    true,
    file.endsWith(".tsx") ? ts.ScriptKind.TSX : ts.ScriptKind.TS,
  );
  const rel = path.relative(ROOT, file);
  const hits: Hit[] = [];
  const check = (node: ts.Node, text: string) => {
    if (adminUses(text).length === 0) return;
    const line = sf.getLineAndCharacterOfPosition(node.getStart(sf)).line + 1;
    hits.push({ file: rel, line, text: text.replace(/\s+/g, " ").trim() });
  };
  const visit = (node: ts.Node): void => {
    if (ts.isImportDeclaration(node) || ts.isExportDeclaration(node)) return;
    if (ts.isTaggedTemplateExpression(node) && isSqlTag(node)) return;
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) {
      check(node, node.text);
      return;
    }
    if (ts.isTemplateExpression(node)) {
      check(node, templateText(node));
      for (const span of node.templateSpans) visit(span.expression);
      return;
    }
    if (ts.isJsxElement(node) || ts.isJsxFragment(node)) {
      check(node, jsxText(node.children));
      if (ts.isJsxElement(node)) visit(node.openingElement);
      for (const child of node.children) if (!ts.isJsxText(child)) visit(child);
      return;
    }
    ts.forEachChild(node, visit);
  };
  visit(sf);
  return hits;
}

describe("terminology", () => {
  it("says super admin, never admins on their own", () => {
    expect(adminUses("Only admins and Operations create events")).toEqual(["admins"]);
    expect(adminUses("Ask an admin")).toEqual(["admin"]);
    expect(adminUses("Ask a super admin")).toEqual([]);
    expect(adminUses("Super admins see everything")).toEqual([]);
    expect(adminUses("admin")).toEqual([]); // a role key, not copy
    const hits = DIRS.flatMap((d) => sourceFiles(path.join(ROOT, d))).flatMap(scanAdmin);
    const key = (h: Hit) => `${h.file}: ${h.text}`;
    expect(
      hits.filter((h) => !ADMIN_ALLOWED.has(key(h))).map((h) => `${h.file}:${h.line}: ${h.text}`),
    ).toEqual([]);
  });

  it("tells a verb from a noun", () => {
    expect(nounUses("Show more")).toEqual([]);
    expect(nounUses("Show {} more ({} not shown)")).toEqual([]);
    expect(nounUses("Show them")).toEqual([]);
    expect(nounUses("Sign-off requests show as Done once they are no longer waiting")).toEqual([]);
    expect(nounUses("editionId")).toEqual([]);
    expect(nounUses("/signage?show=needs_artwork")).toEqual([]);
    expect(nounUses("Show name")).toEqual(["Show"]);
    expect(nounUses("Check the show in the top bar")).toEqual(["show"]);
    expect(nounUses("Edition")).toEqual(["Edition"]);
    expect(nounUses("Copy this edition's halls")).toEqual(["edition"]);
  });

  it("calls it an event, never a show or an edition", () => {
    const hits = DIRS.flatMap((d) => sourceFiles(path.join(ROOT, d))).flatMap(scan);
    const key = (h: Hit) => `${h.file}: ${h.text}`;
    const leftovers = hits.filter((h) => !KNOWN_LEFTOVERS.has(key(h)));
    expect(leftovers.map((h) => `${h.file}:${h.line}: ${h.text}`)).toEqual([]);
    // Known leftovers that have been fixed come off the list.
    const stillThere = new Set(hits.map(key));
    expect([...KNOWN_LEFTOVERS].filter((k) => !stillThere.has(k))).toEqual([]);
  });
});
