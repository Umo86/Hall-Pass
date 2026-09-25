import "server-only";
import { and, count, eq, inArray, isNull, lt, ne, or, sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  approvalInstances,
  editions,
  exhibitors,
  signageItems,
  standSubmissions,
} from "@/lib/db/schema";
import { effectiveDeadline, type DeadlineKey } from "@/lib/deadlines";
import { todayInLondon } from "@/lib/today";
import { editionForDeadlines } from "./editions";
import { standsEnabled } from "@/lib/config";

export async function dashboardData(editionId: string) {
  const liveItems = and(eq(signageItems.editionId, editionId), isNull(signageItems.deletedAt));
  const signageOnly = and(liveItems, eq(signageItems.kind, "signage"));
  // Open sign-offs for this show's live, not-held items (and stands when on),
  // as subqueries so the ids never make a round trip.
  const itemIds = db
    .select({ id: signageItems.id })
    .from(signageItems)
    .where(and(liveItems, ne(signageItems.status, "on_hold")));
  const subIds = db
    .select({ id: standSubmissions.id })
    .from(standSubmissions)
    .where(eq(standSubmissions.editionId, editionId));

  const [statusCounts, sponsorshipCount, standCounts, budgetRow, edition, pendingRows, forDeadlines] =
    await Promise.all([
      db
        // Same items as the signage schedule: organiser and sponsor signage
        // plus everything from the Sponsorship section.
        .select({ status: signageItems.status, n: count() })
        .from(signageItems)
        .where(liveItems)
        .groupBy(signageItems.status),
      db
        .select({ n: count() })
        .from(signageItems)
        .where(and(liveItems, eq(signageItems.category, "sponsor"))),
      standsEnabled
        ? db
            .select({ status: standSubmissions.status, n: count() })
            .from(standSubmissions)
            .innerJoin(exhibitors, eq(standSubmissions.exhibitorId, exhibitors.id))
            .where(
              and(eq(standSubmissions.editionId, editionId), eq(exhibitors.standType, "space_only")),
            )
            .groupBy(standSubmissions.status)
        : Promise.resolve([] as { status: string; n: number }[]),
      // The signage budget covers signage; sponsorship items are sold separately.
      db
        .select({
          estimate: sql<string>`coalesce(sum(${signageItems.costEstimate}), 0)`,
          actual: sql<string>`coalesce(sum(${signageItems.costActual}), 0)`,
        })
        .from(signageItems)
        .where(signageOnly),
      db.select().from(editions).where(eq(editions.id, editionId)).limit(1),
      db
        .select()
        .from(approvalInstances)
        .where(
          and(
            eq(approvalInstances.status, "pending"),
            standsEnabled
              ? or(inArray(approvalInstances.entityId, itemIds), inArray(approvalInstances.entityId, subIds))
              : and(
                  eq(approvalInstances.entityType, "signage_item"),
                  inArray(approvalInstances.entityId, itemIds),
                ),
          ),
        ),
      editionForDeadlines(editionId),
    ]);

  const sittingWith = new Map<string, number>();
  for (const p of pendingRows) {
    const key = p.assignedRole ?? "named user";
    sittingWith.set(key, (sittingWith.get(key) ?? 0) + 1);
  }

  const now = Date.now();
  const overdue = pendingRows
    .filter((p) => p.dueAt && p.dueAt.getTime() < now)
    .sort((a, b) => (a.dueAt?.getTime() ?? 0) - (b.dueAt?.getTime() ?? 0));

  // Deadlines in the next 7 days.
  const keys: DeadlineKey[] = [
    ...(standsEnabled ? (["stand_design_due", "insurance_due"] as DeadlineKey[]) : []),
    "venue_rigging_submission",
    "artwork_due",
    "print_deadline",
    "delivery",
  ];
  const today = todayInLondon();
  const in7 = new Date(Date.now() + 7 * 86_400_000).toISOString().slice(0, 10);
  const upcomingDeadlines = forDeadlines
    ? keys
        .map((key) => ({ key, date: effectiveDeadline(forDeadlines, key) }))
        .filter((d): d is { key: DeadlineKey; date: string } =>
          Boolean(d.date && d.date >= today && d.date <= in7),
        )
    : [];

  return {
    edition: edition[0],
    statusCounts: Object.fromEntries(statusCounts.map((r) => [r.status, r.n])),
    sponsorshipCount: Number(sponsorshipCount[0]?.n ?? 0),
    standCounts: Object.fromEntries(standCounts.map((r) => [r.status, r.n])),
    budget: {
      budget: edition[0]?.signageBudget ?? null,
      estimate: budgetRow[0]?.estimate ?? "0",
      actual: budgetRow[0]?.actual ?? "0",
    },
    sittingWith: [...sittingWith.entries()].sort((a, b) => b[1] - a[1]),
    overdueCount: overdue.length,
    overdue: overdue.slice(0, 8),
    mostOverdue: overdue[0] ?? null,
    upcomingDeadlines,
    pendingTotal: pendingRows.length,
  };
}

export async function refsForInstanceEntities(rows: { entityType: string; entityId: string }[]) {
  const itemIds = rows.filter((r) => r.entityType === "signage_item").map((r) => r.entityId);
  const subIds = rows.filter((r) => r.entityType === "stand_submission").map((r) => r.entityId);
  const items = itemIds.length
    ? await db
        .select({ id: signageItems.id, ref: signageItems.ref, name: signageItems.name })
        .from(signageItems)
        .where(inArray(signageItems.id, itemIds))
    : [];
  const subs = subIds.length
    ? await db
        .select({ id: standSubmissions.id, ref: standSubmissions.ref })
        .from(standSubmissions)
        .where(inArray(standSubmissions.id, subIds))
    : [];
  const map = new Map<string, { ref: string; name?: string }>();
  for (const i of items) map.set(i.id, { ref: i.ref, name: i.name });
  for (const s of subs) map.set(s.id, { ref: s.ref });
  return map;
}

export { lt };
