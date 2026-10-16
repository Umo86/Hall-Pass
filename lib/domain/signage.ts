/**
 * Domain glue between signage items, the status machine and the workflow
 * engine. Used by server actions; kept out of components entirely.
 */
import { and, asc, eq, inArray, isNull, sql } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import {
  approvalInstances,
  contractors,
  editions,
  events,
  externalGrants,
  halls,
  itemTypes,
  locations,
  memberships,
  organisations,
  signageItems,
  sponsorEntitlements,
  sponsors,
  suppliers,
  users,
  venues,
  workflows,
} from "@/lib/db/schema";
import { notify } from "@/lib/notify";
import { brandName } from "@/lib/config";
import { departmentSignerIds } from "@/lib/domain/departments";
import {
  departmentRouting,
  eligibleIds,
  loadTeam,
  orNames,
  partnerInviters,
  rerouteDepartmentSteps,
} from "@/lib/people";
import {
  confirmsForSuppliers,
  signoffPaused,
  STAFF_ROLES,
  type PermissionOverrides,
  type SignageItemCtx,
  type StaffActor,
  type StaffRole,
} from "@/lib/authz";
import {
  activeMembership,
  activeSignersWithRole,
  productionConfirmerIds,
} from "@/lib/users/active";
import type { SignageStatus } from "@/lib/status/signage";
import { formatDate, statusLabel } from "@/lib/format";
import {
  createRun,
  defaultSignoffs,
  isDepartmentStep,
  sameSignoffs,
  type EngineSettings,
  type EntityCtx,
  type Instance,
  type SignageCategory,
  type SignoffPlan,
} from "@/lib/workflow";
import { loadRun, loadStepDefs, persistRun } from "@/lib/workflow/persist";
import { resubmitAfterChanges } from "@/lib/workflow/engine";
import { itemPath } from "@/lib/edition-path";
import { writeAudit } from "@/lib/audit";
import { signageTransition } from "@/lib/status/signage";
import { PANEL_BLOCKED_MESSAGE, artworkBlockedReason } from "@/lib/artwork-rules";
import { panelParent } from "@/lib/domain/stand-designs";

export type ItemRow = typeof signageItems.$inferSelect;
export type EditionRow = typeof editions.$inferSelect;

/** The confirmation step each planned date drives. */
const DATE_STEPS = [
  ["printDeadline", "Sent to print"],
  ["deliveryDate", "Delivered"],
  ["installDate", "Installed"],
] as const;

/**
 * Keep the pending confirmation steps' due dates in line with the item's
 * planned dates after an edit (the engine snapshots them at activation).
 */
export async function syncConfirmationDueDates(
  tx: Tx,
  item: { id: string; currentRunNumber: number },
  changes: {
    printDeadline?: string | null;
    deliveryDate?: string | null;
    installDate?: string | null;
  },
): Promise<void> {
  if (item.currentRunNumber <= 0) return;
  for (const [key, step] of DATE_STEPS) {
    const date = changes[key];
    if (date === undefined) continue;
    await tx
      .update(approvalInstances)
      .set({ dueAt: date ? new Date(`${date}T17:00:00Z`) : null })
      .where(
        and(
          eq(approvalInstances.entityType, "signage_item"),
          eq(approvalInstances.entityId, item.id),
          eq(approvalInstances.runNumber, item.currentRunNumber),
          eq(approvalInstances.stepNameSnapshot, step),
          inArray(approvalInstances.status, ["pending", "waiting"]),
        ),
      );
  }
}

export type ItemBundle = {
  item: ItemRow;
  edition: EditionRow;
  venue: typeof venues.$inferSelect;
  organisation: typeof organisations.$inferSelect;
};

/**
 * An item with its show, venue and organisation. Pass the caller's
 * organisation to get null for anyone else's item.
 */
export async function loadItemBundle(
  db: Db | Tx,
  itemId: string,
  scope?: { organisationId: string },
): Promise<ItemBundle | null> {
  const [row] = await db
    .select()
    .from(signageItems)
    .innerJoin(editions, eq(signageItems.editionId, editions.id))
    .innerJoin(venues, eq(editions.venueId, venues.id))
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(eq(signageItems.id, itemId))
    .limit(1);
  if (!row) return null;
  if (scope && row.events.organisationId !== scope.organisationId) return null;
  const [org] = await db
    .select()
    .from(organisations)
    // The show's organisation (through its event) owns the record.
    .where(eq(organisations.id, row.events.organisationId))
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
    organisationId: bundle.organisation.id,
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
    category: bundle.item.category,
    signoffs: bundle.item.signoffs ?? null,
    stepDueDates: {
      "Sent to print": bundle.item.printDeadline,
      Delivered: bundle.item.deliveryDate,
      Installed: bundle.item.installDate,
    },
  };
}

export function engineSettingsFor(bundle: ItemBundle): EngineSettings {
  return {
    costThresholdForDirector: bundle.organisation.settings.cost_threshold_for_director ?? 5000,
  };
}

/**
 * Safety net for a new or restarted round: a department step named for
 * someone who can no longer sign for that department goes to the
 * department's main approver (or anyone in it), and an item following its
 * defaults goes to the department's current main approver
 * (rerouteDepartmentSteps). Changes the instances in place.
 */
async function routeToSigners(tx: Tx, bundle: ItemBundle, instances: Instance[]): Promise<void> {
  if (!instances.some((i) => i.assignedDepartmentId && i.stepKind === "approval")) return;
  const routing = await departmentRouting(tx, bundle.organisation.id);
  const moves = rerouteDepartmentSteps(
    instances.map((i) => ({
      id: i.id,
      status: i.status,
      stepKind: i.stepKind,
      assignedUserId: i.assignedUserId,
      assignedDepartmentId: i.assignedDepartmentId ?? null,
      delegatedFromUserId: i.delegatedFromUserId,
    })),
    { followsDefaults: !bundle.item.signoffs, ...routing },
  );
  for (const mv of moves) {
    const inst = instances.find((i) => i.id === mv.id);
    if (inst) inst.assignedUserId = mv.to;
  }
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
  await routeToSigners(tx, bundle, run);
  const persisted = await persistRun(tx, "signage_item", bundle.item.id, run);
  await tx
    .update(signageItems)
    .set({ currentRunNumber: runNumber })
    .where(eq(signageItems.id, bundle.item.id));
  return persisted;
}

/** A team member as new-item notifications see them. */
export type CreationMember = {
  userId: string;
  role: string;
  departmentId: string | null;
  /** Sections they use; null = every section. */
  features: readonly string[] | null;
  /** Access active (not suspended, end date not reached). */
  active: boolean;
};

/** The section an item of this kind lives in. */
function sectionOfKind(kind: CreationItem["kind"]): string {
  if (kind === "sponsorship_item") return "sponsorship";
  if (kind === "stand_design" || kind === "stand_panel") return "stand_designs";
  return "signage";
}

type CreationItem = {
  kind: "signage" | "sponsorship_item" | "stand_design" | "stand_panel";
  category: string | null;
  ownerUserId: string | null;
  /** The old two-team owner, used only when the owner has no department. */
  ownerRole: "ops" | "marketing";
};

