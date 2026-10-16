import Link from "next/link";
import { notFound } from "next/navigation";
import { inArray } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { users } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, type ApprovalStepCtx } from "@/lib/authz";
import { loadStandBundle, standAuthzCtx } from "@/lib/domain/stand";
import { departmentNames } from "@/lib/domain/departments";
import { editionIsReadOnly } from "@/lib/edition-lock";
import {
  getStandByRef,
  getStandDocuments,
  getStandInstances,
  getVenueRulesById,
} from "@/lib/queries/stands";
import { getEntityAudit, getEntityComments } from "@/lib/queries/signage";
import { getDownloadUrl } from "@/lib/storage";
import { formatDate, formatDateTime, roleLabel } from "@/lib/format";
import { cn } from "@/lib/utils";
import { Page } from "@/components/page-header";
import { StatusBadge } from "@/components/status-badge";
import { ApprovalChain, type ChainInstance } from "@/components/approvals/chain";
import { DecideButtons } from "@/components/approvals/decide-buttons";
import { CommentThread } from "@/components/comments/thread";
import { DocumentsPanel, type DocRow } from "@/components/stands/documents-panel";
import { QuestionnaireAnswers } from "@/components/stands/questionnaire-form";
import { RulesChecklist } from "@/components/stands/checklist";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ editionCode: string; ref: string }>;
}) {
  const { ref } = await params;
  return { title: `${decodeURIComponent(ref)} · Exhibitor stands` };
}

const TABS = [
  { id: "overview", label: "Overview" },
  { id: "documents", label: "Documents" },
  { id: "rules", label: "Venue rules" },
  { id: "signoff", label: "Sign-off" },
  { id: "comments", label: "Comments" },
  { id: "history", label: "History" },
] as const;
type TabId = (typeof TABS)[number]["id"];

/**
 * An exhibitor's stand submission: the reviewer's decision first, then the
 * submission in tabs like an item page — overview (the questionnaire's
 * answers), documents, the venue's rules, sign-off, comments, history.
 */
