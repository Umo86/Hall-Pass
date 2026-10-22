/**
 * Demo logins (testing only, DEMO_LOGIN_PASSWORD) against a real database
 * (TEST_DATABASE_URL), with Better Auth running for real: the sign-in page's
 * list; the shared password set at sign-in (once, audited, set back if a
 * tester changed it) and never for a real person's account; what a demo
 * session can't do; and, off on production, no sign-in and no session.
 * Mocks as in auth-accounts.db.test.ts.
 */
import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";

const state = vi.hoisted(() => ({ cookie: "" }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn(), revalidateTag: vi.fn() }));
vi.mock("next/headers", () => ({
  cookies: async () => ({
    get: () => undefined,
    getAll: () => [],
    has: () => false,
    set: () => {},
    delete: () => {},
  }),
  headers: async () =>
    new Headers({
      host: "localhost:3901",
      "x-real-ip": "198.51.100.7",
      ...(state.cookie ? { cookie: state.cookie } : {}),
    }),
}));
vi.mock("next/navigation", async (importOriginal) => ({
  ...(await importOriginal<typeof import("next/navigation")>()),
  redirect: (to: string) => {
    throw new Error(`NEXT_REDIRECT:${to}`);
  },
}));

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
const BASE = "http://localhost:3901";
const DEMO = "demo-pass-2026";
if (url) {
  vi.stubEnv("DATABASE_URL", url);
  vi.stubEnv("BETTER_AUTH_SECRET", "test-secret-0123456789-abcdefghijklmnopqrstuvwxyz");
  vi.stubEnv("NEXT_PUBLIC_APP_URL", BASE);
  vi.stubEnv("RESEND_API_KEY", "");
  vi.stubEnv("EMAIL_FROM", "");
  vi.stubEnv("DEMO_LOGIN_PASSWORD", "");
}

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let auth: typeof import("@/app/actions/auth");
let usersActions: typeof import("@/app/actions/users");
let account: typeof import("@/app/actions/account");
let actor: typeof import("@/lib/auth/actor");
let demo: typeof import("@/lib/auth/demo-logins");
let server: typeof import("@/lib/auth/server");
let password: typeof import("@/lib/auth/password");
let INCORRECT: string;

const n = Date.now() % 1_000_000;
const demoMail = (k: string) => `${k}-${n}@demologins.test`;
const OWNER = `owner-${n}@demologins.example`;
const OWNER_PASSWORD = "owner-pass-123";
let orgId: string;
let ownerId: string;
let demoAdminId: string;

async function member(
  email: string,
  role: "admin" | "ops" | "viewer",
  extra: Partial<typeof schema.memberships.$inferInsert> = {},
) {
  const id = randomUUID();
  await db
    .insert(schema.users)
    .values({ id, email, fullName: email.split("-")[0], emailVerified: true });
  await db.insert(schema.memberships).values({ userId: id, organisationId: orgId, role, ...extra });
  return id;
}

async function credential(email: string) {
  const [row] = await db
    .select({ password: schema.authAccount.password })
    .from(schema.authAccount)
    .innerJoin(schema.users, eq(schema.users.id, schema.authAccount.userId))
    .where(and(eq(schema.users.email, email), eq(schema.authAccount.providerId, "credential")));
  return row?.password ?? null;
}

async function demoAudits(email: string) {
  return db
    .select()
    .from(schema.auditLog)
    .where(
      and(
        eq(schema.auditLog.subjectEmail, email),
        eq(schema.auditLog.summary, "Demo login password set (DEMO_LOGIN_PASSWORD, testing only)"),
      ),
    );
}

async function redirectOf(p: Promise<unknown>): Promise<string> {
  try {
    const out = await p;
    throw new Error(`Expected a redirect, got ${JSON.stringify(out)}`);
  } catch (err) {
    const m = /^NEXT_REDIRECT:(.*)$/.exec((err as Error).message);
    if (!m) throw err;
    return m[1];
  }
}