/**
 * Who hears about a newly created item ("New items in my area"): people
 * with access in the owner's department who use the item's section. When
 * the owner has no department, the owning team instead (plus Sales for
 * anything sponsorship), with the same section check. Never the creator,
 * nor the owner (who is told the item is theirs — item_assigned). Pure so
 * the rules are unit-testable.
 */
export function itemCreationRecipients(
  members: readonly CreationMember[],
  item: CreationItem,
  creatorUserId: string,
): string[] {
  const section = sectionOfKind(item.kind);
  const usesSection = (m: CreationMember) =>
    m.role === "admin" || m.features === null || m.features.includes(section);
  const owner = item.ownerUserId ? members.find((m) => m.userId === item.ownerUserId) : undefined;
  let chosen: CreationMember[];
  if (owner?.departmentId) {
    chosen = members.filter((m) => m.departmentId === owner.departmentId);
  } else {
    const roles = new Set<string>([item.ownerRole]);
    if (item.kind === "sponsorship_item" || item.category === "sponsor") roles.add("sales");
    chosen = members.filter((m) => roles.has(m.role));
  }
  return [...new Set(chosen.filter((m) => m.active && usesSection(m)).map((m) => m.userId))].filter(
    (id) => id !== creatorUserId && id !== item.ownerUserId,
  );
}

export async function resolveItemCreationRecipients(
  db: Db | Tx,
  organisationId: string,
  item: CreationItem,
  creatorUserId: string,
): Promise<string[]> {
  const rows = await db
    .select({
      userId: memberships.userId,
      role: memberships.role,
      departmentId: memberships.departmentId,
      features: memberships.features,
      active: sql<boolean>`${activeMembership()}`,
    })
    .from(memberships)
    .where(eq(memberships.organisationId, organisationId));
  return itemCreationRecipients(
    rows.map((r) => ({ ...r, active: Boolean(r.active) })),
    item,
    creatorUserId,
  );
}

/** An item whose owner just changed, for telling the people concerned. */
export type OwnerChange = {
  id: string;
  ref: string;
  name: string;
  kind: string;
  editionCode: string;
  /** Who owned it before (null: nobody). */
  fromUserId: string | null;
};

/**
 * Tell the new owner the items are theirs (item_assigned, emailed; one
 * message for several) and each previous owner that theirs have moved —
 * never the person who made the change.
 */
export async function notifyOwnerChange(
  tx: Tx,
  opts: {
    actor: { id: string; name: string };
    to: { id: string; name: string };
    items: readonly OwnerChange[];
  },
): Promise<void> {
  const { actor, to, items } = opts;
  if (items.length === 0) return;
  if (to.id !== actor.id) {
    const one = items[0];
    await notify(tx, {
      userIds: [to.id],
      kind: "item_assigned",
      title:
        items.length === 1
          ? `${actor.name} gave you ${one.ref} — ${one.name}`
          : `${actor.name} gave you ${items.length} items`,
      body:
        items.length === 1
          ? "You own it now: reminders and decisions about it come to you."
          : `${items
              .slice(0, 5)
              .map((i) => i.ref)
              .join(", ")}${items.length > 5 ? "…" : ""}. You own them now.`,
      link:
        items.length === 1
          ? itemPath(one.editionCode, one)
          : `/${one.editionCode}/signage?show=mine`,
      ...(items.length === 1 ? { entityType: "signage_item" as const, entityId: one.id } : {}),
    });
  }
  const byPrevious = new Map<string, OwnerChange[]>();
  for (const i of items) {
    if (!i.fromUserId || i.fromUserId === actor.id || i.fromUserId === to.id) continue;
    byPrevious.set(i.fromUserId, [...(byPrevious.get(i.fromUserId) ?? []), i]);
  }
  for (const [userId, list] of byPrevious) {
    const one = list[0];
    await notify(tx, {
      userIds: [userId],
      kind: "item_assigned",
      title:
        list.length === 1
          ? `${one.ref} is now ${to.name}'s`
          : `${list.length} of your items are now ${to.name}'s`,
      body: `${actor.name} gave ${
        list.length === 1
          ? `${one.ref} — ${one.name}`
          : list
              .map((i) => i.ref)
              .slice(0, 5)
              .join(", ")
      } to ${to.name}.`,
      link: itemPath(one.editionCode, one),
      ...(list.length === 1 ? { entityType: "signage_item" as const, entityId: one.id } : {}),
    });
  }
}

/** User ids that can decide an instance — used for notifications. */
export async function resolveAssigneeUserIds(
  db: Db | Tx,
  organisationId: string,
  editionId: string,
  venueId: string,
  item: { supplierId: string | null; sponsorId: string | null } | null,
  instance: {
    assignedRole: string | null;
    assignedUserId: string | null;
    assignedDepartmentId?: string | null;
    stepKind?: string | null;
    stepKindSnapshot?: string | null;
  },
): Promise<string[]> {
  if (instance.assignedUserId) return [instance.assignedUserId];
  if (instance.assignedDepartmentId) {
    return departmentSignerIds(db, organisationId, instance.assignedDepartmentId);
  }
  const role = instance.assignedRole;
  if (!role) return [];
  const kind = instance.stepKindSnapshot ?? instance.stepKind;
  // Installed and the build check: whoever confirms production (signage.confirm).
  if (role === "ops" && kind === "confirmation") return productionConfirmerIds(db, organisationId);
  if ((STAFF_ROLES as readonly string[]).includes(role)) {
    // Active people with the role whose sign-off isn't paused.
    return activeSignersWithRole(db, organisationId, role as StaffRole);
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
  kind: "signage" | "sponsorship_item" | "stand_design" | "stand_panel";
  hallId: string | null;
  locationId: string | null;
  itemTypeId: string | null;
  widthMm: number | null;
  heightMm: number | null;
  quantity: number | null;
  fixingMethod: string | null;
}): string[] {
  const missing: string[] = [];
  // A stand design needs only its drawings; a panel needs its size.
  if (item.kind === "stand_design") return missing;
  if (item.kind === "stand_panel") {
    if (!item.widthMm) missing.push("width");
    if (!item.heightMm) missing.push("height");
    if (!item.quantity) missing.push("quantity");
    return missing;
  }
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
        // Stand-design sign-off is kept for stands.
        isNull(workflows.forKind),
      ),
    )
    .orderBy(asc(workflows.createdAt));
  return (rows.find((r) => r.isDefault) ?? rows[0])?.id ?? null;
}

/** The product's name as this organisation shows it (never hard-coded). */
function brandOf(bundle: ItemBundle): string {
  return bundle.organisation.brandName?.trim() || brandName;
}

