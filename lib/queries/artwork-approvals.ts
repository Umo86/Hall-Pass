import "server-only";
import { and, desc, eq, ilike, inArray, isNotNull, isNull, ne, or, sql } from "drizzle-orm";
import { alias } from "drizzle-orm/pg-core";
import { db } from "@/lib/db/client";
import {
  approvalInstances,
  artworkVersions,
  editions,
  events,
  signageItems,
  sponsors,
  users,
} from "@/lib/db/schema";
import { departmentNames } from "@/lib/domain/departments";
import { getInlineUrl } from "@/lib/storage";

/** The artwork filters on the Approvals page, in plain words. */
export const ARTWORK_FILTERS = {
  waiting: { label: "Waiting for sign-off", statuses: ["in_review"] },
  changes: { label: "Changes asked for", statuses: ["changes_requested"] },
  approved: {
    label: "Signed off",
    statuses: [
      "approved",
      "approved_with_conditions",
      "in_production",
      "delivered",
      "installed",
      "snagged",
      "closed",
    ],
  },
  rejected: { label: "Rejected", statuses: ["rejected"] },
  not_sent: { label: "Not sent yet", statuses: ["draft", "awaiting_artwork", "on_hold"] },
} as const;

export type ArtworkFilter = keyof typeof ARTWORK_FILTERS | "all";

export type ArtworkSignoff = {
  id: string;
  stepName: string;
  status: string;
  /** Who it's with: a named person, or "Anyone in Marketing". */
  who: string | null;
  deciderName: string | null;
  decidedAt: Date | null;
  comment: string | null;
};

export type ArtworkRow = {
  id: string;
  ref: string;
  name: string;
  kind: "signage" | "sponsorship_item";
  status: string;
  category: string | null;
  sponsorName: string | null;
  showCode: string;
  showName: string;
  version: number;
  uploadedAt: Date;
  previewUrl: string | null;
  href: string;
  signoffs: ArtworkSignoff[];
};

const LIMIT = 150;

/**
 * Every signage item (sponsorship items too) that has artwork, with where
 * its sign-off stands in the current round. Newest artwork first.
 */
export async function listArtworkApprovals(opts: {
  organisationId: string;
  editionId?: string | null;
  filter: ArtworkFilter;
  search?: string;
}): Promise<{ rows: ArtworkRow[]; counts: Record<string, number>; truncated: boolean }> {
  const search = opts.search?.trim();
  const base = and(
    eq(events.organisationId, opts.organisationId),
    ne(editions.status, "archived"),
    isNull(signageItems.deletedAt),
    isNotNull(signageItems.currentArtworkVersionId),
    opts.editionId ? eq(signageItems.editionId, opts.editionId) : undefined,
    search
      ? or(ilike(signageItems.name, `%${search}%`), ilike(signageItems.ref, `%${search}%`))
      : undefined,
  );

  const statusRows = await db
    .select({ status: signageItems.status, n: sql<number>`count(*)::int` })
    .from(signageItems)
    .innerJoin(editions, eq(signageItems.editionId, editions.id))
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(base)
    .groupBy(signageItems.status);
  const counts: Record<string, number> = { all: 0 };
  for (const [key, f] of Object.entries(ARTWORK_FILTERS)) {
    counts[key] = statusRows
      .filter((r) => (f.statuses as readonly string[]).includes(r.status))
      .reduce((n, r) => n + r.n, 0);
  }
  counts.all = statusRows.reduce((n, r) => n + r.n, 0);

  const wanted =
    opts.filter === "all" ? null : (ARTWORK_FILTERS[opts.filter].statuses as readonly string[]);
  const items = await db
    .select({
      item: signageItems,
      showCode: editions.code,
      showName: editions.name,
      sponsorName: sponsors.companyName,
      version: artworkVersions,
    })
    .from(signageItems)
    .innerJoin(editions, eq(signageItems.editionId, editions.id))
    .innerJoin(events, eq(editions.eventId, events.id))
    .innerJoin(artworkVersions, eq(artworkVersions.id, signageItems.currentArtworkVersionId))
    .leftJoin(sponsors, eq(signageItems.sponsorId, sponsors.id))
    .where(
      and(
        base,
        wanted
          ? inArray(signageItems.status, wanted as (typeof signageItems.$inferSelect)["status"][])
          : undefined,
      ),
    )
    .orderBy(desc(artworkVersions.createdAt))
    .limit(LIMIT + 1);
  const truncated = items.length > LIMIT;
  const page = items.slice(0, LIMIT);

  const ids = page.map((r) => r.item.id);
  const assignee = alias(users, "assignee");
  const decider = alias(users, "decider");
  const instances = ids.length
    ? await db
        .select({
          instance: approvalInstances,
          assigneeName: assignee.fullName,
          deciderName: decider.fullName,
        })
        .from(approvalInstances)
        .leftJoin(assignee, eq(approvalInstances.assignedUserId, assignee.id))
        .leftJoin(decider, eq(approvalInstances.decidedBy, decider.id))
        .where(
          and(
            eq(approvalInstances.entityType, "signage_item"),
            inArray(approvalInstances.entityId, ids),
            eq(approvalInstances.stepKindSnapshot, "approval"),
            ne(approvalInstances.status, "skipped"),
            ne(approvalInstances.status, "invalidated"),
          ),
        )
        .orderBy(approvalInstances.sortOrderSnapshot)
    : [];
  const deptNames = await departmentNames(
    db,
    instances.map((i) => i.instance.assignedDepartmentId),
  );
  const runOf = new Map(page.map((r) => [r.item.id, r.item.currentRunNumber]));

  const rows = await Promise.all(
    page.map(async ({ item, showCode, showName, sponsorName, version }) => {
      const sample = version.filePath.startsWith("seed/");
      const previewUrl = version.previewPath
        ? await getInlineUrl("artwork", version.previewPath).catch(() => null)
        : !sample && version.mimeType.startsWith("image/")
          ? await getInlineUrl("artwork", version.filePath).catch(() => null)
          : null;
      const signoffs = instances
        .filter(
          ({ instance }) =>
            instance.entityId === item.id && instance.runNumber === runOf.get(item.id),
        )
        .map(({ instance, assigneeName, deciderName }) => ({
          id: instance.id,
          stepName: instance.stepNameSnapshot,
          status: instance.status,
          who: instance.assignedUserId
            ? assigneeName || "a named person"
            : instance.assignedDepartmentId
              ? `Anyone in ${deptNames.get(instance.assignedDepartmentId) ?? "the department"}`
              : null,
          deciderName: deciderName || null,
          decidedAt: instance.decidedAt,
          comment: instance.decisionComment,
        }));
      const section = item.kind === "sponsorship_item" ? "sponsorship" : "signage";
      return {
        id: item.id,
        ref: item.ref,
        name: item.name,
        kind: item.kind,
        status: item.status,
        category: item.category,
        sponsorName,
        showCode,
        showName,
        version: version.versionNumber,
        uploadedAt: version.createdAt,
        previewUrl,
        href: `/${showCode}/${section}/${item.ref}?tab=artwork`,
        signoffs,
      } satisfies ArtworkRow;
    }),
  );
  return { rows, counts, truncated };
}
