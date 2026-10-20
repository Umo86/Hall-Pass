/**
 * Sign-in configuration: pure functions of the environment, no secrets
 * returned (lib/auth/secret.ts derives the secret itself). Unit-tested in
 * tests/unit/auth-config.test.ts.
 */
type Env = Record<string, string | undefined>;

/** Message the production secret is derived from (HMAC key: CRON_SECRET). */
export const DERIVED_SECRET_LABEL = "hall-pass:better-auth:v1";

/** This is the production deployment on Vercel. */
export function onVercelProduction(env: Env = process.env): boolean {
  return env.VERCEL_ENV === "production";
}

/**
 * Where Better Auth's secret comes from: BETTER_AUTH_SECRET when it is set;
 * otherwise, on Vercel production only, it is derived from CRON_SECRET (so no
 * new secret has to be typed or shown anywhere); otherwise there is none.
 */
export function authSecretSource(env: Env = process.env): "env" | "derived" | null {
  if (env.BETTER_AUTH_SECRET?.trim()) return "env";
  if (onVercelProduction(env) && env.CRON_SECRET?.trim()) return "derived";
  return null;
}

/** Real sign-in (Better Auth) is set up on this deployment. */
export function authConfigured(env: Env = process.env): boolean {
  return authSecretSource(env) !== null;
}

/** Session length (rolling) and link lifetime. */
export const SESSION_DAYS = 30;
export const LINK_MINUTES = 60;
/** Cookies: hp.session_token (__Secure-hp.session_token on https). */
export const COOKIE_PREFIX = "hp";

/** The app's public origin for auth links: NEXT_PUBLIC_APP_URL, else Vercel's domain, else localhost:PORT. */
export function authBaseURL(env: Env = process.env): string {
  const explicit = env.NEXT_PUBLIC_APP_URL?.trim();
  if (explicit) return explicit.replace(/\/$/, "");
  const vercel = env.VERCEL_PROJECT_PRODUCTION_URL ?? env.VERCEL_BRANCH_URL ?? env.VERCEL_URL;
  if (vercel) return `https://${vercel.replace(/\/$/, "")}`;
  return `http://localhost:${env.PORT ?? "3000"}`; // next dev/start set PORT
}

/** Origins Better Auth trusts: the base URL plus this deployment's own Vercel URLs. */
export function authTrustedOrigins(env: Env = process.env): string[] {
  const list = [authBaseURL(env)];
  for (const host of [env.VERCEL_URL, env.VERCEL_BRANCH_URL])
    if (host) list.push(`https://${host}`);
  return [...new Set(list.map((u) => new URL(u).origin))];
}

/**
 * Demo sign-in (hp-dev-user cookie). Never on Vercel production, whatever
 * DEV_AUTH says (VERCEL_TARGET_ENV is checked too, in case only that one is
 * exposed); never on any other Vercel deployment with real sign-in; DEV_AUTH=1
 * turns it on elsewhere (also next to real sign-in, so CI and demos work);
 * local `next dev` has it on while real sign-in isn't set up.
 */
export function devAuthEnabled(env: Env = process.env): boolean {
  if (onVercelProduction(env) || env.VERCEL_TARGET_ENV === "production") return false;
  if (env.VERCEL_ENV && authConfigured(env)) return false;
  if (env.DEV_AUTH === "1") return true;
  if (authConfigured(env)) return false;
  return env.NODE_ENV === "development";
}

/** With real sign-in set up, demo sign-in only works for the seeded …@….test accounts. */
export function demoEmailAllowed(email: string, env: Env = process.env): boolean {
  return !authConfigured(env) || email.trim().toLowerCase().endsWith(".test");
}

/** Local development without email: show the link that would have been emailed. */
export function devLinksShown(env: Env = process.env): boolean {
  return (
    env.NODE_ENV === "development" && !env.VERCEL_ENV && !(env.RESEND_API_KEY && env.EMAIL_FROM)
  );
}
