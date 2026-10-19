/**
 * database-setup.sql promises to be re-runnable: its preamble drops every
 * table, type and function the dump below it creates. Reads the file (as
 * the other static guards do), so a type added by a migration and dumped
 * without a matching DROP fails here rather than on someone's second run.
 */
import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

const sql = readFileSync(path.resolve(__dirname, "../../database-setup.sql"), "utf8");
const preambleEnd = sql.indexOf("-- PostgreSQL database dump");
const preamble = sql.slice(0, preambleEnd);
const dump = sql.slice(preambleEnd);

const names = (re: RegExp, text: string) => [...text.matchAll(re)].map((m) => m[1]).sort();

describe("database-setup.sql preamble", () => {
  it("found the preamble and the dump", () => {
    expect(preambleEnd).toBeGreaterThan(0);
    expect(dump).toContain("CREATE TABLE public.");
  });

  it("drops every type the dump creates", () => {
    const created = names(/^CREATE TYPE public\.(\w+)/gm, dump);
    const dropped = new Set(names(/^DROP TYPE IF EXISTS public\.(\w+) CASCADE;/gm, preamble));
    expect(created.length).toBeGreaterThan(30);
    expect(created.filter((t) => !dropped.has(t))).toEqual([]);
  });

  it("drops every table the dump creates", () => {
    const created = names(/^CREATE TABLE public\.(\w+)/gm, dump);
    const list = /^DROP TABLE IF EXISTS (.+) CASCADE;$/m.exec(preamble)?.[1] ?? "";
    const dropped = new Set(list.split(",").map((t) => t.trim().replace(/^public\./, "")));
    expect(created.filter((t) => !dropped.has(t))).toEqual([]);
  });

  it("drops every function the dump creates", () => {
    const created = names(/^CREATE FUNCTION public\.(\w+)/gm, dump);
    const dropped = new Set(names(/^DROP FUNCTION IF EXISTS public\.(\w+)\(/gm, preamble));
    expect(created.filter((f) => !dropped.has(f))).toEqual([]);
  });
});
