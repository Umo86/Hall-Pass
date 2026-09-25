import "server-only";
import ExcelJS from "exceljs";
import { and, asc, eq, inArray, isNotNull, isNull } from "drizzle-orm";
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
import { safeSheetName } from "./sheet-name";

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

type ItemRef = { id: string; currentRunNumber: number };

/**
 * Current-run sign-off state per item, e.g. "Approved 12 Mar 2027, J Smith".
 * Only these items' instances are read, and superseded runs are ignored.
 */
async function currentApprovals(items: ItemRef[]) {
  const byItem = new Map<string, { step: string; text: string; order: number; role: string | null }[]>();
  const stepOrder = new Map<string, number>();
  if (items.length === 0) return { byItem, orderedSteps: [] as string[] };
  const runOf = new Map(items.map((i) => [i.id, i.currentRunNumber]));
  const instances = await db
    .select({ instance: approvalInstances, decider: users })
    .from(approvalInstances)
    .leftJoin(users, eq(approvalInstances.decidedBy, users.id))
    .where(
      and(
        eq(approvalInstances.entityType, "signage_item"),
        inArray(approvalInstances.entityId, [...runOf.keys()]),
      ),
    );
  for (const { instance, decider } of instances) {
    if (instance.runNumber !== runOf.get(instance.entityId)) continue;
    if (instance.status === "invalidated" || instance.status === "skipped") continue;
    const order = instance.sortOrderSnapshot;
    stepOrder.set(
      instance.stepNameSnapshot,
      Math.min(order, stepOrder.get(instance.stepNameSnapshot) ?? order),
    );
    const text =
      instance.decidedAt && decider
        ? `${statusLabel(instance.status)} ${formatDate(instance.decidedAt)}, ${decider.fullName || decider.email}`
        : statusLabel(instance.status);
    const list = byItem.get(instance.entityId) ?? [];
    list.push({ step: instance.stepNameSnapshot, text, order, role: instance.assignedRole });
    byItem.set(instance.entityId, list);
  }
  const orderedSteps = [...stepOrder.entries()]
    .sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]))
    .map(([name]) => name);
  return { byItem, orderedSteps };
}

function fillStatus(row: ExcelJS.Row, status: string) {
  const fill = STATUS_FILLS[status];
  if (fill) row.getCell("status").fill = { type: "pattern", pattern: "solid", fgColor: { argb: fill } };
}