/** Live invitations nobody has accepted yet for this company in this event. */
async function pendingInvites(
  tx: Tx,
  bundle: ItemBundle,
  scope: { role: "supplier" | "venue" | "sponsor"; scopeId: string },
): Promise<{ email: string; at: Date }[]> {
  const rows = await tx
    .select({
      email: externalGrants.invitedEmail,
      at: externalGrants.createdAt,
      expiresAt: externalGrants.expiresAt,
    })
    .from(externalGrants)
    .where(
      and(
        eq(externalGrants.organisationId, bundle.organisation.id),
        eq(externalGrants.editionId, bundle.edition.id),
        eq(externalGrants.role, scope.role),
        eq(externalGrants.scopeId, scope.scopeId),
        isNull(externalGrants.userId),
        isNull(externalGrants.revokedAt),
      ),
    );
  return rows.filter((r) => !r.expiresAt || r.expiresAt.getTime() > Date.now());
}

/**
 * A partner step started with nobody at the company able to sign in: tell
 * the people who can act. A supplier's confirmation goes to whoever
 * confirms production (they can confirm it themselves); a venue or sponsor
 * sign-off goes to Operations and the item's owner. People who can invite
 * partners get the invitation link; everyone else is told who can.
 */
async function noticeNobodyCanSignIn(
  tx: Tx,
  bundle: ItemBundle,
  inst: { stepName: string; stepKind?: string },
  scope: { role: "supplier" | "venue" | "sponsor"; scopeId: string },
): Promise<void> {
  const { item, edition, organisation } = bundle;
  const team = await loadTeam(tx, organisation.id);
  const companyName =
    scope.role === "supplier"
      ? (
          await tx
            .select({ name: suppliers.name })
            .from(suppliers)
            .where(eq(suppliers.id, scope.scopeId))
            .limit(1)
        )[0]?.name
      : scope.role === "venue"
        ? bundle.venue.name
        : (
            await tx
              .select({ name: sponsors.companyName })
              .from(sponsors)
              .where(eq(sponsors.id, scope.scopeId))
              .limit(1)
          )[0]?.name;
  const who = companyName ?? `the ${scope.role}`;
  const recipients =
    scope.role === "supplier"
      ? await productionConfirmerIds(tx, organisation.id)
      : [
          ...eligibleIds(team, { type: "task" }, { organisationId: organisation.id }).filter(
            (id) => team.find((m) => m.userId === id)?.role === "ops",
          ),
          ...(item.ownerUserId ? [item.ownerUserId] : []),
        ];
  if (recipients.length === 0) return;
  const inviters = await partnerInviters(tx, organisation.id, { team });
  const inviterIds = new Set(inviters.map((m) => m.userId));
  const askNames = orNames(inviters.map((m) => m.name));
  const invites = await pendingInvites(tx, bundle, scope);
  const brand = brandOf(bundle);
  const itemLink = itemPath(edition.code, item);
  const inviteLink = `/users?tab=external&invite=1&role=${scope.role}&scopeId=${scope.scopeId}&edition=${edition.id}`;
  const isConfirm = inst.stepKind === "confirmation";
  const title = isConfirm
    ? `To confirm — ${inst.stepName}: ${item.name} (${item.ref})`
    : `Nobody at ${who} can sign off ${item.ref} — ${item.name}`;
  const situation = invites.length
    ? `${invites[0].email} was invited on ${formatDate(invites[0].at)} but hasn't signed in to ${brand} yet, so ${who} can't ${isConfirm ? "confirm this" : `sign off ${inst.stepName}`}.`
    : `Nobody at ${who} can sign in to ${brand} yet, so they can't ${isConfirm ? "confirm this" : `sign off ${inst.stepName}`}.`;
  const doIt = isConfirm ? `Confirm it on ${item.ref} yourself once it's done` : "";
  const invite = invites.length ? "resend the invitation" : "invite them";
  const canInviteText = isConfirm ? `${doIt}, or ${invite}.` : `${capitalise(invite)}.`;
  const askText = isConfirm
    ? `${doIt} — or ask ${askNames} to ${invite}.`
    : `Ask ${askNames} to ${invite}.`;
  const unique = [...new Set(recipients)];
  const canInvite = unique.filter((id) => inviterIds.has(id));
  const others = unique.filter((id) => !inviterIds.has(id));
  const base = {
    kind: "approval_requested",
    title,
    entityType: "signage_item" as const,
    entityId: item.id,
  };
  if (canInvite.length) {
    await notify(tx, {
      ...base,
      userIds: canInvite,
      body: `${situation} ${canInviteText}`,
      link: inviteLink,
    });
  }
  if (others.length) {
    await notify(tx, {
      ...base,
      userIds: others,
      body: `${situation} ${askText}`,
      link: isConfirm ? itemLink : `${itemLink}?tab=artwork`,
    });
  }
}

function capitalise(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
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
    stepKind?: string;
    assignedRole: string | null;
    assignedUserId: string | null;
    assignedDepartmentId?: string | null;
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
    // A supplier's confirmation with nobody at the supplier to make it.
    if (
      assignees.length === 0 &&
      inst.stepKind === "confirmation" &&
      inst.assignedRole === "supplier" &&
      !inst.assignedUserId
    ) {
      // No supplier chosen at all: Operations were already told the item is
      // approved without one (decideApproval), so say nothing misleading here.
      if (!item.supplierId) continue;
      await noticeNobodyCanSignIn(tx, bundle, inst, { role: "supplier", scopeId: item.supplierId });
      continue;
    }
    // A venue or sponsor sign-off with nobody there who can sign in.
    if (
      assignees.length === 0 &&
      !inst.assignedUserId &&
      (inst.assignedRole === "venue" || inst.assignedRole === "sponsor")
    ) {
      const scopeId = inst.assignedRole === "venue" ? bundle.venue.id : item.sponsorId;
      if (scopeId) {
        await noticeNobodyCanSignIn(tx, bundle, inst, { role: inst.assignedRole, scopeId });
      }
      continue;
    }
    await notify(tx, {
      userIds: assignees,
      kind: "approval_requested",
      ...(inst.stepKind === "confirmation"
        ? {
            title: `To confirm — ${inst.stepName}: ${item.name} (${item.ref})`,
            body: `${bundle.edition.name}. Confirm it in ${brandOf(bundle)} once it's done.`,
          }
        : {
            title: `Please sign off: ${item.name} (${item.ref})`,
            body: [
              `${inst.stepName} for ${bundle.edition.name}.`,
              item.category === "sponsor" ? "Sponsor signage." : "Organiser signage.",
              "Open it to view the artwork, then approve, ask for changes or reject — you can leave a comment either way.",
            ].join(" "),
          }),
      link: `${itemPath(bundle.edition.code, item)}?tab=artwork`,
      entityType: "signage_item",
      entityId: item.id,
    });
  }
}

/**
 * Send a draft for sign-off inside the caller's transaction, with its audit
 * row: In sign-off when it has artwork, else Needs artwork (sign-off then
 * starts on the first upload). Throws a plain-language error when it can't
 * go yet. Shared by "Send for sign-off" and "upload and send".
 */
