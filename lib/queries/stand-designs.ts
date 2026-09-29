import "server-only";
import { and, asc, eq, inArray, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  approvalInstances,
  artworkVersions,
  halls,
  locations,
  signageItems,
  sponsors,
  suppliers,
} from "@/lib/db/schema";
import { departmentNames } from "@/lib/domain/departments";
import { ensureStandDesignWorkflow } from "@/lib/domain/stand-designs";
import { itemFormOptions } from "@/lib/queries/item-form-options";
import { getInlineUrl } from "@/lib/storage";
import { APPROVED_OR_LATER, type SignageStatus } from "@/lib/status/signage";
import type { StandFormOptions } from "@/components/stand-designs/stand-form";

export type WaitingOn = { name: string; who: string | null; overdue: boolean };

/** What each item is waiting on now: its pending sign-off or confirmation steps. */
async function waitingOn(ids: string[]): Promise<Map<string, WaitingOn[]>> {
  const out = new Map<string, WaitingOn[]>();
  if (ids.length === 0) return out;
  const rows = await db
    .select()
    .from(approvalInstances)
    .where(
      and(
        eq(approvalInstances.entityType, "signage_item"),
        inArray(approvalInstances.entityId, ids),
        eq(approvalInstances.status, "pending"),
      ),
    )
    .orderBy(asc(approvalInstances.sortOrderSnapshot));
  const depts = await departmentNames(
    db,
    rows.map((r) => r.assignedDepartmentId),
  );
  const now = Date.now();
  for (const r of rows) {
    const list = out.get(r.entityId) ?? [];
    list.push({
      name: r.stepNameSnapshot,
      who: r.assignedDepartmentId ? (depts.get(r.assignedDepartmentId) ?? null) : r.assignedRole,
      overdue: Boolean(r.dueAt && r.dueAt.getTime() < now),
    });
    out.set(r.entityId, list);
  }
  return out;
}

const preview = (path: string | null, filePath: string | null, mime: string | null) =>
  path
    ? getInlineUrl("artwork", path).catch(() => null)
    : filePath && mime?.startsWith("image/") && !filePath.startsWith("seed/")
      ? getInlineUrl("artwork", filePath).catch(() => null)
      : Promise.resolve(null);

export type StandCard = {
  id: string;
  ref: string;
  name: string;
  status: string;
  standNumber: string | null;
  hallName: string | null;
  locationName: string | null;
  sponsorName: string | null;
  size: string | null;
  previewUrl: string | null;
  designVersion: number | null;
  waitingOn: WaitingOn[];
  panels: { total: number; approved: number };
};

function sizeLabel(w: number | null, d: number | null, h: number | null) {
  const parts = [w, d, h].filter((n): n is number => n != null);
  return parts.length ? `${parts.map((n) => n.toLocaleString("en-GB")).join(" × ")} mm` : null;
}

/** The show's designed stands, newest last, with where each one is up to. */
export async function listStandDesigns(editionId: string): Promise<StandCard[]> {
  const rows = await db
    .select({
      item: signageItems,
      hallName: halls.name,
      locationName: locations.name,
      sponsorName: sponsors.companyName,
      version: artworkVersions.versionNumber,
      previewPath: artworkVersions.previewPath,
      filePath: artworkVersions.filePath,
      mimeType: artworkVersions.mimeType,
    })
    .from(signageItems)
    .leftJoin(halls, eq(signageItems.hallId, halls.id))
    .leftJoin(locations, eq(signageItems.locationId, locations.id))
    .leftJoin(sponsors, eq(signageItems.sponsorId, sponsors.id))
    .leftJoin(artworkVersions, eq(signageItems.currentArtworkVersionId, artworkVersions.id))
    .where(
      and(
        eq(signageItems.editionId, editionId),
        eq(signageItems.kind, "stand_design"),
        isNull(signageItems.deletedAt),
      ),
    )
    .orderBy(asc(signageItems.seq));
  const ids = rows.map((r) => r.item.id);
  const [waiting, panelRows] = await Promise.all([
    waitingOn(ids),
    ids.length
      ? db
          .select({ parentId: signageItems.parentItemId, status: signageItems.status })
          .from(signageItems)
          .where(and(inArray(signageItems.parentItemId, ids), isNull(signageItems.deletedAt)))
      : [],
  ]);
  return Promise.all(
    rows.map(async (r) => {
      const panels = panelRows.filter((p) => p.parentId === r.item.id);
      return {
        id: r.item.id,
        ref: r.item.ref,
        name: r.item.name,
        status: r.item.status,
        standNumber: r.item.standNumber,
        hallName: r.hallName,
        locationName: r.locationName,
        sponsorName: r.sponsorName,
        size: sizeLabel(r.item.widthMm, r.item.depthMm, r.item.heightMm),
        previewUrl: await preview(r.previewPath, r.filePath, r.mimeType),
        designVersion: r.version,
        waitingOn: waiting.get(r.item.id) ?? [],
        panels: {
          total: panels.length,
          approved: panels.filter((p) => APPROVED_OR_LATER.includes(p.status as SignageStatus))
            .length,
        },
      };
    }),
  );
}

export type PanelRow = {
  id: string;
  ref: string;
  name: string;
  status: string;
  size: string | null;
  quantity: number;
  supplierName: string | null;
  previewUrl: string | null;
  version: number | null;
  waitingOn: WaitingOn[];
};

/** A stand's panels in the order they were added. */
export async function listStandPanels(standId: string): Promise<PanelRow[]> {
  const rows = await db
    .select({
      item: signageItems,
      supplierName: suppliers.name,
      version: artworkVersions.versionNumber,
      previewPath: artworkVersions.previewPath,
      filePath: artworkVersions.filePath,
      mimeType: artworkVersions.mimeType,
    })
    .from(signageItems)
    .leftJoin(suppliers, eq(signageItems.supplierId, suppliers.id))
    .leftJoin(artworkVersions, eq(signageItems.currentArtworkVersionId, artworkVersions.id))
    .where(and(eq(signageItems.parentItemId, standId), isNull(signageItems.deletedAt)))
    .orderBy(asc(signageItems.seq));
  const waiting = await waitingOn(rows.map((r) => r.item.id));
  return Promise.all(
    rows.map(async (r) => ({
      id: r.item.id,
      ref: r.item.ref,
      name: r.item.name,
      status: r.item.status,
      size: sizeLabel(r.item.widthMm, null, r.item.heightMm),
      quantity: r.item.quantity,
      supplierName: r.supplierName,
      previewUrl: await preview(r.previewPath, r.filePath, r.mimeType),
      version: r.version,
      waitingOn: waiting.get(r.item.id) ?? [],
    })),
  );
}

/** Pickers for the stand form: places, sponsors and the design approvers. */
export async function standFormOptions(opts: {
  organisationId: string;
  editionId: string;
  workflowId?: string | null;
}): Promise<StandFormOptions & { suppliers: { id: string; name: string }[] }> {
  const workflowId = opts.workflowId ?? (await ensureStandDesignWorkflow(db, opts.organisationId));
  const o = await itemFormOptions({
    organisationId: opts.organisationId,
    editionId: opts.editionId,
    kind: "signage",
    workflowId,
  });
  return {
    halls: o.halls,
    locations: o.locations,
    sponsors: o.sponsors,
    signoffSteps: o.signoffSteps ?? [],
    suppliers: o.suppliers.map((s) => ({ id: s.id, name: s.name })),
  };
}
