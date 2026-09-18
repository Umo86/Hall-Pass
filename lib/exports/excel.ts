import "server-only";
import ExcelJS from "exceljs";
import { and, asc, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  approvalInstances,
  contractors,
  editions,
  exhibitors,
  halls,
  itemTypes,
  locations,
  signageItems,
  sponsors,
  standSubmissions,
  suppliers,
  users,
} from "@/lib/db/schema";
import { formatDate, statusLabel } from "@/lib/format";

const STATUS_FILLS: Record<string, string> = {
  draft: "FFE5E5E5",
  awaiting_artwork: "FFFDE9C8",
  in_review: "FFD6EAF8",
  changes_requested: "FFFAD7A0",
  approved: "FFD5F5E3",
  approved_with_conditions: "FFD1F2EB",
  in_production: "FFE8DAEF",
  delivered: "FFD6DBF5",
  installed: "FFD5F5E3",
  snagged: "FFF5D5DB",
  closed: "FFD0D3D4",
  rejected: "FFF5B7B1",
  on_hold: "FFFCF3CF",
};

function styleHeader(row: ExcelJS.Row) {
  row.font = { bold: true, color: { argb: "FFFFFFFF" } };
  row.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF262626" } };
  row.height = 18;
}

/** Signage schedule: one sheet per hall plus a summary, approval columns. */
export async function buildScheduleWorkbook(editionId: string, includeCosts: boolean) {
  const [edition] = await db.select().from(editions).where(eq(editions.id, editionId));
  const rows = await db
    .select({
      item: signageItems,
      typeName: itemTypes.name,
      hallName: halls.name,
      locationName: locations.name,
      sponsorName: sponsors.companyName,
      supplierName: suppliers.name,
    })
    .from(signageItems)
    .leftJoin(itemTypes, eq(signageItems.itemTypeId, itemTypes.id))
    .leftJoin(halls, eq(signageItems.hallId, halls.id))
    .leftJoin(locations, eq(signageItems.locationId, locations.id))
    .leftJoin(sponsors, eq(signageItems.sponsorId, sponsors.id))
    .leftJoin(suppliers, eq(signageItems.supplierId, suppliers.id))
    .where(and(eq(signageItems.editionId, editionId), isNull(signageItems.deletedAt)))
    .orderBy(asc(signageItems.seq));

  // Approval status per step, e.g. "Approved 12 Mar 2027, J Smith, v3".
  const instances = await db
    .select({ instance: approvalInstances, decider: users })
    .from(approvalInstances)
    .leftJoin(users, eq(approvalInstances.decidedBy, users.id))
    .where(eq(approvalInstances.entityType, "signage_item"));
  const byItem = new Map<string, { step: string; text: string; order: number }[]>();
  const stepNames = new Set<string>();
  for (const { instance, decider } of instances) {
    if (instance.status === "invalidated" || instance.status === "skipped") continue;
    stepNames.add(instance.stepNameSnapshot);
    const list = byItem.get(instance.entityId) ?? [];
    const versionSuffix = instance.lockedVersionId ? "" : "";
    const text =
      instance.decidedAt && decider
        ? `${statusLabel(instance.status)} ${formatDate(instance.decidedAt)}, ${decider.fullName || decider.email}${versionSuffix}`
        : statusLabel(instance.status);
    list.push({ step: instance.stepNameSnapshot, text, order: instance.sortOrderSnapshot });
    byItem.set(instance.entityId, list);
  }
  const orderedSteps = [...stepNames].sort();

  const wb = new ExcelJS.Workbook();
  wb.creator = "Hall Pass";

  const baseColumns = [
    { header: "Ref", key: "ref", width: 16 },
    { header: "Name", key: "name", width: 36 },
    { header: "Status", key: "status", width: 20 },
    { header: "Type", key: "type", width: 18 },
    { header: "Hall", key: "hall", width: 12 },
    { header: "Location", key: "location", width: 20 },
    { header: "W (mm)", key: "w", width: 9 },
    { header: "H (mm)", key: "h", width: 9 },
    { header: "Qty", key: "qty", width: 6 },
    { header: "Material", key: "material", width: 16 },
    { header: "Finish", key: "finish", width: 12 },
    { header: "Fixing", key: "fixing", width: 14 },
    { header: "Sponsor", key: "sponsor", width: 16 },
    { header: "Supplier", key: "supplier", width: 16 },
    { header: "Install", key: "install", width: 14 },
    ...(includeCosts
      ? [
          { header: "Estimate £", key: "estimate", width: 12 },
          { header: "Actual £", key: "actual", width: 12 },
          { header: "PO", key: "po", width: 12 },
        ]
      : []),
    ...orderedSteps.map((s) => ({ header: s, key: `step:${s}`, width: 30 })),
  ];

  function addRows(ws: ExcelJS.Worksheet, data: typeof rows) {
    ws.columns = baseColumns as ExcelJS.Column[];
    styleHeader(ws.getRow(1));
    ws.views = [{ state: "frozen", ySplit: 1, xSplit: 2 }];
    for (const r of data) {
      const stepCells = Object.fromEntries(
        (byItem.get(r.item.id) ?? []).map((s) => [`step:${s.step}`, s.text]),
      );
      const row = ws.addRow({
        ref: r.item.ref,
        name: r.item.name,
        status: statusLabel(r.item.status),
        type: r.typeName ?? "",
        hall: r.hallName ?? "",
        location: r.locationName ?? "",
        w: r.item.widthMm ?? "",
        h: r.item.heightMm ?? "",
        qty: r.item.quantity,
        material: r.item.material ?? "",
        finish: r.item.finish ?? "",
        fixing: r.item.fixingMethod ? statusLabel(r.item.fixingMethod) : "",
        sponsor: r.sponsorName ?? "",
        supplier: r.supplierName ?? "",
        install: r.item.installDate
          ? `${formatDate(r.item.installDate)}${r.item.installSlot ? ` ${r.item.installSlot.toUpperCase()}` : ""}`
          : "",
        ...(includeCosts
          ? {
              estimate: r.item.costEstimate ? Number(r.item.costEstimate) : "",
              actual: r.item.costActual ? Number(r.item.costActual) : "",
              po: r.item.poNumber ?? "",
            }
          : {}),
        ...stepCells,
      });
      const fill = STATUS_FILLS[r.item.status];
      if (fill) {
        row.getCell("status").fill = {
          type: "pattern",
          pattern: "solid",
          fgColor: { argb: fill },
        };
      }
    }
  }

  const summary = wb.addWorksheet("Summary");
  addRows(summary, rows);

  const hallNames = [...new Set(rows.map((r) => r.hallName).filter(Boolean))] as string[];
  for (const hallName of hallNames) {
    const ws = wb.addWorksheet(hallName.slice(0, 31));
    addRows(
      ws,
      rows.filter((r) => r.hallName === hallName),
    );
  }

  return { workbook: wb, edition };
}

