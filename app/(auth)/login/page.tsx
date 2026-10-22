import type { ReactNode } from "react";
import { redirect } from "next/navigation";
import { LoginCard, type DevUser } from "@/components/auth/login-card";
import { brandName } from "@/lib/config";
import { demoEmailAllowed, devAuthEnabled, getAccessBlock, getSession } from "@/lib/auth/actor";
import type { AccessBlock } from "@/lib/access";
import { authConfigured, demoLoginPassword, devLinksShown } from "@/lib/auth/config";
import { listDemoLogins } from "@/lib/auth/demo-logins";
import { getAuthSession } from "@/lib/auth/session";
import { loginNotice } from "@/lib/auth/messages";
import { emailConfigured } from "@/lib/email/dispatch";
import { PORTAL_HOME, STAFF_HOME, safeNext } from "@/lib/edition-path";
import { roleLabel } from "@/lib/format";
import { brandImage } from "@/lib/brand-images";
import { checkDatabase } from "@/lib/db/status";

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
 * who to ask — by name, with their email as a link when it is known.
 */
function blockedNotice(block: AccessBlock): ReactNode {
  const name = block.askName?.trim();
  const email = block.askEmail?.trim();
  const who = name ? (
    <>
      {name}
      {email && (
        <>
          {" ("}
          <a href={`mailto:${email}`} className="font-medium underline underline-offset-2">
            {email}
          </a>
          {")"}
        </>
      )}
    </>
  ) : (
    "a super admin"
  );
  return block.state === "suspended" ? (
    <>Your access is paused for now. To get it back, ask {who}.</>
  ) : (
    <>Your access has ended. If you still need it, ask {who} to give you a new end date.</>
  );
}

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

  // Signed in but not invited (Better Auth's session gate makes this all but
  // impossible): explain instead of looping.
  const unprovisionedEmail = !block
    ? ((await getAuthSession().catch(() => null))?.user.email ?? null)
    : null;

  // Self-diagnosis for the unconfigured state, so a misdeployed instance
  // says exactly what is missing instead of a dead end — about the
  // connection actually used (DATABASE_TARGET=neon: POSTGRES_URL).
  const database = await checkDatabase({ depth: "ping" });
  const databaseReachable = database.state === "ok";
  // A plain "not set" shows the setup hint instead.
  const databaseError =
    !databaseReachable && (database.info || database.misconfigured)
      ? (database.error ?? null)
      : null;

  // Demo logins (testing only): the seeded accounts and their shared password.
  const demoPassword = demoLoginPassword();
  const demoLogins =
    demoPassword && databaseReachable ? await listDemoLogins().catch(() => []) : [];

  return (
    <LoginCard
      brandName={brandName}
      passwordSignIn={authConfigured()}
      demoLogins={
        demoPassword && demoLogins.length > 0
          ? { password: demoPassword, accounts: demoLogins }
          : null
      }
      emailEnabled={emailConfigured()}
      devLinks={authConfigured() && !emailConfigured() && devLinksShown()}
      devEnabled={devAuthEnabled()}
      devUsers={await devUserList()}
      photo={brandImage("login")}
      next={next}
      notice={block ? blockedNotice(block) : loginNotice(error)}
      unprovisionedEmail={unprovisionedEmail}
      configStatus={{
        authSecret: authConfigured(),
        databaseUrl: Boolean(database.info),
        databaseReachable,
        databaseError,
        // Whether demo sign-in actually works here (never on Vercel production, whatever DEV_AUTH says).
        devAuth: devAuthEnabled(),
      }}
    />
  );
}
