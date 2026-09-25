"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { documents, standSubmissions, venueRules } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { computeIsComplex, standTransition } from "@/lib/status/stand";
import { resubmitAfterChanges } from "@/lib/workflow";
import { loadRun, persistRun } from "@/lib/workflow/persist";
import { buildStoragePath, putObject, sha256Hex } from "@/lib/storage";
import { notify } from "@/lib/notify";
import {
  loadStandBundle,
  standAuthzCtx,
  standEntityCtx,
  startStandRun,
  stepActiveFlags,
} from "@/lib/domain/stand";
import { resolveAssigneeUserIds } from "@/lib/domain/signage";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";

async function bundleWithFlags(subId: string, organisationId: string) {
  const bundle = await loadStandBundle(db, subId, { organisationId });
  if (!bundle) return null;
  const run =
    bundle.sub.currentRunNumber > 0
      ? await loadRun(db, "stand_submission", bundle.sub.id, bundle.sub.currentRunNumber)
      : [];
  return { bundle, flags: stepActiveFlags(run) };
}

const questionnaireSchema = z.object({
  submissionId: z.string().uuid(),
  maxHeightMm: z.coerce.number().int().positive().optional().nullable(),
  isDoubleDeck: z.coerce.boolean().default(false),
  hasPlatformOver600mm: z.coerce.boolean().default(false),
  hasRampedRaisedFloor: z.coerce.boolean().default(false),
  hasRigging: z.coerce.boolean().default(false),
  hasCeilingOrRoof: z.coerce.boolean().default(false),
  hasTieredSeating: z.coerce.boolean().default(false),
  otherComplexNotes: z.string().max(3000).optional().nullable(),
});

export async function saveStandQuestionnaire(input: unknown): Promise<ActionResult> {
  const parsed = questionnaireSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  const loaded = await bundleWithFlags(parsed.data.submissionId, session.organisation.id);
  if (!loaded) return fail("Submission not found");
  const { bundle, flags } = loaded;
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  const ctx = standAuthzCtx(bundle, flags);

  const isExhibitor = can(session.actor, { type: "stand.submit", sub: ctx });
  const isOps = can(session.actor, { type: "stand.review" });
  if (!isExhibitor && !isOps) return fail("You cannot edit this submission");
  if (!["not_submitted", "changes_requested"].includes(bundle.sub.status) && !isOps) {
    return fail("The questionnaire is locked while the submission is in review");
  }

  const d = parsed.data;
  const isComplex = computeIsComplex({
    isDoubleDeck: d.isDoubleDeck,
    hasPlatformOver600mm: d.hasPlatformOver600mm,
    hasRampedRaisedFloor: d.hasRampedRaisedFloor,
    hasRigging: d.hasRigging,
    hasCeilingOrRoof: d.hasCeilingOrRoof,
    hasTieredSeating: d.hasTieredSeating,
    maxHeightMm: d.maxHeightMm ?? null,
  });

  await db.transaction(async (tx) => {
    await tx
      .update(standSubmissions)
      .set({
        maxHeightMm: d.maxHeightMm ?? null,
        isDoubleDeck: d.isDoubleDeck,
        hasPlatformOver600mm: d.hasPlatformOver600mm,
        hasRampedRaisedFloor: d.hasRampedRaisedFloor,
        hasRigging: d.hasRigging,
        hasCeilingOrRoof: d.hasCeilingOrRoof,
        hasTieredSeating: d.hasTieredSeating,
        otherComplexNotes: d.otherComplexNotes ?? null,
        isComplex,
      })
      .where(eq(standSubmissions.id, bundle.sub.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: bundle.edition.id,
      actorUserId: session.user.id,
      entityType: "stand_submission",
      entityId: bundle.sub.id,
      action: "update",
      after: { ...d, isComplex },
      summary: `Structure questionnaire updated for ${bundle.sub.ref}${isComplex ? " (complex structure)" : ""}`,
    });
  });
  revalidatePath("/", "layout");
  return success(
    undefined,
    isComplex
      ? "Saved — this design counts as a complex structure and will need engineer review"
      : "Saved",
  );
}

const DOC_TYPES = [
  "plan",
  "elevation",
  "structural_calcs",
  "rams",
  "insurance_pl",
  "fire_cert",
  "electrical_cert",
  "rigging_plan",
  "other",
] as const;

