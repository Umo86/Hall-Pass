/**
 * What to tell someone whose password sign-in failed. A wrong email or
 * password gets the usual reply; anything else (a wrong or disabled API key,
 * email sign-in switched off, Supabase unreachable) says so, so the admin
 * can fix the set-up instead of everyone retyping their password.
 */
export function signInErrorMessage(error: {
  code?: string;
  status?: number;
  message?: string;
}): string {
  const msg = error.message ?? "";
  if (error.code === "invalid_credentials" || /invalid login credentials/i.test(msg)) {
    return "Incorrect email or password";
  }
  if (error.code === "email_not_confirmed") {
    return "This email hasn't been confirmed yet — use the link in your invitation email";
  }
  const detail = msg.trim() || (error.status ? `error ${error.status}` : "no reply");
  return `Sign-in isn't working right now (${detail}). Please tell your admin.`;
}

/** The Supabase project id from its URL, for logs and set-up checks. */
export function supabaseProjectRef(url: string | undefined): string {
  if (!url) return "not set";
  try {
    return new URL(url).hostname.split(".")[0];
  } catch {
    return "invalid URL";
  }
}

/** The Supabase project a database URL points at (never the password). */
export function databaseProjectRef(url: string | undefined): string {
  if (!url) return "not set";
  try {
    const u = new URL(url);
    const fromUser = /^postgres\.([a-z0-9]+)$/.exec(decodeURIComponent(u.username));
    if (fromUser) return fromUser[1];
    const fromHost = /^db\.([a-z0-9]+)\.supabase\.co$/.exec(u.hostname);
    if (fromHost) return fromHost[1];
    return "not a Supabase database";
  } catch {
    return "invalid URL";
  }
}

export type AuthServiceStatus =
  | "ok"
  | "not configured"
  | "email sign-in is switched off"
  | "key rejected"
  | "unreachable"
  | `error ${number}`;

/**
 * Ask the configured Supabase Auth whether it accepts our public key and
 * allows email sign-in. Public information only; nothing secret is sent.
 */
export async function checkAuthService(
  url: string | undefined,
  key: string | undefined,
  fetchImpl: typeof fetch = fetch,
): Promise<AuthServiceStatus> {
  if (!url || !key) return "not configured";
  try {
    const res = await fetchImpl(`${url.replace(/\/$/, "")}/auth/v1/settings`, {
      headers: { apikey: key },
      signal: AbortSignal.timeout(4000),
      cache: "no-store",
    });
    if (res.status === 401 || res.status === 403) return "key rejected";
    if (!res.ok) return `error ${res.status}`;
    const settings = (await res.json()) as { external?: { email?: boolean } };
    return settings.external?.email === false ? "email sign-in is switched off" : "ok";
  } catch {
    return "unreachable";
  }
}
