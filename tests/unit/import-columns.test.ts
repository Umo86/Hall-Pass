import { describe, expect, it } from "vitest";
import { IMPORT_COLUMNS, importColumnFinder } from "@/lib/exports/import-columns";

describe("importColumnFinder", () => {
  it("finds every column of the current template by its heading", () => {
    const find = importColumnFinder([...IMPORT_COLUMNS]);
    IMPORT_COLUMNS.forEach((name, i) => expect(find(name)).toBe(i + 1));
  });

  it("still reads sheets made before Stand no. was added", () => {
    const old = IMPORT_COLUMNS.filter((c) => c !== "Stand no.");
    const find = importColumnFinder([...old]);
    expect(find("Location")).toBe(5);
    expect(find("Width mm")).toBe(6);
    expect(find("Category")).toBe(20);
    expect(find("Stand no.")).toBeNull();
  });

  it("ignores case and punctuation, and knows other names for Stand no.", () => {
    const find = importColumnFinder(["REF", "name", "Stand Number", "location "]);
    expect(find("Ref")).toBe(1);
    expect(find("Name")).toBe(2);
    expect(find("Stand no.")).toBe(3);
    expect(find("Location")).toBe(4);
  });

  it("falls back to the original positions when headings are missing", () => {
    const find = importColumnFinder([]);
    expect(find("Ref")).toBe(1);
    expect(find("Supplier")).toBe(14);
    expect(find("Stand no.")).toBeNull();
  });
});
