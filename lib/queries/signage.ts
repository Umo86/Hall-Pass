import "server-only";
import { departmentNames } from "@/lib/domain/departments";
import { and, asc, desc, eq, inArray, isNotNull, isNull, or, sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  approvalInstances,
  artworkVersions,
  auditLog,
  comments,
  contractors,
  halls,
  itemTypes,
  locations,
  signageItems,
  snags,
  sponsors,
  suppliers,
  users,
} from "@/lib/db/schema";
import type { LabelRow } from "@/lib/exports/label-fields";
import { loadItemBundle } from "@/lib/domain/signage";
import { loadRun } from "@/lib/workflow/persist";

export type ScheduleRow = {
  id: string;
  ref: string;
  name: string;
  status: string;
  kind: "signage" | "sponsorship_item";
  category: string | null;
  typeName: string | null;
  /** Print or digital (from the signage type). */
  format: string | null;
  hallName: string | null;
  locationName: string | null;
  sponsorName: string | null;
  supplierName: string | null;
  ownerRole: string;
  widthMm: number | null;
  heightMm: number | null;
  quantity: number;
  fixingMethod: string | null;
  requiresVenueApproval: boolean;
  costEstimate: string | null;
  costActual: string | null;
  poNumber: string | null;
  installDate: string | null;
  installSlot: string | null;
  printDeadline: string | null;
  artworkDueOverride: string | null;
  currentVersion: number | null;
  previewPath: string | null;
  pendingSteps: { name: string; role: string | null; dueAt: string | null; overdue: boolean }[];
};

export async function listScheduleRows(editionId: string): Promise<ScheduleRow[]> {
  const rows = await db
    .select({
      item: signageItems,
      typeName: itemTypes.name,
      format: itemTypes.format,
      hallName: halls.name,
      locationName: locations.name,
      sponsorName: sponsors.companyName,
      supplierName: suppliers.name,
      currentVersion: artworkVersions.versionNumber,
      previewPath: artworkVersions.previewPath,
    })
    .from(signageItems)
    .leftJoin(itemTypes, eq(signageItems.itemTypeId, itemTypes.id))
    .leftJoin(halls, eq(signageItems.hallId, halls.id))
    .leftJoin(locations, eq(signageItems.locationId, locations.id))
    .leftJoin(sponsors, eq(signageItems.sponsorId, sponsors.id))
    .leftJoin(suppliers, eq(signageItems.supplierId, suppliers.id))
    .leftJoin(artworkVersions, eq(signageItems.currentArtworkVersionId, artworkVersions.id))
    // Everything for the show — organiser signage, sponsor signage and the
    // items sold in the Sponsorship section — in one schedule.
    .where(and(eq(signageItems.editionId, editionId), isNull(signageItems.deletedAt)))
    .orderBy(asc(signageItems.seq));

  const ids = rows.map((r) => r.item.id);
  const pending = ids.length
    ? await db
        .select()
        .from(approvalInstances)
        .where(
          and(
            eq(approvalInstances.entityType, "signage_item"),
            inArray(approvalInstances.entityId, ids),
            eq(approvalInstances.status, "pending"),
          ),
        )
    : [];
  const deptNames = await departmentNames(
    db,
    pending.map((p) => p.assignedDepartmentId),
  );
  const pendingByItem = new Map<string, typeof pending>();
  for (const p of pending) {
    const list = pendingByItem.get(p.entityId) ?? [];
    list.push(p);
    pendingByItem.set(p.entityId, list);
  }

  const now = Date.now();
  return rows.map((r) => ({
    id: r.item.id,
    ref: r.item.ref,
    name: r.item.name,
    status: r.item.status,
    kind: r.item.kind,
    category: r.item.category,
    typeName: r.typeName,
    format: r.format,
    hallName: r.hallName,
    locationName: r.locationName,
    sponsorName: r.sponsorName,
    supplierName: r.supplierName,
    ownerRole: r.item.ownerRole,
    widthMm: r.item.widthMm,
    heightMm: r.item.heightMm,
    quantity: r.item.quantity,
    fixingMethod: r.item.fixingMethod,
    requiresVenueApproval: r.item.requiresVenueApproval,
    costEstimate: r.item.costEstimate,
    costActual: r.item.costActual,
    poNumber: r.item.poNumber,
    installDate: r.item.installDate,
    installSlot: r.item.installSlot,
    printDeadline: r.item.printDeadline,
    artworkDueOverride: r.item.artworkDueOverride,
    currentVersion: r.currentVersion,
    previewPath: r.previewPath,
    pendingSteps: (pendingByItem.get(r.item.id) ?? []).map((p) => ({
      name: p.stepNameSnapshot,
      role: p.assignedDepartmentId
        ? (deptNames.get(p.assignedDepartmentId) ?? null)
        : p.assignedRole,
      dueAt: p.dueAt?.toISOString() ?? null,
      overdue: Boolean(p.dueAt && p.dueAt.getTime() < now),
    })),
  }));
}

