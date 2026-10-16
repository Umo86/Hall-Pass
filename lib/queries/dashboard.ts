import "server-only";
import { and, asc, eq, isNull, lte, ne, or, sql } from "drizzle-orm";
import { alias } from "drizzle-orm/pg-core";
import { db } from "@/lib/db/client";
import {
  approvalInstances,
  departments,
  exhibitors,
  signageItems,
  standSubmissions,
  tasks,
  users,
} from "@/lib/db/schema";
import { DEADLINE_LABELS, addDaysIso, effectiveDeadline, type DeadlineKey } from "@/lib/deadlines";
import { todayInLondon } from "@/lib/today";
import { editionForDeadlines } from "./editions";
import { standsEnabled } from "@/lib/config";
import { SIGNAGE_KINDS, deadlineHref, itemPath } from "@/lib/edition-path";
import { orderByKind } from "@/lib/calendar";
import { stepIsMine } from "@/lib/domain/signage";
import type { Feature, StaffActor } from "@/lib/authz";
import { daysOverdue } from "@/components/approvals/step-words";
import {
  DEADLINE_FEATURE,
  deadlineWorkLabel,
  onsiteSoon,
  sponsorshipSummary,
  waitingOnLabel,
  type DeadlineWork,
} from "@/components/dashboard/rules";

export type UpcomingDeadline = {
  id: string;
  /** "Artwork due", "Print deadline: Hall 1 banner". */
  label: string;
  /** How much is left, for event deadlines: "3 items still need artwork". */
  detail: string | null;
  date: string;
  href: string;
  /** The section the link goes to; the page shows plain text to people without it. */
  feature: Feature | null;
};

export type OverdueSignoff = {
  id: string;
  ref: string;
  name: string;
  href: string;
  stepName: string;
  waitingOn: string;
  daysLate: number;
};

const SIGNAGE_KIND_LIST: readonly string[] = SIGNAGE_KINDS;
const NEEDS_ARTWORK = ["draft", "awaiting_artwork"];
const NOT_DELIVERED = [
  "draft",
  "awaiting_artwork",
  "in_review",
  "changes_requested",
  "approved",
  "approved_with_conditions",
  "in_production",
  "on_hold",
];
const SETTLED = ["installed", "snagged", "closed", "rejected"];

/**
 * Everything the event dashboard shows, for one event and the person
 * looking at it. The rules (what counts, the words) are in
 * components/dashboard/rules.ts; this only fetches and adds up.
 */