/**
 * Contractor install schedule: what goes up where and when, one sheet per
 * install contractor plus deliveries — the document handed to install crews.
 */
export async function buildContractorSchedule(editionId: string) {
  const [edition] = await db.select().from(editions).where(eq(editions.id, editionId));
  const rows = await db
    .select({
      item: signageItems,
      typeName: itemTypes.name,
      hallName: halls.name,
      locationName: locations.name,
      contractorName: contractors.name,
    })
    .from(signageItems)
    .leftJoin(itemTypes, eq(signageItems.itemTypeId, itemTypes.id))
    .leftJoin(halls, eq(signageItems.hallId, halls.id))
    .leftJoin(locations, eq(signageItems.locationId, locations.id))
    .leftJoin(contractors, eq(signageItems.installContractorId, contractors.id))
    .where(and(eq(signageItems.editionId, editionId), isNull(signageItems.deletedAt)))
    .orderBy(asc(signageItems.installDate), asc(signageItems.seq));

  const wb = new ExcelJS.Workbook();
  wb.creator = "Hall Pass";

  const columns = [
    { header: "Install date", key: "date", width: 14 },
    { header: "Slot", key: "slot", width: 8 },
    { header: "Ref", key: "ref", width: 16 },
    { header: "Name", key: "name", width: 36 },
    { header: "Hall", key: "hall", width: 12 },
    { header: "Location", key: "location", width: 20 },
    { header: "Type", key: "type", width: 18 },
    { header: "W (mm)", key: "w", width: 9 },
    { header: "H (mm)", key: "h", width: 9 },
    { header: "Qty", key: "qty", width: 6 },
    { header: "Fixing", key: "fixing", width: 16 },
    { header: "Weight (kg)", key: "weight", width: 11 },
    { header: "Status", key: "status", width: 20 },
    { header: "Contractor", key: "contractor", width: 20 },
  ];

  function fillSheet(ws: ExcelJS.Worksheet, data: typeof rows) {
    ws.columns = columns as ExcelJS.Column[];
    styleHeader(ws.getRow(1));
    ws.views = [{ state: "frozen", ySplit: 1, xSplit: 3 }];
    for (const r of data) {
      const row = ws.addRow({
        date: r.item.installDate ? formatDate(r.item.installDate) : "TBC",
        slot: r.item.installSlot?.toUpperCase() ?? "",
        ref: r.item.ref,
        name: r.item.name,
        hall: r.hallName ?? "",
        location: r.locationName ?? "",
        type: r.typeName ?? "",
        w: r.item.widthMm ?? "",
        h: r.item.heightMm ?? "",
        qty: r.item.quantity,
        fixing: r.item.fixingMethod ? statusLabel(r.item.fixingMethod) : "",
        weight: r.item.weightKg ? Number(r.item.weightKg) : "",
        status: statusLabel(r.item.status),
        contractor: r.contractorName ?? "Unassigned",
      });
      const fill = STATUS_FILLS[r.item.status];
      if (fill) {
        row.getCell("status").fill = { type: "pattern", pattern: "solid", fgColor: { argb: fill } };
      }
    }
  }

  fillSheet(wb.addWorksheet("All installs"), rows);
  const names = [...new Set(rows.map((r) => r.contractorName ?? "Unassigned"))];
  for (const name of names) {
    fillSheet(
      wb.addWorksheet(name.slice(0, 31)),
      rows.filter((r) => (r.contractorName ?? "Unassigned") === name),
    );
  }

  const deliveries = wb.addWorksheet("Deliveries");
  deliveries.columns = [
    { header: "Delivery date", key: "date", width: 14 },
    { header: "Ref", key: "ref", width: 16 },
    { header: "Name", key: "name", width: 36 },
    { header: "Hall", key: "hall", width: 12 },
    { header: "Qty", key: "qty", width: 6 },
    { header: "Supplier PO", key: "po", width: 14 },
    { header: "Status", key: "status", width: 20 },
  ] as ExcelJS.Column[];
  styleHeader(deliveries.getRow(1));
  for (const r of rows.filter((r) => r.item.deliveryDate)) {
    deliveries.addRow({
      date: formatDate(r.item.deliveryDate!),
      ref: r.item.ref,
      name: r.item.name,
      hall: r.hallName ?? "",
      qty: r.item.quantity,
      po: r.item.poNumber ?? "",
      status: statusLabel(r.item.status),
    });
  }

  return { workbook: wb, edition };
}