export type SponsorshipRow = {
  id: string;
  ref: string;
  name: string;
  status: string;
  typeName: string | null;
  kind: "signage" | "sponsorship_item";
  sponsorId: string | null;
  sponsorName: string | null;
  supplierName: string | null;
  quantity: number;
  costEstimate: string | null;
  salePrice: string | null;
  soldAt: Date | null;
  orderByDate: string | null;
  photoPath: string | null;
  /** Artwork preview, used when there is no product photo. */
  previewPath: string | null;
  currentVersion: number | null;
};

/**
 * The sponsorship register: everything for sale to sponsors (sponsorship
 * items, sold or not) and sponsor signage. Soonest order-by date first.
 */
export async function listSponsorshipRows(editionId: string): Promise<SponsorshipRow[]> {
  const rows = await db
    .select({
      item: signageItems,
      typeName: itemTypes.name,
      sponsorName: sponsors.companyName,
      supplierName: suppliers.name,
      currentVersion: artworkVersions.versionNumber,
      previewPath: artworkVersions.previewPath,
    })
    .from(signageItems)
    .leftJoin(itemTypes, eq(signageItems.itemTypeId, itemTypes.id))
    .leftJoin(sponsors, eq(signageItems.sponsorId, sponsors.id))
    .leftJoin(suppliers, eq(signageItems.supplierId, suppliers.id))
    .leftJoin(artworkVersions, eq(signageItems.currentArtworkVersionId, artworkVersions.id))
    .where(
      and(
        eq(signageItems.editionId, editionId),
        or(eq(signageItems.kind, "sponsorship_item"), isNotNull(signageItems.sponsorId)),
        isNull(signageItems.deletedAt),
      ),
    )
    .orderBy(sql`${signageItems.orderByDate} ASC NULLS LAST`, asc(signageItems.seq));
  return rows.map((r) => ({
    id: r.item.id,
    ref: r.item.ref,
    name: r.item.name,
    status: r.item.status,
    typeName: r.typeName,
    kind: r.item.kind,
    sponsorId: r.item.sponsorId,
    sponsorName: r.sponsorName,
    supplierName: r.supplierName,
    quantity: r.item.quantity,
    costEstimate: r.item.costEstimate,
    salePrice: r.item.salePrice,
    soldAt: r.item.soldAt,
    orderByDate: r.item.orderByDate,
    photoPath: r.item.photoPath,
    previewPath: r.previewPath,
    currentVersion: r.currentVersion,
  }));
}

/**
 * Spec-label rows with the names a label prints, for given items or for a
 * whole edition (optionally one hall), in ref order. Deleted items are left
 * out.
 */