export async function submitItemInTx(
  tx: Tx,
  bundle: ItemBundle,
  opts: { actorUserId: string; now: Date },
): Promise<{ next: SignageStatus; pending: Instance[] }> {
  const i = bundle.item;
  if (i.status !== "draft") throw new Error("This item has already been sent for sign-off");
  if (artworkBlockedReason(i.status, await panelParent(tx, i)) === PANEL_BLOCKED_MESSAGE) {
    throw new Error(PANEL_BLOCKED_MESSAGE);
  }
  const missing = missingSubmitFields(i);
  if (missing.length > 0) {
    throw new Error(`Cannot send for sign-off yet — missing: ${missing.join(", ")}`);
  }
  // Items created by import (or before a workflow existed) get the default.
  const workflowId =
    i.workflowId ?? (await defaultSignageWorkflowId(tx, bundle.organisation.id, i.itemTypeId));
  if (!workflowId) throw new Error("No sign-off workflow is set up yet — ask an admin");
  const next = signageTransition(i.status, "submit_for_review", {
    hasArtwork: Boolean(i.currentArtworkVersionId),
  });
  await tx.update(signageItems).set({ status: next, workflowId }).where(eq(signageItems.id, i.id));
  let pending: Instance[] = [];
  if (next === "in_review") {
    const instances = await startItemRun(tx, { ...bundle, item: { ...i, workflowId } }, opts.now);
    await notifyPendingAssignees(tx, bundle, instances);
    pending = instances.filter((x) => x.status === "pending");
  }
  await writeAudit(tx, {
    organisationId: bundle.organisation.id,
    editionId: bundle.edition.id,
    actorUserId: opts.actorUserId,
    entityType: "signage_item",
    entityId: i.id,
    action: "submit",
    before: { status: i.status },
    after: { status: next },
    summary:
      next === "in_review"
        ? `${i.ref} sent for sign-off`
        : `${i.ref} ready for artwork — sign-off starts on upload`,
  });
  return { next, pending };
}

/**
 * Send an item back for sign-off after changes were asked for, inside the
 * caller's transaction, with its audit row. The run restarts from the step
 * that asked (or as a new round, as the workflow says).
 */
export async function resubmitItemInTx(
  tx: Tx,
  bundle: ItemBundle,
  opts: { actorUserId: string; now: Date },
): Promise<{ next: SignageStatus; pending: Instance[] }> {
  const item = bundle.item;
  if (item.status !== "changes_requested") {
    throw new Error("Only items with changes requested can be sent back for sign-off");
  }
  const next = signageTransition(item.status, "resubmit");
  const run = await loadRun(tx, "signage_item", item.id, item.currentRunNumber);
  const res = resubmitAfterChanges(run, { entity: itemEntityCtx(bundle), now: opts.now });
  let pending: Instance[];
  if (res.mode === "restart_from_step") {
    await routeToSigners(tx, bundle, res.instances);
    const persisted = await persistRun(tx, "signage_item", item.id, res.instances);
    pending = newlyPending(run, persisted);
  } else {
    // The whole run restarts as a new round; the old one stays in history.
    pending = (await startItemRun(tx, bundle, opts.now)).filter((x) => x.status === "pending");
  }
  await notifyPendingAssignees(tx, bundle, pending);
  await tx.update(signageItems).set({ status: next }).where(eq(signageItems.id, item.id));
  await writeAudit(tx, {
    organisationId: bundle.organisation.id,
    editionId: bundle.edition.id,
    actorUserId: opts.actorUserId,
    entityType: "signage_item",
    entityId: item.id,
    action: "submit",
    after: { status: next, mode: res.mode },
    summary: `${item.ref} resubmitted`,
  });
  return { next, pending };
}

/** "Operations sign-off and Marketing sign-off" — who was just asked. */
export function askedSummary(pending: Array<{ stepName: string }>): string {
  return joinWords([...new Set(pending.map((p) => p.stepName))]);
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
    (k) =>
      patch[k] !== undefined &&
      normalise(patch[k]) !== normalise(current[k]) &&
      // Selling an item for the first time isn't a change to what was approved.
      !(k === "sponsorId" && normalise(current[k]) === ""),
  );
}

/**
 * Who hears that a snag was fixed (or won't be): whoever raised it and the
 * item's owner — never the person who closed it. Pure.
 */
