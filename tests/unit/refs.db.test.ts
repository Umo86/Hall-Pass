/**
 * DB-backed tests: ref generation under concurrency, RLS deny-by-default and
 * the append-only audit trigger. These run against TEST_DATABASE_URL and
 * skip when it is not set (e.g. a checkout without Postgres).
 */
import { sql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { formatSignageRef, nextCounterValue } from "@/lib/refs";
import * as schema from "@/lib/db/schema";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let editionId: string;

d("database integration", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 10, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    await migrate(db, { migrationsFolder: "lib/db/migrations" });

    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Test Org", slug: `test-${Date.now()}` })
      .returning();
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: org.id, name: "Test Event", code: `TE${Date.now() % 10000}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: org.id, name: "Test Venue", code: `TV${Date.now() % 10000}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Test Edition",
        code: `TST${Date.now() % 10000}`,
        buildStart: "2027-10-01",
        buildEnd: "2027-10-04",
        openStart: "2027-10-05",
        openEnd: "2027-10-07",
        breakdownEnd: "2027-10-08",
      })
      .returning();
    editionId = edition.id;
  });

  afterAll(async () => {
    await client?.end();
  });

  it("generates sequential refs and never reuses one under concurrency", async () => {
    const takes = await Promise.all(
      Array.from({ length: 20 }, () =>
        db.transaction(async (tx) => nextCounterValue(tx, editionId, "signage")),
      ),
    );
    const unique = new Set(takes);
    expect(unique.size).toBe(20);
    expect(Math.min(...takes)).toBe(1);
    expect(Math.max(...takes)).toBe(20);
    expect(formatSignageRef("BIRM27", 7)).toBe("SIG-BIRM27-007");
  });

  it("audit_log rejects UPDATE and DELETE at the database level", async () => {
    const [row] = await db
      .insert(schema.auditLog)
      .values({ entityType: "test", action: "create", summary: "audit trigger test" })
      .returning();
    const causeMessage = async (p: Promise<unknown>) => {
      try {
        await p;
        return null;
      } catch (err) {
        const e = err as Error & { cause?: Error };
        return `${e.message} ${e.cause?.message ?? ""}`;
      }
    };
    expect(
      await causeMessage(
        db.execute(sql`UPDATE audit_log SET summary = 'tampered' WHERE id = ${row.id}`),
      ),
    ).toMatch(/append-only/);
    expect(await causeMessage(db.execute(sql`DELETE FROM audit_log WHERE id = ${row.id}`))).toMatch(
      /append-only/,
    );
  });

  it("RLS is enabled on every public table", async () => {
    const rows = await db.execute(sql`
      SELECT tablename FROM pg_tables
      WHERE schemaname = 'public' AND rowsecurity = false
        AND tablename NOT LIKE '%drizzle%'
    `);
    expect(rows.map((r) => (r as { tablename: string }).tablename)).toEqual([]);
  });

  it("anon and authenticated roles have no table privileges", async () => {
    const rows = await db.execute(sql`
      SELECT grantee, table_name FROM information_schema.role_table_grants
      WHERE table_schema = 'public' AND grantee IN ('anon', 'authenticated')
    `);
    expect(rows.length).toBe(0);
  });
});