/**
 * Venue submission pack: every item needing venue approval (rigging,
 * suspended and structural pieces) with weights, fixings and approval state —
 * the workbook sent to the venue's rigging team.
 */
export async function buildVenuePack(editionId: string) {
  const [edition] = await db.select().from(editions).where(eq(editions.id, editionId));
  const rows = await db
    .select({
      item: signageItems,
      typeName: itemTypes.name,
      hallName: halls.name,
      locationName: locations.name,
    })
    .from(signageItems)
    .leftJoin(itemTypes, eq(signageItems.itemTypeId, itemTypes.id))
    .leftJoin(halls, eq(signageItems.hallId, halls.id))
    .leftJoin(locations, eq(signageItems.locationId, locations.id))
    .where(
      and(
        eq(signageItems.editionId, editionId),
        eq(signageItems.requiresVenueApproval, true),
        isNull(signageItems.deletedAt),
      ),
    )
    .orderBy(asc(signageItems.seq));

  const instances = await db
    .select({ instance: approvalInstances, decider: users })
    .from(approvalInstances)
    .leftJoin(users, eq(approvalInstances.decidedBy, users.id))
    .where(eq(approvalInstances.entityType, "signage_item"));
  const venueState = new Map<string, string>();
  for (const { instance, decider } of instances) {
    if (instance.assignedRole !== "venue" || instance.status === "invalidated") continue;
    const text = instance.decidedAt
      ? `${statusLabel(instance.status)} ${formatDate(instance.decidedAt)} (${decider?.fullName ?? "—"})`
      : statusLabel(instance.status);
    venueState.set(instance.entityId, text);
  }

  const wb = new ExcelJS.Workbook();
  wb.creator = "Hall Pass";
  const ws = wb.addWorksheet("Venue submission");
  ws.columns = [
    { header: "Ref", key: "ref", width: 16 },
    { header: "Name", key: "name", width: 36 },
    { header: "Hall", key: "hall", width: 12 },
    { header: "Location", key: "location", width: 20 },
    { header: "Type", key: "type", width: 18 },
    { header: "W (mm)", key: "w", width: 9 },
    { header: "H (mm)", key: "h", width: 9 },
    { header: "D (mm)", key: "d", width: 9 },
    { header: "Qty", key: "qty", width: 6 },
    { header: "Weight (kg)", key: "weight", width: 11 },
    { header: "Fixing method", key: "fixing", width: 18 },
    { header: "Material", key: "material", width: 16 },
    { header: "Install date", key: "install", width: 14 },
    { header: "Venue approval", key: "venue", width: 32 },
  ] as ExcelJS.Column[];
  styleHeader(ws.getRow(1));
  ws.views = [{ state: "frozen", ySplit: 1, xSplit: 2 }];
  for (const r of rows) {
    ws.addRow({
      ref: r.item.ref,
      name: r.item.name,
      hall: r.hallName ?? "",
      location: r.locationName ?? "",
      type: r.typeName ?? "",
      w: r.item.widthMm ?? "",
      h: r.item.heightMm ?? "",
      d: r.item.depthMm ?? "",
      qty: r.item.quantity,
      weight: r.item.weightKg ? Number(r.item.weightKg) : "",
      fixing: r.item.fixingMethod ? statusLabel(r.item.fixingMethod) : "",
      material: r.item.material ?? "",
      install: r.item.installDate ? formatDate(r.item.installDate) : "",
      venue: venueState.get(r.item.id) ?? "Not yet submitted",
    });
  }
  return { workbook: wb, edition };
}