export function snagClosedRecipients(input: {
  raisedByUserId: string | null;
  ownerUserId: string | null;
  actorUserId: string;
}): string[] {
  return [...new Set([input.raisedByUserId, input.ownerUserId])].filter(
    (id): id is string => Boolean(id) && id !== input.actorUserId,
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

/**
 * Check an item's sign-off choices and store them in their simplest form:
 * each step must be a department step of the item's workflow, and each named
 * person must be in that department (or an admin) with sign-off rights.
 * Returns null when the choices are just the category defaults, so later
 * changes to the defaults still apply to the item.
 */
export async function normaliseSignoffs(
  db: Db | Tx,
  opts: {
    organisationId: string;
    workflowId: string | null;
    category: SignageCategory | null;
    plan: SignoffPlan | null | undefined;
  },
): Promise<SignoffPlan | null> {
  if (!opts.plan) return null;
  if (!opts.workflowId) return null;
  const steps = (await loadStepDefs(db, opts.workflowId)).filter(isDepartmentStep);
  const byId = new Map(steps.map((s) => [s.id, s]));
  const seen = new Set<string>();
  const plan: SignoffPlan = [];
  for (const entry of opts.plan) {
    const step = byId.get(entry.stepId);
    if (!step) throw new Error("That sign-off step no longer exists — reload the page");
    if (seen.has(step.id)) continue;
    seen.add(step.id);
    plan.push({ stepId: step.id, userId: entry.userId || null });
  }
  if (plan.length === 0) throw new Error("Choose at least one department to sign this off");
  const userIds = plan.map((p) => p.userId).filter((u): u is string => Boolean(u));
  if (userIds.length > 0) {
    const members = await db
      .select({
        userId: memberships.userId,
        role: memberships.role,
        overrides: memberships.permissionOverrides,
        active: sql<boolean>`${activeMembership()}`,
        fullName: users.fullName,
        email: users.email,
      })
      .from(memberships)
      .innerJoin(users, eq(users.id, memberships.userId))
      .where(
        and(
          eq(memberships.organisationId, opts.organisationId),
          inArray(memberships.userId, userIds),
        ),
      );
    const byUser = new Map(members.map((m) => [m.userId, m]));
    for (const entry of plan) {
      if (!entry.userId) continue;
      const m = byUser.get(entry.userId);
      const step = byId.get(entry.stepId)!;
      // Name the person and the sign-off, so it's clear what to change.
      const who = m ? m.fullName || m.email : "Someone you chose";
      if (!m) {
        throw new Error(`${step.name}: the person chosen has left the team — pick someone else`);
      }
      if (!m.active) {
        throw new Error(`${step.name}: ${who}'s access is paused or has ended — pick someone else`);
      }
      if (signoffPaused(m.overrides as PermissionOverrides)) {
        throw new Error(`${step.name}: ${who}'s sign-off is paused — pick someone else`);
      }
      if (step.departmentId) {
        const signers = await departmentSignerIds(db, opts.organisationId, step.departmentId);
        if (!signers.includes(entry.userId)) {
          throw new Error(
            `${step.name}: ${who} no longer signs off for that department — pick one of its approvers`,
          );
        }
      } else if (m.role !== "admin" && step.approverRole && m.role !== step.approverRole) {
        throw new Error(`${step.name}: pick someone from that department`);
      }
    }
  }
  return sameSignoffs(plan, defaultSignoffs(steps, opts.category)) ? null : plan;
}

/** Ids an item can link to, as they arrive from a form, import or bulk edit. */
export type ItemLinks = {
  itemTypeId?: string | null;
  hallId?: string | null;
  locationId?: string | null;
  sponsorId?: string | null;
  sponsorEntitlementId?: string | null;
  supplierId?: string | null;
  installContractorId?: string | null;
  workflowId?: string | null;
};

/** Archived suppliers stay on the items that have them but can't be picked anew. */
export function archivedSupplierMessage(name: string): string {
  return `${name} is archived — restore it in Suppliers, or choose another supplier`;
}

/**
 * Every id linked to an item must belong to the same organisation — and,
 * for halls, locations, sponsors and entitlements, to the item's own event.
 * Throws a plain-language error otherwise (nothing is linked across events
 * or organisations, whatever a request says). An archived supplier is
 * refused unless it is the item's current one (`currentSupplierId`).
 */
export async function assertItemLinks(
  db: Db | Tx,
  opts: {
    organisationId: string;
    editionId: string;
    links: ItemLinks;
    /** The item's supplier now (edits): kept even if archived since. */
    currentSupplierId?: string | null;
  },
): Promise<void> {
  const l = opts.links;
  const bad = (what: string) => {
    throw new Error(`That ${what} isn't part of this event — reload the page and try again`);
  };
  const one = async <T>(q: Promise<T[]>) => (await q).length > 0;
  if (l.itemTypeId) {
    const ok = await one(
      db
        .select({ id: itemTypes.id })
        .from(itemTypes)
        .where(
          and(eq(itemTypes.id, l.itemTypeId), eq(itemTypes.organisationId, opts.organisationId)),
        ),
    );
    if (!ok) bad("item type");
  }
  if (l.hallId) {
    const ok = await one(
      db
        .select({ id: halls.id })
        .from(halls)
        .where(and(eq(halls.id, l.hallId), eq(halls.editionId, opts.editionId))),
    );
    if (!ok) bad("hall");
  }
  if (l.locationId) {
    const ok = await one(
      db
        .select({ id: locations.id })
        .from(locations)
        .innerJoin(halls, eq(locations.hallId, halls.id))
        .where(and(eq(locations.id, l.locationId), eq(halls.editionId, opts.editionId))),
    );
    if (!ok) bad("location");
  }
  if (l.sponsorId) {
    const ok = await one(
      db
        .select({ id: sponsors.id })
        .from(sponsors)
        .where(and(eq(sponsors.id, l.sponsorId), eq(sponsors.editionId, opts.editionId))),
    );
    if (!ok) bad("sponsor");
  }
  if (l.sponsorEntitlementId) {
    const ok = await one(
      db
        .select({ id: sponsorEntitlements.id })
        .from(sponsorEntitlements)
        .innerJoin(sponsors, eq(sponsorEntitlements.sponsorId, sponsors.id))
        .where(
          and(
            eq(sponsorEntitlements.id, l.sponsorEntitlementId),
            eq(sponsors.editionId, opts.editionId),
          ),
        ),
    );
    if (!ok) bad("sponsor entitlement");
  }
  if (l.supplierId) {
    const [row] = await db
      .select({ name: suppliers.name, isArchived: suppliers.isArchived })
      .from(suppliers)
      .where(and(eq(suppliers.id, l.supplierId), eq(suppliers.organisationId, opts.organisationId)))
      .limit(1);
    if (!row) bad("supplier");
    else if (row.isArchived && l.supplierId !== opts.currentSupplierId) {
      throw new Error(archivedSupplierMessage(row.name));
    }
  }
  if (l.installContractorId) {
    const ok = await one(
      db
        .select({ id: contractors.id })
        .from(contractors)
        .where(
          and(
            eq(contractors.id, l.installContractorId),
            eq(contractors.organisationId, opts.organisationId),
          ),
        ),
    );
    if (!ok) bad("contractor");
  }
  if (l.workflowId) {
    const ok = await one(
      db
        .select({ id: workflows.id })
        .from(workflows)
        .where(
          and(eq(workflows.id, l.workflowId), eq(workflows.organisationId, opts.organisationId)),
        ),
    );
    if (!ok) bad("sign-off workflow");
  }
}

/** The show, if it belongs to the organisation. */
export async function ownEdition(db: Db | Tx, organisationId: string, editionId: string) {
  const [row] = await db
    .select({ edition: editions })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(editions.id, editionId), eq(events.organisationId, organisationId)))
    .limit(1);
  return row?.edition ?? null;
}

// ---------------------------------------------------------------------------
// The signage list and the item page's "next step" (pure; unit tested in
// tests/unit/signage-list.test.ts and signage-next-step.test.ts). Computed
// on the server and handed to the page as plain data.

/** Dashboard stages: each status (except Rejected) belongs to one. */
export const SIGNAGE_STAGES = {
  getting_ready: ["draft", "awaiting_artwork", "on_hold"],
  in_signoff: ["in_review", "changes_requested"],
  production: ["approved", "approved_with_conditions", "in_production", "delivered"],
  onsite: ["installed", "snagged", "closed"],
} as const satisfies Record<string, readonly SignageStatus[]>;

export type SignageStage = keyof typeof SIGNAGE_STAGES;

export const STAGE_LABELS: Record<SignageStage, string> = {
  getting_ready: "Getting ready",
  in_signoff: "In sign-off",
  production: "Production & delivery",
  onsite: "Onsite & done",
};

/** The statuses for `?stage=…`; null for no stage or one we don't know (no filter). */
export function stageStatuses(stage: string | null | undefined): SignageStatus[] | null {
  if (!stage || !(stage in SIGNAGE_STAGES)) return null;
  return [...SIGNAGE_STAGES[stage as SignageStage]];
}

export function stageOf(status: string): SignageStage | null {
  for (const [stage, list] of Object.entries(SIGNAGE_STAGES)) {
    if ((list as readonly string[]).includes(status)) return stage as SignageStage;
  }
  return null;
}

/** The status chips above the list, in the order they are shown. */
export const QUICK_FILTERS = [
  "needs_artwork",
  "not_sent",
  "in_signoff",
  "changes_requested",
  "ready_to_print",
  "sent_to_print",
  "delivered",
  "onsite",
  "overdue",
  "mine",
] as const;

export type QuickFilter = (typeof QUICK_FILTERS)[number];

export const QUICK_FILTER_LABELS: Record<QuickFilter, string> = {
  needs_artwork: "Needs artwork",
  not_sent: "Not sent yet",
  in_signoff: "In sign-off",
  changes_requested: "Changes requested",
  ready_to_print: "Ready to print",
  sent_to_print: "Sent to print",
  delivered: "Delivered",
  onsite: "Installed / snagged",
  overdue: "Overdue",
  mine: "Mine",
};

