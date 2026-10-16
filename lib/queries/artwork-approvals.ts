import "server-only";
import { itemPath } from "@/lib/edition-path";
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
import { getDownloadUrl, getInlineUrl } from "@/lib/storage";
import { isVideoArtwork } from "@/lib/artwork-rules";
import { roleLabel } from "@/lib/format";

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
  /** Who it's with: a named person, the department ("Marketing") or the role ("Venue"). */
  who: string | null;
  deciderName: string | null;
  decidedAt: Date | null;
  comment: string | null;
};

export type ArtworkRow = {
  id: string;
  ref: string;
  name: string;
  kind: "signage" | "sponsorship_item" | "stand_design" | "stand_panel";
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
          who: whoLabel(instance, assigneeName, deptNames),
          deciderName: deciderName || null,
          decidedAt: instance.decidedAt,
          comment: instance.decisionComment,
        }));
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
        href: `${itemPath(showCode, item)}?tab=artwork`,
        signoffs,
      } satisfies ArtworkRow;
    }),
  );
  return { rows, counts, truncated };
}

function whoLabel(
  instance: typeof approvalInstances.$inferSelect,
  assigneeName: string | null,
  deptNames: Map<string, string>,
): string | null {
  if (instance.assignedUserId) return assigneeName || "a named person";
  if (instance.assignedDepartmentId) {
    return deptNames.get(instance.assignedDepartmentId) ?? "the department";
  }
  return instance.assignedRole ? roleLabel(instance.assignedRole) : null;
}

export type PreviewKind = "image" | "pdf" | "video";

export type ReviewVersion = {
  id: string;
  versionNumber: number;
  fileName: string;
  mimeType: string;
  notes: string | null;
  uploadedAt: string;
  uploaderName: string | null;
  /** Small picture for lists (generated preview or the image itself). */
  thumbUrl: string | null;
  /** What the review sheet shows. */
  previewUrl: string | null;
  previewKind: PreviewKind | null;
  downloadUrl: string | null;
  /** Demo records carry no real file. */
  sample: boolean;
};

export type ReviewArtwork = {
  current: ReviewVersion;
  previous: ReviewVersion | null;
  /** Every sign-off step of the current round, with who it is with. */
  signoffs: (ArtworkSignoff & { stepKind: "approval" | "confirmation" })[];
};

async function versionView(
  version: typeof artworkVersions.$inferSelect,
  uploaderName: string | null,
  withDownload: boolean,
): Promise<ReviewVersion> {
  const sample = version.filePath.startsWith("seed/");
  const isImage = version.mimeType.startsWith("image/");
  const isPdf = version.mimeType === "application/pdf";
  const isVideo = isVideoArtwork(version.mimeType, version.fileName);
  const inline = (path: string) => getInlineUrl("artwork", path).catch(() => null);
  const [previewOrFile, file, downloadUrl] = await Promise.all([
    version.previewPath ? inline(version.previewPath) : null,
    !sample && !version.previewPath && (isImage || isPdf || isVideo)
      ? inline(version.filePath)
      : null,
    withDownload && !sample
      ? getDownloadUrl("artwork", version.filePath).catch(() => null)
      : Promise.resolve(null),
  ]);
  const previewUrl = previewOrFile ?? file;
  const previewKind: PreviewKind | null = !previewUrl
    ? null
    : version.previewPath || isImage
      ? "image"
      : isPdf
        ? "pdf"
        : "video";
  return {
    id: version.id,
    versionNumber: version.versionNumber,
    fileName: version.fileName,
    mimeType: version.mimeType,
    notes: version.notes,
    uploadedAt: version.createdAt.toISOString(),
    uploaderName,
    thumbUrl: previewKind === "image" ? previewUrl : null,
    previewUrl,
    previewKind,
    downloadUrl,
    sample,
  };
}

/**
 * For the review queue: each item's current artwork (and the one before,
 * to compare), with every step of the current round. Callers pass items the
 * person may already see (their own pending sign-offs).
 */
export async function reviewArtworkForItems(
  organisationId: string,
  itemIds: string[],
): Promise<Map<string, ReviewArtwork>> {
  const ids = [...new Set(itemIds)];
  const out = new Map<string, ReviewArtwork>();
  if (ids.length === 0) return out;
  const uploader = alias(users, "uploader");
  const items = await db
    .select({
      id: signageItems.id,
      current: signageItems.currentArtworkVersionId,
      run: signageItems.currentRunNumber,
    })
    .from(signageItems)
    .innerJoin(editions, eq(signageItems.editionId, editions.id))
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(inArray(signageItems.id, ids), eq(events.organisationId, organisationId)));
  const versions = await db
    .select({
      version: artworkVersions,
      uploaderName: uploader.fullName,
      uploaderEmail: uploader.email,
    })
    .from(artworkVersions)
    .leftJoin(uploader, eq(uploader.id, artworkVersions.uploadedBy))
    .where(
      inArray(
        artworkVersions.signageItemId,
        items.map((i) => i.id),
      ),
    )
    .orderBy(desc(artworkVersions.versionNumber));
  const assignee = alias(users, "assignee");
  const decider = alias(users, "decider");
  const steps = await db
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
        inArray(
          approvalInstances.entityId,
          items.map((i) => i.id),
        ),
        ne(approvalInstances.status, "skipped"),
        ne(approvalInstances.status, "invalidated"),
      ),
    )
    .orderBy(approvalInstances.sortOrderSnapshot);
  const deptNames = await departmentNames(
    db,
    steps.map((st) => st.instance.assignedDepartmentId),
  );
  await Promise.all(
    items.map(async (item) => {
      const mine = versions.filter((v) => v.version.signageItemId === item.id);
      const currentIndex = mine.findIndex((v) => v.version.id === item.current);
      if (currentIndex < 0) return;
      const cur = mine[currentIndex];
      const prev = mine[currentIndex + 1] ?? null;
      const [current, previous] = await Promise.all([
        versionView(cur.version, cur.uploaderName || cur.uploaderEmail, true),
        prev ? versionView(prev.version, prev.uploaderName || prev.uploaderEmail, false) : null,
      ]);
      out.set(item.id, {
        current,
        previous,
        signoffs: steps
          .filter((st) => st.instance.entityId === item.id && st.instance.runNumber === item.run)
          .map(({ instance, assigneeName, deciderName }) => ({
            id: instance.id,
            stepName: instance.stepNameSnapshot,
            stepKind: instance.stepKindSnapshot,
            status: instance.status,
            who: whoLabel(instance, assigneeName, deptNames),
            deciderName: deciderName || null,
            decidedAt: instance.decidedAt,
            comment: instance.decisionComment,
          })),
      });
    }),
  );
  return out;
}

/** How many items are waiting for sign-off (for the empty "Waiting on me"). */
export async function countItemsInSignoff(organisationId: string): Promise<number> {
  const [row] = await db
    .select({ n: sql<number>`count(*)::int` })
    .from(signageItems)
    .innerJoin(editions, eq(signageItems.editionId, editions.id))
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(
      and(
        eq(events.organisationId, organisationId),
        ne(editions.status, "archived"),
        isNull(signageItems.deletedAt),
        eq(signageItems.status, "in_review"),
      ),
    );
  return Number(row?.n ?? 0);
}