/** Stand approval register. */
export async function buildStandRegister(editionId: string) {
  const [edition] = await db.select().from(editions).where(eq(editions.id, editionId));
  const rows = await db
    .select({ exhibitor: exhibitors, sub: standSubmissions, contractor: contractors })
    .from(exhibitors)
    .leftJoin(standSubmissions, eq(standSubmissions.exhibitorId, exhibitors.id))
    .leftJoin(contractors, eq(exhibitors.contractorId, contractors.id))
    .where(eq(exhibitors.editionId, editionId))
    .orderBy(asc(exhibitors.standNumber));

  const instances = await db
    .select({ instance: approvalInstances, decider: users })
    .from(approvalInstances)
    .leftJoin(users, eq(approvalInstances.decidedBy, users.id))
    .where(eq(approvalInstances.entityType, "stand_submission"));

  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet("Stand approvals");
  ws.columns = [
    { header: "Stand", key: "stand", width: 10 },
    { header: "Exhibitor", key: "exhibitor", width: 28 },
    { header: "Type", key: "type", width: 14 },
    { header: "Contractor", key: "contractor", width: 22 },
    { header: "Status", key: "status", width: 22 },
    { header: "Complex", key: "complex", width: 10 },
    { header: "Max height (mm)", key: "height", width: 14 },
    { header: "Outcome", key: "outcome", width: 24 },
    { header: "Conditions", key: "conditions", width: 40 },
    { header: "Approvals", key: "approvals", width: 60 },
  ] as ExcelJS.Column[];
  styleHeader(ws.getRow(1));
  ws.views = [{ state: "frozen", ySplit: 1 }];

  for (const r of rows) {
    const subInstances = r.sub
      ? instances
          .filter(
            ({ instance }) =>
              instance.entityId === r.sub!.id &&
              instance.decidedAt &&
              instance.status !== "invalidated",
          )
          .map(
            ({ instance, decider }) =>
              `${instance.stepNameSnapshot}: ${statusLabel(instance.status)} ${formatDate(instance.decidedAt)} (${decider?.fullName ?? "—"})`,
          )
          .join("; ")
      : "";
    ws.addRow({
      stand: r.exhibitor.standNumber,
      exhibitor: r.exhibitor.companyName,
      type: statusLabel(r.exhibitor.standType),
      contractor: r.contractor?.name ?? "",
      status: statusLabel(r.sub?.status ?? "not_submitted"),
      complex: r.sub?.isComplex ? "Yes" : "No",
      height: r.sub?.maxHeightMm ?? "",
      outcome: r.sub?.outcome ? statusLabel(r.sub.outcome) : "",
      conditions: r.sub?.conditionsText ?? "",
      approvals: subInstances,
    });
  }
  return { workbook: wb, edition };
}
