import "server-only";
import { and, asc, desc, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  contractors,
  halls,
  itemTypes,
  locations,
  memberships,
  sponsorEntitlements,
  sponsors,
  supplierServiceLinks,
  supplierServices,
  suppliers,
  users,
  workflows,
} from "@/lib/db/schema";
import { defaultSignageWorkflowId } from "@/lib/domain/signage";
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
}): Promise<ItemFormOptions> {
  const isSignage = opts.kind === "signage";
  const [typeRows, hallRows, locationRows, sponsorRows, entRows, supplierRows, contractorRows, wfRows] =
    await Promise.all([
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
        .select({ id: suppliers.id, name: suppliers.name, service: supplierServices.name })
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
              ),
            )
            .orderBy(desc(workflows.isDefault), asc(workflows.name))
        : [],
    ]);
  // One entry per supplier, with what they do ("Big Print Co — Signage print, Installation").
  const supplierMap = new Map<string, { id: string; name: string; services: string[] }>();
  for (const r of supplierRows) {
    const entry = supplierMap.get(r.id) ?? { id: r.id, name: r.name, services: [] };
    if (r.service && !entry.services.includes(r.service)) entry.services.push(r.service);
    supplierMap.set(r.id, entry);
  }

  // Department sign-offs and the people who can sign each one.
  const workflowId =
    opts.workflowId ?? (await defaultSignageWorkflowId(db, opts.organisationId, null));
  const [steps, people] = await Promise.all([
    workflowId ? loadStepDefs(db, workflowId) : [],
    db
      .select({
        id: users.id,
        name: users.fullName,
        email: users.email,
        role: memberships.role,
        overrides: memberships.permissionOverrides,
      })
      .from(memberships)
      .innerJoin(users, eq(memberships.userId, users.id))
      .where(eq(memberships.organisationId, opts.organisationId))
      .orderBy(asc(users.fullName)),
  ]);
  const signers = people.filter(
    (p) =>
      p.role !== "viewer" &&
      (p.overrides as Record<string, unknown> | null)?.["approval.decide"] !== false,
  );

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
    signoffSteps: steps.filter(isDepartmentStep).map((s) => ({
      id: s.id,
      name: s.name,
      department: s.approverRole,
      defaultUserId: s.approverType === "user" ? s.approverUserId : null,
      defaultFor: s.defaultFor ?? [],
    })),
    signers: signers.map((p) => ({ id: p.id, name: p.name || p.email, role: p.role })),
  };
}
