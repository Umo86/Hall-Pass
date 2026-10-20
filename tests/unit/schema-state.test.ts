import { describe, expect, it } from "vitest";
import journal from "@/lib/db/migrations/meta/_journal.json";
import { latestMigration, schemaState } from "@/lib/db/schema-state";

/** migrations-1: /api/health says when the database hasn't had this release's migrations. */
describe("schemaState", () => {
  it("knows this release's newest migration", () => {
    expect(latestMigration().tag).toBe("0014_better_auth");
  });

  it("journal entries are in order (each migration newer than the one before)", () => {
    const { entries } = journal;
    for (let i = 1; i < entries.length; i++) {
      expect(entries[i].idx).toBe(entries[i - 1].idx + 1);
      expect(entries[i].when).toBeGreaterThan(entries[i - 1].when);
    }
  });

  it("current when the database has the newest migration, behind when it doesn't", () => {
    const { when } = latestMigration();
    expect(schemaState(when)).toBe("current");
    expect(schemaState(when + 1)).toBe("current");
    expect(schemaState(when - 1)).toBe("behind");
  });

  it("unknown when the bookkeeping table can't be read", () => {
    expect(schemaState(null)).toBe("unknown");
    expect(schemaState(Number.NaN)).toBe("unknown");
  });
});
