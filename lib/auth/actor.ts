import "server-only";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { and, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  externalGrants,
  memberships,
  organisations,
  users,
  type OrganisationSettings,
} from "@/lib/db/schema";
import type { Actor, ExternalActor, StaffActor } from "@/lib/authz";
import { createSupabaseServerClient, supabaseConfigured } from "./supabase-server";

export const DEV_COOKIE = "hp-dev-user";

/**
 * Development sign-in is available when Supabase Auth is not configured and
 * explicitly enabled. It lets the seeded users be assumed via a cookie so
 * the platform can be demonstrated with only a database connection.
 * An explicit DEV_AUTH=1 always enables it (even with Supabase configured,
 * so a project without auth users yet is never locked out); the automatic
 * enable in local development applies only while Supabase is unconfigured.
 * Remove DEV_AUTH before real users arrive.
 */
export function devAuthEnabled(): boolean {
  if (process.env.DEV_AUTH === "1") return true;
  if (supabaseConfigured()) return false;
  return process.env.NODE_ENV === "development";
}

export type Session = {
  actor: Actor;
  user: { id: string; email: string; fullName: string; isExternal: boolean };
  organisation: { id: string; brandName: string; settings: OrganisationSettings };
};

/** Session for a user id without cookies — used by the tokenised iCal feed. */
export async function sessionForUserId(userId: string): Promise<Session | null> {
  return loadSessionForUserId(userId);
}

async function loadSessionForUserId(userId: string): Promise<Session | null> {
  const user = await db.query.users.findFirst({ where: eq(users.id, userId) });
  if (!user) return null;
  return loadSessionForUser(user);
}

async function loadSessionForUser(user: typeof users.$inferSelect): Promise<Session | null> {
  const membership = await db.query.memberships.findFirst({
    where: eq(memberships.userId, user.id),
  });
  if (membership) {
    const org = await db.query.organisations.findFirst({
      where: eq(organisations.id, membership.organisationId),
    });
    if (!org) return null;
    const actor: StaffActor = {
      kind: "staff",
      userId: user.id,
      organisationId: org.id,
      role: membership.role,
    };
    return {
      actor,
      user: { id: user.id, email: user.email, fullName: user.fullName, isExternal: false },
      organisation: { id: org.id, brandName: org.brandName, settings: org.settings },
    };
  }

  let grants = await db.query.externalGrants.findMany({
    where: eq(externalGrants.userId, user.id),
  });
  if (grants.length === 0) {
    // Claim invitations sent to this email on first sign-in.
    const claimed = await db
      .update(externalGrants)
      .set({ userId: user.id, acceptedAt: new Date() })
      .where(and(eq(externalGrants.invitedEmail, user.email), isNull(externalGrants.userId)))
      .returning();
    grants = claimed;
  }
  if (grants.length === 0) return null;
  const org = await db.query.organisations.findFirst({
    where: eq(organisations.id, grants[0].organisationId),
  });
  if (!org) return null;
  const actor: ExternalActor = {
    kind: "external",
    userId: user.id,
    organisationId: org.id,
    grants: grants.map((g) => ({
      role: g.role,
      editionId: g.editionId,
      scopeType: g.scopeType,
      scopeId: g.scopeId,
      expiresAt: g.expiresAt,
      revokedAt: g.revokedAt,
    })),
  };
  return {
    actor,
    user: { id: user.id, email: user.email, fullName: user.fullName, isExternal: true },
    organisation: { id: org.id, brandName: org.brandName, settings: org.settings },
  };
}

/** The current session, or null when signed out. */
export async function getSession(): Promise<Session | null> {
  const supabase = await createSupabaseServerClient();
  if (supabase) {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      const existing = await loadSessionForUserId(user.id);
      if (existing) return existing;
      // First sign-in: create the app user row keyed by the auth uid.
      if (user.email) {
        await db
          .insert(users)
          .values({ id: user.id, email: user.email, fullName: "" })
          .onConflictDoNothing();
        return loadSessionForUserId(user.id);
      }
      return null;
    }
    // No Supabase user: fall through — DEV_AUTH=1 keeps the dev cookie
    // usable even with Supabase configured, so demos are never locked out.
  }
  if (devAuthEnabled()) {
    const store = await cookies();
    const email = store.get(DEV_COOKIE)?.value;
    if (!email) return null;
    const user = await db.query.users.findFirst({ where: eq(users.email, email) });
    if (!user) return null;
    return loadSessionForUser(user);
  }
  return null;
}

export async function requireSession(): Promise<Session> {
  const session = await getSession();
  if (!session) redirect("/login");
  return session;
}

export async function requireStaffSession(): Promise<Session & { actor: StaffActor }> {
  const session = await requireSession();
  if (session.actor.kind !== "staff") redirect("/portal/approvals");
  return session as Session & { actor: StaffActor };
}

export async function requirePortalSession(): Promise<Session & { actor: ExternalActor }> {
  const session = await requireSession();
  if (session.actor.kind !== "external") redirect("/editions");
  return session as Session & { actor: ExternalActor };
}
