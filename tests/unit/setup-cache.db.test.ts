/**
 * regressions-5: the setup checklist's facts are loaded once per request —
 * the layout's "Setup 3/6" and the Dashboard or Setup page under it share
 * them through React cache(), keyed by value. React's cache only memoises
 * inside a server request, so it is stood in for here by a plain memoiser.
 */
import { randomUUID } from "node:crypto";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";

const calls = vi.hoisted(() => ({ n: 0 }));
vi.mock("react", async (importOriginal) => {
  const actual = await importOriginal<typeof import("react")>();
  return {
    ...actual,
    cache: <A extends unknown[], R>(fn: (...args: A) => R) => {
      const memo = new Map<string, R>();
      return (...args: A) => {
        const key = JSON.stringify(args);
        if (!memo.has(key)) {
          calls.n++;
          memo.set(key, fn(...args));
        }
        return memo.get(key)!;
      };
    },
  };
});

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
const n = Date.now() % 1_000_000;

d("setup status per request", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 2, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
  });
  afterAll(async () => {
    await client?.end();
  });

  it("the layout and the page share one load of the facts", async () => {
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Setup cache", slug: `setup-cache-${n}-${randomUUID().slice(0, 4)}` })
      .returning();
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: org.id, name: "Cache Show", code: `SC${n}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: org.id, name: "Cache Hall", code: `SCH${n}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Cache 2027",
        code: `SCE${n}`,
        buildStart: "2027-02-01",
        buildEnd: "2027-02-02",
        openStart: "2027-02-03",
        openEnd: "2027-02-04",
        breakdownEnd: "2027-02-05",
      })
      .returning();
    const { getSetupStatus, SETUP_STEP_ACTION } = await import("@/lib/queries/setup");
    const perms = Object.fromEntries(
      Object.keys(SETUP_STEP_ACTION).map((k) => [k, true]),
    ) as Parameters<typeof getSetupStatus>[2];
    const before = calls.n;
    // The layout loads the event one way, the page another: same values.
    const fromLayout = await getSetupStatus({ ...edition }, org.id, perms);
    const fromPage = await getSetupStatus({ ...edition }, org.id, perms);
    expect(calls.n - before).toBe(2); // one organisation load, one event load
    expect(fromPage.facts).toBe(fromLayout.facts);
    expect(fromPage.org).toBe(fromLayout.org);
    expect(fromPage.summary).toEqual(fromLayout.summary);
  });
});
