import { requirePortalSession } from "@/lib/auth/actor";
import { db } from "@/lib/db/client";
import { loadStandBundle, standAuthzCtx, stepActiveFlags } from "@/lib/domain/stand";
import { getStandDocuments, getSubmissionForExhibitor } from "@/lib/queries/stands";
import { getEntityComments } from "@/lib/queries/signage";
import { loadRun } from "@/lib/workflow/persist";
import { can } from "@/lib/authz";
import { getDownloadUrl } from "@/lib/storage";
import { formatDateTime } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import { CommentThread } from "@/components/comments/thread";
import { DocumentsPanel, type DocRow } from "@/components/stands/documents-panel";
import { QuestionnaireForm } from "@/components/stands/questionnaire-form";
import { SubmitStandButton } from "@/components/stands/submit-button";

export const metadata = { title: "My Submission" };
export const dynamic = "force-dynamic";

export default async function PortalSubmissionPage() {
  const session = await requirePortalSession();
  const grant = session.actor.grants.find(
    (g) => (g.role === "exhibitor" || g.role === "contractor") && g.scopeType === "exhibitor",
  );
  if (!grant?.scopeId) {
    return (
      <div className="p-4 sm:p-6">
        <p className="text-muted-foreground text-sm">
          No stand submission is linked to your account. Contact the organiser if you believe this
          is wrong.
        </p>
      </div>
    );
  }

  const row = await getSubmissionForExhibitor(grant.scopeId);
  if (!row) {
    return (
      <div className="p-4 sm:p-6">
        <p className="text-muted-foreground text-sm">
          Your submission record has not been created yet — the organiser will set it up.
        </p>
      </div>
    );
  }
  const bundle = await loadStandBundle(db, row.sub.id);
  if (!bundle) return null;

  const run =
    row.sub.currentRunNumber > 0
      ? await loadRun(db, "stand_submission", row.sub.id, row.sub.currentRunNumber)
      : [];
  const ctx = standAuthzCtx(bundle, stepActiveFlags(run));
  const canSubmit = can(session.actor, { type: "stand.submit", sub: ctx });
  const editable = ["not_submitted", "changes_requested", "rejected"].includes(row.sub.status);

  const docs = await getStandDocuments(row.sub.id);
  const comments = await getEntityComments("stand_submission", row.sub.id, false);

  const docRows: DocRow[] = await Promise.all(
    docs.map(async ({ doc, uploader }) => ({
      id: doc.id,
      docType: doc.docType,
      fileName: doc.fileName,
      status: doc.status,
      reviewNote: doc.reviewNote,
      submissionVersion: doc.submissionVersion,
      expiresAt: doc.expiresAt,
      expiryFlag: false,
      uploaderName: uploader?.fullName ?? null,
      createdAt: doc.createdAt.toISOString(),
      downloadUrl: doc.filePath.startsWith("seed/")
        ? null
        : await getDownloadUrl("documents", doc.filePath).catch(() => null),
    })),
  );

  const changesComment = run.find((i) => i.status === "changes_requested")?.decisionComment;

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6 p-4 sm:p-6">
      <div className="flex flex-wrap items-center gap-3">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">
            Stand {bundle.exhibitor.standNumber} — {bundle.exhibitor.companyName}
          </h1>
          <p className="text-muted-foreground text-sm">
            {bundle.edition.name} · submission v{row.sub.submissionVersion}
            {row.sub.submittedAt ? ` · submitted ${formatDateTime(row.sub.submittedAt)}` : ""}
          </p>
        </div>
        <StatusBadge status={row.sub.status} />
      </div>

      {row.sub.status === "changes_requested" && (
        <div className="rounded-lg border border-orange-300 bg-orange-50 p-4 text-sm dark:border-orange-900 dark:bg-orange-950">
          <p className="font-medium text-orange-800 dark:text-orange-300">Changes requested</p>
          {changesComment && <p className="mt-1">“{changesComment}”</p>}
          <p className="text-muted-foreground mt-1">
            Upload revised documents below, then resubmit.
          </p>
        </div>
      )}

      {row.sub.outcome && (
        <div className="rounded-lg border p-4 text-sm">
          <p className="font-medium">
            Outcome: <StatusBadge status={row.sub.outcome} />
          </p>
          {row.sub.conditionsText && (
            <p className="mt-2 text-teal-800 dark:text-teal-300">
              Conditions of approval: {row.sub.conditionsText}
            </p>
          )}
        </div>
      )}

      <section>
        <h2 className="mb-2 text-sm font-semibold">Structure questionnaire</h2>
        <QuestionnaireForm
          values={{
            submissionId: row.sub.id,
            maxHeightMm: row.sub.maxHeightMm,
            isDoubleDeck: row.sub.isDoubleDeck,
            hasPlatformOver600mm: row.sub.hasPlatformOver600mm,
            hasRampedRaisedFloor: row.sub.hasRampedRaisedFloor,
            hasRigging: row.sub.hasRigging,
            hasCeilingOrRoof: row.sub.hasCeilingOrRoof,
            hasTieredSeating: row.sub.hasTieredSeating,
            otherComplexNotes: row.sub.otherComplexNotes,
            isComplex: row.sub.isComplex,
          }}
          readOnly={!editable || !canSubmit}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Documents</h2>
        <DocumentsPanel
          submissionId={row.sub.id}
          requiredTypes={bundle.edition.standRequiredDocTypes}
          documents={docRows}
          canUpload={canSubmit && editable}
          canReview={false}
          currentVersion={row.sub.submissionVersion}
        />
      </section>

      {canSubmit && editable && (
        <SubmitStandButton
          submissionId={row.sub.id}
          isResubmit={row.sub.status !== "not_submitted"}
        />
      )}

      <section>
        <h2 className="mb-2 text-sm font-semibold">Messages</h2>
        <CommentThread
          entityType="stand_submission"
          entityId={row.sub.id}
          comments={comments.map(({ comment, author }) => ({
            id: comment.id,
            body: comment.body,
            isInternal: false,
            authorName: author.fullName || author.email,
            createdAt: comment.createdAt.toISOString(),
          }))}
          canWriteInternal={false}
          canWriteExternal={can(session.actor, { type: "comment.external.write", entity: ctx })}
          isStaff={false}
        />
      </section>
    </div>
  );
}