const STATUS_CHIP: Record<string, QuickFilter> = {
  in_review: "in_signoff",
  changes_requested: "changes_requested",
  approved: "ready_to_print",
  approved_with_conditions: "ready_to_print",
  in_production: "sent_to_print",
  delivered: "delivered",
  installed: "onsite",
  snagged: "onsite",
};

/** Which chips a row counts under: its status chip, then Overdue and Mine. */
export function quickFiltersFor(row: {
  status: string;
  hasArtwork: boolean;
  overdue: boolean;
  mine: boolean;
}): QuickFilter[] {
  const out: QuickFilter[] = [];
  if (row.status === "draft" || row.status === "awaiting_artwork") {
    out.push(row.status === "draft" && row.hasArtwork ? "not_sent" : "needs_artwork");
  } else if (STATUS_CHIP[row.status]) {
    out.push(STATUS_CHIP[row.status]);
  }
  if (row.overdue) out.push("overdue");
  if (row.mine) out.push("mine");
  return out;
}

/**
 * Overdue on the list: a waiting step is past its due date, or the artwork
 * is past due and still missing.
 */
export function rowIsOverdue(
  row: {
    status: string;
    hasArtwork: boolean;
    artworkDue: string | null;
    pendingSteps: { overdue: boolean }[];
  },
  today: string,
): boolean {
  if (row.pendingSteps.some((s) => s.overdue)) return true;
  return (
    (row.status === "draft" || row.status === "awaiting_artwork") &&
    !row.hasArtwork &&
    Boolean(row.artworkDue && row.artworkDue < today)
  );
}

type MineStep = {
  stepKind: "approval" | "confirmation";
  assignedRole: string | null;
  assignedUserId: string | null;
  assignedDepartmentId: string | null;
};

type MineActor = Pick<StaffActor, "userId" | "role" | "signoffDepartmentIds" | "overrides">;

/**
 * Is this waiting step mine to decide as its assignee — named for me, for a
 * department I sign off for, or for my role? Print, delivery and install
 * confirmations are mine when I confirm them for suppliers (signage.confirm:
 * Operations by default). An admin's power to decide anything doesn't count.
 */
export function stepIsMine(s: MineStep, actor: MineActor): boolean {
  if (s.assignedUserId) return s.assignedUserId === actor.userId;
  if (s.assignedDepartmentId) {
    return actor.signoffDepartmentIds?.includes(s.assignedDepartmentId) ?? false;
  }
  if (
    s.stepKind === "confirmation" &&
    (s.assignedRole === "supplier" || s.assignedRole === "ops")
  ) {
    return actor.role !== "admin" && confirmsForSuppliers(actor);
  }
  return Boolean(s.assignedRole) && s.assignedRole === actor.role;
}

/** "Mine" on the list: I own it, or one of its waiting steps is mine (stepIsMine). */
export function isMineRow(
  row: { ownerUserId: string | null; pendingSteps: MineStep[] },
  actor: MineActor,
): boolean {
  if (row.ownerUserId === actor.userId) return true;
  return row.pendingSteps.some((s) => stepIsMine(s, actor));
}

/** The statuses at which each production confirmation is the thing waiting. */
const CONFIRMATION_DUE_AT: Record<string, string[]> = {
  "Sent to print": ["approved", "approved_with_conditions"],
  Delivered: ["in_production"],
  Installed: ["delivered"],
};

/**
 * Is a waiting step really still waiting? A production confirmation left
 * pending on an item that has already moved past it (older or imported
 * data) is not shown as what the item waits on.
 */
export function stepStillDue(
  step: { stepKind: "approval" | "confirmation"; stepName: string },
  status: string,
): boolean {
  if (step.stepKind !== "confirmation" || status === "on_hold") return true;
  const due = CONFIRMATION_DUE_AT[step.stepName];
  return !due || due.includes(status);
}

/** The bulk confirmations on the list. */
export type BulkConfirmStep = "Sent to print" | "Delivered";

const SIGNED_OFF: string[] = ["approved", "approved_with_conditions"];
const BEFORE_SIGNOFF: string[] = [
  "draft",
  "awaiting_artwork",
  "in_review",
  "changes_requested",
  "rejected",
];

/**
 * Why an item can't take a bulk "Sent to print" or "Delivered" confirmation,
 * in a few words for the result list; null when it can.
 */
export function bulkConfirmSkipReason(
  step: BulkConfirmStep,
  item: {
    status: string;
    supplierId: string | null;
    /** The steps waiting in the item's current round. */
    pendingStepNames: string[];
    canDecide: boolean;
  },
): string | null {
  if (item.status === "on_hold") return "on hold";
  if (BEFORE_SIGNOFF.includes(item.status)) return "not signed off yet";
  if (step === "Sent to print") {
    if (!SIGNED_OFF.includes(item.status)) return "already sent to print";
  } else {
    if (SIGNED_OFF.includes(item.status)) return "not sent to print yet";
    if (item.status !== "in_production") return "already delivered";
  }
  if (!item.pendingStepNames.includes(step)) return "nothing waiting to confirm";
  if (step === "Sent to print" && !item.supplierId) return "no supplier set";
  if (!item.canDecide) return "not yours to confirm";
  return null;
}

/** Once installed, what was approved can no longer change (reopen first). */
export const SPEC_LOCKED_STATUSES: SignageStatus[] = ["installed", "snagged", "closed"];

export function specLocked(status: string): boolean {
  return (SPEC_LOCKED_STATUSES as string[]).includes(status);
}

type ReadinessItem = {
  kind: "signage" | "sponsorship_item" | "stand_design" | "stand_panel";
  hallId: string | null;
  locationId: string | null;
  itemTypeId: string | null;
  widthMm: number | null;
  heightMm: number | null;
  quantity: number | null;
  fixingMethod: string | null;
  supplierId: string | null;
  currentArtworkVersionId: string | null;
};

/** The form fields sign-off needs, so the form can tag them up front. */
export function signoffRequiredFields(kind: ReadinessItem["kind"]): string[] {
  switch (kind) {
    case "signage":
      return ["hallId", "locationId", "itemTypeId", "widthMm", "heightMm", "fixingMethod"];
    case "sponsorship_item":
      return ["itemTypeId"];
    case "stand_panel":
      return ["widthMm", "heightMm"];
    default:
      return [];
  }
}

export type ReadinessLine = {
  key: "where" | "type" | "size" | "quantity" | "fixing" | "artwork" | "supplier";
  label: string;
  done: boolean;
  /** Blocking lines must be done before it can go for sign-off. */
  blocking: boolean;
  /** The form field to jump to, when the line is a field. */
  field?: string;
};

export type Readiness = {
  lines: ReadinessLine[];
  /** Everything sign-off needs is filled in (the server's check agrees). */
  fieldsReady: boolean;
  hasArtwork: boolean;
};

/**
 * What an item needs before (and soon after) it goes for sign-off, as a
 * checklist. The blocking lines are exactly missingSubmitFields.
 */
