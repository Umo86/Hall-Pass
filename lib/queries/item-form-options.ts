import "server-only";
import { listDepartments } from "@/lib/domain/departments";
import { and, asc, desc, eq, inArray, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  contractors,
  halls,
  itemTypes,
  locations,
  signageItems,
  sponsorEntitlements,
  sponsors,
  supplierServiceLinks,
  supplierServices,
  suppliers,
  workflows,
} from "@/lib/db/schema";
import { defaultSignageWorkflowId } from "@/lib/domain/signage";
import {
  eligibleIds,
  loadTeam,
  peopleFor,
  refusalFor,
  type PersonOption,
  type TeamMember,
} from "@/lib/people";
import type { SignoffPlan } from "@/lib/workflow/types";
import { loadStepDefs } from "@/lib/workflow/persist";
import { isDepartmentStep } from "@/lib/workflow/signoffs";
import type { ItemFormOptions } from "@/components/signage/item-form";

/**
 * Everything the item form's pickers need, for one kind of item. Workflows
 * are only loaded for the create form (the default one first).
 */
export async function itemFormOptions(opts: {
  organisationId: string;
  editionId: string;
  kind: "signage" | "sponsorship_item";
  withWorkflows?: boolean;
  /** The item's workflow (edit); new items use the organisation's default. */
  workflowId?: string | null;
  /** Keep a type that's been hidden since the item chose it. */
  includeTypeId?: string | null;
  /**
   * The item's current supplier, kept even if it has been archived since
   * (null: the item has none). Left out, an edit form (no workflows) keeps
   * every archived supplier still set on one of this event's items, so
   * saving never drops a supplier the picker didn't list.
   */
  includeSupplierId?: string | null;
  /** The person filling the form in: offered first as "Me". */
  viewer?: { id: string; departmentId: string | null } | null;
  /** The item's owner now (edit): kept in the picker, labelled if they can't own it any more. */
  ownerUserId?: string | null;
  /** The item's stored sign-off choices (edit): named people who can't sign are kept, labelled. */
  plan?: SignoffPlan | null;
}): Promise<ItemFormOptions> {
  const isSignage = opts.kind === "signage";
  const [
    typeRows,
    hallRows,
    locationRows,
    sponsorRows,
    entRows,
    supplierRows,
    contractorRows,
    wfRows,
    peopleRows,
  ] = await Promise.all([
    db
      .select({
        id: itemTypes.id,
        name: itemTypes.name,
        format: itemTypes.format,
        isArchived: itemTypes.isArchived,
      })
      .from(itemTypes)
      .where(and(eq(itemTypes.organisationId, opts.organisationId), eq(itemTypes.kind, opts.kind)))
      .orderBy(asc(itemTypes.sortOrder), asc(itemTypes.name)),
    isSignage
      ? db
          .select({ id: halls.id, name: halls.name })
          .from(halls)
          .where(eq(halls.editionId, opts.editionId))
          .orderBy(asc(halls.sortOrder), asc(halls.name))
      : [],
    isSignage
      ? db
          .select({ id: locations.id, name: locations.name, hallId: locations.hallId })
          .from(locations)
          .innerJoin(halls, eq(locations.hallId, halls.id))
          .where(eq(halls.editionId, opts.editionId))
          .orderBy(asc(locations.name))
      : [],
    db
      .select({ id: sponsors.id, name: sponsors.companyName })
      .from(sponsors)
      .where(eq(sponsors.editionId, opts.editionId))
      .orderBy(asc(sponsors.companyName)),
    db
      .select({
        id: sponsorEntitlements.id,
        sponsorId: sponsorEntitlements.sponsorId,
        description: sponsorEntitlements.description,
      })
      .from(sponsorEntitlements)
      .innerJoin(sponsors, eq(sponsorEntitlements.sponsorId, sponsors.id))
      .where(eq(sponsors.editionId, opts.editionId)),
    db
      .select({
        id: suppliers.id,
        name: suppliers.name,
        isArchived: suppliers.isArchived,
        service: supplierServices.name,
      })
      .from(suppliers)
      .leftJoin(supplierServiceLinks, eq(supplierServiceLinks.supplierId, suppliers.id))
      .leftJoin(
        supplierServices,
        and(
          eq(supplierServiceLinks.serviceId, supplierServices.id),
          eq(supplierServices.isArchived, false),
        ),
      )
      .where(eq(suppliers.organisationId, opts.organisationId))
      .orderBy(asc(suppliers.name), asc(supplierServices.sortOrder)),
    isSignage
      ? db
          .select({ id: contractors.id, name: contractors.name })
          .from(contractors)
          .where(eq(contractors.organisationId, opts.organisationId))
          .orderBy(asc(contractors.name))
      : [],
    opts.withWorkflows
      ? db
          .select({ id: workflows.id, name: workflows.name })
          .from(workflows)
          .where(
            and(
              eq(workflows.organisationId, opts.organisationId),
              eq(workflows.appliesTo, "signage"),
              eq(workflows.isArchived, false),
              isNull(workflows.forKind),
            ),
          )
          .orderBy(desc(workflows.isDefault), asc(workflows.name))
      : [],
    // Who can own an item, and the names on its sign-off: lib/people.ts.
    loadTeam(db, opts.organisationId),
  ]);
  const team = peopleRows;
  // Archived suppliers are left out of pickers, except one the item still uses.
  const keepArchived = new Set<string>();
  if (opts.includeSupplierId) keepArchived.add(opts.includeSupplierId);
  if (opts.includeSupplierId === undefined && !opts.withWorkflows) {
    const archivedIds = [...new Set(supplierRows.filter((r) => r.isArchived).map((r) => r.id))];
    if (archivedIds.length > 0) {
      const used = await db
        .selectDistinct({ id: signageItems.supplierId })
        .from(signageItems)
        .where(
          and(
            eq(signageItems.editionId, opts.editionId),
            isNull(signageItems.deletedAt),
            inArray(signageItems.supplierId, archivedIds),
          ),
        );
      for (const u of used) if (u.id) keepArchived.add(u.id);
    }
  }
  // One entry per supplier, with what they do ("Big Print Co — Signage print, Installation").
  const supplierMap = new Map<string, { id: string; name: string; services: string[] }>();
  for (const r of supplierRows) {
    if (r.isArchived && !keepArchived.has(r.id)) continue;
    const name = r.isArchived ? `${r.name} (archived)` : r.name;
    const entry = supplierMap.get(r.id) ?? { id: r.id, name, services: [] };
    if (r.service && !entry.services.includes(r.service)) entry.services.push(r.service);
    supplierMap.set(r.id, entry);
  }

  // Department sign-offs and the people who can sign each one.
  const workflowId =
    opts.workflowId ?? (await defaultSignageWorkflowId(db, opts.organisationId, null));
  const [steps, depts] = await Promise.all([
    workflowId ? loadStepDefs(db, workflowId) : [],
    listDepartments(db, opts.organisationId),
  ]);
  const deptById = new Map(depts.map((d) => [d.id, d]));

  return {
    itemTypes: typeRows
      .filter((t) => !t.isArchived || t.id === opts.includeTypeId)
      .map((t) => ({ id: t.id, name: t.name, format: t.format })),
    halls: hallRows,
    locations: locationRows,
    sponsors: sponsorRows,
    entitlements: entRows,
    suppliers: [...supplierMap.values()],
    contractors: contractorRows,
    workflows: wfRows,
    owners: await ownerChoices(team, {
      organisationId: opts.organisationId,
      editionId: opts.editionId,
      kind: opts.kind,
      ownerUserId: opts.ownerUserId ?? null,
    }),
    viewer: opts.viewer ?? null,
    signoffSteps: steps.filter(isDepartmentStep).map((s) => {
      const dept = s.departmentId ? deptById.get(s.departmentId) : undefined;
      // Only approvers who can open this event (Users → Events).
      const people = (dept?.approvers ?? [])
        .filter(
          (a) =>
            a.active && a.userId && (a.editionIds == null || a.editionIds.includes(opts.editionId)),
        )
        .map((a) => ({ id: a.userId!, name: a.fullName, jobTitle: a.jobTitle }));
      // Someone this item names for the step who can't sign it now stays
      // visible, with why, so the choice is never silently swapped.
      const unavailable = (opts.plan ?? [])
        .filter((p) => p.stepId === s.id && p.userId && !people.some((x) => x.id === p.userId))
        .map((p) => {
          const m = team.find((x) => x.userId === p.userId);
          return {
            id: p.userId!,
            name: m?.name ?? "Someone who has left",
            reason:
              refusalFor(
                {
                  type: "signoff",
                  departmentId: s.departmentId ?? null,
                  editionId: opts.editionId,
                },
                m,
                { organisationId: opts.organisationId },
              )?.label ?? "Can't sign off",
          };
        });
      return {
        id: s.id,
        name: s.name,
        departmentName: dept?.name ?? s.name.replace(/ sign-off$/, ""),
        defaultUserId: s.approverType === "user" ? s.approverUserId : null,
        defaultFor: s.defaultFor ?? [],
        people,
        ...(unavailable.length > 0 ? { unavailable } : {}),
      };
    }),
  };
}

/**
 * Who can own an item of this kind, for organiser and for sponsor signage
 * (Sales may own sponsor signage only). Each list also carries the people
 * the other one offers, labelled, so switching the category never drops
 * the person picked; the current owner is always there.
 */
async function ownerChoices(
  team: TeamMember[],
  opts: {
    organisationId: string;
    /** Only people who can open the event (Users → Events). */
    editionId: string;
    kind: "signage" | "sponsorship_item";
    ownerUserId: string | null;
  },
): Promise<Record<"organiser" | "sponsor", PersonOption[]>> {
  const purpose = (sponsored: boolean) =>
    ({ type: "owner", item: { kind: opts.kind, sponsored }, editionId: opts.editionId }) as const;
  const either = [
    ...eligibleIds(team, purpose(false), { organisationId: opts.organisationId }),
    ...eligibleIds(team, purpose(true), { organisationId: opts.organisationId }),
    opts.ownerUserId,
  ];
  const [organiser, sponsor] = await Promise.all(
    [false, true].map((sponsored) =>
      peopleFor(db, opts.organisationId, purpose(sponsored), { include: either, team }),
    ),
  );
  return { organiser, sponsor };
}