export async function uploadStandDocument(formData: FormData): Promise<ActionResult> {
  const submissionId = formData.get("submissionId");
  const docType = formData.get("docType");
  const expiresAt = formData.get("expiresAt");
  const file = formData.get("file");
  if (
    typeof submissionId !== "string" ||
    typeof docType !== "string" ||
    !DOC_TYPES.includes(docType as (typeof DOC_TYPES)[number]) ||
    !(file instanceof File)
  ) {
    return fail("Invalid upload");
  }
  const session = await requireSession();
  const loaded = await bundleWithFlags(submissionId, session.organisation.id);
  if (!loaded) return fail("Submission not found");
  const { bundle, flags } = loaded;
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  const ctx = standAuthzCtx(bundle, flags);
  const isExhibitor = can(session.actor, { type: "stand.submit", sub: ctx });
  const isOps = can(session.actor, { type: "stand.review" });
  if (!isExhibitor && !isOps) return fail("You cannot upload documents here");
  if (file.size > 100 * 1024 * 1024) return fail("Documents are limited to 100 MB");

  const bytes = Buffer.from(await file.arrayBuffer());
  const storagePath = buildStoragePath({
    organisationId: session.organisation.id,
    editionId: bundle.edition.id,
    entityType: "stand_submission",
    entityId: bundle.sub.id,
    fileName: file.name,
  });
  await putObject("documents", storagePath, bytes);

  await db.transaction(async (tx) => {
    await tx.insert(documents).values({
      organisationId: session.organisation.id,
      editionId: bundle.edition.id,
      entityType: "stand_submission",
      entityId: bundle.sub.id,
      docType: docType as (typeof DOC_TYPES)[number],
      filePath: storagePath,
      fileName: file.name,
      mimeType: file.type || "application/octet-stream",
      fileSize: file.size,
      sha256: sha256Hex(bytes),
      submissionVersion: bundle.sub.submissionVersion,
      expiresAt: typeof expiresAt === "string" && expiresAt ? expiresAt : null,
      uploadedBy: session.user.id,
      isExternalUpload: session.actor.kind === "external",
    });
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: bundle.edition.id,
      actorUserId: session.user.id,
      entityType: "stand_submission",
      entityId: bundle.sub.id,
      action: "upload",
      after: { docType, fileName: file.name },
      summary: `${docType} uploaded for ${bundle.sub.ref} (v${bundle.sub.submissionVersion})`,
    });
  });
  revalidatePath("/", "layout");
  return success(undefined, "Document uploaded");
}