export default async function StandDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ editionCode: string; ref: string }>;
  searchParams: Promise<{ tab?: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode, ref } = await params;
  const { tab: rawTab } = await searchParams;
  const tab: TabId = TABS.some((t) => t.id === rawTab) ? (rawTab as TabId) : "overview";
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

  const readOnly = editionIsReadOnly(bundle.edition.status);
  const ctx = standAuthzCtx(bundle);
  const canReview = can(session.actor, { type: "stand.review" }) && !readOnly;
  const deptNames = await departmentNames(
    db,
    instanceRows.map((r) => r.instance.assignedDepartmentId),
  );

  const canDecideIds = new Set<string>();
  const canDelegateIds = new Set<string>();
  for (const { instance } of instanceRows) {
    if (readOnly) break;
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
    assignedDepartmentName: instance.assignedDepartmentId
      ? (deptNames.get(instance.assignedDepartmentId) ?? null)
      : null,
    assignedUserId: instance.assignedUserId,
    deciderName: decider?.fullName ?? decider?.email ?? null,
    decidedAt: instance.decidedAt,
    decisionComment: instance.decisionComment,
    conditionsText: instance.conditionsText,
    lockedVersionLabel: instance.lockedVersionId ? `submission v${instance.lockedVersionId}` : null,
    dueAt: instance.dueAt,
  }));
  // The viewer's own decisions go at the top; the chain doesn't repeat them.
  const myDecisions = chain.filter((c) => canDecideIds.has(c.id));
  // Everyone else this round is waiting on, for the overview.
  const waitingOn = chain
    .filter(
      (c) =>
        c.status === "pending" && c.runNumber === sub.currentRunNumber && !canDecideIds.has(c.id),
    )
    .map((c) => `${c.stepName} (${c.assignedDepartmentName ?? roleLabel(c.assignedRole)})`);
  const now = new Date();

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
  const rulesTicked = checklistItems.filter((c) => c.checked).length;

  const docRows: DocRow[] =
    tab === "documents"
      ? await Promise.all(
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
        )
      : [];

  const label = (id: TabId, text: string) => {
    const n =
      id === "documents"
        ? docs.length
        : id === "comments"
          ? comments.length
          : id === "rules" && checklistItems.length
            ? `${rulesTicked}/${checklistItems.length}`
            : null;
    return n ? `${text} (${n})` : text;
  };

  return (
    <Page width="default" className="gap-4">
      <header className="flex flex-col gap-1">
        <nav aria-label="Breadcrumb" className="text-muted-foreground text-xs">
          <Link href={`/${editionCode}/stands`} className="hover:underline">
            Exhibitor stands
          </Link>{" "}
          / {sub.ref}
        </nav>
        <div className="flex flex-wrap items-center gap-2">
          <h1 className="text-xl font-semibold tracking-tight">
            {bundle.exhibitor.companyName} — stand {bundle.exhibitor.standNumber}
          </h1>
          <StatusBadge status={sub.status} />
          {sub.isComplex && (
            <span className="text-sm font-medium text-orange-700 dark:text-orange-400">
              Complex structure
            </span>
          )}
        </div>
        <p className="text-muted-foreground text-sm">
          {[bundle.exhibitor.contactName, bundle.exhibitor.contactEmail].filter(Boolean).join(" ")}
          {" · "}submission v{sub.submissionVersion}
          {sub.submittedAt ? ` · submitted ${formatDateTime(sub.submittedAt)}` : ""}
        </p>
      </header>

      {readOnly && (
        <p className="text-muted-foreground text-sm">
          This event is archived, so its stands can no longer be changed.
        </p>
      )}

      {myDecisions.map((d) => {
        const overdue = d.dueAt && d.dueAt.getTime() < now.getTime();
        return (
          <section
            key={d.id}
            aria-label={`Your decision: ${d.stepName}`}
            className="rounded-lg border border-sky-300 bg-sky-50/60 p-4 dark:border-sky-800 dark:bg-sky-950/30"
          >
            <p className="font-semibold">Your decision — {d.stepName}</p>
            <p className="text-muted-foreground mb-3 text-sm">
              On submission v{sub.submissionVersion}: check its{" "}
              <Link href="?tab=documents" className="link">
                documents
              </Link>{" "}
              and{" "}
              <Link href="?tab=rules" className="link">
                the venue&apos;s rules
              </Link>{" "}
              first.
              {d.dueAt && (
                <span className={overdue ? "text-destructive font-medium" : undefined}>
                  {" "}
                  {overdue ? "Overdue since" : "Due"} {formatDate(d.dueAt)}.
                </span>
              )}
            </p>
            <DecideButtons
              instanceId={d.id}
              stepKind={d.stepKind}
              stepName={d.stepName}
              expectedStatus="pending"
              expectedLockedVersionId={String(sub.submissionVersion)}
              itemRef={sub.ref}
              itemName={`${bundle.exhibitor.companyName} — stand ${bundle.exhibitor.standNumber}`}
            />
          </section>
        );
      })}

      <nav className="flex gap-1 overflow-x-auto border-b" aria-label="Submission sections">
        {TABS.map((t) => (
          <Link
            key={t.id}
            href={`/${editionCode}/stands/${sub.ref}${t.id === "overview" ? "" : `?tab=${t.id}`}`}
            className={cn(
              "inline-flex min-h-11 items-center px-3 text-sm whitespace-nowrap sm:min-h-9",
              tab === t.id
                ? "border-primary text-foreground border-b-2 font-medium"
                : "text-muted-foreground hover:text-foreground",
            )}
            aria-current={tab === t.id ? "page" : undefined}
          >
            {label(t.id, t.label)}
          </Link>
        ))}
      </nav>

      {tab === "overview" && (
        <div className="grid gap-4">
          {waitingOn.length > 0 && (
            <p className="bg-muted/50 rounded-lg px-4 py-3 text-sm">
              <span className="text-muted-foreground">Waiting on: </span>
              {waitingOn.join(", ")} ·{" "}
              <Link href={`/${editionCode}/stands/${sub.ref}?tab=signoff`} className="link">
                see the sign-off
              </Link>
            </p>
          )}
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
          <section className="rounded-lg border p-4" aria-labelledby="questionnaire-heading">
            <h2 id="questionnaire-heading" className="mb-3 text-sm font-semibold">
              Structure questionnaire
            </h2>
            <QuestionnaireAnswers
              canEdit={canReview}
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
            />
          </section>
        </div>
      )}

      {tab === "documents" && (
        <DocumentsPanel
          submissionId={sub.id}
          requiredTypes={bundle.edition.standRequiredDocTypes}
          documents={docRows}
          canUpload={canReview}
          canReview={canReview}
          currentVersion={sub.submissionVersion}
        />
      )}

      {tab === "rules" && (
        <RulesChecklist
          submissionId={sub.id}
          items={checklistItems}
          canTick={canReview}
          submitted={sub.status !== "not_submitted"}
        />
      )}

      {tab === "signoff" &&
        (chain.length === 0 ? (
          <p className="text-muted-foreground text-sm">
            Not submitted yet — sign-off starts when the exhibitor submits their design.
          </p>
        ) : (
          <ApprovalChain
            instances={chain}
            currentRun={sub.currentRunNumber}
            canDecideIds={
              new Set([...canDecideIds].filter((id) => !myDecisions.some((d) => d.id === id)))
            }
            canDelegateIds={canDelegateIds}
            currentVersionId={String(sub.submissionVersion)}
            requiresInstallPhoto={false}
            delegatableUsers={[]}
          />
        ))}

      {tab === "comments" && (
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
      )}

      {tab === "history" && (
        <ol className="max-w-3xl space-y-2 text-sm" aria-label="History">
          {audit.length === 0 && (
            <li className="text-muted-foreground rounded-lg border border-dashed px-4 py-6 text-center">
              No changes recorded yet.
            </li>
          )}
          {audit.map(({ entry, actor }) => (
            <li
              key={entry.id}
              className="flex flex-col gap-1 rounded-lg border p-3 sm:flex-row sm:gap-3"
            >
              <span className="text-muted-foreground shrink-0 text-xs sm:w-40">
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
      )}
    </Page>
  );
}
