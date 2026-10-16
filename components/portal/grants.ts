import "server-only";
/**
 * Partner portal access for one kind of company (suppliers or venues), to
 * show next to each one: who can sign in, for which event.
 */
import { and, desc, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { editions, externalGrants, users } from "@/lib/db/schema";
import { londonDateOfAccessEnd } from "@/lib/access";
import { grantStatus, type GrantStatus } from "./summary";

export type PortalGrant = {
  id: string;
  name: string | null;
  email: string;
  editionId: string;
  eventCode: string;
  eventName: string;
  status: Exclude<GrantStatus, "revoked">;
  expiresAt: string | null;
  /** The London date access ends (or ended) on. */
  endsOn: string | null;
};

/**
 * Every grant for venues or suppliers in the organisation that hasn't been
 * revoked, newest first, grouped by the venue or supplier it is for.
 */
export async function portalGrantsByScope(
  organisationId: string,
  scopeType: "supplier" | "venue",
): Promise<Map<string, PortalGrant[]>> {
  const rows = await db
    .select({
      g: externalGrants,
      name: users.fullName,
      eventCode: editions.code,
      eventName: editions.name,
    })
    .from(externalGrants)
    .leftJoin(users, eq(externalGrants.userId, users.id))
    .leftJoin(editions, eq(editions.id, externalGrants.editionId))
    .where(
      and(
        eq(externalGrants.organisationId, organisationId),
        eq(externalGrants.scopeType, scopeType),
        isNull(externalGrants.revokedAt),
      ),
    )
    .orderBy(desc(externalGrants.createdAt));
  const now = new Date();
  const out = new Map<string, PortalGrant[]>();
  for (const { g, name, eventCode, eventName } of rows) {
    if (!g.scopeId) continue;
    const status = grantStatus(g, now);
    if (status === "revoked") continue;
    const list = out.get(g.scopeId) ?? [];
    list.push({
      id: g.id,
      name: name || null,
      email: g.invitedEmail,
      editionId: g.editionId,
      eventCode: eventCode ?? "—",
      eventName: eventName ?? "an event that no longer exists",
      status,
      expiresAt: g.expiresAt ? g.expiresAt.toISOString() : null,
      endsOn: g.expiresAt ? londonDateOfAccessEnd(g.expiresAt) : null,
    });
    out.set(g.scopeId, list);
  }
  return out;
}