/** Signage schedule: one sheet per hall plus a summary, approval columns. */
export async function buildScheduleWorkbook(editionId: string, includeCosts: boolean) {
  const [edition] = await db.select().from(editions).where(eq(editions.id, editionId));
  const rows = await db
    .select({
      item: signageItems,
      typeName: itemTypes.name,
      format: itemTypes.format,
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
    // The same items as the on-screen schedule, sponsorship items included.
    .where(and(eq(signageItems.editionId, editionId), isNull(signageItems.deletedAt)))
    .orderBy(asc(signageItems.seq));

  const { byItem, orderedSteps } = await currentApprovals(rows.map((r) => r.item));

  const wb = new ExcelJS.Workbook();
  wb.creator = "Hall Pass";

  const baseColumns = [
    { header: "Ref", key: "ref", width: 16 },
    { header: "Name", key: "name", width: 36 },
    { header: "Status", key: "status", width: 20 },
    { header: "Category", key: "category", width: 12 },
    { header: "Sponsor", key: "sponsor", width: 18 },
    { header: "Type", key: "type", width: 18 },
    { header: "Format", key: "format", width: 12 },
    { header: "Hall", key: "hall", width: 12 },
    { header: "Location", key: "location", width: 20 },
    { header: "W (mm)", key: "w", width: 9 },
    { header: "H (mm)", key: "h", width: 9 },
    { header: "Qty", key: "qty", width: 6 },
    { header: "Material", key: "material", width: 16 },
    { header: "Finish", key: "finish", width: 12 },
    { header: "Fixing", key: "fixing", width: 14 },
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
        category: r.item.category === "sponsor" ? "Sponsor" : "Organiser",
        format:
          r.item.kind === "sponsorship_item"
            ? "Merchandise"
            : r.format === "digital"
              ? "Digital"
              : r.format === "print"
                ? "Print"
                : "",
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
      fillStatus(row, r.item.status);
    }
  }

  const used = new Set<string>();
  addRows(wb.addWorksheet(safeSheetName("Summary", used)), rows);

  const hallNames = [...new Set(rows.map((r) => r.hallName).filter(Boolean))] as string[];
  for (const hallName of hallNames) {
    addRows(
      wb.addWorksheet(safeSheetName(hallName, used)),
      rows.filter((r) => r.hallName === hallName),
    );
  }

  return { workbook: wb, edition };
}

/**
 * Sponsor report: everything sold to sponsors (signage and sponsorship
 * items), a summary plus one sheet per sponsor — what they bought and where
 * its sign-off stands. Built for sales to send on.
 */
export async function buildSponsorWorkbook(editionId: string, includeCosts: boolean) {
  const [edition] = await db.select().from(editions).where(eq(editions.id, editionId));
  const rows = await db
    .select({
      item: signageItems,
      typeName: itemTypes.name,
      sponsorName: sponsors.companyName,
      supplierName: suppliers.name,
    })
    .from(signageItems)
    .innerJoin(sponsors, eq(signageItems.sponsorId, sponsors.id))
    .leftJoin(itemTypes, eq(signageItems.itemTypeId, itemTypes.id))
    .leftJoin(suppliers, eq(signageItems.supplierId, suppliers.id))
    .where(
      and(
        eq(signageItems.editionId, editionId),
        isNotNull(signageItems.sponsorId),
        isNull(signageItems.deletedAt),
      ),
    )
    .orderBy(asc(sponsors.companyName), asc(signageItems.seq));

  const { byItem } = await currentApprovals(rows.map((r) => r.item));

  const wb = new ExcelJS.Workbook();
  wb.creator = "Hall Pass";
  const columns = [
    { header: "Sponsor", key: "sponsor", width: 22 },
    { header: "Ref", key: "ref", width: 16 },
    { header: "Name", key: "name", width: 36 },
    { header: "Kind", key: "kind", width: 16 },
    { header: "Type", key: "type", width: 18 },
    { header: "Status", key: "status", width: 20 },
    { header: "Qty", key: "qty", width: 6 },
    { header: "Size (mm)", key: "size", width: 14 },
    { header: "Supplier", key: "supplier", width: 18 },
    { header: "Delivery", key: "delivery", width: 14 },
    ...(includeCosts
      ? [
          { header: "Estimate £", key: "estimate", width: 12 },
          { header: "Actual £", key: "actual", width: 12 },
        ]
      : []),
    { header: "Sign-off", key: "signoff", width: 60 },
  ];

  function fill(ws: ExcelJS.Worksheet, data: typeof rows) {
    ws.columns = columns as ExcelJS.Column[];
    styleHeader(ws.getRow(1));
    ws.views = [{ state: "frozen", ySplit: 1, xSplit: 2 }];
    for (const r of data) {
      const steps = (byItem.get(r.item.id) ?? []).sort((a, b) => a.order - b.order);
      const row = ws.addRow({
        sponsor: r.sponsorName,
        ref: r.item.ref,
        name: r.item.name,
        kind: r.item.kind === "sponsorship_item" ? "Sponsorship item" : "Signage",
        type: r.typeName ?? "",
        status: statusLabel(r.item.status),
        qty: r.item.quantity,
        size: r.item.widthMm && r.item.heightMm ? `${r.item.widthMm} × ${r.item.heightMm}` : "",
        supplier: r.supplierName ?? "",
        delivery: r.item.deliveryDate ? formatDate(r.item.deliveryDate) : "",
        ...(includeCosts
          ? {
              estimate: r.item.costEstimate ? Number(r.item.costEstimate) : "",
              actual: r.item.costActual ? Number(r.item.costActual) : "",
            }
          : {}),
        signoff: steps.map((s) => `${s.step}: ${s.text}`).join("; "),
      });
      fillStatus(row, r.item.status);
    }
  }

  const used = new Set<string>();
  fill(wb.addWorksheet(safeSheetName("All sponsors", used)), rows);
  for (const name of [...new Set(rows.map((r) => r.sponsorName))]) {
    fill(
      wb.addWorksheet(safeSheetName(name, used)),
      rows.filter((r) => r.sponsorName === name),
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
      fillStatus(row, r.item.status);
    }
  }

  // Only signage is installed; sponsorship items (bags, lanyards) are
  // delivered, so they appear on the Deliveries sheet only.
  const installs = rows.filter((r) => r.item.kind === "signage");
  const used = new Set<string>(["deliveries"]);
  fillSheet(wb.addWorksheet(safeSheetName("All installs", used)), installs);
  const names = [...new Set(installs.map((r) => r.contractorName ?? "Unassigned"))];
  for (const name of names) {
    fillSheet(
      wb.addWorksheet(safeSheetName(name, used)),
      installs.filter((r) => (r.contractorName ?? "Unassigned") === name),
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

  const { byItem } = await currentApprovals(rows.map((r) => r.item));
  const venueState = new Map<string, string>();
  for (const [itemId, steps] of byItem) {
    const venue = steps.find((s) => s.role === "venue");
    if (venue) venueState.set(itemId, venue.text);
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