export function signoffReadiness(item: ReadinessItem): Readiness {
  const hasArtwork = Boolean(item.currentArtworkVersionId);
  const lines: ReadinessLine[] = [];
  const noun =
    item.kind === "stand_design" ? "Design" : item.kind === "stand_panel" ? "Graphic" : "Artwork";
  if (item.kind === "signage") {
    lines.push({
      key: "where",
      label: "Hall and location",
      done: Boolean(item.hallId && item.locationId),
      blocking: true,
      field: item.hallId ? "locationId" : "hallId",
    });
  }
  if (item.kind === "signage" || item.kind === "sponsorship_item") {
    lines.push({
      key: "type",
      label: "Item type",
      done: Boolean(item.itemTypeId),
      blocking: true,
      field: "itemTypeId",
    });
  }
  if (item.kind === "signage" || item.kind === "stand_panel") {
    lines.push({
      key: "size",
      label: "Size",
      done: Boolean(item.widthMm && item.heightMm && item.quantity),
      blocking: true,
      field: !item.widthMm ? "widthMm" : !item.heightMm ? "heightMm" : "quantity",
    });
  }
  if (item.kind === "signage") {
    lines.push({
      key: "fixing",
      label: "Fixing method",
      done: Boolean(item.fixingMethod),
      blocking: true,
      field: "fixingMethod",
    });
  }
  lines.push({ key: "artwork", label: noun, done: hasArtwork, blocking: false });
  if (item.kind !== "stand_design") {
    lines.push({
      key: "supplier",
      label: "Supplier (needed before print)",
      done: Boolean(item.supplierId),
      blocking: false,
      field: "supplierId",
    });
  }
  // A missing quantity on a sponsorship item has no line of its own.
  const fieldsReady = missingSubmitFields(item).length === 0;
  if (!fieldsReady && lines.every((l) => !l.blocking || l.done)) {
    lines.unshift({
      key: "quantity",
      label: "Quantity",
      done: false,
      blocking: true,
      field: "quantity",
    });
  }
  return { lines, fieldsReady, hasArtwork };
}

/** "Add size and fixing method first", or null when nothing blocks sign-off. */
export function submitBlockedReason(readiness: Readiness): string | null {
  const missing = readiness.lines.filter((l) => l.blocking && !l.done);
  if (missing.length === 0) return null;
  return `Add ${joinWords(missing.map((l) => l.label.toLowerCase()))} first`;
}

/** Was artwork uploaded since the request for changes (made against `requestVersionId`)? */
export function newArtworkSinceChanges(
  requestVersionId: string | null,
  currentVersionId: string | null,
): boolean {
  return currentVersionId != null && currentVersionId !== requestVersionId;
}

function joinWords(words: string[]): string {
  if (words.length <= 1) return words[0] ?? "";
  return `${words.slice(0, -1).join(", ")} and ${words[words.length - 1]}`;
}

export type NextStepAction =
  | { type: "link"; label: string; href: string }
  | { type: "submit"; label: string; disabledReason?: string }
  | { type: "resubmit"; label: string; confirm: boolean }
  | { type: "confirm"; instanceId: string; stepName: string; label: string }
  | { type: "close"; label: string }
  | { type: "resume"; label: string }
  | { type: "reopen"; label: string };

export type NextStep = {
  tone: "action" | "waiting" | "warning" | "done";
  title: string;
  detail?: string;
  action: NextStepAction | null;
  secondary?: NextStepAction | null;
  /** Show the readiness checklist under the sentence. */
  showChecklist?: boolean;
};

export type NextStepPending = {
  id: string;
  stepName: string;
  stepKind: "approval" | "confirmation";
  /** "Anyone in Operations", "Dana Director", "Big Print Co". */
  who: string;
  dueAt: Date | null;
  canDecide: boolean;
};

export type NextStepInput = {
  kind: ReadinessItem["kind"];
  status: string;
  onHoldReason: string | null;
  readiness: Readiness;
  /** Waiting steps of the current round. */
  pending: NextStepPending[];
  /** The latest request for changes in the current round. */
  changeRequest: { stepName: string; deciderName: string | null; comment: string | null } | null;
  rejection: { stepName: string; deciderName: string | null; comment: string | null } | null;
  newArtworkSinceChanges: boolean;
  openSnags: number;
  can: {
    edit: boolean;
    submit: boolean;
    upload: boolean;
    close: boolean;
    reopen: boolean;
    resume: boolean;
  };
  now: Date;
};

const CONFIRM_LABELS: Record<string, string> = {
  "Sent to print": "Confirm sent to print",
  Delivered: "Confirm delivered",
  Installed: "Confirm installed",
};

const CONFIRM_TITLES: Record<string, [string, string]> = {
  // [what's done, what's next]
  "Sent to print": ["Signed off", "confirm it has gone to print"],
  Delivered: ["Sent to print", "confirm delivery"],
  Installed: ["Delivered", "confirm it is installed"],
};

function quote(text: string | null | undefined): string | undefined {
  return text?.trim() ? `“${text.trim()}”` : undefined;
}

/** "Operations sign-off — overdue since 23 Sept 2026", "… — due 3 Oct 2026". */
function dueLine(steps: NextStepPending[], now: Date): { text?: string; overdue: boolean } {
  const dated = steps
    .filter((s) => s.dueAt)
    .sort((a, b) => a.dueAt!.getTime() - b.dueAt!.getTime());
  const first = dated[0];
  if (!first) return { text: steps.map((s) => s.stepName).join(", ") || undefined, overdue: false };
  const overdue = first.dueAt!.getTime() < now.getTime();
  return {
    text: `${first.stepName} — ${overdue ? "overdue since" : "due"} ${formatDate(first.dueAt)}`,
    overdue,
  };
}

/**
 * The one thing that happens next on an item, who it waits on, and the
 * single button that does it (when the viewer may). Every kind of item
 * shares it; stand designs stop at sign-off and move on to their panels.
 */
