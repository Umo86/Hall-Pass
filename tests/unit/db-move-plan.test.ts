import { describe, expect, it } from "vitest";
import type { Catalog, ForeignKey, TableInfo } from "@/lib/db/move/catalog";
import { describeDeferred, planCopy } from "@/lib/db/move/plan";
import realCatalog from "./fixtures/move-catalog.json";

/** A synthetic table: `fks` as [name, ref, cols, nullable]. */
function table(key: string, fks: [string, string, string[], boolean][] = []): TableInfo {
  const [schema, name] = key.includes(".") ? key.split(".") : ["public", key];
  return {
    key: `${schema}.${name}`,
    schema,
    name,
    rls: true,
    columns: [],
    pk: ["id"],
    fks: fks.map(([fk, ref, cols, nullable]): ForeignKey => ({
      name: fk,
      ref: ref.includes(".") ? ref : `public.${ref}`,
      cols,
      nullable,
    })),
  };
}
const catalog = (...tables: TableInfo[]): Pick<Catalog, "tables"> => ({ tables });

describe("planCopy", () => {
  it("puts parents before children, ties by name", () => {
    const plan = planCopy(
      catalog(
        table("c", [["c_b", "b", ["b_id"], false]]),
        table("b", [["b_a", "a", ["a_id"], false]]),
        table("a"),
        table("z"),
      ),
    );
    expect(plan.order).toEqual(["public.a", "public.b", "public.c", "public.z"]);
    expect(plan.deferred).toEqual([]);
    expect(plan.cycles).toEqual([]);
  });

  it("defers a nullable self-reference", () => {
    const plan = planCopy(
      catalog(table("comments", [["parent", "comments", ["parent_id"], true]])),
    );
    expect(plan.order).toEqual(["public.comments"]);
    expect(plan.deferred.map(describeDeferred)).toEqual(["public.comments.parent_id"]);
    expect(plan.cycles).toEqual([["public.comments"]]);
  });

  it("breaks a two-table cycle on its nullable side only", () => {
    const plan = planCopy(
      catalog(
        table("items", [["items_current", "versions", ["current_version_id"], true]]),
        table("versions", [["versions_item", "items", ["item_id"], false]]),
      ),
    );
    expect(plan.deferred.map(describeDeferred)).toEqual(["public.items.current_version_id"]);
    expect(plan.order).toEqual(["public.items", "public.versions"]);
  });

  it("throws on a cycle with no nullable key", () => {
    expect(() =>
      planCopy(
        catalog(
          table("a", [["a_b", "b", ["b_id"], false]]),
          table("b", [["b_a", "a", ["a_id"], false]]),
        ),
      ),
    ).toThrow(/cycle with no nullable column to break it: public.a, public.b/);
  });

  it("throws on a NOT NULL self-reference", () => {
    expect(() => planCopy(catalog(table("t", [["t_t", "t", ["t_id"], false]])))).toThrow(
      /Self-reference t_t on public.t is NOT NULL/,
    );
  });

  it("orders a composite key after the table it references", () => {
    const plan = planCopy(
      catalog(
        table("sponsors", [
          [
            "sponsors_package_same_event_fk",
            "sponsorship_packages",
            ["edition_id", "package_id"],
            false,
          ],
          ["sponsors_edition", "editions", ["edition_id"], false],
        ]),
        table("sponsorship_packages", [["packages_edition", "editions", ["edition_id"], false]]),
        table("editions"),
      ),
    );
    expect(plan.order).toEqual([
      "public.editions",
      "public.sponsorship_packages",
      "public.sponsors",
    ]);
  });

  it("ignores keys to tables outside the copy (other schemas)", () => {
    const plan = planCopy(
      catalog(table("profiles", [["profiles_user", "auth.users", ["user_id"], false]])),
    );
    expect(plan.order).toEqual(["public.profiles"]);
  });

  it("today's schema (captured from the migrated test database): exactly the five cycle columns", () => {
    const plan = planCopy(realCatalog as Catalog);
    expect(plan.deferred.map(describeDeferred).sort()).toEqual([
      "public.comments.parent_id",
      "public.editions.cloned_from_edition_id",
      "public.signage_items.current_artwork_version_id",
      "public.signage_items.parent_item_id",
      "public.tasks.parent_task_id",
    ]);
    expect(plan.order).toHaveLength(49); // 48 public tables + drizzle's
    const at = (k: string) => plan.order.indexOf(k);
    expect(at("public.users")).toBeLessThan(at("public.auth_session"));
    expect(at("public.users")).toBeLessThan(at("public.auth_account"));
    expect(at("public.sponsorship_packages")).toBeLessThan(at("public.sponsors"));
    expect(at("public.signage_items")).toBeLessThan(at("public.artwork_versions"));
    expect(plan.cycles.map((c) => c.join("+")).sort()).toEqual([
      "public.artwork_versions+public.signage_items",
      "public.comments",
      "public.editions",
      "public.tasks",
    ]);
  });
});
