// No "server-only" marker: the seed script sets up the stand workflow too.
import { and, eq } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import { signageItems, workflows } from "@/lib/db/schema";
import type { SignoffPlan, StepDef } from "@/lib/workflow/types";
import { isDepartmentStep } from "@/lib/workflow/signoffs";
import { syncDepartmentSteps } from "./departments";

export const STAND_DESIGN_WORKFLOW_NAME = "Stand design sign-off";

/**
 * The organisation's stand-design sign-off: one step per department and
 * nothing else, so an approved design simply stays approved. Created the
 * first time a stand is added; department changes keep it in step like
 * every other signage workflow.
 */
export async function ensureStandDesignWorkflow(tx: Db | Tx, organisationId: string) {
  const [existing] = await tx
    .select({ id: workflows.id })
    .from(workflows)
    .where(
      and(
        eq(workflows.organisationId, organisationId),
        eq(workflows.forKind, "stand_design"),
        eq(workflows.isArchived, false),
      ),
    )
    .limit(1);
  if (existing) return existing.id;
  const [row] = await tx
    .insert(workflows)
    .values({
      organisationId,
      name: STAND_DESIGN_WORKFLOW_NAME,
      appliesTo: "signage",
      forKind: "stand_design",
      isDefault: false,
    })
    .returning({ id: workflows.id });
  await syncDepartmentSteps(tx, organisationId);
  return row.id;
}

/**
 * A stand's sign-off plan carried over to one of its panels: the same
 * departments and people, matched by department because the panel's
 * workflow has its own steps. Null (the defaults) stays null.
 */
export function mapPlanToWorkflow(
  plan: SignoffPlan | null,
  fromSteps: Pick<StepDef, "id" | "departmentId">[],
  toSteps: Pick<StepDef, "id" | "departmentId" | "kind" | "defaultFor">[],
): SignoffPlan | null {
  if (!plan) return null;
  const deptOf = new Map(fromSteps.map((s) => [s.id, s.departmentId ?? null]));
  const targets = toSteps.filter((s) => isDepartmentStep(s) && s.departmentId);
  const mapped: SignoffPlan = [];
  for (const entry of plan) {
    const dept = deptOf.get(entry.stepId);
    const target = dept ? targets.find((s) => s.departmentId === dept) : undefined;
    if (target && !mapped.some((m) => m.stepId === target.id)) {
      mapped.push({ stepId: target.id, userId: entry.userId });
    }
  }
  return mapped.length > 0 ? mapped : null;
}

/**
 * For a stand panel, its stand's status (panel graphics wait for the design
 * to be approved); null for anything else.
 */
export async function panelParent(
  db: Db | Tx,
  item: { kind: string; parentItemId: string | null },
): Promise<{ parentStatus: string | null } | null> {
  if (item.kind !== "stand_panel") return null;
  if (!item.parentItemId) return { parentStatus: null };
  const [parent] = await db
    .select({ status: signageItems.status })
    .from(signageItems)
    .where(eq(signageItems.id, item.parentItemId))
    .limit(1);
  return { parentStatus: parent?.status ?? null };
}

// ---------------------------------------------------------------------------
// The Feature stands list and panels following their stand (pure; unit
// tested in tests/unit/stand-designs-next.test.ts).

const APPROVED_STATUSES = [
  "approved",
  "approved_with_conditions",
  "in_production",
  "delivered",
  "installed",
  "snagged",
  "closed",
];

/** The status chips above the Feature stands cards. */
export const STAND_CHIPS = [
  "needs_design",
  "not_sent",
  "in_signoff",
  "changes_requested",
  "approved",
  "on_hold",
] as const;

export type StandChip = (typeof STAND_CHIPS)[number];

export const STAND_CHIP_LABELS: Record<StandChip, string> = {
  needs_design: "Needs design",
  not_sent: "Not sent yet",
  in_signoff: "In sign-off",
  changes_requested: "Changes requested",
  approved: "Approved",
  on_hold: "On hold",
};

/** Which chip a stand counts under (rejected stands only under All). */
export function standChip(status: string, hasDesign: boolean): StandChip | null {
  if (status === "on_hold") return "on_hold";
  if (status === "draft" || status === "awaiting_artwork") {
    return status === "draft" && hasDesign ? "not_sent" : "needs_design";
  }
  if (status === "in_review") return "in_signoff";
  if (status === "changes_requested") return "changes_requested";
  if (APPROVED_STATUSES.includes(status)) return "approved";
  return null;
}

