/**
 * The orphan-artwork sweep (cron job 9) and its two guards against deleting
 * real files: it never runs while MOVE_DATABASE_TOKEN is set (and not
 * "off"), nor against a database with no artwork versions (an empty or
 * half-copied database makes every file look orphaned). Runs on a scratch
 * database so the empty-table case doesn't touch the shared test database;
 * the bucket is a fake.
 */
import { randomUUID } from "node:crypto";
import postgres from "postgres";
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import { runMigrations } from "@/lib/db/migrate-core";

const storage = vi.hoisted(() => ({
  s3List: vi.fn(),
  s3Delete: vi.fn(),
}));
vi.mock("@/lib/storage", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@/lib/storage")>()),
  s3Enabled: () => true,
  s3List: storage.s3List,
  s3Delete: storage.s3Delete,
}));

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
const SCRATCH = `hp_sweep_${process.pid}_${Date.now() % 100_000}`;
const TODAY = "2026-10-20";
const OLD = new Date("2026-10-01T00:00:00Z");
const NEW = new Date("2026-10-19T23:00:00Z");

let admin: postgres.Sql;
let scratch: postgres.Sql;
let jobs: typeof import("@/lib/cron/jobs");

d("orphan artwork sweep", () => {
  beforeAll(async () => {
    admin = postgres(url!, { max: 1, prepare: false, onnotice: () => {} });
    await admin.unsafe(`CREATE DATABASE "${SCRATCH}"`);
    const scratchUrl = new URL(url!);
    scratchUrl.pathname = `/${SCRATCH}`;
    await runMigrations(scratchUrl.toString());
    scratch = postgres(scratchUrl.toString(), { max: 1, prepare: false, onnotice: () => {} });
    vi.stubEnv("DATABASE_URL", scratchUrl.toString());
    vi.stubEnv("MOVE_DATABASE_TOKEN", "");
    jobs = await import("@/lib/cron/jobs");
  }, 60_000);

  afterAll(async () => {
    await scratch?.end({ timeout: 5 });
    await admin?.unsafe(`DROP DATABASE IF EXISTS "${SCRATCH}" WITH (FORCE)`).catch(() => {});
    await admin?.end({ timeout: 5 });
    vi.unstubAllEnvs();
  });

  beforeEach(() => {
    storage.s3List.mockReset();
    storage.s3Delete.mockReset();
    storage.s3List.mockResolvedValue({
      objects: [
        { key: "artwork/item/v1.pdf", size: 1, lastModified: OLD },
        { key: "artwork/item/orphan.pdf", size: 1, lastModified: OLD },
        { key: "artwork/item/just-uploaded.pdf", size: 1, lastModified: NEW },
      ],
    });
    storage.s3Delete.mockResolvedValue(undefined);
  });

  it("does nothing on a database with no artwork versions", async () => {
    expect(await jobs.orphanArtworkSweep(TODAY)).toEqual({
      job: "orphan_artwork_sweep",
      sent: 0,
      skipped: 0,
    });
    expect(storage.s3List).not.toHaveBeenCalled();
    expect(storage.s3Delete).not.toHaveBeenCalled();
  });

  it("removes only old, unrecorded artwork once versions exist — and never while a move is armed", async () => {
    const [org] =
      await scratch`INSERT INTO organisations (name, slug) VALUES ('Sweep', 'sweep') RETURNING id`;
    const [event] =
      await scratch`INSERT INTO events (organisation_id, name, code) VALUES (${org.id}, 'E', 'E') RETURNING id`;
    const [venue] =
      await scratch`INSERT INTO venues (organisation_id, name, code) VALUES (${org.id}, 'V', 'V') RETURNING id`;
    const [edition] = await scratch`
      INSERT INTO editions (event_id, venue_id, name, code, build_start, build_end, open_start, open_end, breakdown_end)
      VALUES (${event.id}, ${venue.id}, 'Ed', 'SWP27', '2027-01-01', '2027-01-02', '2027-01-03', '2027-01-04', '2027-01-05')
      RETURNING id`;
    const itemId = randomUUID();
    await scratch`INSERT INTO signage_items (id, edition_id, ref, seq, name)
                  VALUES (${itemId}, ${edition.id}, 'SIG-SWP27-001', 1, 'Sign')`;
    await scratch`INSERT INTO artwork_versions (signage_item_id, version_number, file_path, file_name, mime_type, file_size, sha256)
                  VALUES (${itemId}, 1, 'item/v1.pdf', 'v1.pdf', 'application/pdf', 1, 'x')`;

    // Armed for a move: nothing is listed or deleted.
    vi.stubEnv("MOVE_DATABASE_TOKEN", "x".repeat(64));
    expect(await jobs.orphanArtworkSweep(TODAY)).toMatchObject({ sent: 0, skipped: 0 });
    expect(storage.s3List).not.toHaveBeenCalled();

    // Switched off ("off" is how the token is disarmed): the sweep runs.
    vi.stubEnv("MOVE_DATABASE_TOKEN", "off");
    expect(await jobs.orphanArtworkSweep(TODAY)).toEqual({
      job: "orphan_artwork_sweep",
      sent: 1,
      skipped: 2,
    });
    expect(storage.s3Delete).toHaveBeenCalledTimes(1);
    expect(storage.s3Delete).toHaveBeenCalledWith("artwork", "item/orphan.pdf");
  });
});
