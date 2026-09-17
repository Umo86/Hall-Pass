import "server-only";
import { and, asc, desc, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  approvalInstances,
  contractors,
  documents,
  exhibitors,
  standSubmissions,
  users,
  venueRules,
} from "@/lib/db/schema";

export async function listStandRows(editionId: string) {
  const rows = await db
    .select({
      exhibitor: exhibitors,
      sub: standSubmissions,
      contractor: contractors,
    })
    .from(exhibitors)
    .leftJoin(standSubmissions, eq(standSubmissions.exhibitorId, exhibitors.id))
    .leftJoin(contractors, eq(exhibitors.contractorId, contractors.id))
    .where(eq(exhibitors.editionId, editionId))
    .orderBy(asc(exhibitors.standNumber));
  return rows;
}

export async function getStandByRef(ref: string) {
  const [sub] = await db
    .select()
    .from(standSubmissions)
    .where(eq(standSubmissions.ref, ref))
    .limit(1);
  return sub ?? null;
}

export async function getStandDocuments(subId: string) {
  return db
    .select({ doc: documents, uploader: users })
    .from(documents)
    .leftJoin(users, eq(documents.uploadedBy, users.id))
    .where(and(eq(documents.entityType, "stand_submission"), eq(documents.entityId, subId)))
    .orderBy(desc(documents.createdAt));
}

export async function getStandInstances(subId: string) {
  return db
    .select({ instance: approvalInstances, decider: users })
    .from(approvalInstances)
    .leftJoin(users, eq(approvalInstances.decidedBy, users.id))
    .where(
      and(
        eq(approvalInstances.entityType, "stand_submission"),
        eq(approvalInstances.entityId, subId),
      ),
    )
    .orderBy(
      desc(approvalInstances.runNumber),
      asc(approvalInstances.sortOrderSnapshot),
      asc(approvalInstances.createdAt),
    );
}

export async function getVenueRulesById(venueId: string) {
  return db.select().from(venueRules).where(eq(venueRules.venueId, venueId));
}

/** The exhibitor's own submission for the portal, via their grants. */
export async function getSubmissionForExhibitor(exhibitorId: string) {
  const [row] = await db
    .select({ sub: standSubmissions, exhibitor: exhibitors })
    .from(standSubmissions)
    .innerJoin(exhibitors, eq(standSubmissions.exhibitorId, exhibitors.id))
    .where(eq(standSubmissions.exhibitorId, exhibitorId))
    .limit(1);
  return row ?? null;
}