export function nextStep(input: NextStepInput): NextStep {
  const { status, readiness, can } = input;
  const artwork =
    input.kind === "stand_design" ? "design" : input.kind === "stand_panel" ? "graphic" : "artwork";
  const uploadLink = (label: string): NextStepAction | null =>
    can.upload ? { type: "link", label, href: "?tab=artwork#upload" } : null;
  const approvals = input.pending.filter((p) => p.stepKind === "approval");
  const mine = approvals.find((p) => p.canDecide);
  const waitingOn = (steps: NextStepPending[]) => joinWords([...new Set(steps.map((s) => s.who))]);

  switch (status) {
    case "on_hold":
      return {
        tone: "warning",
        title: input.onHoldReason ? `On hold: ${input.onHoldReason}` : "On hold",
        detail: "Sign-off is paused; due dates move on by the time it is held.",
        action: can.resume ? { type: "resume", label: "Resume" } : null,
      };
    case "draft": {
      if (!readiness.fieldsReady) {
        const missing = readiness.lines.filter((l) => l.blocking && !l.done);
        return {
          tone: "action",
          title: `Next: add ${joinWords(missing.map((l) => l.label.toLowerCase()))} so it can go for sign-off`,
          action: can.edit
            ? { type: "link", label: "Edit details", href: "?tab=details&edit=1" }
            : null,
          // Shown, but not until it is ready — and saying why.
          secondary: can.submit
            ? {
                type: "submit",
                label: "Send for sign-off",
                disabledReason: submitBlockedReason(readiness) ?? undefined,
              }
            : null,
          showChecklist: true,
        };
      }
      if (!readiness.hasArtwork) {
        return {
          tone: "action",
          title: `Next: upload the ${artwork}`,
          detail: "Sign-off starts as soon as you send it.",
          action: uploadLink(`Upload ${artwork}`),
          secondary: can.submit ? { type: "submit", label: `Ready for ${artwork}` } : null,
          showChecklist: true,
        };
      }
      return {
        tone: "action",
        title: "Ready to send for sign-off",
        detail: "Everything sign-off needs is here.",
        action: can.submit ? { type: "submit", label: "Send for sign-off" } : null,
        showChecklist: true,
      };
    }
    case "awaiting_artwork":
      return {
        tone: "action",
        title: `Next: upload the ${artwork}`,
        detail: "Sign-off starts straight away when it is uploaded.",
        action: uploadLink(`Upload ${artwork}`),
      };
    case "in_review": {
      if (mine) {
        const overdue = Boolean(mine.dueAt && mine.dueAt.getTime() < input.now.getTime());
        return {
          tone: overdue ? "warning" : "action",
          title: `Your sign-off: ${mine.stepName}`,
          detail: mine.dueAt
            ? `${overdue ? "Overdue since" : "Due"} ${formatDate(mine.dueAt)}`
            : undefined,
          action: { type: "link", label: `Review ${artwork}`, href: "?tab=artwork#your-decision" },
        };
      }
      const due = dueLine(approvals, input.now);
      return {
        tone: due.overdue ? "warning" : "waiting",
        title: approvals.length ? `Waiting on ${waitingOn(approvals)}` : "In sign-off",
        detail: due.text,
        action: null,
      };
    }
    case "changes_requested": {
      const who = input.changeRequest?.deciderName || input.changeRequest?.stepName || "Someone";
      const resubmit = (label: string, confirm: boolean): NextStepAction | null =>
        can.submit ? { type: "resubmit", label, confirm } : null;
      return {
        tone: "action",
        title: `${who} asked for changes`,
        detail: quote(input.changeRequest?.comment),
        action: input.newArtworkSinceChanges
          ? resubmit("Send back for sign-off", false)
          : uploadLink("Upload new version"),
        secondary: input.newArtworkSinceChanges ? null : resubmit("Resubmit without changes", true),
      };
    }
    case "rejected":
      return {
        tone: "warning",
        title: `Rejected by ${input.rejection?.deciderName || input.rejection?.stepName || "a sign-off"}`,
        detail: quote(input.rejection?.comment),
        action: can.reopen ? { type: "reopen", label: "Reopen as a draft" } : null,
      };
    case "approved":
    case "approved_with_conditions":
    case "in_production":
    case "delivered": {
      const confirmation = input.pending.find((p) => p.stepKind === "confirmation");
      if (!confirmation) {
        if (input.kind === "stand_design") {
          return {
            tone: "action",
            title: "Design signed off. Next: add the panels",
            action: { type: "link", label: "Add panels", href: "?tab=panels" },
          };
        }
        // Nothing waiting to confirm (older data): just say where it is.
        return {
          tone: "done",
          title: status.startsWith("approved") ? "Signed off" : statusLabel(status),
          action: null,
        };
      }
      const [done, next] = CONFIRM_TITLES[confirmation.stepName] ?? [
        "Signed off",
        `confirm ${confirmation.stepName.toLowerCase()}`,
      ];
      if (
        confirmation.stepName === "Sent to print" &&
        !readiness.lines.find((l) => l.key === "supplier")?.done
      ) {
        return {
          tone: "warning",
          title: `${done}. Next: ${next}`,
          detail: "Set the supplier first — nothing goes to print without one.",
          action: can.edit
            ? { type: "link", label: "Set the supplier", href: "?tab=details&edit=1#supplierId" }
            : null,
        };
      }
      if (!confirmation.canDecide) {
        return {
          tone: "waiting",
          title: `${done}. Waiting on ${confirmation.who} to ${next}`,
          detail: dueLine([confirmation], input.now).text,
          action: null,
        };
      }
      return {
        tone: "action",
        title: `${done}. Next: ${next}`,
        detail: confirmation.dueAt ? dueLine([confirmation], input.now).text : undefined,
        action: {
          type: "confirm",
          instanceId: confirmation.id,
          stepName: confirmation.stepName,
          label: CONFIRM_LABELS[confirmation.stepName] ?? "Confirm",
        },
      };
    }
    case "installed":
      return {
        tone: "action",
        title: "Installed. Next: mark it complete",
        detail: "No snags open.",
        action: can.close ? { type: "close", label: "Mark complete" } : null,
      };
    case "snagged":
      return {
        tone: "warning",
        title: `${input.openSnags} snag${input.openSnags === 1 ? "" : "s"} open — fix them to finish`,
        action: { type: "link", label: "View snags", href: "?tab=details#snags" },
      };
    case "closed":
      return { tone: "done", title: "Complete — installed and snag-free", action: null };
    default:
      return { tone: "waiting", title: statusLabel(status), action: null };
  }
}

export type ProgressStep = { key: string; label: string; state: "done" | "current" | "todo" };

const SIGN_STAGES = [
  ["details", "Details"],
  ["artwork", "Artwork"],
  ["signoff", "Sign-off"],
  ["print", "Print"],
  ["delivered", "Delivered"],
  ["installed", "Installed"],
  ["complete", "Complete"],
] as const;

const STAND_STAGES = [
  ["details", "Stand"],
  ["artwork", "Design"],
  ["signoff", "Sign-off"],
  ["panels", "Panels"],
] as const;

/** The slim stepper under the next step: where the item is in its life. */
export function itemProgress(
  kind: ReadinessItem["kind"],
  status: string,
  ctx: { fieldsReady: boolean; hasArtwork: boolean; previousStatus?: string | null },
): ProgressStep[] {
  const stages = kind === "stand_design" ? STAND_STAGES : SIGN_STAGES;
  const s = status === "on_hold" ? (ctx.previousStatus ?? "draft") : status;
  let current: number;
  switch (s) {
    case "draft":
      current = !ctx.fieldsReady ? 0 : !ctx.hasArtwork ? 1 : 2;
      break;
    case "awaiting_artwork":
      current = 1;
      break;
    case "in_review":
    case "changes_requested":
    case "rejected":
      current = 2;
      break;
    case "approved":
    case "approved_with_conditions":
      current = 3;
      break;
    case "in_production":
      current = 4;
      break;
    case "delivered":
      current = 5;
      break;
    case "installed":
    case "snagged":
      current = 6;
      break;
    default:
      current = stages.length; // closed: everything done
  }
  // A stand design's life ends at sign-off; then its panels follow.
  if (kind === "stand_design" && current >= 3 && s !== "closed") current = 3;
  return stages.map(([key, label], i) => ({
    key,
    label,
    state: i < current ? "done" : i === current ? "current" : "todo",
  }));
}
