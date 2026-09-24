/**
 * Domain glue between signage items, the status machine and the workflow
 * engine. Used by server actions; kept out of components entirely.
 */
import { and, asc, eq, isNull } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import {
  editions,
  externalGrants,
  itemTypes,
  memberships,
  organisations,
  signageItems,
  venues,
  workflows,
} from "@/lib/db/schema";
import { notify } from "@/lib/notify";
import type { SignageItemCtx } from "@/lib/authz";
import { createRun, type EngineSettings, type EntityCtx, type Instance } from "@/lib/workflow";
import { loadStepDefs, persistRun } from "@/lib/workflow/persist";

export type ItemRow = typeof signageItems.$inferSelect;
export type EditionRow = typeof editions.$inferSelect;

export type ItemBundle = {
  item: ItemRow;
  edition: EditionRow;
  venue: typeof venues.$inferSelect;
  organisation: typeof organisations.$inferSelect;
};

export async function loadItemBundle(db: Db | Tx, itemId: string): Promise<ItemBundle | null> {
  const [row] = await db
    .select()
    .from(signageItems)
    .innerJoin(editions, eq(signageItems.editionId, editions.id))
    .innerJoin(venues, eq(editions.venueId, venues.id))
    .where(eq(signageItems.id, itemId))
    .limit(1);
  if (!row) return null;
  const [org] = await db
    .select()
    .from(organisations)
    .where(eq(organisations.id, row.venues.organisationId))
    .limit(1);
  return {
    item: row.signage_items,
    edition: row.editions,
    venue: row.venues,
    organisation: org,
  };
}

export function itemAuthzCtx(bundle: ItemBundle): SignageItemCtx {
  return {
    editionId: bundle.edition.id,
    venueId: bundle.venue.id,
    kind: bundle.item.kind,
    ownerUserId: bundle.item.ownerUserId,
    sponsorId: bundle.item.sponsorId,
    supplierId: bundle.item.supplierId,
    requiresVenueApproval: bundle.item.requiresVenueApproval,
    status: bundle.item.status,
  };
}

export function itemEntityCtx(bundle: ItemBundle): EntityCtx {
  return {
    kind: "signage",
    sponsorId: bundle.item.sponsorId,
    requiresVenueApproval: bundle.item.requiresVenueApproval,
    requiresEventDirector: bundle.item.requiresEventDirector,
    costEstimate: bundle.item.costEstimate ? Number(bundle.item.costEstimate) : null,
    fixingMethod: bundle.item.fixingMethod,
    supplierId: bundle.item.supplierId,
  };
}

export function engineSettingsFor(bundle: ItemBundle): EngineSettings {
  return {
    costThresholdForDirector: bundle.organisation.settings.cost_threshold_for_director ?? 5000,
  };
}

/** Start a fresh run for the item and persist it. Returns the instances. */
export async function startItemRun(tx: Tx, bundle: ItemBundle, now: Date): Promise<Instance[]> {
  const workflowId = bundle.item.workflowId;
  if (!workflowId) throw new Error("Item has no workflow assigned");
  const steps = await loadStepDefs(tx, workflowId);
  const runNumber = bundle.item.currentRunNumber + 1;
  const run = createRun({
    steps,
    entity: itemEntityCtx(bundle),
    settings: engineSettingsFor(bundle),
    runNumber,
    now,
  });
  const persisted = await persistRun(tx, "signage_item", bundle.item.id, run);
  await tx
    .update(signageItems)
    .set({ currentRunNumber: runNumber })
    .where(eq(signageItems.id, bundle.item.id));
  return persisted;
}

/**
 * Who hears about a newly created item: members of the owning role, plus
 * sales for anything sponsorship (their team sells it) — never the creator.
 * Pure so the rules are unit-testable.
 */
