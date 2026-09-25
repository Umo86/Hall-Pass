import "server-only";
import { and, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { externalGrants, memberships, staffInvites, users } from "@/lib/db/schema";
import { appUrl } from "@/lib/app-url";
import { supabaseAdmin } from "./supabase-admin";
import { createSupabaseServerClient } from "./supabase-server";

export type AccountEmailResult =
  /** Supabase emailed a link to create their account. */
  | "invite_sent"
  /** They already have an account: Supabase emailed a sign-in link. */
  | "signin_sent"
  /** Nothing could be sent (Supabase not set up here, or it refused). */
  | "not_sent";

/**
 * Is this email allowed into Hall Pass? Only people with a team membership,
 * an open staff invitation or a live partner invitation. Everyone else is
 * turned away without an email — there is no sign-up.
 */
export async function emailIsInvited(email: string): Promise<boolean> {
  const e = email.trim().toLowerCase();
  const [member] = await db
    .select({ id: memberships.id })
    .from(memberships)
    .innerJoin(users, eq(users.id, memberships.userId))
    .where(eq(users.email, e))
    .limit(1);
  if (member) return true;
  const [invite] = await db
    .select({ id: staffInvites.id })
    .from(staffInvites)
    .where(
      and(
        eq(staffInvites.invitedEmail, e),
        isNull(staffInvites.acceptedAt),
        isNull(staffInvites.revokedAt),
      ),
    )
    .limit(1);
  if (invite) return true;
  const grants = await db
    .select({ expiresAt: externalGrants.expiresAt })
    .from(externalGrants)
    .where(and(eq(externalGrants.invitedEmail, e), isNull(externalGrants.revokedAt)));
  return grants.some((g) => !g.expiresAt || g.expiresAt.getTime() > Date.now());
}

/**
 * Email an invited person the way in, through Supabase: a link to create
 * their account (name and password) the first time, or a sign-in link if
 * they already have one. The link only works from their inbox, so only the
 * invited email can create the account.
 */
export async function sendAccountEmail(
  email: string,
  opts: { fullName?: string | null } = {},
): Promise<AccountEmailResult> {
  const e = email.trim().toLowerCase();
  const base = appUrl();
  const admin = supabaseAdmin();
  if (admin) {
    const { error } = await admin.auth.admin.inviteUserByEmail(e, {
      redirectTo: `${base}/auth/accept`,
      data: opts.fullName ? { full_name: opts.fullName } : undefined,
    });
    if (!error) return "invite_sent";
    const exists = error.status === 422 || /already|registered|exists/i.test(error.message);
    if (!exists) {
      console.error("sendAccountEmail: invite failed", error.status, error.message);
      return "not_sent";
    }
  }
  // Already has an account (or no service key): a sign-in link, never a new account
  // unless they're invited and there's no other way.
  const supabase = await createSupabaseServerClient();
  if (!supabase) return "not_sent";
  const { error } = await supabase.auth.signInWithOtp({
    email: e,
    options: {
      shouldCreateUser: !admin,
      // A brand-new account (no service key to invite with) still needs its
      // name and password set; an existing one just signs in.
      emailRedirectTo: `${base}/auth/callback?next=${encodeURIComponent(admin ? "/" : "/auth/accept")}`,
    },
  });
  if (error) {
    console.error("sendAccountEmail: sign-in link failed", error.status, error.message);
    return "not_sent";
  }
  return "signin_sent";
}
