/**
 * Sign-in on Better Auth against a real database (TEST_DATABASE_URL), with
 * Better Auth running for real: invitation acceptance (staff and partner)
 * creates the account and signs in; password sign-in and the session gate
 * (suspended people are told who to ask, and get no session); email links
 * for new invitees and for people never invited; reset by link; change
 * password; super-admin access links; the HTTP allowlist; and an honest
 * reply when the rate limiter can't be asked.
 *
 * Cookies: Better Auth's nextCookies writes through next/headers from inside
 * node_modules, which the test mocks don't reach, so a session cookie is
 * taken from Better Auth's own responses and put on the mocked headers.
 */
import { randomUUID } from "node:crypto";
import { desc, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";

const state = vi.hoisted(() => ({
  cookie: "",
  /** proxy.ts's x-hp-path (the requested path), and a server action's id. */
  path: "",
  action: "",
  limiter: null as null | "limited" | "unavailable",
}));
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
      "x-real-ip": "198.51.100.1",
      ...(state.cookie ? { cookie: state.cookie } : {}),
      ...(state.path ? { "x-hp-path": state.path } : {}),
      ...(state.action ? { "next-action": state.action } : {}),
    }),
}));
vi.mock("next/navigation", async (importOriginal) => ({
  ...(await importOriginal<typeof import("next/navigation")>()),
  redirect: (to: string) => {
    throw new Error(`NEXT_REDIRECT:${to}`);
  },
}));
vi.mock("@/lib/auth/rate-limit", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/auth/rate-limit")>();
  return {
    ...actual,
    allow: async (...args: Parameters<typeof actual.allow>) =>
      state.limiter ?? actual.allow(...args),
  };
});

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
const BASE = "http://localhost:3901";
if (url) {
  vi.stubEnv("DATABASE_URL", url);
  vi.stubEnv("BETTER_AUTH_SECRET", "test-secret-0123456789-abcdefghijklmnopqrstuvwxyz");
  vi.stubEnv("NEXT_PUBLIC_APP_URL", BASE);
  vi.stubEnv("RESEND_API_KEY", "");
  vi.stubEnv("EMAIL_FROM", "");
}

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let auth: typeof import("@/app/actions/auth");
let invites: typeof import("@/app/actions/invites");
let account: typeof import("@/app/actions/account");
let usersActions: typeof import("@/app/actions/users");
let links: typeof import("@/lib/auth/links");
let server: typeof import("@/lib/auth/server");
let password: typeof import("@/lib/auth/password");
let messages: typeof import("@/lib/auth/messages");
let staffInvite: typeof import("@/lib/auth/staff-invite");
let inviteToken: typeof import("@/lib/auth/invite-token");

const n = Date.now() % 1_000_000;
const mail = (k: string) => `${k}-${n}@accounts.test`;
let orgId: string;
let otherOrgId: string;
let editionId: string;
let adminId: string;
const ADMIN_PASSWORD = "admin-pass-123";

async function userByEmail(email: string) {
  const [u] = await db
    .select()
    .from(schema.users)
    .where(eq(schema.users.email, email.toLowerCase()));
  return u;
}

async function sessionsOf(userId: string) {
  return db.select().from(schema.authSession).where(eq(schema.authSession.userId, userId));
}

async function auditFor(userId: string) {
  return db
    .select()
    .from(schema.auditLog)
    .where(eq(schema.auditLog.subjectUserId, userId))
    .orderBy(desc(schema.auditLog.createdAt));
}

/** A team member with a password, made directly. */
async function memberWithPassword(
  key: string,
  role: "admin" | "ops" | "viewer",
  pass: string,
  extra: Partial<typeof schema.memberships.$inferInsert> = {},
  org = orgId,
) {
  const id = randomUUID();
  await db
    .insert(schema.users)
    .values({ id, email: mail(key), fullName: key, emailVerified: true });
  await db.insert(schema.memberships).values({ userId: id, organisationId: org, role, ...extra });
  await db.insert(schema.authAccount).values({
    userId: id,
    accountId: id,
    providerId: "credential",
    password: await password.hashPassword(pass),
  });
  return id;
}

async function staffInviteFor(email: string, role: "ops" | "viewer" = "ops") {
  const { inviteUrl } = await db.transaction((tx) =>
    staffInvite.createStaffInvite(tx, {
      organisationId: orgId,
      email,
      role,
      invitedBy: adminId,
      summary: `Invited ${email}`,
    }),
  );
  return inviteUrl.split("/invite/")[1];
}

