import "server-only";
import { AsyncLocalStorage } from "node:async_hooks";
import { eq } from "drizzle-orm";
import { betterAuth } from "better-auth/minimal";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { magicLink } from "better-auth/plugins/magic-link";
import { nextCookies } from "better-auth/next-js";
import { createAuthMiddleware } from "better-auth/api";
import { db } from "@/lib/db/client";
import { authAccount, authSession, authVerification, users } from "@/lib/db/schema";
import { brandName } from "@/lib/config";
import {
  COOKIE_PREFIX,
  LINK_MINUTES,
  SESSION_DAYS,
  authBaseURL,
  authTrustedOrigins,
  demoAccountLocked,
} from "./config";
import { authSecret } from "./secret";
import { hashPassword, isLegacyHash, verifyPassword } from "./password";
import { consumeRateLimit, rateLimitEnabled } from "./rate-limit";
import { auditSignIn, emailIsInvited } from "./account-link";
import { sendMagicLinkEmail, sendPasswordResetEmail } from "./emails";

/**
 * While a super admin makes a link to pass on (lib/auth/links.ts), or local
 * development shows one, the magic-link or reset email is handed back here
 * instead of being sent.
 */
export const linkCapture = new AsyncLocalStorage<{ url?: string }>();

async function invitedUserId(userId: string): Promise<boolean> {
  const u = await db.query.users.findFirst({
    where: eq(users.id, userId),
    columns: { email: true },
  });
  // Demo logins off on this deployment: no new session for a demo account by any route.
  return Boolean(u && !demoAccountLocked(u.email) && (await emailIsInvited(u.email)));
}

function createAuth() {
  return betterAuth({
    appName: brandName,
    baseURL: authBaseURL(),
    // BETTER_AUTH_SECRET, or on Vercel production one derived from CRON_SECRET
    // (lib/auth/secret.ts). Better Auth refuses its default secret in production.
    secret: authSecret() ?? undefined,
    trustedOrigins: authTrustedOrigins(),
    database: drizzleAdapter(db, {
      provider: "pg",
      transaction: true,
      schema: { users, authSession, authAccount, authVerification },
    }),
    user: {
      modelName: "users",
      fields: { name: "fullName", image: "avatarPath" },
      changeEmail: { enabled: false },
      deleteUser: { enabled: false },
    },
    session: {
      modelName: "authSession",
      expiresIn: SESSION_DAYS * 24 * 60 * 60,
      updateAge: 24 * 60 * 60,
      cookieCache: { enabled: false },
    },
    account: { modelName: "authAccount", accountLinking: { enabled: false } },
    verification: { modelName: "authVerification", storeIdentifier: "hashed" },
    emailAndPassword: {
      enabled: true,
      // No sign-up: accounts are made from invitations (lib/auth/accounts.ts).
      disableSignUp: true,
      minPasswordLength: 8,
      maxPasswordLength: 200,
      resetPasswordTokenExpiresIn: LINK_MINUTES * 60,
      revokeSessionsOnPasswordReset: true,
      password: { hash: hashPassword, verify: verifyPassword },
      sendResetPassword: async ({ user, token }) => {
        // Our own page takes the token straight away (no Better Auth redirect hop).
        const url = `${authBaseURL()}/reset-password?token=${encodeURIComponent(token)}`;
        const capture = linkCapture.getStore();
        if (capture) {
          capture.url = url;
          return;
        }
        await sendPasswordResetEmail({ to: user.email, name: user.name, userId: user.id, url });
      },
    },
    rateLimit: {
      enabled: rateLimitEnabled(),
      window: 60,
      max: 100,
      customRules: { "/magic-link/verify": { window: 15 * 60, max: 20 } },
      customStorage: { consume: consumeRateLimit },
    },
    advanced: {
      cookiePrefix: COOKIE_PREFIX,
      useSecureCookies: authBaseURL().startsWith("https://"),
      ipAddress: { ipAddressHeaders: ["x-real-ip", "x-forwarded-for"] },
      database: { generateId: "uuid" },
    },
    onAPIError: { errorURL: "/login" },
    telemetry: { enabled: false },
    databaseHooks: {
      // The only place Better Auth may create a user: a magic link for an
      // invited email with no account yet.
      user: {
        create: {
          before: async (user) => ((await emailIsInvited(user.email)) ? undefined : false),
        },
      },
      session: {
        create: {
          // An account alone isn't enough: on the team (not suspended, not
          // ended) or a live partner invitation.
          before: async (session) => ((await invitedUserId(session.userId)) ? undefined : false),
          // Sign-ins by email link are recorded here; password sign-ins in app/actions/auth.ts.
          after: async (session, ctx) => {
            if (ctx?.path !== "/magic-link/verify") return;
            const u = await db.query.users.findFirst({ where: eq(users.id, session.userId) });
            if (u) await auditSignIn(u, "link");
          },
        },
      },
    },
    hooks: {
      // A carried-over bcrypt hash is replaced by scrypt at the first good password sign-in.
      after: createAuthMiddleware(async (ctx) => {
        if (ctx.path !== "/sign-in/email" || !ctx.context.newSession) return;
        const userId = ctx.context.newSession.user.id;
        const account = await ctx.context.internalAdapter.findCredentialAccount(userId);
        if (account?.password && isLegacyHash(account.password)) {
          await ctx.context.internalAdapter.updatePassword(
            userId,
            await ctx.context.password.hash(String(ctx.body.password)),
          );
        }
      }),
    },
    plugins: [
      magicLink({
        expiresIn: LINK_MINUTES * 60,
        // Gated by databaseHooks.user.create.before (invited emails only).
        disableSignUp: false,
        storeToken: "hashed",
        sendMagicLink: async ({ email, url }) => {
          const capture = linkCapture.getStore();
          if (capture) {
            capture.url = url;
            return;
          }
          if (!(await sendMagicLinkEmail({ to: email, url }))) {
            throw new Error("magic link email not sent");
          }
        },
      }),
      // Must stay last: sets cookies from server actions and route handlers.
      nextCookies(),
    ],
  });
}

type Auth = ReturnType<typeof createAuth>;
let instance: Auth | undefined;

/**
 * The Better Auth instance, made on first use. Better Auth starts
 * initialising when it is created (and refuses a missing secret in
 * production), so it is never created at import time: `next build` and the
 * tests import this module freely. Callers check authConfigured() first.
 */
export function getAuth(): Auth {
  return (instance ??= createAuth());
}
