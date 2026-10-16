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
  externalGrants,
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
import {
  isMineRow,
  loadItemBundle,
  quickFiltersFor,
  rowIsOverdue,
  stepStillDue,
  type QuickFilter,
} from "@/lib/domain/signage";
import type { StaffActor } from "@/lib/authz";
import { artworkDue } from "@/lib/deadlines";
import { roleLabel } from "@/lib/format";
import { todayInLondon } from "@/lib/today";
import { editionForDeadlines } from "@/lib/queries/editions";
import { SIGNAGE_KINDS } from "@/lib/edition-path";
import { loadRun } from "@/lib/workflow/persist";
import { alias } from "drizzle-orm/pg-core";

/** A waiting sign-off or confirmation on a list row. */
export type ScheduleStep = {
  name: string;
  /** Department or role (kept for older callers); see `who` for the words to show. */
  role: string | null;
  /** Who it waits on: a named person, the department, the supplier or the role. */
  who: string;
  stepKind: "approval" | "confirmation";
  assignedRole: string | null;
  assignedUserId: string | null;
  assignedDepartmentId: string | null;
  dueAt: string | null;
  overdue: boolean;
};

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
  hallId: string | null;
  hallName: string | null;
  locationId: string | null;
  locationName: string | null;
  standNumber: string | null;
  sponsorName: string | null;
  supplierId: string | null;
  supplierName: string | null;
  ownerRole: string;
  ownerUserId: string | null;
  /** The owner's name (or email). */
  ownerName: string | null;
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
  /** The date artwork is due: the item's own, else the event's deadline. */
  artworkDue: string | null;
  currentVersion: number | null;
  previewPath: string | null;
  /** Waiting steps of the current round. */
  pendingSteps: ScheduleStep[];
  /** The status chips the row counts under (see quickFiltersFor). */
  quick: QuickFilter[];
};

/**
 * The signage list for an event: signs and sponsorship items, with who each
 * is waiting on, when the artwork is due, and (for `viewer`) which are theirs.
 */
