/**
 * Sessions end when access does, against a real database
 * (TEST_DATABASE_URL): suspending someone or removing them deletes their
 * sessions in the same transaction (audited with how many), reactivating
 * creates none, and the daily access-end job does the same next to its
 * "Access ended" row. Daily housekeeping removes only what has expired, and
 * the rate limiter counts exactly under concurrency.
 */
import { randomBytes, randomUUID } from "node:crypto";
import { and, eq, inArray } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) vi.stubEnv("DATABASE_URL", url);

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let manage: typeof import("@/lib/users/manage");
let jobs: typeof import("@/lib/cron/jobs");
let rateLimit: typeof import("@/lib/auth/rate-limit");
let orgId: string;
let adminId: string;
const n = Date.now() % 1_000_000;
const mail = (k: string) => `${k}-${n}@sessions.test`;
const ctx = () => ({ organisationId: orgId, actorUserId: adminId, actorName: "Alex" });
const DAY = 24 * 60 * 60 * 1000;

async function member(key: string, extra: Partial<typeof schema.memberships.$inferInsert> = {}) {
  const id = randomUUID();
  await db.insert(schema.users).values({ id, email: mail(key), fullName: key });
  await db
    .insert(schema.memberships)
    .values({ userId: id, organisationId: orgId, role: "viewer", ...extra });
  return id;
}

async function sessions(userId: string, count: number, expiresAt = new Date(Date.now() + DAY)) {
  for (let i = 0; i < count; i++) {
    await db
      .insert(schema.authSession)
      .values({ userId, token: randomBytes(16).toString("hex"), expiresAt });
  }
}

const sessionCount = async (userId: string) =>
  (await db.select().from(schema.authSession).where(eq(schema.authSession.userId, userId))).length;

async function lastAudit(userId: string, summary: string) {
  const rows = await db
    .select()
    .from(schema.auditLog)
    .where(and(eq(schema.auditLog.subjectUserId, userId), eq(schema.auditLog.summary, summary)));
  return rows.at(-1);
}

d("sessions end when access does", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    manage = await import("@/lib/users/manage");
    jobs = await import("@/lib/cron/jobs");
    rateLimit = await import("@/lib/auth/rate-limit");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Sessions Org", slug: `sessions-${n}` })
      .returning();
    orgId = org.id;
    adminId = await member("alex", { role: "admin" });
    await db.update(schema.users).set({ fullName: "Alex" }).where(eq(schema.users.id, adminId));
  });

  afterAll(async () => {
    vi.unstubAllEnvs();
    await client?.end();
  });

  it("suspending someone signs them out everywhere, in the same transaction", async () => {
    const dana = await member("dana");
    await sessions(dana, 2);
    await db.transaction((tx) => manage.suspendMemberTx(tx, ctx(), { userId: dana }));
    expect(await sessionCount(dana)).toBe(0);
    const row = await lastAudit(dana, `Suspended ${mail("dana")}`);
    expect(row?.after).toMatchObject({ sessionsEnded: 2 });
    // Reactivating gives access back but creates no session.
    await db.transaction((tx) => manage.reactivateMemberTx(tx, ctx(), { userId: dana }));
    expect(await sessionCount(dana)).toBe(0);
  });

  it("removing someone signs them out everywhere", async () => {
    const remy = await member("remy");
    await sessions(remy, 3);
    await db.transaction((tx) => manage.removeMemberTx(tx, ctx(), { userId: remy }));
    expect(await sessionCount(remy)).toBe(0);
    const row = await lastAudit(remy, `Removed ${mail("remy")} from the team`);
    expect(row?.after).toMatchObject({ sessionsEnded: 3 });
  });

  it("the daily job ends access on its date and signs them out with the same record", async () => {
    const eve = await member("eve", { accessEndsAt: new Date(Date.now() - 60_000) });
    await sessions(eve, 2);
    const kept = await member("kim", { accessEndsAt: new Date(Date.now() + 30 * DAY) });
    await sessions(kept, 1);
    await jobs.endExpiredAccess(new Date().toISOString().slice(0, 10));
    expect(await sessionCount(eve)).toBe(0);
    expect(await sessionCount(kept)).toBe(1);
    const row = await lastAudit(eve, `Access ended for ${mail("eve")}`);
    expect(row?.after).toMatchObject({ accessEnded: true, sessionsEnded: 2 });
  });

  it("housekeeping removes only expired sessions and links, and day-old rate-limit rows", async () => {
    const hal = await member("hal");
    const now = new Date();
    await sessions(hal, 1, new Date(now.getTime() - 1000));
    await sessions(hal, 1, new Date(now.getTime() + DAY));
    const tag = `hk-${n}-${randomUUID()}`;
    const links = await db
      .insert(schema.authVerification)
      .values([
        { identifier: `${tag}-old`, value: hal, expiresAt: new Date(now.getTime() - 1000) },
        { identifier: `${tag}-new`, value: hal, expiresAt: new Date(now.getTime() + 60_000) },
      ])
      .returning();
    const limits = await db
      .insert(schema.authRateLimit)
      .values([
        { key: `${tag}-old`, count: 3, lastRequest: now.getTime() - DAY - 1000 },
        { key: `${tag}-new`, count: 3, lastRequest: now.getTime() - 60_000 },
      ])
      .returning();
    const out = await jobs.authHousekeeping(now);
    expect(out.job).toBe("auth_housekeeping");
    expect(out.sent).toBeGreaterThanOrEqual(3);
    expect(await sessionCount(hal)).toBe(1);
    const leftLinks = await db
      .select()
      .from(schema.authVerification)
      .where(
        inArray(
          schema.authVerification.id,
          links.map((l) => l.id),
        ),
      );
    expect(leftLinks.map((l) => l.identifier)).toEqual([`${tag}-new`]);
    const leftLimits = await db
      .select()
      .from(schema.authRateLimit)
      .where(
        inArray(
          schema.authRateLimit.id,
          limits.map((l) => l.id),
        ),
      );
    expect(leftLimits.map((l) => l.key)).toEqual([`${tag}-new`]);
  });

  it("the rate limiter allows exactly the limit, however many arrive at once", async () => {
    const key = `concurrent-${n}-${randomUUID()}`;
    const results = await Promise.all(
      Array.from({ length: 10 }, () => rateLimit.consumeRateLimit(key, { window: 900, max: 5 })),
    );
    expect(results.filter((r) => r.allowed)).toHaveLength(5);
    for (const r of results.filter((r) => !r.allowed)) {
      expect(r.retryAfter).toBeGreaterThan(890);
      expect(r.retryAfter).toBeLessThanOrEqual(900);
    }
    // The key is stored as an HMAC, never as given.
    const raw = await db
      .select()
      .from(schema.authRateLimit)
      .where(eq(schema.authRateLimit.key, key));
    expect(raw).toEqual([]);
    const [row] = await db
      .select()
      .from(schema.authRateLimit)
      .where(eq(schema.authRateLimit.key, rateLimit.bucketKey(key)));
    expect(row.count).toBe(10);
  });
});