/**
 * The "Next:" line on a stand's card and the tab its card opens: the design
 * tab until the design is approved, then Panels.
 */
export function standNextLine(input: {
  status: string;
  hasDesign: boolean;
  /** Who the current sign-off waits on. */
  waitingOn: string[];
  panels: { total: number; approved: number };
}): { text: string; tone: "action" | "waiting" | "warning" | "done"; tab: "artwork" | "panels" } {
  const { status, panels } = input;
  if (APPROVED_STATUSES.includes(status)) {
    if (panels.total === 0) return { text: "Next: add the panels", tone: "action", tab: "panels" };
    return {
      text: `Panels: ${panels.approved} of ${panels.total} approved`,
      tone: panels.approved === panels.total ? "done" : "waiting",
      tab: "panels",
    };
  }
  switch (status) {
    case "on_hold":
      return { text: "On hold", tone: "warning", tab: "artwork" };
    case "draft":
      return input.hasDesign
        ? { text: "Next: send the design for sign-off", tone: "action", tab: "artwork" }
        : { text: "Next: upload the design", tone: "action", tab: "artwork" };
    case "awaiting_artwork":
      return { text: "Next: upload the design", tone: "action", tab: "artwork" };
    case "in_review": {
      const who = [...new Set(input.waitingOn.filter(Boolean))];
      return {
        text: who.length
          ? `Waiting on ${who.length > 1 ? `${who.slice(0, -1).join(", ")} and ${who[who.length - 1]}` : who[0]}`
          : "In sign-off",
        tone: "waiting",
        tab: "artwork",
      };
    }
    case "changes_requested":
      return { text: "Next: upload a new version (changes asked)", tone: "action", tab: "artwork" };
    case "rejected":
      return { text: "Design rejected", tone: "warning", tab: "artwork" };
    default:
      return { text: "In sign-off", tone: "waiting", tab: "artwork" };
  }
}

/** Panels whose graphic is up (or done) keep where they went. */
const PANEL_PLACED = ["installed", "snagged", "closed"];

type PanelPlace = {
  hallId: string | null;
  locationId: string | null;
  standNumber: string | null;
  category: string | null;
  sponsorId: string | null;
  /** Who runs it: a panel's owner is always its stand's owner. */
  ownerUserId?: string | null;
  ownerRole?: "ops" | "marketing";
};

type PanelPatch = Partial<
  Omit<PanelPlace, "ownerRole"> & {
    ownerRole: "ops" | "marketing";
    signoffs: SignoffPlan | null;
    isSponsorDeliverable: boolean;
  }
>;

/**
 * What a panel takes from its stand after the stand changes: its owner
 * (always — a panel's owner can only change on its stand), its place (hall,
 * location, stand no.) until it is installed, and — while it is still a
 * draft — whose stand it is and who signs it off (the stand's plan already
 * mapped onto the panel's workflow). Only real differences.
 */
export function panelSyncPatch(
  stand: PanelPlace,
  panel: PanelPlace & { status: string; signoffs: SignoffPlan | null },
  mappedSignoffs: SignoffPlan | null,
): PanelPatch {
  const patch: PanelPatch = {};
  if (
    stand.ownerUserId !== undefined &&
    (stand.ownerUserId ?? null) !== (panel.ownerUserId ?? null)
  ) {
    patch.ownerUserId = stand.ownerUserId ?? null;
  }
  if (stand.ownerRole && panel.ownerRole && stand.ownerRole !== panel.ownerRole) {
    patch.ownerRole = stand.ownerRole;
  }
  if (PANEL_PLACED.includes(panel.status)) return patch;
  for (const key of ["hallId", "locationId", "standNumber"] as const) {
    if ((stand[key] ?? null) !== (panel[key] ?? null)) patch[key] = stand[key] ?? null;
  }
  if (panel.status === "draft") {
    if ((stand.category ?? "organiser") !== (panel.category ?? "organiser")) {
      patch.category = stand.category;
    }
    if ((stand.sponsorId ?? null) !== (panel.sponsorId ?? null)) {
      patch.sponsorId = stand.sponsorId ?? null;
      patch.isSponsorDeliverable = Boolean(stand.sponsorId);
    }
    if (JSON.stringify(mappedSignoffs ?? null) !== JSON.stringify(panel.signoffs ?? null)) {
      patch.signoffs = mappedSignoffs ?? null;
    }
  }
  return patch;
}