export async function listScheduleRows(
  editionId: string,
  opts: { viewer?: StaffActor; today?: string } = {},
): Promise<ScheduleRow[]> {
  const today = opts.today ?? todayInLondon();
  const owner = alias(users, "item_owner");
  const [rows, deadlines] = await Promise.all([
    db
      .select({
        item: signageItems,
        ownerName: owner.fullName,
        ownerEmail: owner.email,
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
      .leftJoin(owner, eq(owner.id, signageItems.ownerUserId))
      // Everything for the show — organiser signage, sponsor signage and the
      // items sold in the Sponsorship section — in one schedule.
      .where(
        and(
          eq(signageItems.editionId, editionId),
          isNull(signageItems.deletedAt),
          // Stands and their panels live in Stand designs.
          inArray(signageItems.kind, [...SIGNAGE_KINDS]),
        ),
      )
      .orderBy(asc(signageItems.seq)),
    editionForDeadlines(editionId),
  ]);

  const ids = rows.map((r) => r.item.id);
  const pending = ids.length
    ? await db
        .select({
          instance: approvalInstances,
          assigneeName: users.fullName,
          assigneeEmail: users.email,
        })
        .from(approvalInstances)
        .leftJoin(users, eq(approvalInstances.assignedUserId, users.id))
        .where(
          and(
            eq(approvalInstances.entityType, "signage_item"),
            inArray(approvalInstances.entityId, ids),
            eq(approvalInstances.status, "pending"),
          ),
        )
        .orderBy(asc(approvalInstances.sortOrderSnapshot))
    : [];
  const deptNames = await departmentNames(
    db,
    pending.map((p) => p.instance.assignedDepartmentId),
  );
  const runOf = new Map(rows.map((r) => [r.item.id, r.item.currentRunNumber]));
  const statusOf = new Map(rows.map((r) => [r.item.id, r.item.status as string]));
  const pendingByItem = new Map<string, typeof pending>();
  for (const p of pending) {
    // Only the current round counts; an older round's leftovers don't.
    if (runOf.get(p.instance.entityId) !== p.instance.runNumber) continue;
    const status = statusOf.get(p.instance.entityId) ?? "";
    if (
      !stepStillDue(
        { stepKind: p.instance.stepKindSnapshot, stepName: p.instance.stepNameSnapshot },
        status,
      )
    ) {
      continue;
    }
    const list = pendingByItem.get(p.instance.entityId) ?? [];
    list.push(p);
    pendingByItem.set(p.instance.entityId, list);
  }

  const now = Date.now();
  return rows.map((r) => {
    const department = (id: string | null) => (id ? (deptNames.get(id) ?? null) : null);
    const pendingSteps: ScheduleStep[] = (pendingByItem.get(r.item.id) ?? []).map(
      ({ instance: p, assigneeName, assigneeEmail }) => {
        const dept = department(p.assignedDepartmentId);
        const who =
          (p.assignedUserId && (assigneeName || assigneeEmail)) ||
          dept ||
          (p.assignedRole === "supplier"
            ? (r.supplierName ?? "Supplier")
            : roleLabel(p.assignedRole));
        return {
          name: p.stepNameSnapshot,
          role: dept ?? p.assignedRole,
          who,
          stepKind: p.stepKindSnapshot,
          assignedRole: p.assignedRole,
          assignedUserId: p.assignedUserId,
          assignedDepartmentId: p.assignedDepartmentId,
          dueAt: p.dueAt?.toISOString() ?? null,
          overdue: Boolean(p.dueAt && p.dueAt.getTime() < now),
        };
      },
    );
    const artworkDueDate = deadlines
      ? artworkDue({ artworkDueOverride: r.item.artworkDueOverride }, deadlines)
      : r.item.artworkDueOverride;
    const hasArtwork = r.currentVersion != null;
    const base = {
      status: r.item.status,
      hasArtwork,
      artworkDue: artworkDueDate,
      pendingSteps,
    };
    return {
      id: r.item.id,
      ref: r.item.ref,
      name: r.item.name,
      status: r.item.status,
      kind: r.item.kind as "signage" | "sponsorship_item",
      category: r.item.category,
      typeName: r.typeName,
      format: r.format,
      hallId: r.item.hallId,
      hallName: r.hallName,
      locationId: r.item.locationId,
      locationName: r.locationName,
      standNumber: r.item.standNumber,
      sponsorName: r.sponsorName,
      supplierId: r.item.supplierId,
      supplierName: r.supplierName,
      ownerRole: r.item.ownerRole,
      ownerUserId: r.item.ownerUserId,
      ownerName: r.ownerName || r.ownerEmail || null,
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
      artworkDue: artworkDueDate,
      currentVersion: r.currentVersion,
      previewPath: r.previewPath,
      pendingSteps,
      quick: quickFiltersFor({
        status: r.item.status,
        hasArtwork,
        overdue: rowIsOverdue(base, today),
        mine: opts.viewer
          ? isMineRow({ ownerUserId: r.item.ownerUserId, pendingSteps }, opts.viewer)
          : false,
      }),
    };
  });
}

export type DeletedRow = {
  id: string;
  ref: string;
  name: string;
  kind: string;
  deletedAt: Date;
  deletedBy: string | null;
};

/**
 * An event's deleted items, most recently deleted first, with who deleted
 * each (from its latest delete in the audit log).
 */
export async function listDeletedItems(editionId: string, limit = 200): Promise<DeletedRow[]> {
  const rows = await db
    .select({
      id: signageItems.id,
      ref: signageItems.ref,
      name: signageItems.name,
      kind: signageItems.kind,
      deletedAt: signageItems.deletedAt,
    })
    .from(signageItems)
    .where(and(eq(signageItems.editionId, editionId), isNotNull(signageItems.deletedAt)))
    .orderBy(desc(signageItems.deletedAt))
    .limit(limit);
  if (rows.length === 0) return [];
  const deletes = await db
    .select({
      entityId: auditLog.entityId,
      at: auditLog.createdAt,
      name: users.fullName,
      email: users.email,
    })
    .from(auditLog)
    .leftJoin(users, eq(auditLog.actorUserId, users.id))
    .where(
      and(
        eq(auditLog.entityType, "signage_item"),
        eq(auditLog.action, "soft_delete"),
        inArray(
          auditLog.entityId,
          rows.map((r) => r.id),
        ),
      ),
    )
    .orderBy(desc(auditLog.createdAt));
  const by = new Map<string, string | null>();
  for (const d of deletes) {
    if (d.entityId && !by.has(d.entityId)) by.set(d.entityId, d.name || d.email || null);
  }
  return rows.map((r) => ({
    id: r.id,
    ref: r.ref,
    name: r.name,
    kind: r.kind,
    deletedAt: r.deletedAt!,
    deletedBy: by.get(r.id) ?? null,
  }));
}

/** How many of an event's items are deleted (for "Recently deleted (n)"). */
export async function countDeletedItems(editionId: string): Promise<number> {
  const [row] = await db
    .select({ n: sql<number>`count(*)::int` })
    .from(signageItems)
    .where(and(eq(signageItems.editionId, editionId), isNotNull(signageItems.deletedAt)));
  return Number(row?.n ?? 0);
}

export type SponsorshipRow = {
  id: string;
  ref: string;
  name: string;
  status: string;
  /** The status it was put on hold from. */
  previousStatus: string | null;
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
  /** Who the current round's sign-off waits on ("Marketing", "Dana Director"). */
  waitingOn: string[];
};

/**
 * Who each item's current sign-off round waits on: the named person, else
 * the department, else the role. Approval steps only.
 */
async function signoffWaitingOn(
  rows: { id: string; currentRunNumber: number }[],
): Promise<Map<string, string[]>> {
  const out = new Map<string, string[]>();
  if (rows.length === 0) return out;
  const runOf = new Map(rows.map((r) => [r.id, r.currentRunNumber]));
  const pending = await db
    .select({ instance: approvalInstances, name: users.fullName, email: users.email })
    .from(approvalInstances)
    .leftJoin(users, eq(approvalInstances.assignedUserId, users.id))
    .where(
      and(
        eq(approvalInstances.entityType, "signage_item"),
        inArray(
          approvalInstances.entityId,
          rows.map((r) => r.id),
        ),
        eq(approvalInstances.status, "pending"),
        eq(approvalInstances.stepKindSnapshot, "approval"),
      ),
    )
    .orderBy(asc(approvalInstances.sortOrderSnapshot));
  const depts = await departmentNames(
    db,
    pending.map((p) => p.instance.assignedDepartmentId),
  );
  for (const { instance: p, name, email } of pending) {
    if (runOf.get(p.entityId) !== p.runNumber) continue;
    const who =
      (p.assignedUserId && (name || email)) ||
      (p.assignedDepartmentId ? depts.get(p.assignedDepartmentId) : null) ||
      roleLabel(p.assignedRole);
    out.set(p.entityId, [...(out.get(p.entityId) ?? []), who]);
  }
  return out;
}

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
        inArray(signageItems.kind, [...SIGNAGE_KINDS]),
        isNull(signageItems.deletedAt),
      ),
    )
    .orderBy(sql`${signageItems.orderByDate} ASC NULLS LAST`, asc(signageItems.seq));
  const waiting = await signoffWaitingOn(
    rows
      .filter((r) => r.item.status === "in_review")
      .map((r) => ({ id: r.item.id, currentRunNumber: r.item.currentRunNumber })),
  );
  return rows.map((r) => ({
    id: r.item.id,
    ref: r.item.ref,
    name: r.item.name,
    status: r.item.status,
    previousStatus: r.item.previousStatus,
    typeName: r.typeName,
    kind: r.item.kind as "signage" | "sponsorship_item",
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
    waitingOn: waiting.get(r.item.id) ?? [],
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

/** An item's snags with who raised and who fixed each one (names, not ids). */
export async function getItemSnagsWithPeople(itemId: string) {
  const raiser = alias(users, "snag_raiser");
  const fixer = alias(users, "snag_fixer");
  const rows = await db
    .select({
      snag: snags,
      raisedName: raiser.fullName,
      raisedEmail: raiser.email,
      fixedName: fixer.fullName,
      fixedEmail: fixer.email,
    })
    .from(snags)
    .leftJoin(raiser, eq(raiser.id, snags.raisedByUserId))
    .leftJoin(fixer, eq(fixer.id, snags.resolvedBy))
    .where(eq(snags.signageItemId, itemId))
    .orderBy(desc(snags.createdAt));
  return rows.map((r) => ({
    ...r.snag,
    raisedByName: r.raisedName || r.raisedEmail || null,
    resolvedByName: r.fixedName || r.fixedEmail || null,
  }));
}

/**
 * How many approvals a new version would invalidate — shown in the upload
 * dialog ("This will invalidate 3 approvals") before the user confirms.
 */
export type InvalidationPreview = {
  count: number;
  steps: string[];
  /** Stand designs: panels already approved or in production on this design. */
  panels: { approved: number; inProduction: number } | null;
};

export async function artworkInvalidationPreview(itemId: string): Promise<InvalidationPreview> {
  const bundle = await loadItemBundle(db, itemId);
  if (!bundle) return { count: 0, steps: [], panels: null };
  const panels = bundle.item.kind === "stand_design" ? await standPanelCounts(itemId) : null;
  if (bundle.item.currentRunNumber === 0) return { count: 0, steps: [], panels };
  const run = await loadRun(db, "signage_item", itemId, bundle.item.currentRunNumber);
  const decided = run.filter(
    (i) =>
      ["approved", "approved_with_conditions", "confirmed"].includes(i.status) &&
      i.invalidateOnNewVersion,
  );
  return { count: decided.length, steps: decided.map((i) => i.stepName), panels };
}

/** How many of a stand's panels are signed off, and how many are already being made. */
export async function standPanelCounts(
  standId: string,
): Promise<{ approved: number; inProduction: number }> {
  const rows = await db
    .select({ status: signageItems.status })
    .from(signageItems)
    .where(and(eq(signageItems.parentItemId, standId), isNull(signageItems.deletedAt)));
  const inProduction = rows.filter((r) =>
    ["in_production", "delivered", "installed", "snagged", "closed"].includes(r.status),
  ).length;
  const approved = rows.filter((r) =>
    ["approved", "approved_with_conditions"].includes(r.status),
  ).length;
  return { approved, inProduction };
}

/** "3 panels are approved and 1 panel is in production — check they still fit the new design." */
export function panelWarning(
  panels: { approved: number; inProduction: number } | null,
): string | null {
  if (!panels || panels.approved + panels.inProduction === 0) return null;
  const say = (n: number, state: string) => `${n} ${n === 1 ? "panel is" : "panels are"} ${state}`;
  const parts: string[] = [];
  if (panels.approved) parts.push(say(panels.approved, "approved"));
  if (panels.inProduction) parts.push(say(panels.inProduction, "in production"));
  return `${parts.join(" and ")} — check they still fit the new design.`;
}

export type OnsiteRow = {
  id: string;
  ref: string;
  name: string;
  kind: string;
  status: string;
  hallId: string | null;
  hallName: string | null;
  locationName: string | null;
  standNumber: string | null;
  installDate: string | null;
  installSlot: string | null;
  contractorName: string | null;
  supplierName: string | null;
  installedAt: string | null;
  openSnags: number;
  /** The open snags themselves, newest first (photo paths, not URLs). */
  openSnagList: {
    id: string;
    description: string;
    severity: string;
    status: string;
    photoPath: string | null;
    /** Who reported it, when known, and when. */
    raisedByName: string | null;
    raisedAt: string;
  }[];
  /** Someone at the item's supplier can sign in (a live, accepted portal invitation). */
  supplierHasAccess: boolean;
  currentArtworkVersionId: string | null;
  /**
   * The earliest production confirmation still waiting in the current
   * round (Sent to print, Delivered or Installed), with who holds it.
   */
  pendingConfirmation: {
    id: string;
    stepName: string;
    /** The round's last confirmation: the install step, whatever it is called. */
    isInstall: boolean;
    assignedRole: string | null;
    assignedUserId: string | null;
    assignedDepartmentId: string | null;
    /** "Operations", "Big Print Co", a person's name. */
    who: string;
  } | null;
  authz: {
    ownerUserId: string | null;
    sponsorId: string | null;
    supplierId: string | null;
    requiresVenueApproval: boolean;
  };
};

/** Statuses that mean the thing exists physically and can be installed or checked. */
const ONSITE_STATUSES = ["in_production", "delivered", "installed", "snagged", "closed"];

/**
 * The Onsite checklist: every sign, sponsorship item and stand panel that is
 * printed or later, with what it needs next (the confirmation that is
 * waiting, its open snags, close). Ordered by install date and slot, then ref.
 */
export async function listOnsiteRows(editionId: string): Promise<OnsiteRow[]> {
  const rows = await db
    .select({
      item: signageItems,
      hallName: halls.name,
      locationName: locations.name,
      contractorName: contractors.name,
      supplierName: suppliers.name,
    })
    .from(signageItems)
    .leftJoin(halls, eq(signageItems.hallId, halls.id))
    .leftJoin(locations, eq(signageItems.locationId, locations.id))
    .leftJoin(contractors, eq(signageItems.installContractorId, contractors.id))
    .leftJoin(suppliers, eq(signageItems.supplierId, suppliers.id))
    .where(
      and(
        eq(signageItems.editionId, editionId),
        isNull(signageItems.deletedAt),
        inArray(signageItems.kind, ["signage", "sponsorship_item", "stand_panel"]),
        inArray(
          signageItems.status,
          ONSITE_STATUSES as (typeof signageItems.$inferSelect)["status"][],
        ),
      ),
    )
    .orderBy(asc(signageItems.installDate), asc(signageItems.installSlot), asc(signageItems.seq));
  const ids = rows.map((r) => r.item.id);
  if (ids.length === 0) return [];
  const [confirmations, openSnagRows] = await Promise.all([
    db
      .select({ instance: approvalInstances, name: users.fullName, email: users.email })
      .from(approvalInstances)
      .leftJoin(users, eq(approvalInstances.assignedUserId, users.id))
      .where(
        and(
          eq(approvalInstances.entityType, "signage_item"),
          inArray(approvalInstances.entityId, ids),
          eq(approvalInstances.stepKindSnapshot, "confirmation"),
        ),
      )
      .orderBy(asc(approvalInstances.sortOrderSnapshot)),
    db
      .select({ snag: snags, raisedName: users.fullName, raisedEmail: users.email })
      .from(snags)
      .leftJoin(users, eq(users.id, snags.raisedByUserId))
      .where(and(inArray(snags.signageItemId, ids), inArray(snags.status, ["open", "in_progress"])))
      .orderBy(desc(snags.createdAt)),
  ]);
  // Suppliers with someone who can sign in for this event (an accepted,
  // live invitation of an active account).
  const supplierIds = [
    ...new Set(rows.map((r) => r.item.supplierId).filter((x): x is string => Boolean(x))),
  ];
  const withAccess = new Set<string>();
  if (supplierIds.length > 0) {
    const grants = await db
      .select({ scopeId: externalGrants.scopeId, expiresAt: externalGrants.expiresAt })
      .from(externalGrants)
      .where(
        and(
          eq(externalGrants.editionId, editionId),
          eq(externalGrants.role, "supplier"),
          eq(externalGrants.scopeType, "supplier"),
          inArray(externalGrants.scopeId, supplierIds),
          isNotNull(externalGrants.userId),
          isNull(externalGrants.revokedAt),
        ),
      );
    for (const g of grants) {
      if (g.scopeId && (!g.expiresAt || g.expiresAt.getTime() > Date.now()))
        withAccess.add(g.scopeId);
    }
  }
  const deptNames = await departmentNames(
    db,
    confirmations.map((c) => c.instance.assignedDepartmentId),
  );
  const byItem = new Map<string, typeof confirmations>();
  for (const c of confirmations) {
    byItem.set(c.instance.entityId, [...(byItem.get(c.instance.entityId) ?? []), c]);
  }
  return rows.map((r) => {
    const round = (byItem.get(r.item.id) ?? []).filter(
      (c) => c.instance.runNumber === r.item.currentRunNumber,
    );
    const last = round[round.length - 1];
    const first = round.find((c) => c.instance.status === "pending");
    const itemSnags = openSnagRows.filter((s) => s.snag.signageItemId === r.item.id);
    const p = first?.instance;
    return {
      id: r.item.id,
      ref: r.item.ref,
      name: r.item.name,
      kind: r.item.kind,
      status: r.item.status,
      hallId: r.item.hallId,
      hallName: r.hallName,
      locationName: r.locationName,
      standNumber: r.item.standNumber,
      installDate: r.item.installDate,
      installSlot: r.item.installSlot,
      contractorName: r.contractorName,
      supplierName: r.supplierName,
      installedAt: r.item.installedAt?.toISOString() ?? null,
      openSnags: itemSnags.length,
      openSnagList: itemSnags.map(({ snag: s, raisedName, raisedEmail }) => ({
        id: s.id,
        description: s.description,
        severity: s.severity,
        status: s.status,
        photoPath: s.photoPath,
        raisedByName: raisedName || raisedEmail || null,
        raisedAt: s.createdAt.toISOString(),
      })),
      supplierHasAccess: Boolean(r.item.supplierId && withAccess.has(r.item.supplierId)),
      currentArtworkVersionId: r.item.currentArtworkVersionId,
      pendingConfirmation: p
        ? {
            id: p.id,
            stepName: p.stepNameSnapshot,
            isInstall: p.id === last?.instance.id,
            assignedRole: p.assignedRole,
            assignedUserId: p.assignedUserId,
            assignedDepartmentId: p.assignedDepartmentId,
            who:
              (p.assignedUserId && (first.name || first.email)) ||
              (p.assignedDepartmentId ? deptNames.get(p.assignedDepartmentId) : null) ||
              (p.assignedRole === "supplier"
                ? (r.supplierName ?? "the supplier")
                : roleLabel(p.assignedRole)),
          }
        : null,
      authz: {
        ownerUserId: r.item.ownerUserId,
        sponsorId: r.item.sponsorId,
        supplierId: r.item.supplierId,
        requiresVenueApproval: r.item.requiresVenueApproval,
      },
    };
  });
}
