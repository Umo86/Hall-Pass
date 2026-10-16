import { redirect } from "next/navigation";
import { LoginCard, type DevUser } from "@/components/auth/login-card";
import { brandName } from "@/lib/config";
import { demoEmailAllowed, devAuthEnabled, getAccessBlock, getSession } from "@/lib/auth/actor";
import type { AccessBlock } from "@/lib/access";
import { createSupabaseServerClient, supabaseConfigured } from "@/lib/auth/supabase-server";
import { supabaseUrl } from "@/lib/auth/supabase-config";
import { PORTAL_HOME, STAFF_HOME, safeNext } from "@/lib/edition-path";
import { roleLabel } from "@/lib/format";
import { brandImage } from "@/lib/brand-images";

export const metadata = { title: "Sign in" };
export const dynamic = "force-dynamic";

async function devUserList(): Promise<DevUser[]> {
  if (!devAuthEnabled()) return [];
  try {
    const { asc, eq } = await import("drizzle-orm");
    const { db } = await import("@/lib/db/client");
    const { externalGrants, memberships, users } = await import("@/lib/db/schema");
    // Oldest first, so the seeded accounts are always on the list however many
    // people later runs have added (without an order the 30 were arbitrary).
    const rows = await db
      .select({ user: users, membership: memberships })
      .from(users)
      .leftJoin(memberships, eq(memberships.userId, users.id))
      .orderBy(asc(users.createdAt), asc(users.email))
      .limit(30);
    const grants = await db.select().from(externalGrants);
    return rows
      .map(({ user, membership }) => {
        const grant = grants.find((g) => g.userId === user.id && !g.revokedAt);
        const role = membership?.role ?? grant?.role ?? null;
        if (!role) return null;
        return {
          email: user.email,
          name: user.fullName || user.email.split("@")[0],
          role: roleLabel(role),
          isExternal: !membership,
        };
      })
      .filter((u): u is DevUser => u !== null && demoEmailAllowed(u.email))
      .sort((a, b) => Number(a.isExternal) - Number(b.isExternal));
  } catch {
    return [];
  }
}

/**
 * Why a suspended person, or one whose access has ended, can't get in, and
 * who to ask — by name, with their email when it is known.
 */
function blockedNotice(block: AccessBlock & { askEmail?: string | null }): string {
  const name = block.askName?.trim();
  const email = block.askEmail?.trim();
  const who = name ? `${name}${email ? ` (${email})` : ""}` : "a super admin";
  return block.state === "suspended"
    ? `Your access is paused for now. To get it back, ask ${who}.`
    : `Your access has ended. If you still need it, ask ${who} to give you a new end date.`;
}

const NOTICES: Record<string, string> = {
  auth: "That sign-in link has expired or was already used — ask for a new one below.",
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string; error?: string }>;
}) {
  const { next: rawNext, error } = await searchParams;
  const next = safeNext(rawNext);
  const session = await getSession().catch(() => null);
  if (session) redirect(next ?? (session.actor.kind === "staff" ? STAFF_HOME : PORTAL_HOME));

  // Suspended, or access ended: say so and who to ask, instead of looping.
  const block = await getAccessBlock().catch(() => null);

  // Signed in with Supabase but not invited: explain instead of looping.
  let unprovisionedEmail: string | null = null;
  const supabase = await createSupabaseServerClient().catch(() => null);
  if (supabase && !block) {
    const { data } = await supabase.auth.getUser().catch(() => ({ data: { user: null } }));
    unprovisionedEmail = data.user?.email ?? null;
  }

  // Self-diagnosis for the unconfigured state, so a misdeployed instance
  // says exactly what is missing instead of a dead end.
  let databaseReachable = false;
  let databaseError: string | null = null;
  if (process.env.DATABASE_URL) {
    try {
      const { sql } = await import("drizzle-orm");
      const { db } = await import("@/lib/db/client");
      await db.execute(sql`SELECT 1`);
      databaseReachable = true;
    } catch (err) {
      const { describeDbError } = await import("@/lib/db/diagnose");
      databaseError = describeDbError(err, process.env.DATABASE_URL);
    }
  }

  return (
    <LoginCard
      brandName={brandName}
      supabaseEnabled={supabaseConfigured()}
      devEnabled={devAuthEnabled()}
      devUsers={await devUserList()}
      photo={brandImage("login")}
      next={next}
      notice={
        block
          ? blockedNotice(block)
          : error
            ? (NOTICES[error] ?? "Sign-in didn't work — please try again.")
            : null
      }
      unprovisionedEmail={unprovisionedEmail}
      configStatus={{
        supabaseUrl: Boolean(supabaseUrl()),
        supabaseKey: Boolean(
          process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
          process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
        ),
        databaseUrl: Boolean(process.env.DATABASE_URL),
        databaseReachable,
        databaseError,
        devAuth: process.env.DEV_AUTH === "1",
      }}
    />
  );
}
