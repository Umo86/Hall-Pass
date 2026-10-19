/**
 * Phone widths (360–390 px): a grid track sized by its content lets one
 * long line or button row widen the whole page. These containers must keep
 * minmax(0, 1fr) tracks / min-width 0 and let button rows wrap
 * (regressions-3: Users → Departments; regressions-4: an item's Artwork &
 * sign-off tab, where super admins see three buttons per step). Checked in
 * the browser at 390 px when they were fixed; this keeps the classes from
 * being lost.
 */
import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

const ROOT = path.resolve(__dirname, "../..");
const read = (file: string) => readFileSync(path.join(ROOT, file), "utf8");

/** The className of the first element whose className contains every one of `marks`. */
function classesWith(source: string, marks: string[]): string[] {
  for (const m of source.matchAll(/className="([^"]+)"/g)) {
    const classes = m[1].split(/\s+/);
    if (marks.every((k) => classes.includes(k))) return classes;
  }
  return [];
}

describe("phone layout", () => {
  it("Users → Departments: one shrinkable column below lg, cards that can shrink", () => {
    const src = read("components/users/departments-panel.tsx");
    expect(classesWith(src, ["grid", "lg:grid-cols-2"])).toContain("grid-cols-1");
    expect(classesWith(src, ["flex", "flex-col", "rounded-lg", "border"])).toContain("min-w-0");
  });

  it("the sign-off chain's buttons wrap, and the artwork tab can't be widened by them", () => {
    expect(
      classesWith(read("components/approvals/chain.tsx"), ["sm:ml-auto", "sm:w-auto"]),
    ).toContain("flex-wrap");
    const page = read("app/(app)/[editionCode]/signage/[ref]/page.tsx");
    const tab = classesWith(page, ["grid", "gap-8"]);
    expect(tab).toContain("min-w-0");
    expect(tab).toContain("grid-cols-1");
  });

  it("Users → Events: the Events card can shrink and long event names wrap", () => {
    for (const [file, id] of [
      ["components/users/person-editor.tsx", "p-events-h"],
      ["components/users/add-user-form.tsx", "add-events-h"],
    ] as const) {
      const m = read(file).match(new RegExp(`className="([^"]+)"\\s*aria-labelledby="${id}"`));
      expect(m?.[1].split(/\s+/), file).toContain("min-w-0");
    }
    const fields = read("components/users/person-fields.tsx");
    expect(classesWith(fields, ["flex", "min-h-11", "items-start"])).toContain("min-w-0");
    expect(classesWith(fields, ["min-w-0", "break-words"]).length).toBeGreaterThan(0);
  });

  it("the events chip sits in a wrapping row wherever it's shown", () => {
    for (const file of [
      "components/users/team-list.tsx",
      "components/users/departments-panel.tsx",
      "components/approvals/approvers-editor.tsx",
    ]) {
      const src = read(file);
      const chips = [...src.matchAll(/<Events(Tag|Chip)\b/g)];
      expect(chips.length, file).toBeGreaterThan(0);
      for (const chip of chips) {
        const before = src.slice(0, chip.index);
        const wrappers = [...before.matchAll(/<(?:span|div)\s+className="([^"]+)"/g)]
          .map((m) => m[1].split(/\s+/))
          .filter((c) => c.includes("flex"));
        expect(wrappers.at(-1), file).toContain("flex-wrap");
      }
    }
  });
});
