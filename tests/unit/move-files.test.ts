import { describe, expect, it } from "vitest";
import { checkFiles, FILE_BUCKETS, type FileRef, type Lister } from "@/lib/db/move/files";

/** A fake bucket listing `pageSize` keys per page. */
function fakeLister(keys: string[], pageSize = 2): Lister & { calls: string[] } {
  const calls: string[] = [];
  const lister = async (prefix: string, cursor?: string) => {
    calls.push(`${prefix}@${cursor ?? 0}`);
    const all = keys.filter((k) => k.startsWith(prefix));
    const start = Number(cursor ?? 0);
    const objects = all.slice(start, start + pageSize).map((key) => ({ key }));
    const next = start + pageSize < all.length ? String(start + pageSize) : undefined;
    return { objects, nextCursor: next };
  };
  return Object.assign(lister, { calls });
}

const ref = (table: string, column: string, value: string, id = "1"): FileRef => ({
  table,
  column,
  id,
  value,
});

describe("checkFiles", () => {
  it("counts samples, non-files, present and missing per bucket", async () => {
    const lister = fakeLister([
      "artwork/a/v1.pdf",
      "artwork/a/v1.png",
      "documents/d/spec.pdf",
      "photos/p/install.jpg",
      "artwork/orphan/old.pdf",
    ]);
    const report = await checkFiles(
      [
        ref("artwork_versions", "file_path", "a/v1.pdf"),
        ref("artwork_versions", "preview_path", "a/v1.png"),
        ref("artwork_versions", "file_path", "seed/demo.pdf"),
        ref("documents", "file_path", "d/spec.pdf"),
        // In the wrong bucket: documents are looked for under documents/ only.
        ref("documents", "file_path", "p/install.jpg", "2"),
        ref("signage_items", "install_photo_path", "p/install.jpg"),
        ref("signage_items", "install_photo_path", "Installed by the venue team"),
        ref("exports", "file_path", "schedule.xlsx"),
      ],
      lister,
    );
    expect(report).toEqual({
      references: 8,
      present: 4,
      samples: 1,
      notFiles: 2,
      missing: [
        {
          table: "documents",
          column: "file_path",
          id: "2",
          value: "p/install.jpg",
          key: "documents/p/install.jpg",
        },
      ],
      unreferencedObjects: 1,
    });
  });

  it("finds columns with no fixed bucket in any bucket", async () => {
    const report = await checkFiles(
      [
        ref("users", "avatar_path", "u/me.png"),
        ref("halls", "floorplan_path", "h/plan.pdf"),
        ref("organisations", "logo_path", "o/logo.png"),
      ],
      fakeLister(["photos/u/me.png", "floorplans/h/plan.pdf"]),
    );
    expect(report.present).toBe(2);
    expect(report.missing.map((m) => m.key)).toEqual(["artwork/o/logo.png"]);
  });

  it("follows the lister's pages, listing each bucket prefix once", async () => {
    const keys = Array.from({ length: 7 }, (_, i) => `artwork/x/${i}.pdf`);
    const lister = fakeLister(keys, 3);
    const report = await checkFiles(
      keys.map((k, i) =>
        ref("artwork_versions", "file_path", k.slice("artwork/".length), String(i)),
      ),
      lister,
    );
    expect(report.present).toBe(7);
    expect(report.missing).toEqual([]);
    expect(lister.calls.filter((c) => c.startsWith("artwork/"))).toEqual([
      "artwork/@0",
      "artwork/@3",
      "artwork/@6",
    ]);
    expect(lister.calls.filter((c) => c.endsWith("@0"))).toHaveLength(FILE_BUCKETS.length);
  });
});