/** A password sign-in straight through Better Auth's handler: its session cookie. */
async function cookieFor(email: string, pass: string): Promise<string> {
  const res = await server.getAuth().handler(
    new Request(`${BASE}/api/auth/sign-in/email`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: BASE,
        "x-real-ip": "198.51.100.9",
      },
      body: JSON.stringify({ email, password: pass }),
    }),
  );
  expect(res.status, await res.clone().text()).toBe(200);
  return cookieFrom(res);
}

function cookieFrom(res: Response): string {
  return res.headers
    .getSetCookie()
    .map((c) => c.split(";")[0])
    .join("; ");
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

d("sign-in on Better Auth: accounts, sessions and links", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    auth = await import("@/app/actions/auth");
    invites = await import("@/app/actions/invites");
    account = await import("@/app/actions/account");
    usersActions = await import("@/app/actions/users");
    links = await import("@/lib/auth/links");
    server = await import("@/lib/auth/server");
    password = await import("@/lib/auth/password");
    messages = await import("@/lib/auth/messages");
    staffInvite = await import("@/lib/auth/staff-invite");
    inviteToken = await import("@/lib/auth/invite-token");
    const [org, other] = await db
      .insert(schema.organisations)
      .values([
        { name: "Accounts Org", slug: `accounts-${n}` },
        { name: "Other Org", slug: `accounts-other-${n}` },
      ])
      .returning();
    orgId = org.id;
    otherOrgId = other.id;
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Accounts Show", code: `AC${n % 100000}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Accounts Hall", code: `AH${n % 10000}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Accounts 2027",
        code: `AZ${n}`,
        buildStart: "2027-03-01",
        buildEnd: "2027-03-02",
        openStart: "2027-03-03",
        openEnd: "2027-03-04",
        breakdownEnd: "2027-03-05",
      })
      .returning();
    editionId = edition.id;
    adminId = await memberWithPassword("alex", "admin", ADMIN_PASSWORD);
    await db.update(schema.users).set({ fullName: "Alex" }).where(eq(schema.users.id, adminId));
  });

  afterAll(async () => {
    vi.unstubAllEnvs();
    await client?.end();
  });

  it("a staff invitation accepted creates the account, claims it and signs in", async () => {
    state.cookie = "";
    const email = `Sam-${n}@Accounts.TEST`; // stored lower-case
    const token = await staffInviteFor(email, "ops");
    const to = await redirectOf(
      invites.acceptInvite({
        token,
        fullName: "Sam Staff",
        password: "s3cure-pass",
        confirm: "s3cure-pass",
      }),
    );
    expect(to).toBe("/my-work");
    const user = await userByEmail(email);
    expect(user.email).toBe(email.toLowerCase());
    expect(user.emailVerified).toBe(true);
    expect(user.fullName).toBe("Sam Staff");
    expect(user.isExternal).toBe(false);
    const [acct] = await db
      .select()
      .from(schema.authAccount)
      .where(eq(schema.authAccount.userId, user.id));
    expect(acct.providerId).toBe("credential");
    expect(acct.accountId).toBe(user.id);
    expect(await password.verifyPassword({ hash: acct.password!, password: "s3cure-pass" })).toBe(
      true,
    );
    const [m] = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, user.id));
    expect(m.role).toBe("ops");
    expect(await sessionsOf(user.id)).toHaveLength(1);
    const summaries = (await auditFor(user.id)).map((a) => a.summary);
    expect(summaries).toContain(`${email.toLowerCase()} set up their account`);
    expect(summaries).toContain("Staff invitation accepted (ops)");
  });

  it("a partner invitation accepted makes an external account and lands in the portal", async () => {
    state.cookie = "";
    const email = mail("pia");
    const token = inviteToken.generateInviteToken();
    await db.insert(schema.externalGrants).values({
      invitedEmail: email,
      organisationId: orgId,
      editionId,
      role: "sponsor",
      invitedBy: adminId,
      inviteTokenHash: inviteToken.hashInviteToken(token),
    });
    const to = await redirectOf(
      invites.acceptInvite({
        token,
        fullName: "Pia Partner",
        password: "partner-pass",
        confirm: "partner-pass",
      }),
    );
    expect(to).toBe("/portal/approvals");
    const user = await userByEmail(email);
    expect(user.isExternal).toBe(true);
    expect(user.emailVerified).toBe(true);
    const [grant] = await db
      .select()
      .from(schema.externalGrants)
      .where(eq(schema.externalGrants.invitedEmail, email));
    expect(grant.userId).toBe(user.id);
    expect(await sessionsOf(user.id)).toHaveLength(1);
  });

  it("a second invitation for an email with an account says to sign in first", async () => {
    state.cookie = "";
    const token = await staffInviteFor(mail("sam"), "viewer");
    expect(
      await invites.acceptInvite({
        token,
        fullName: "Sam Again",
        password: "whatever-1",
        confirm: "whatever-1",
      }),
    ).toEqual({
      ok: false,
      error:
        "You already have an account with this email — sign in with it first, then open this invitation link again.",
    });
  });

  it("password sign-in: the right password signs in (audited), a wrong one is 'incorrect'", async () => {
    state.cookie = "";
    const sam = await userByEmail(mail("sam"));
    const before = (await sessionsOf(sam.id)).length;
    expect(
      await redirectOf(
        auth.signInWithPassword({
          email: mail("SAM").toUpperCase(),
          password: "s3cure-pass",
          next: "/approvals",
        }),
      ),
    ).toBe("/approvals");
    expect((await sessionsOf(sam.id)).length).toBe(before + 1);
    expect((await auditFor(sam.id)).map((a) => a.summary)).toContain(
      `${mail("sam")} signed in (password)`,
    );
    expect(await auth.signInWithPassword({ email: mail("sam"), password: "wrong-pass" })).toEqual({
      ok: false,
      error: messages.INCORRECT,
    });
    expect(
      await auth.signInWithPassword({ email: mail("nobody"), password: "s3cure-pass" }),
    ).toEqual({ ok: false, error: messages.INCORRECT });
  });

  it("a suspended member with the right password is told who to ask, and gets no session", async () => {
    state.cookie = "";
    const id = await memberWithPassword("sid", "ops", "sid-pass-123", {
      suspendedAt: new Date(),
      suspendedBy: adminId,
    });
    expect(await auth.signInWithPassword({ email: mail("sid"), password: "sid-pass-123" })).toEqual(
      { ok: false, error: `Your access is paused — ask Alex (${mail("alex")}).` },
    );
    expect(await sessionsOf(id)).toHaveLength(0);
  });

  it("an email link for a new invitee creates the account, then /auth/accept sets it up", async () => {
    state.cookie = "";
    const email = mail("mia");
    await staffInviteFor(email, "viewer");
    const link = await links.createSignInLink(email);
    expect(link).toMatch(new RegExp(`^${BASE}/api/auth/magic-link/verify\\?token=`));
    const res = await server
      .getAuth()
      .handler(
        new Request(link!, { headers: { host: "localhost:3901", "x-real-ip": "198.51.100.1" } }),
      );
    expect(res.status).toBe(302);
    expect(new URL(res.headers.get("location")!, BASE).pathname).toBe("/auth/accept");
    const user = await userByEmail(email);
    expect(user.emailVerified).toBe(true);
    expect(await sessionsOf(user.id)).toHaveLength(1);
    expect((await auditFor(user.id)).map((a) => a.summary)).toContain(
      `${email} signed in (email link)`,
    );
    // The link works once.
    const again = await server.getAuth().handler(new Request(link!));
    expect(again.headers.get("location")).toContain("error=INVALID_TOKEN");

    state.cookie = cookieFrom(res);
    const to = await redirectOf(
      auth.completeAccount({
        fullName: "Mia Magic",
        password: "mia-pass-1",
        confirm: "mia-pass-1",
      }),
    );
    expect(to).toBe("/my-work");
    const after = await userByEmail(email);
    expect(after.fullName).toBe("Mia Magic");
    const [m] = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, user.id));
    expect(m.role).toBe("viewer");
    state.cookie = "";
    expect(await cookieFor(email, "mia-pass-1")).toContain("hp.session_token=");
  });

  it("set-up never replaces a password: someone with one is refused, and nothing changes", async () => {
    // Two sessions for someone who already has a password; one of them posts
    // the /auth/accept action directly with a password of their choosing.
    state.cookie = "";
    const id = await memberWithPassword("pat", "ops", "pat-real-pass");
    const [before] = await db
      .select()
      .from(schema.authAccount)
      .where(eq(schema.authAccount.userId, id));
    const cookieA = await cookieFor(mail("pat"), "pat-real-pass");
    await cookieFor(mail("pat"), "pat-real-pass");
    const auditBefore = (await auditFor(id)).length;
    state.cookie = cookieA;
    expect(
      await auth.completeAccount({
        fullName: "Taken Over",
        password: "attacker-pass-123",
        confirm: "attacker-pass-123",
      }),
    ).toEqual({ ok: false, error: messages.ALREADY_HAS_PASSWORD });
    const [after] = await db
      .select()
      .from(schema.authAccount)
      .where(eq(schema.authAccount.userId, id));
    expect(after.password).toBe(before.password);
    expect((await userByEmail(mail("pat"))).fullName).toBe("pat");
    expect(await sessionsOf(id)).toHaveLength(2);
    expect((await auditFor(id)).length).toBe(auditBefore);
    state.cookie = "";
    expect(
      await auth.signInWithPassword({ email: mail("pat"), password: "attacker-pass-123" }),
    ).toEqual({ ok: false, error: messages.INCORRECT });
  });

  it("set-up saves a password only when there is none (two tabs at once: the first wins)", async () => {
    const { setPasswordAndName } = await import("@/lib/auth/accounts");
    const id = randomUUID();
    const email = mail("tab");
    await db.insert(schema.users).values({ id, email, fullName: "", emailVerified: true });
    await db.insert(schema.memberships).values({ userId: id, organisationId: orgId, role: "ops" });
    const results = await Promise.all([
      setPasswordAndName({ userId: id, email, fullName: "Tab One", password: "tab-one-pass" }),
      setPasswordAndName({ userId: id, email, fullName: "Tab Two", password: "tab-two-pass" }),
    ]);
    expect(results.sort()).toEqual(["exists", "ok"]);
    const accounts = await db
      .select()
      .from(schema.authAccount)
      .where(eq(schema.authAccount.userId, id));
    expect(accounts).toHaveLength(1);
    const winner = (await userByEmail(email)).fullName;
    const winnerPass = winner === "Tab One" ? "tab-one-pass" : "tab-two-pass";
    expect(
      await password.verifyPassword({ hash: accounts[0].password!, password: winnerPass }),
    ).toBe(true);
    expect(
      (await auditFor(id)).filter((a) => a.summary.endsWith("set up their account")),
    ).toHaveLength(1);
    expect(
      await setPasswordAndName({ userId: id, email, fullName: "Later", password: "later-pass-1" }),
    ).toBe("exists");
  });

  it("sessions roll only where the cookie is rewritten too: route handlers and actions, not pages", async () => {
    // Better Auth extends a session once a day. A page render can't set
    // cookies, so rolling there would move the database alone and the
    // browser's cookie would still run out 30 days after sign-in.
    const DAY = 24 * 60 * 60 * 1000;
    const id = await memberWithPassword("rio", "ops", "rio-pass-123");
    state.cookie = await cookieFor(mail("rio"), "rio-pass-123");
    const age = () =>
      db
        .update(schema.authSession)
        .set({ expiresAt: new Date(Date.now() + 28 * DAY) })
        .where(eq(schema.authSession.userId, id));
    const expiry = async () => (await sessionsOf(id))[0].expiresAt.getTime();
    const { getAuthSession } = await import("@/lib/auth/session");
    try {
      await age();
      state.path = "/my-work"; // a page (document load or client navigation)
      expect((await getAuthSession())?.user.id).toBe(id);
      expect(await expiry()).toBeLessThan(Date.now() + 29 * DAY);

      state.path = "/api/session"; // the layouts' keep-alive ping
      const { GET } = await import("@/app/api/session/route");
      const res = await GET();
      expect(res.status).toBe(204);
      expect(res.headers.get("cache-control")).toBe("no-store");
      expect(await expiry()).toBeGreaterThan(Date.now() + 29 * DAY);

      await age();
      state.path = "/my-work";
      state.action = "7f00aa"; // a server action posted from that page
      expect((await getAuthSession())?.user.id).toBe(id);
      expect(await expiry()).toBeGreaterThan(Date.now() + 29 * DAY);

      state.action = "";
      state.path = "/api/session";
      state.cookie = "";
      expect((await GET()).status).toBe(401);
    } finally {
      state.path = "";
      state.action = "";
      state.cookie = "";
    }
  });

  it("an email link for someone never invited makes no account", async () => {
    const email = mail("stranger");
    const link = await links.createSignInLink(email);
    const res = await server.getAuth().handler(new Request(link!));
    expect(res.status).toBe(302);
    expect(res.headers.get("location")).toContain("/login?error=failed_to_create_user");
    expect(await userByEmail(email)).toBeUndefined();
  });

  it("reset by link: every old session ends, the new password works, the link works once", async () => {
    state.cookie = "";
    const sam = await userByEmail(mail("sam"));
    await db.delete(schema.authSession).where(eq(schema.authSession.userId, sam.id));
    await cookieFor(mail("sam"), "s3cure-pass");
    await cookieFor(mail("sam"), "s3cure-pass");
    const old = (await sessionsOf(sam.id)).map((s) => s.token);
    expect(old).toHaveLength(2);
    const link = await links.createPasswordResetLink(mail("sam"));
    expect(link).toMatch(new RegExp(`^${BASE}/reset-password\\?token=`));
    const token = new URL(link!).searchParams.get("token")!;
    expect(await links.resetTokenUserId(token)).toBe(sam.id);
    // Stored hashed: the token itself is nowhere in the table.
    const stored = await db
      .select()
      .from(schema.authVerification)
      .where(eq(schema.authVerification.value, sam.id));
    expect(stored.some((v) => v.identifier.includes(token))).toBe(false);

    const to = await redirectOf(
      auth.updatePassword({ token, password: "brand-new-pass", confirm: "brand-new-pass" }),
    );
    expect(to).toBe("/");
    const now = await sessionsOf(sam.id);
    expect(now.filter((s) => old.includes(s.token))).toEqual([]);
    expect(now).toHaveLength(1); // the link signed them in
    const [row] = (await auditFor(sam.id)).filter(
      (a) => a.summary === "Password changed (reset link)",
    );
    expect(row.after).toMatchObject({ sessionsEnded: 2 });
    expect(row.organisationId).toBe(orgId);
    expect(
      await auth.signInWithPassword({ email: mail("sam"), password: "s3cure-pass" }),
    ).toMatchObject({ ok: false, error: messages.INCORRECT });
    expect(await cookieFor(mail("sam"), "brand-new-pass")).toContain("hp.session_token=");
    expect(
      await auth.updatePassword({ token, password: "another-pass", confirm: "another-pass" }),
    ).toEqual({
      ok: false,
      error: "The link has expired — ask for a new one from the sign-in page",
    });
    expect(await links.resetTokenUserId(token)).toBeNull();
  });

  it("change password: checks the current one, keeps this session, ends the others", async () => {
    const sam = await userByEmail(mail("sam"));
    await db.delete(schema.authSession).where(eq(schema.authSession.userId, sam.id));
    state.cookie = "";
    const here = await cookieFor(mail("sam"), "brand-new-pass");
    await cookieFor(mail("sam"), "brand-new-pass");
    state.cookie = here;
    expect(
      await account.changeMyPassword({
        currentPassword: "not-it",
        password: "changed-pass",
        confirm: "changed-pass",
      }),
    ).toEqual({ ok: false, error: "Your current password isn't right" });
    expect(
      await account.changeMyPassword({
        currentPassword: "brand-new-pass",
        password: "changed-pass",
        confirm: "changed-pass",
      }),
    ).toMatchObject({ ok: true, message: "Password changed" });
    const left = await sessionsOf(sam.id);
    expect(left).toHaveLength(1);
    expect(here).toContain(left[0].token);
    const [row] = (await auditFor(sam.id)).filter((a) => a.summary === "Password changed");
    expect(row.after).toEqual({ sessionsEnded: 1 });
    expect(row.organisationId).toBe(orgId);
    state.cookie = "";
    expect(await cookieFor(mail("sam"), "changed-pass")).toContain("hp.session_token=");
  });

  it("a super admin makes sign-in and reset links; nobody else can, and only for their people", async () => {
    const sam = await userByEmail(mail("sam"));
    const sidId = (await userByEmail(mail("sid"))).id;
    const outsider = await memberWithPassword("olly", "ops", "olly-pass-1", {}, otherOrgId);
    state.cookie = await cookieFor(mail("alex"), ADMIN_PASSWORD);
    const made = await usersActions.createAccessLink({ userId: sam.id, kind: "sign_in" });
    expect(made).toMatchObject({ ok: true, data: { minutes: 60 } });
    const signIn = (made as { data: { url: string } }).data.url;
    expect(signIn).toContain("/api/auth/magic-link/verify?token=");
    const res = await server.getAuth().handler(new Request(signIn));
    expect(res.status).toBe(302);
    expect(new URL(res.headers.get("location")!, BASE).pathname).toBe("/");
    const reset = await usersActions.createAccessLink({ userId: sam.id, kind: "password_reset" });
    expect(reset).toMatchObject({ ok: true });
    expect((reset as { data: { url: string } }).data.url).toContain("/reset-password?token=");
    expect((await auditFor(sam.id)).map((a) => a.summary)).toEqual(
      expect.arrayContaining([
        `Made a sign-in link for ${mail("sam")}`,
        `Made a password reset link for ${mail("sam")}`,
      ]),
    );
    expect(await usersActions.createAccessLink({ userId: outsider, kind: "sign_in" })).toEqual({
      ok: false,
      error: "Person not found",
    });
    expect(await usersActions.createAccessLink({ userId: sidId, kind: "sign_in" })).toMatchObject({
      ok: false,
      error: expect.stringContaining("can't sign in at the moment"),
    });
    state.cookie = await cookieFor(mail("sam"), "changed-pass");
    expect(await usersActions.createAccessLink({ userId: sidId, kind: "sign_in" })).toEqual({
      ok: false,
      error: "Only a super admin can make sign-in links",
    });
    state.cookie = "";
  });

  it("someone invited again who has an account from before gets sign-in help (never another organisation's)", async () => {
    const { listGrants } = await import("@/lib/users/external");
    const { reinvitedAccounts } = await import("@/lib/users/reinvited");
    const account = async (key: string, external = false) => {
      const id = randomUUID();
      await db
        .insert(schema.users)
        .values({ id, email: mail(key), fullName: key, emailVerified: true, isExternal: external });
      await db.insert(schema.authAccount).values({
        userId: id,
        accountId: id,
        providerId: "credential",
        password: await password.hashPassword(`${key}-old-pass`),
      });
      return id;
    };
    // Removed from the team (no membership any more), then invited again.
    const remy = await account("remy");
    await staffInviteFor(mail("remy"), "ops");
    // A partner whose access was revoked, invited again (the new grant has no account yet).
    const paz = await account("paz", true);
    await db.insert(schema.externalGrants).values([
      {
        invitedEmail: mail("paz"),
        userId: paz,
        organisationId: orgId,
        editionId,
        role: "sponsor",
        invitedBy: adminId,
        inviteTokenHash: inviteToken.hashInviteToken(inviteToken.generateInviteToken()),
        acceptedAt: new Date(),
        revokedAt: new Date(),
      },
      {
        invitedEmail: mail("paz"),
        organisationId: orgId,
        editionId,
        role: "sponsor",
        invitedBy: adminId,
        inviteTokenHash: inviteToken.hashInviteToken(inviteToken.generateInviteToken()),
      },
    ]);
    // A member of another organisation whose email is invited here as a partner.
    const otto = await account("otto");
    await db
      .insert(schema.memberships)
      .values({ userId: otto, organisationId: otherOrgId, role: "ops" });
    await db.insert(schema.externalGrants).values({
      invitedEmail: mail("otto"),
      organisationId: orgId,
      editionId,
      role: "sponsor",
      invitedBy: adminId,
      inviteTokenHash: inviteToken.hashInviteToken(inviteToken.generateInviteToken()),
    });

    const found = await reinvitedAccounts(db, orgId, [mail("remy"), mail("PAZ"), mail("otto")]);
    expect(Object.fromEntries(found)).toEqual({ [mail("remy")]: remy, [mail("paz")]: paz });
    // Users → External: the waiting invitation knows the account it will sign in as.
    const rows = (await listGrants(db, orgId, null)).filter((g) => g.email === mail("paz"));
    expect(rows.map((g) => [g.status, g.accountUserId])).toEqual(
      expect.arrayContaining([
        ["invited", paz],
        ["revoked", paz],
      ]),
    );
    expect(
      (await listGrants(db, orgId, null)).find((g) => g.email === mail("otto"))?.accountUserId,
    ).toBeNull();

    state.cookie = await cookieFor(mail("alex"), ADMIN_PASSWORD);
    try {
      const reset = await usersActions.createAccessLink({ userId: remy, kind: "password_reset" });
      expect(reset).toMatchObject({ ok: true });
      const signIn = await usersActions.createAccessLink({ userId: paz, kind: "sign_in" });
      expect(signIn).toMatchObject({ ok: true });
      expect(await usersActions.createAccessLink({ userId: otto, kind: "sign_in" })).toEqual({
        ok: false,
        error: "Person not found",
      });
      // The reset link works: Remy chooses a new password and is signed in.
      const token = new URL((reset as { data: { url: string } }).data.url).searchParams.get(
        "token",
      )!;
      state.cookie = "";
      expect(
        await redirectOf(
          auth.updatePassword({ token, password: "remy-new-pass", confirm: "remy-new-pass" }),
        ),
      ).toBe("/");
      expect(await sessionsOf(remy)).toHaveLength(1);
    } finally {
      state.cookie = "";
    }
  });

  it("without email, links and resets say so (outside local development)", async () => {
    state.cookie = "";
    expect(await auth.signInWithMagicLink({ email: mail("sam") })).toEqual({
      ok: false,
      error: messages.EMAIL_OFF_LINK,
    });
    expect(await auth.sendPasswordReset({ email: mail("nobody") })).toEqual({
      ok: false,
      error: messages.EMAIL_OFF_RESET,
    });
  });

  it("when the rate limiter can't be asked, sign-in says it isn't working, not 'too many'", async () => {
    state.cookie = "";
    try {
      state.limiter = "unavailable";
      expect(
        await auth.signInWithPassword({ email: mail("sam"), password: "changed-pass" }),
      ).toEqual({ ok: false, error: messages.UNAVAILABLE });
      state.limiter = "limited";
      expect(
        await auth.signInWithPassword({ email: mail("sam"), password: "changed-pass" }),
      ).toEqual({ ok: false, error: messages.TOO_MANY });
    } finally {
      state.limiter = null;
    }
  });

  it("over HTTP only the email-link landing is open, and it never answers with a 500", async () => {
    const { GET, POST } = await import("@/app/api/auth/[...all]/route");
    for (const path of ["/api/auth/sign-in/email", "/api/auth/get-session", "/api/auth/ok"]) {
      expect((await GET(new Request(`${BASE}${path}`))).status, path).toBe(404);
    }
    expect(POST().status).toBe(404);
    const res = await GET(new Request(`${BASE}/api/auth/magic-link/verify?token=x`));
    expect(res.status).toBeGreaterThanOrEqual(300);
    expect(res.status).toBeLessThan(400);
    expect(res.headers.get("location")).toContain("error=");
    // Without its error landing (cut short), a link still fails to the sign-in page.
    expect(new URL(res.headers.get("location")!, BASE).pathname).toBe("/login");
    const { GET: callback } = await import("@/app/auth/callback/route");
    state.cookie = "";
    const cb = await callback(new Request(`${BASE}/auth/callback?code=old`));
    expect(cb.headers.get("location")).toBe(`${BASE}/login?error=auth`);
  });

  it("an email link cut short after its token still lands in the app, never on raw JSON", async () => {
    const { GET } = await import("@/app/api/auth/[...all]/route");
    state.cookie = "";
    const cut = (link: string) => link.slice(0, link.indexOf("&"));
    // Someone with an account: signed in, then the home page.
    await memberWithPassword("cora", "ops", "cora-pass-123");
    const link = await links.createSignInLink(mail("cora"), "/approvals");
    expect(cut(link!)).toMatch(/\/api\/auth\/magic-link\/verify\?token=[^&]+$/);
    const res = await GET(new Request(cut(link!), { headers: { "x-real-ip": "198.51.100.3" } }));
    expect(res.status).toBe(302);
    expect(await res.text()).not.toContain("token");
    expect(new URL(res.headers.get("location")!, BASE).pathname).toBe("/");
    expect(res.headers.getSetCookie().join(";")).toContain("hp.session_token=");
    // A new invitee: their account is made, then they choose a name and password.
    const email = mail("nell");
    await staffInviteFor(email, "viewer");
    const first = await links.createSignInLink(email);
    const landed = await GET(
      new Request(cut(first!), { headers: { "x-real-ip": "198.51.100.3" } }),
    );
    expect(landed.status).toBe(302);
    expect(new URL(landed.headers.get("location")!, BASE).pathname).toBe("/auth/accept");
    expect((await userByEmail(email)).emailVerified).toBe(true);
  });
});