export function itemCreationRecipients(
  members: Array<{ userId: string; role: string }>,
  item: {
    kind: "signage" | "sponsorship_item";
    category: string | null;
    ownerRole: "ops" | "marketing";
  },
  creatorUserId: string,
): string[] {
  const roles = new Set<string>([item.ownerRole]);
  if (item.kind === "sponsorship_item" || item.category === "sponsorship") roles.add("sales");
  return [
    ...new Set(members.filter((m) => roles.has(m.role)).map((m) => m.userId)),
  ].filter((id) => id !== creatorUserId);
}

export async function resolveItemCreationRecipients(
  db: Db | Tx,
  organisationId: string,
  item: {
    kind: "signage" | "sponsorship_item";
    category: string | null;
    ownerRole: "ops" | "marketing";
  },
  creatorUserId: string,
): Promise<string[]> {
  const members = await db
    .select({ userId: memberships.userId, role: memberships.role })
    .from(memberships)
    .where(eq(memberships.organisationId, organisationId));
  return itemCreationRecipients(members, item, creatorUserId);
}

/** User ids that can decide an instance — used for notifications. */
export async function resolveAssigneeUserIds(
  db: Db | Tx,
  organisationId: string,
  editionId: string,
  venueId: string,
  item: { supplierId: string | null; sponsorId: string | null } | null,
  instance: { assignedRole: string | null; assignedUserId: string | null },
): Promise<string[]> {
  if (instance.assignedUserId) return [instance.assignedUserId];
  const role = instance.assignedRole;
  if (!role) return [];
  const staffRoles = ["admin", "ops", "marketing", "sales", "event_director", "viewer"];
  if (staffRoles.includes(role)) {
    const rows = await db
      .select({ userId: memberships.userId })
      .from(memberships)
      .where(
        and(
          eq(memberships.organisationId, organisationId),
          eq(memberships.role, role as (typeof memberships.$inferSelect)["role"]),
        ),
      );
    return rows.map((r) => r.userId);
  }
  const grants = await db
    .select()
    .from(externalGrants)
    .where(
      and(
        eq(externalGrants.organisationId, organisationId),
        eq(externalGrants.editionId, editionId),
        eq(externalGrants.role, role as (typeof externalGrants.$inferSelect)["role"]),
        isNull(externalGrants.revokedAt),
      ),
    );
  return grants
    .filter((g) => {
      if (g.expiresAt && g.expiresAt.getTime() < Date.now()) return false;
      switch (role) {
        case "venue":
          return g.scopeType === "venue" && g.scopeId === venueId;
        case "supplier":
          return g.scopeType === "supplier" && g.scopeId != null && g.scopeId === item?.supplierId;
        case "sponsor":
          return g.scopeType === "sponsor" && g.scopeId != null && g.scopeId === item?.sponsorId;
        default:
          return true; // engineer / hs are edition-scoped
      }
    })
    .map((g) => g.userId)
    .filter((id): id is string => Boolean(id));
}

/**
 * Fields an item needs before it can go for sign-off. Sponsorship items
 * (bags, lanyards) have no hall, location or fixing, so only signage needs
 * those.
 */
export function missingSubmitFields(item: {
  kind: "signage" | "sponsorship_item";
  hallId: string | null;
  locationId: string | null;
  itemTypeId: string | null;
  widthMm: number | null;
  heightMm: number | null;
  quantity: number | null;
  fixingMethod: string | null;
}): string[] {
  const missing: string[] = [];
  if (item.kind === "signage") {
    if (!item.hallId) missing.push("hall");
    if (!item.locationId) missing.push("location");
  }
  if (!item.itemTypeId) missing.push("item type");
  if (item.kind === "signage") {
    if (!item.widthMm) missing.push("width");
    if (!item.heightMm) missing.push("height");
  }
  if (!item.quantity) missing.push("quantity");
  if (item.kind === "signage" && !item.fixingMethod) missing.push("fixing method");
  return missing;
}

/**
 * The workflow a new or imported item should use: its item type's default,
 * else the organisation's default (then first) live signage workflow.
 */