export async function getLabelRows(opts: {
  itemIds?: string[];
  editionId?: string;
  hallId?: string;
}): Promise<(LabelRow & { id: string; editionId: string })[]> {
  const where = [isNull(signageItems.deletedAt)];
  if (opts.itemIds) where.push(inArray(signageItems.id, opts.itemIds));
  if (opts.editionId) where.push(eq(signageItems.editionId, opts.editionId));
  if (opts.hallId) where.push(eq(signageItems.hallId, opts.hallId));
  if (!opts.itemIds && !opts.editionId) return [];
  if (opts.itemIds?.length === 0) return [];
  return db
    .select({
      id: signageItems.id,
      editionId: signageItems.editionId,
      ref: signageItems.ref,
      name: signageItems.name,
      kind: signageItems.kind,
      widthMm: signageItems.widthMm,
      heightMm: signageItems.heightMm,
      quantity: signageItems.quantity,
      material: signageItems.material,
      finish: signageItems.finish,
      fixingMethod: signageItems.fixingMethod,
      installDate: signageItems.installDate,
      installSlot: signageItems.installSlot,
      deliveryDate: signageItems.deliveryDate,
      hallName: halls.name,
      locationName: locations.name,
      contractorName: contractors.name,
      sponsorName: sponsors.companyName,
      supplierName: suppliers.name,
    })
    .from(signageItems)
    .leftJoin(halls, eq(signageItems.hallId, halls.id))
    .leftJoin(locations, eq(signageItems.locationId, locations.id))
    .leftJoin(contractors, eq(signageItems.installContractorId, contractors.id))
    .leftJoin(sponsors, eq(signageItems.sponsorId, sponsors.id))
    .leftJoin(suppliers, eq(signageItems.supplierId, suppliers.id))
    .where(and(...where))
    .orderBy(asc(signageItems.seq));
}

export async function getItemByRef(ref: string) {
  const [item] = await db.select().from(signageItems).where(eq(signageItems.ref, ref)).limit(1);
  return item ?? null;
}

export async function getItemVersions(itemId: string) {
  return db
    .select({ version: artworkVersions, uploader: users })
    .from(artworkVersions)
    .leftJoin(users, eq(artworkVersions.uploadedBy, users.id))
    .where(eq(artworkVersions.signageItemId, itemId))
    .orderBy(desc(artworkVersions.versionNumber));
}

export async function getItemInstances(itemId: string) {
  const rows = await db
    .select({ instance: approvalInstances, decider: users })
    .from(approvalInstances)
    .leftJoin(users, eq(approvalInstances.decidedBy, users.id))
    .where(
      and(eq(approvalInstances.entityType, "signage_item"), eq(approvalInstances.entityId, itemId)),
    )
    .orderBy(
      desc(approvalInstances.runNumber),
      asc(approvalInstances.sortOrderSnapshot),
      asc(approvalInstances.createdAt),
    );
  return rows;
}

export async function getEntityComments(
  entityType: "signage_item" | "stand_submission",
  entityId: string,
  includeInternal: boolean,
) {
  return db
    .select({ comment: comments, author: users })
    .from(comments)
    .innerJoin(users, eq(comments.authorId, users.id))
    .where(
      and(
        eq(comments.entityType, entityType),
        eq(comments.entityId, entityId),
        isNull(comments.deletedAt),
        includeInternal ? undefined : eq(comments.isInternal, false),
      ),
    )
    .orderBy(asc(comments.createdAt));
}

export async function getEntityAudit(entityType: string, entityId: string) {
  return db
    .select({ entry: auditLog, actor: users })
    .from(auditLog)
    .leftJoin(users, eq(auditLog.actorUserId, users.id))
    .where(and(eq(auditLog.entityType, entityType), eq(auditLog.entityId, entityId)))
    .orderBy(desc(auditLog.createdAt))
    .limit(200);
}

export async function getItemSnags(itemId: string) {
  return db
    .select()
    .from(snags)
    .where(eq(snags.signageItemId, itemId))
    .orderBy(desc(snags.createdAt));
}

/**
 * How many approvals a new version would invalidate — shown in the upload
 * dialog ("This will invalidate 3 approvals") before the user confirms.
 */
export async function artworkInvalidationPreview(
  itemId: string,
): Promise<{ count: number; steps: string[] }> {
  const bundle = await loadItemBundle(db, itemId);
  if (!bundle || bundle.item.currentRunNumber === 0) return { count: 0, steps: [] };
  const run = await loadRun(db, "signage_item", itemId, bundle.item.currentRunNumber);
  const decided = run.filter(
    (i) =>
      ["approved", "approved_with_conditions", "confirmed"].includes(i.status) &&
      i.invalidateOnNewVersion,
  );
  return { count: decided.length, steps: decided.map((i) => i.stepName) };
}