/** A password sign-in straight through Better Auth's handler: its session cookie. */
async function cookieFor(email: string, pass: string): Promise<string> {
  const res = await server.getAuth().handler(
    new Request(`${BASE}/api/auth/sign-in/email`, {
      method: "POST",
      headers: { "content-type": "application/json", origin: BASE, "x-real-ip": "198.51.100.8" },
      body: JSON.stringify({ email, password: pass }),
    }),
  );
  expect(res.status, await res.clone().text()).toBe(200);
  return res.headers
    .getSetCookie()
    .map((c) => c.split(";")[0])
    .join("; ");
}

d("demo logins (testing only)", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    auth = await import("@/app/actions/auth");
    usersActions = await import("@/app/actions/users");
    account = await import("@/app/actions/account");
    actor = await import("@/lib/auth/actor");
    demo = await import("@/lib/auth/demo-logins");
    server = await import("@/lib/auth/server");
    password = await import("@/lib/auth/password");
    INCORRECT = (await import("@/lib/auth/messages")).INCORRECT;
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Demo Logins Org", slug: `demo-logins-${n}` })
      .returning();
    orgId = org.id;
    demoAdminId = await member(demoMail("admin"), "admin");
    await member(demoMail("viewer"), "viewer");
    await member(demoMail("gone"), "ops", { suspendedAt: new Date() });
    ownerId = await member(OWNER, "admin");
    await db.insert(schema.authAccount).values({
      userId: ownerId,
      accountId: ownerId,
      providerId: "credential",
      password: await password.hashPassword(OWNER_PASSWORD),
    });
  });

  afterAll(async () => {
    vi.unstubAllEnvs();
    await client?.end();
  });

  const ours = (list: { email: string }[]) =>
    list.filter((l) => l.email.endsWith(`-${n}@demologins.test`));

  it("off: nothing listed, no password made, and a demo account without one can't sign in", async () => {
    vi.stubEnv("DEMO_LOGIN_PASSWORD", "");
    expect(await demo.listDemoLogins()).toEqual([]);
    expect(await demo.ensureDemoPassword(demoMail("admin"), DEMO)).toBe(false);
    expect(await auth.signInWithPassword({ email: demoMail("admin"), password: DEMO })).toEqual({
      ok: false,
      error: INCORRECT,
    });
    expect(await credential(demoMail("admin"))).toBeNull();
  });

  it("on: the demo accounts that can sign in now, super admin first; suspended ones aren't offered", async () => {
    vi.stubEnv("DEMO_LOGIN_PASSWORD", DEMO);
    expect(ours(await demo.listDemoLogins())).toEqual([
      { email: demoMail("admin"), name: "admin", role: "Super admin", isExternal: false },
      { email: demoMail("viewer"), name: "viewer", role: "Viewer (read-only)", isExternal: false },
    ]);
    // A real person's account is never listed.
    expect((await demo.listDemoLogins()).map((l) => l.email)).not.toContain(OWNER);
  });

  it("on: the shared password signs in — set once and audited, set back if a tester changed it", async () => {
    vi.stubEnv("DEMO_LOGIN_PASSWORD", DEMO);
    state.cookie = "";
    expect(
      await redirectOf(auth.signInWithPassword({ email: demoMail("admin"), password: DEMO })),
    ).toBe("/");
    const hash = await credential(demoMail("admin"));
    expect(hash).not.toBeNull();
    expect(await password.verifyPassword({ hash: hash!, password: DEMO })).toBe(true);
    expect(await demoAudits(demoMail("admin"))).toHaveLength(1);
    // Signing in again changes nothing.
    await redirectOf(auth.signInWithPassword({ email: demoMail("admin"), password: DEMO }));
    expect(await credential(demoMail("admin"))).toBe(hash);
    expect(await demoAudits(demoMail("admin"))).toHaveLength(1);
    // A tester changed it on My account: the shared one works again, and is audited again.
    await db
      .update(schema.authAccount)
      .set({ password: await password.hashPassword("changed-by-tester") })
      .where(eq(schema.authAccount.password, hash!));
    // Their own password doesn't work while demo logins are on…
    expect(
      await auth.signInWithPassword({ email: demoMail("admin"), password: "changed-by-tester" }),
    ).toEqual({ ok: false, error: INCORRECT });
    // …and the shared one is set back.
    await redirectOf(auth.signInWithPassword({ email: demoMail("admin"), password: DEMO }));
    expect(await demoAudits(demoMail("admin"))).toHaveLength(2);
  });

  it("on: a wrong password changes nothing, and a real person's account is never given the demo password", async () => {
    vi.stubEnv("DEMO_LOGIN_PASSWORD", DEMO);
    expect(
      await auth.signInWithPassword({ email: demoMail("viewer"), password: "not-the-demo" }),
    ).toEqual({ ok: false, error: INCORRECT });
    expect(await credential(demoMail("viewer"))).toBeNull();
    const before = await credential(OWNER);
    expect(await auth.signInWithPassword({ email: OWNER, password: DEMO })).toEqual({
      ok: false,
      error: INCORRECT,
    });
    expect(await demo.ensureDemoPassword(OWNER, DEMO)).toBe(false);
    expect(await credential(OWNER)).toBe(before);
  });

  it("a demo session keeps its role but can't make sign-in links or change people", async () => {
    vi.stubEnv("DEMO_LOGIN_PASSWORD", DEMO);
    state.cookie = await cookieFor(demoMail("admin"), DEMO);
    const session = await actor.getSession();
    expect(session?.actor).toMatchObject({ kind: "staff", role: "admin", demo: true });
    expect(
      await usersActions.createAccessLink({ userId: ownerId, kind: "password_reset" }),
    ).toEqual({ ok: false, error: "Only a super admin can make sign-in links" });
    expect(await usersActions.suspendUser({ userId: ownerId, handTo: {} })).toMatchObject({
      ok: false,
    });
    expect(
      (await db.select().from(schema.memberships).where(eq(schema.memberships.userId, ownerId)))[0]
        .suspendedAt,
    ).toBeNull();
    // Nor change the shared password for everyone else.
    expect(
      await account.changeMyPassword({
        currentPassword: DEMO,
        password: "mine-only-123",
        confirm: "mine-only-123",
      }),
    ).toEqual({ ok: false, error: "Demo accounts keep the shared demo password" });
    // The real super admin's session is not a demo one.
    state.cookie = await cookieFor(OWNER, OWNER_PASSWORD);
    expect((await actor.getSession())?.actor.demo).toBeUndefined();
  });

  it("off on production: demo accounts can't sign in, and their sessions end", async () => {
    vi.stubEnv("DEMO_LOGIN_PASSWORD", DEMO);
    const demoCookie = await cookieFor(demoMail("admin"), DEMO);
    vi.stubEnv("DEMO_LOGIN_PASSWORD", "");
    vi.stubEnv("VERCEL_ENV", "production");
    try {
      state.cookie = "";
      expect(await auth.signInWithPassword({ email: demoMail("admin"), password: DEMO })).toEqual({
        ok: false,
        error: INCORRECT,
      });
      state.cookie = demoCookie;
      expect(await actor.getSession()).toBeNull();
      // The calendar feed (looked up by user id) is closed too.
      expect(await actor.sessionForUserId(demoAdminId)).toBeNull();
      // Better Auth's own sign-in route makes no session for them either.
      const direct = await server.getAuth().handler(
        new Request(`${BASE}/api/auth/sign-in/email`, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            origin: BASE,
            "x-real-ip": "198.51.100.9",
          },
          body: JSON.stringify({ email: demoMail("admin"), password: DEMO }),
        }),
      );
      expect(direct.status).not.toBe(200);
      // Real people are unaffected.
      state.cookie = await cookieFor(OWNER, OWNER_PASSWORD);
      expect((await actor.getSession())?.user.email).toBe(OWNER);
    } finally {
      vi.stubEnv("VERCEL_ENV", "");
    }
  });
});
