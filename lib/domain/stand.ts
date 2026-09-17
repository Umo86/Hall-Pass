/** Domain glue for stand submissions. */
import { eq } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import {
  editions,
  exhibitors,
  organisations,
  standSubmissions,
  venues,
} from "@/lib/db/schema";
import type { StandSubmissionCtx } from "@/lib/authz";
import { createRun, type EngineSettings, type EntityCtx, type Instance } from "@/lib/workflow";
import { loadStepDefs, persistRun } from "@/lib/workflow/persist";

export type StandBundle = {
  sub: typeof standSubmissions.$inferSelect;
  exhibitor: typeof exhibitors.$inferSelect;
  edition: typeof editions.$inferSelect;
  venue: typeof venues.$inferSelect;
  organisation: typeof organisations.$inferSelect;
};

export async function loadStandBundle(db: Db | Tx, subId: string): Promise<StandBundle | null> {
  const [row] = await db
    .select()
    .from(standSubmissions)
    .innerJoin(exhibitors, eq(standSubmissions.exhibitorId, exhibitors.id))
    .innerJoin(editions, eq(standSubmissions.editionId, editions.id))
    .innerJoin(venues, eq(editions.venueId, venues.id))
    .where(eq(standSubmissions.id, subId))
    .limit(1);
  if (!row) return null;
  const [org] = await db
    .select()
    .from(organisations)
    .where(eq(organisations.id, row.venues.organisationId))
    .limit(1);
  return {
    sub: row.stand_submissions,
    exhibitor: row.exhibitors,
    edition: row.editions,
    venue: row.venues,
    organisation: org,
  };
}

/**
 * Step-active flags for external scoping: a role's step is "active" once it
 * is pending or later in the current run (brief 3.2 — "at or past the step").
 */
export function stepActiveFlags(instances: Instance[]): {
  venueStepActive: boolean;
  engineerStepActive: boolean;
  hsStepActive: boolean;
} {
  const activeStatuses = ["pending", "approved", "approved_with_conditions", "changes_requested", "rejected", "confirmed"];
  const activeFor = (role: string) =>
    instances.some((i) => i.assignedRole === role && activeStatuses.includes(i.status));
  return {
    venueStepActive: activeFor("venue"),
    engineerStepActive: activeFor("structural_engineer"),
    hsStepActive: activeFor("hs"),
  };
}

export function standAuthzCtx(
  bundle: StandBundle,
  flags?: ReturnType<typeof stepActiveFlags>,
): StandSubmissionCtx {
  return {
    editionId: bundle.edition.id,
    venueId: bundle.venue.id,
    exhibitorId: bundle.exhibitor.id,
    contractorId: bundle.sub.contractorId,
    ...flags,
  };
}

export function standEntityCtx(bundle: StandBundle): EntityCtx {
  return {
    kind: "stand",
    isComplex: bundle.sub.isComplex,
    venueRequiresStandApproval: bundle.venue.requiresStandApproval,
  };
}

export function standEngineSettings(bundle: StandBundle): EngineSettings {
  return {
    costThresholdForDirector: bundle.organisation.settings.cost_threshold_for_director ?? 5000,
  };
}

export async function startStandRun(tx: Tx, bundle: StandBundle, now: Date): Promise<Instance[]> {
  const workflowId = bundle.sub.workflowId;
  if (!workflowId) throw new Error("Submission has no workflow assigned");
  const steps = await loadStepDefs(tx, workflowId);
  const runNumber = bundle.sub.currentRunNumber + 1;
  const run = createRun({
    steps,
    entity: standEntityCtx(bundle),
    settings: standEngineSettings(bundle),
    runNumber,
    now,
  });
  const persisted = await persistRun(tx, "stand_submission", bundle.sub.id, run);
  await tx
    .update(standSubmissions)
    .set({ currentRunNumber: runNumber })
    .where(eq(standSubmissions.id, bundle.sub.id));
  return persisted;
}
