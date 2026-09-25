import Link from "next/link";
import { notFound } from "next/navigation";
import { inArray } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { users } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, type ApprovalStepCtx } from "@/lib/authz";
import { loadStandBundle, standAuthzCtx } from "@/lib/domain/stand";
import {
  getStandByRef,
  getStandDocuments,
  getStandInstances,
  getVenueRulesById,
} from "@/lib/queries/stands";
import { getEntityAudit, getEntityComments } from "@/lib/queries/signage";
import { getDownloadUrl } from "@/lib/storage";
import { formatDateTime } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import { ApprovalChain, type ChainInstance } from "@/components/approvals/chain";
import { CommentThread } from "@/components/comments/thread";
import { DocumentsPanel, type DocRow } from "@/components/stands/documents-panel";
import { QuestionnaireForm } from "@/components/stands/questionnaire-form";
import { RulesChecklist } from "@/components/stands/checklist";

export const dynamic = "force-dynamic";

export default async function StandDetailPage({
  params,
}: {
  params: Promise<{ editionCode: string; ref: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode, ref } = await params;
  const sub = await getStandByRef(decodeURIComponent(ref));
  if (!sub) notFound();
  const bundle = await loadStandBundle(db, sub.id, { organisationId: session.organisation.id });
  if (!bundle || bundle.edition.code !== editionCode.toUpperCase()) notFound();

  const [docs, instanceRows, comments, audit, rules] = await Promise.all([
    getStandDocuments(sub.id),
    getStandInstances(sub.id),
    getEntityComments("stand_submission", sub.id, true),
    getEntityAudit("stand_submission", sub.id),
    getVenueRulesById(bundle.venue.id),
  ]);

  const ctx = standAuthzCtx(bundle);
  const canReview = can(session.actor, { type: "stand.review" });

  const canDecideIds = new Set<string>();
  const canDelegateIds = new Set<string>();
  for (const { instance } of instanceRows) {
    if (instance.status !== "pending" || instance.runNumber !== sub.currentRunNumber) continue;
    const step: ApprovalStepCtx = {
      assignedRole: instance.assignedRole,
      assignedDepartmentId: instance.assignedDepartmentId,
      assignedUserId: instance.assignedUserId,
      entity: { type: "stand", sub: ctx },
    };
    if (can(session.actor, { type: "approval.decide", step })) canDecideIds.add(instance.id);
    if (can(session.actor, { type: "approval.delegate", step })) canDelegateIds.add(instance.id);
  }

  const chain: ChainInstance[] = instanceRows.map(({ instance, decider }) => ({
    id: instance.id,
    runNumber: instance.runNumber,
    stepName: instance.stepNameSnapshot,
    stepKind: instance.stepKindSnapshot,
    sortOrder: instance.sortOrderSnapshot,
    status: instance.status,
    assignedRole: instance.assignedRole,
    assignedDepartmentId: instance.assignedDepartmentId,
    assignedUserId: instance.assignedUserId,
    deciderName: decider?.fullName ?? decider?.email ?? null,
    decidedAt: instance.decidedAt,
    decisionComment: instance.decisionComment,
    conditionsText: instance.conditionsText,
    lockedVersionLabel: instance.lockedVersionId ? `submission v${instance.lockedVersionId}` : null,
    dueAt: instance.dueAt,
  }));

  const checkerIds = sub.rulesChecklist
    .map((c) => c.checked_by)
    .filter((x): x is string => Boolean(x));
  const checkers = checkerIds.length
    ? await db.select().from(users).where(inArray(users.id, checkerIds))
    : [];
  const checkerName = (id: string | null) => checkers.find((u) => u.id === id)?.fullName ?? null;

  const ruleById = new Map(rules.map((r) => [r.id, r]));
  const checklistItems = sub.rulesChecklist
    .map((entry) => {
      const rule = ruleById.get(entry.rule_id);
      if (!rule) return null;
      return {
        ruleId: entry.rule_id,
        title: rule.title,
        ruleText: rule.ruleText,
        checked: entry.checked,
        checkedByName: checkerName(entry.checked_by),
        note: entry.note,
      };
    })
    .filter((x): x is NonNullable<typeof x> => Boolean(x));

  const docRows: DocRow[] = await Promise.all(
    docs.map(async ({ doc, uploader }) => ({
      id: doc.id,
      docType: doc.docType,
      fileName: doc.fileName,
      status: doc.status,
      reviewNote: doc.reviewNote,
      submissionVersion: doc.submissionVersion,
      expiresAt: doc.expiresAt,
      expiryFlag: Boolean(doc.expiresAt && doc.expiresAt < bundle.edition.buildEnd),
      uploaderName: uploader?.fullName ?? uploader?.email ?? null,
      createdAt: doc.createdAt.toISOString(),
      downloadUrl: doc.filePath.startsWith("seed/")
        ? null
        : await getDownloadUrl("documents", doc.filePath).catch(() => null),
    })),
  );

  return (
    <div className="flex flex-col gap-6 p-4 sm:p-6">
      <div className="flex flex-wrap items-center gap-3">
        <div>
          <p className="text-muted-foreground text-xs">
            <Link href={`/${editionCode}/stands`} className="hover:underline">
              Stands
            </Link>{" "}
            / {sub.ref}
          </p>
          <h1 className="text-xl font-semibold tracking-tight">
            {bundle.exhibitor.companyName} — stand {bundle.exhibitor.standNumber}
          </h1>
          <p className="text-muted-foreground text-sm">
            {bundle.exhibitor.contactName ?? ""} {bundle.exhibitor.contactEmail ?? ""} · submission
            v{sub.submissionVersion}
            {sub.submittedAt ? ` · submitted ${formatDateTime(sub.submittedAt)}` : ""}
          </p>
        </div>
        <StatusBadge status={sub.status} className="mt-1" />
        {sub.isComplex && (
          <span className="text-sm font-medium text-orange-700 dark:text-orange-400">
            Complex structure
          </span>
        )}
      </div>

      {sub.outcome && (
        <div className="rounded-lg border p-4 text-sm">
          <p className="font-medium">
            Outcome: <StatusBadge status={sub.outcome} />
          </p>
          {sub.conditionsText && (
            <p className="mt-2 text-teal-800 dark:text-teal-300">
              Conditions: {sub.conditionsText}
            </p>
          )}
          {sub.buildCheckDoneAt && (
            <p className="text-muted-foreground mt-2">
              Build check completed {formatDateTime(sub.buildCheckDoneAt)}
              {sub.buildCheckNotes ? ` — “${sub.buildCheckNotes}”` : ""}
            </p>
          )}
        </div>
      )}

      <section>
        <h2 className="mb-2 text-sm font-semibold">Structure questionnaire</h2>
        <QuestionnaireForm
          values={{
            submissionId: sub.id,
            maxHeightMm: sub.maxHeightMm,
            isDoubleDeck: sub.isDoubleDeck,
            hasPlatformOver600mm: sub.hasPlatformOver600mm,
            hasRampedRaisedFloor: sub.hasRampedRaisedFloor,
            hasRigging: sub.hasRigging,
            hasCeilingOrRoof: sub.hasCeilingOrRoof,
            hasTieredSeating: sub.hasTieredSeating,
            otherComplexNotes: sub.otherComplexNotes,
            isComplex: sub.isComplex,
          }}
          readOnly={!canReview}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Documents</h2>
        <DocumentsPanel
          submissionId={sub.id}
          requiredTypes={bundle.edition.standRequiredDocTypes}
          documents={docRows}
          canUpload={canReview}
          canReview={canReview}
          currentVersion={sub.submissionVersion}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Venue rules checklist</h2>
        <RulesChecklist submissionId={sub.id} items={checklistItems} canTick={canReview} />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Approval chain</h2>
        {chain.length === 0 ? (
          <p className="text-muted-foreground text-sm">Not yet submitted.</p>
        ) : (
          <ApprovalChain
            instances={chain}
            currentRun={sub.currentRunNumber}
            canDecideIds={canDecideIds}
            canDelegateIds={canDelegateIds}
            currentVersionId={String(sub.submissionVersion)}
            requiresInstallPhoto={false}
            delegatableUsers={[]}
          />
        )}
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Comments</h2>
        <CommentThread
          entityType="stand_submission"
          entityId={sub.id}
          comments={comments.map(({ comment, author }) => ({
            id: comment.id,
            body: comment.body,
            isInternal: comment.isInternal,
            authorName: author.fullName || author.email,
            createdAt: comment.createdAt.toISOString(),
          }))}
          canWriteInternal={can(session.actor, { type: "comment.internal.write" })}
          canWriteExternal={can(session.actor, { type: "comment.external.write", entity: ctx })}
          isStaff
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">History</h2>
        <ol className="max-w-3xl space-y-2 text-sm">
          {audit.map(({ entry, actor }) => (
            <li key={entry.id} className="flex gap-3 rounded-lg border p-3">
              <span className="text-muted-foreground w-40 shrink-0 text-xs">
                {formatDateTime(entry.createdAt)}
              </span>
              <div>
                <p>{entry.summary}</p>
                <p className="text-muted-foreground text-xs">
                  {actor?.fullName || actor?.email || "System"}
                </p>
              </div>
            </li>
          ))}
        </ol>
      </section>
    </div>
  );
}