export async function defaultSignageWorkflowId(
  db: Db | Tx,
  organisationId: string,
  itemTypeId: string | null,
): Promise<string | null> {
  if (itemTypeId) {
    const [type] = await db
      .select({ wf: itemTypes.defaultWorkflowId })
      .from(itemTypes)
      .where(eq(itemTypes.id, itemTypeId))
      .limit(1);
    if (type?.wf) return type.wf;
  }
  const rows = await db
    .select({ id: workflows.id, isDefault: workflows.isDefault })
    .from(workflows)
    .where(
      and(
        eq(workflows.organisationId, organisationId),
        eq(workflows.appliesTo, "signage"),
        eq(workflows.isArchived, false),
      ),
    )
    .orderBy(asc(workflows.createdAt));
  return (rows.find((r) => r.isDefault) ?? rows[0])?.id ?? null;
}

/**
 * Tell whoever holds each given pending step that it is now their turn.
 * Callers pass only newly pending instances so nobody is told twice.
 */
export async function notifyPendingAssignees(
  tx: Tx,
  bundle: ItemBundle,
  instances: Array<{
    status: string;
    stepName: string;
    assignedRole: string | null;
    assignedUserId: string | null;
  }>,
): Promise<void> {
  const item = bundle.item;
  for (const inst of instances.filter((x) => x.status === "pending")) {
    const assignees = await resolveAssigneeUserIds(
      tx,
      bundle.organisation.id,
      bundle.edition.id,
      bundle.venue.id,
      item,
      inst,
    );
    await notify(tx, {
      userIds: assignees,
      kind: "approval_requested",
      title: `${inst.stepName}: ${item.ref} — ${item.name}`,
      body: "It's your turn to sign off.",
      link: `/${bundle.edition.code}/signage/${item.ref}?tab=approvals`,
      entityType: "signage_item",
      entityId: item.id,
    });
  }
}

/** Instances that are pending now but were not pending before. */
export function newlyPending<T extends { id: string; stepId?: string; status: string }>(
  before: T[],
  after: T[],
): T[] {
  const wasPending = new Set(before.filter((i) => i.status === "pending").map((i) => i.id));
  return after.filter((i) => i.status === "pending" && !wasPending.has(i.id));
}

/**
 * Spec fields that an approval certifies. Changing any of them after
 * sign-off sends the item back for sign-off; dates, supplier, PO and costs
 * stay freely editable.
 */
export const SPEC_KEYS = [
  "name",
  "itemTypeId",
  "widthMm",
  "heightMm",
  "depthMm",
  "quantity",
  "sided",
  "material",
  "finish",
  "fixingMethod",
  "requiresVenueApproval",
  "requiresEventDirector",
  "sponsorId",
] as const;

function normalise(v: unknown): string {
  if (v === null || v === undefined || v === "") return "";
  return String(v);
}

/** Spec keys whose submitted value differs from the stored one. */
export function changedSpecKeys(
  current: Record<string, unknown>,
  patch: Record<string, unknown>,
): string[] {
  return SPEC_KEYS.filter(
    (k) => patch[k] !== undefined && normalise(patch[k]) !== normalise(current[k]),
  );
}

/**
 * Who hears about a new comment: the item's owner (or creator, for imported
 * items with no owner) and everyone who commented before — never the author,
 * and never external users on a staff-only comment. Pure for unit testing.
 */
export function commentRecipients(input: {
  authorId: string;
  ownerId: string | null;
  createdBy: string | null;
  priorAuthors: Array<{ id: string; isExternal: boolean }>;
  isInternal: boolean;
}): string[] {
  const ids = new Set<string>();
  const owner = input.ownerId ?? input.createdBy;
  if (owner) ids.add(owner);
  for (const a of input.priorAuthors) {
    if (input.isInternal && a.isExternal) continue;
    ids.add(a.id);
  }
  ids.delete(input.authorId);
  return [...ids];
}