/** Submit (or resubmit) a stand design. */
export async function submitStandSubmission(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ submissionId: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const loaded = await bundleWithFlags(parsed.data.submissionId, session.organisation.id);
  if (!loaded) return fail("Submission not found");
  const { bundle, flags } = loaded;
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  const ctx = standAuthzCtx(bundle, flags);
  const isExhibitor = can(session.actor, { type: "stand.submit", sub: ctx });
  const isOps = can(session.actor, { type: "stand.review" });
  if (!isExhibitor && !isOps) return fail("You cannot submit this design");

  const isResubmit = ["changes_requested", "rejected"].includes(bundle.sub.status);
  const versionForDocs = isResubmit
    ? bundle.sub.submissionVersion + 1
    : bundle.sub.submissionVersion;

  // Every required doc type must be present for the current version — on
  // resubmit, documents uploaded since the request also count.
  const docs = await db
    .select()
    .from(documents)
    .where(
      and(eq(documents.entityType, "stand_submission"), eq(documents.entityId, bundle.sub.id)),
    );
  const required = bundle.edition.standRequiredDocTypes;
  const presentTypes = new Set(
    docs
      .filter((d) => (d.submissionVersion ?? 1) >= bundle.sub.submissionVersion)
      .map((d) => d.docType),
  );
  const missing = required.filter((r) => !presentTypes.has(r as (typeof docs)[number]["docType"]));
  if (missing.length > 0) {
    return fail(`Cannot submit — missing required documents: ${missing.join(", ")}`);
  }
  if (!bundle.sub.maxHeightMm) return fail("Cannot submit — set the maximum height first");

  let next;
  try {
    next = standTransition(bundle.sub.status, isResubmit ? "resubmit" : "submit", {
      requiredDocsPresent: true,
      maxHeightSet: true,
    });
  } catch (err) {
    return fail(err instanceof Error ? err.message : "This design cannot be submitted right now");
  }

  try {
    await db.transaction(async (tx) => {
      const set: Partial<typeof standSubmissions.$inferInsert> = {
        status: next,
        submittedAt: new Date(),
        submittedBy: session.user.id,
      };
      if (isResubmit) set.submissionVersion = versionForDocs;

      // Generate the rules checklist from venue rules on first submission.
      if (!isResubmit || bundle.sub.rulesChecklist.length === 0) {
        const rules = await tx
          .select()
          .from(venueRules)
          .where(eq(venueRules.venueId, bundle.venue.id));
        set.rulesChecklist = rules
          .filter((r) => r.isChecklistItem && (r.appliesTo === "stand" || r.appliesTo === "both"))
          .map((r) => ({
            rule_id: r.id,
            checked: false,
            checked_by: null,
            checked_at: null,
            note: null,
          }));
      }
      await tx.update(standSubmissions).set(set).where(eq(standSubmissions.id, bundle.sub.id));

      if (isResubmit && bundle.sub.currentRunNumber > 0) {
        const run = await loadRun(
          tx,
          "stand_submission",
          bundle.sub.id,
          bundle.sub.currentRunNumber,
        );
        const res = resubmitAfterChanges(run, { entity: standEntityCtx(bundle), now: new Date() });
        if (res.mode === "restart_from_step") {
          await persistRun(tx, "stand_submission", bundle.sub.id, res.instances);
        } else {
          await startStandRun(tx, bundle, new Date());
        }
      } else {
        const instances = await startStandRun(tx, bundle, new Date());
        for (const inst of instances.filter((i) => i.status === "pending")) {
          const assignees = await resolveAssigneeUserIds(
            tx,
            session.organisation.id,
            bundle.edition.id,
            bundle.venue.id,
            null,
            inst,
          );
          await notify(tx, {
            userIds: assignees,
            kind: "stand_submitted",
            title: `Stand submission received: ${bundle.sub.ref}`,
            body: `${bundle.exhibitor.companyName} — stand ${bundle.exhibitor.standNumber}`,
            link: `/${bundle.edition.code}/stands/${bundle.sub.ref}`,
            entityType: "stand_submission",
            entityId: bundle.sub.id,
          });
        }
      }

      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: "stand_submission",
        entityId: bundle.sub.id,
        action: "submit",
        after: { status: next, submissionVersion: versionForDocs },
        summary: `${bundle.sub.ref} ${isResubmit ? `resubmitted (v${versionForDocs})` : "submitted"}`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, isResubmit ? "Resubmitted for review" : "Submitted — review started");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}

const checklistSchema = z.object({
  submissionId: z.string().uuid(),
  ruleId: z.string().uuid(),
  checked: z.boolean(),
  note: z.string().max(1000).optional().nullable(),
});

export async function tickRulesChecklist(input: unknown): Promise<ActionResult> {
  const parsed = checklistSchema.safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "stand.review" })) return fail("Only ops review the checklist");
  const bundle = await loadStandBundle(db, parsed.data.submissionId, {
    organisationId: session.organisation.id,
  });
  if (!bundle) return fail("Submission not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);

  const updated = bundle.sub.rulesChecklist.map((entry) =>
    entry.rule_id === parsed.data.ruleId
      ? {
          ...entry,
          checked: parsed.data.checked,
          checked_by: session.user.id,
          checked_at: new Date().toISOString(),
          note: parsed.data.note ?? entry.note,
        }
      : entry,
  );
  await db.transaction(async (tx) => {
    await tx
      .update(standSubmissions)
      .set({ rulesChecklist: updated })
      .where(eq(standSubmissions.id, bundle.sub.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: bundle.edition.id,
      actorUserId: session.user.id,
      entityType: "stand_submission",
      entityId: bundle.sub.id,
      action: "update",
      after: { ruleId: parsed.data.ruleId, checked: parsed.data.checked },
      summary: `Rules checklist updated on ${bundle.sub.ref}`,
    });
  });
  revalidatePath("/", "layout");
  return success();
}

const docReviewSchema = z.object({
  documentId: z.string().uuid(),
  status: z.enum(["accepted", "rejected"]),
  reviewNote: z.string().max(1000).optional().nullable(),
});

export async function reviewStandDocument(input: unknown): Promise<ActionResult> {
  const parsed = docReviewSchema.safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "stand.review" })) return fail("Only ops review documents");
  await db.transaction(async (tx) => {
    const [doc] = await tx
      .update(documents)
      .set({ status: parsed.data.status, reviewNote: parsed.data.reviewNote ?? null })
      .where(
        and(
          eq(documents.id, parsed.data.documentId),
          eq(documents.organisationId, session.organisation.id),
        ),
      )
      .returning();
    if (!doc) return;
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: doc?.editionId,
      actorUserId: session.user.id,
      entityType: "document",
      entityId: parsed.data.documentId,
      action: "update",
      after: { status: parsed.data.status },
      summary: `Document ${doc?.fileName ?? ""} ${parsed.data.status}`,
    });
  });
  revalidatePath("/", "layout");
  return success(undefined, `Document ${parsed.data.status}`);
}
