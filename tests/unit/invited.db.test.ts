/**
 * Who may get a sign-in or account email (TEST_DATABASE_URL): team members,
 * open staff invitations and live partner invitations — nobody else.
 */
import { randomUUID } from "node:crypto";
import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "@/lib/db/schema";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let gate: typeof import("@/lib/auth/account-link");
const n = Date.now() % 1_000_000;

d("invited emails only", () => {
  let orgId: string;
  let editionId: string;
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    await migrate(db, { migrationsFolder: "lib/db/migrations" });
    gate = await import("@/lib/auth/account-link");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Gate Org", slug: `gate-${n}` })
      .returning();
    orgId = org.id;
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Gate", code: `GT${n % 10000}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Gate Venue", code: `GV${n % 10000}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Gate 2027",
        code: `GATE${n % 10000}`,
        buildStart: "2027-01-01",
        buildEnd: "2027-01-02",
        openStart: "2027-01-03",
        openEnd: "2027-01-04",
        breakdownEnd: "2027-01-05",
      })
      .returning();
    editionId = edition.id;
  });
  afterAll(async () => {
    await client?.end();
  });

  it("strangers are not invited", async () => {
    expect(await gate.emailIsInvited(`nobody-${n}@gate.test`)).toBe(false);
  });

  it("team members and open staff invitations are", async () => {
    const id = randomUUID();
    await db.insert(schema.users).values({ id, email: `member-${n}@gate.test` });
    await db.insert(schema.memberships).values({ userId: id, organisationId: orgId, role: "ops" });
    expect(await gate.emailIsInvited(`MEMBER-${n}@gate.test`)).toBe(true);

    await db.insert(schema.staffInvites).values({
      organisationId: orgId,
      invitedEmail: `new-${n}@gate.test`,
      role: "viewer",
      inviteTokenHash: `gate-${n}`,
    });
    expect(await gate.emailIsInvited(`new-${n}@gate.test`)).toBe(true);
  });

  it("revoked staff invitations and expired partner invitations are not", async () => {
    await db.insert(schema.staffInvites).values({
      organisationId: orgId,
      invitedEmail: `revoked-${n}@gate.test`,
      role: "viewer",
      inviteTokenHash: `gate-r-${n}`,
      revokedAt: new Date(),
    });
    expect(await gate.emailIsInvited(`revoked-${n}@gate.test`)).toBe(false);

    await db.insert(schema.externalGrants).values({
      invitedEmail: `venue-${n}@gate.test`,
      organisationId: orgId,
      editionId,
      role: "venue",
      inviteTokenHash: `gate-v-${n}`,
      expiresAt: new Date(Date.now() - 86_400_000),
    });
    expect(await gate.emailIsInvited(`venue-${n}@gate.test`)).toBe(false);
    await db.insert(schema.externalGrants).values({
      invitedEmail: `venue2-${n}@gate.test`,
      organisationId: orgId,
      editionId,
      role: "venue",
      inviteTokenHash: `gate-v2-${n}`,
    });
    expect(await gate.emailIsInvited(`venue2-${n}@gate.test`)).toBe(true);
  });
});