export async function dashboardData(opts: {
  edition: { id: string; code: string; signageBudget: string | null };
  actor: StaffActor;
  today?: string;
}) {
  const { edition, actor } = opts;
  const editionId = edition.id;
  const code = edition.code;
  const today = opts.today ?? todayInLondon();
  const weekEnd = addDaysIso(today, 7);
  const live = and(eq(signageItems.editionId, editionId), isNull(signageItems.deletedAt));
  const assignee = alias(users, "assignee");

  const [items, standCounts, pendingRows, forDeadlines, taskRow] = await Promise.all([
    // Every live item of the event, once; the counts and dates come from here.
    db
      .select({
        id: signageItems.id,
        ref: signageItems.ref,
        name: signageItems.name,
        kind: signageItems.kind,
        status: signageItems.status,
        previousStatus: signageItems.previousStatus,
        sponsorId: signageItems.sponsorId,
        salePrice: signageItems.salePrice,
        costEstimate: signageItems.costEstimate,
        costActual: signageItems.costActual,
        currentArtworkVersionId: signageItems.currentArtworkVersionId,
        requiresVenueApproval: signageItems.requiresVenueApproval,
        printDeadline: signageItems.printDeadline,
        artworkDueOverride: signageItems.artworkDueOverride,
        deliveryDate: signageItems.deliveryDate,
        installDate: signageItems.installDate,
        orderByDate: signageItems.orderByDate,
      })
      .from(signageItems)
      .where(live),
    standsEnabled
      ? db
          .select({ status: standSubmissions.status, n: sql<number>`count(*)::int` })
          .from(standSubmissions)
          .innerJoin(exhibitors, eq(standSubmissions.exhibitorId, exhibitors.id))
          .where(
            and(eq(standSubmissions.editionId, editionId), eq(exhibitors.standType, "space_only")),
          )
          .groupBy(standSubmissions.status)
      : Promise.resolve([] as { status: string; n: number }[]),
    // Open sign-offs on this event's live, not-held items (and stands when on).
    db
      .select({
        id: approvalInstances.id,
        entityType: approvalInstances.entityType,
        stepName: approvalInstances.stepNameSnapshot,
        stepKind: approvalInstances.stepKindSnapshot,
        dueAt: approvalInstances.dueAt,
        assignedRole: approvalInstances.assignedRole,
        assignedUserId: approvalInstances.assignedUserId,
        assignedDepartmentId: approvalInstances.assignedDepartmentId,
        departmentName: departments.name,
        assigneeName: sql<
          string | null
        >`coalesce(nullif(${assignee.fullName}, ''), ${assignee.email})`,
        itemRef: signageItems.ref,
        itemName: signageItems.name,
        itemKind: signageItems.kind,
        subRef: standSubmissions.ref,
        company: exhibitors.companyName,
      })
      .from(approvalInstances)
      .leftJoin(
        signageItems,
        and(
          eq(approvalInstances.entityType, "signage_item"),
          eq(signageItems.id, approvalInstances.entityId),
        ),
      )
      .leftJoin(
        standSubmissions,
        and(
          eq(approvalInstances.entityType, "stand_submission"),
          eq(standSubmissions.id, approvalInstances.entityId),
        ),
      )
      .leftJoin(exhibitors, eq(exhibitors.id, standSubmissions.exhibitorId))
      .leftJoin(departments, eq(departments.id, approvalInstances.assignedDepartmentId))
      .leftJoin(assignee, eq(assignee.id, approvalInstances.assignedUserId))
      .where(
        and(
          eq(approvalInstances.status, "pending"),
          or(
            and(live, ne(signageItems.status, "on_hold")),
            standsEnabled ? eq(standSubmissions.editionId, editionId) : undefined,
          ),
        ),
      )
      .orderBy(sql`${approvalInstances.dueAt} ASC NULLS LAST`, asc(approvalInstances.createdAt)),
    editionForDeadlines(editionId),
    // My open tasks for this event: overdue, and due in the next 7 days.
    db
      .select({
        overdue: sql<number>`(count(*) filter (where ${tasks.dueDate} < ${today}))::int`,
        dueSoon: sql<number>`(count(*) filter (where ${tasks.dueDate} >= ${today}))::int`,
      })
      .from(tasks)
      .where(
        and(
          eq(tasks.editionId, editionId),
          eq(tasks.organisationId, actor.organisationId),
          eq(tasks.assignedToUserId, actor.userId),
          isNull(tasks.parentTaskId),
          ne(tasks.status, "done"),
          lte(tasks.dueDate, weekEnd),
        ),
      ),
  ]);

  // ------------------------------------------------ signage and budget
  const signage = items.filter((i) => SIGNAGE_KIND_LIST.includes(i.kind));
  const statusCounts: Record<string, number> = {};
  for (const i of signage) statusCounts[i.status] = (statusCounts[i.status] ?? 0) + 1;

  // The signage budget covers signage; sponsorship items are sold separately.
  let estimate = 0;
  let actual = 0;
  for (const i of items) {
    if (i.kind !== "signage") continue;
    estimate += Number(i.costEstimate ?? 0);
    actual += Number(i.costActual ?? 0);
  }

  // The same rows and rules as the Sponsorship page, so its filters agree.
  const sponsorship = sponsorshipSummary(
    signage
      .filter((i) => i.kind === "sponsorship_item" || i.sponsorId)
      .map((i) => ({ ...i, hasArtwork: i.currentArtworkVersionId != null })),
    today,
  );

  const work: DeadlineWork = {
    needsArtwork: signage.filter(
      (i) => NEEDS_ARTWORK.includes(i.status) && !i.currentArtworkVersionId,
    ).length,
    readyToPrint: signage.filter(
      (i) => i.status === "approved" || i.status === "approved_with_conditions",
    ).length,
    toDeliver: signage.filter((i) => NOT_DELIVERED.includes(i.status)).length,
    venueItems: items.filter((i) => i.requiresVenueApproval).length,
    standDesignsToDo: items.filter(
      (i) =>
        i.kind === "stand_design" && NEEDS_ARTWORK.includes(i.status) && !i.currentArtworkVersionId,
    ).length,
  };

  // ----------------------------------------------------- sign-offs
  const now = Date.now();
  const signoffs = pendingRows
    .map((p) => {
      const isItem = p.entityType === "signage_item";
      const ref = (isItem ? p.itemRef : p.subRef) ?? "";
      return {
        ...p,
        ref,
        name: isItem ? (p.itemName ?? ref) : `${p.company ?? "Stand"} — stand ${ref}`,
        href: isItem
          ? `${itemPath(code, { kind: p.itemKind ?? "signage", ref })}?tab=artwork`
          : `/${code}/stands/${ref}`,
        waitingOn: waitingOnLabel(p),
        isOverdue: Boolean(p.dueAt && p.dueAt.getTime() < now),
      };
    })
    .filter((p) => p.ref);

  const sittingWith = new Map<string, { count: number; overdue: number }>();
  for (const p of signoffs) {
    const entry = sittingWith.get(p.waitingOn) ?? { count: 0, overdue: 0 };
    entry.count++;
    if (p.isOverdue) entry.overdue++;
    sittingWith.set(p.waitingOn, entry);
  }
  const overdue = signoffs.filter((p) => p.isOverdue);

  // Mine as the assignee, as the navigation count and Approvals "Waiting on
  // me" count them; someone whose sign-off is paused decides nothing.
  const paused = actor.role !== "admin" && actor.overrides?.["approval.decide"] === false;
  const mine = paused
    ? []
    : signoffs.filter((p) =>
        stepIsMine(
          {
            stepKind: p.stepKind,
            assignedRole: p.assignedRole,
            assignedUserId: p.assignedUserId,
            assignedDepartmentId: p.assignedDepartmentId,
          },
          actor,
        ),
      );

  // ------------------------------------------- the next seven days
  // The event's own deadlines (linked to their work, with what is left),
  // each item's dates, and sign-offs falling due.
  const soon = (date: string | null | undefined): date is string =>
    Boolean(date && date >= today && date <= weekEnd);
  const upcoming: UpcomingDeadline[] = [];
  const keys: DeadlineKey[] = [
    ...(standsEnabled ? (["stand_design_due", "insurance_due"] as DeadlineKey[]) : []),
    "venue_rigging_submission",
    "artwork_due",
    "print_deadline",
    "delivery",
  ];
  if (forDeadlines) {
    for (const key of keys) {
      const date = effectiveDeadline(forDeadlines, key);
      if (!soon(date)) continue;
      upcoming.push({
        id: `event-${key}`,
        label: DEADLINE_LABELS[key] ?? key,
        detail: deadlineWorkLabel(key, work),
        date,
        href: deadlineHref(code, key),
        feature: DEADLINE_FEATURE[key] ?? null,
      });
    }
  }
  for (const item of signage) {
    if (SETTLED.includes(item.status)) continue;
    const href = itemPath(code, item);
    const add = (date: string | null, what: string) => {
      if (!soon(date)) return;
      // Item pages open for everyone (links from emails keep working).
      upcoming.push({
        id: `${item.ref}-${what}`,
        label: `${what}: ${item.name}`,
        detail: null,
        date,
        href,
        feature: null,
      });
    };
    add(item.artworkDueOverride, "Artwork due");
    add(item.printDeadline, "Print deadline");
    add(item.deliveryDate, "Delivery");
    if (item.kind === "signage") add(item.installDate, "Install");
    const orderBy = orderByKind(item);
    if (orderBy) add(item.orderByDate, orderBy === "sell" ? "Sell by" : "Order by");
  }
  for (const p of signoffs) {
    // Print, delivery and install confirmations are dated by the items already.
    if (p.stepKind === "confirmation" || p.entityType !== "signage_item") continue;
    const date = p.dueAt ? todayInLondon(p.dueAt) : null;
    if (!soon(date)) continue;
    upcoming.push({
      id: `signoff-${p.id}`,
      label: `${p.stepName}: ${p.name}`,
      detail: null,
      date,
      href: p.href,
      feature: null,
    });
  }
  upcoming.sort((a, b) => a.date.localeCompare(b.date) || a.label.localeCompare(b.label));

  return {
    statusCounts,
    standCounts: Object.fromEntries(standCounts.map((r) => [r.status, Number(r.n)])) as Record<
      string,
      number
    >,
    budget: { budget: edition.signageBudget, estimate, actual },
    sponsorship,
    sittingWith: [...sittingWith.entries()]
      .map(([label, v]) => ({ label, ...v }))
      .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label)),
    pendingTotal: signoffs.length,
    overdueCount: overdue.length,
    overdue: overdue.slice(0, 6).map((p): OverdueSignoff => ({
      id: p.id,
      ref: p.ref,
      name: p.name,
      href: p.href,
      stepName: p.stepName,
      waitingOn: p.waitingOn,
      daysLate: p.dueAt ? daysOverdue(p.dueAt, today) : 0,
    })),
    upcomingDeadlines: upcoming.slice(0, 8),
    upcomingCount: upcoming.length,
    /** For "Your next steps" (the page decides which rows this person gets). */
    next: {
      signoffs: { total: mine.length, overdue: mine.filter((p) => p.isOverdue).length },
      tasks: {
        overdue: Number(taskRow[0]?.overdue ?? 0),
        dueSoon: Number(taskRow[0]?.dueSoon ?? 0),
      },
      sponsorship: {
        urgent: sponsorship.urgent,
        unsold: sponsorship.urgentUnsold,
        overdue: sponsorship.overdue,
      },
      onsite: onsiteSoon(items, today),
    },
  };
}

export type DashboardData = Awaited<ReturnType<typeof dashboardData>>;
