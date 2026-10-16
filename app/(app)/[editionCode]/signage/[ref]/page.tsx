import Link from "next/link";
import { notFound } from "next/navigation";
import { and, count, eq, inArray, isNull } from "drizzle-orm";
import { X } from "lucide-react";
import { db } from "@/lib/db/client";
import {
  comments as commentsTable,
  contractors,
  externalGrants,
  halls,
  memberships,
  signageItems,
  snags as snagsTable,
  sponsors as sponsorsTable,
  suppliers,
  users,
} from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, type ApprovalStepCtx } from "@/lib/authz";
import {
  itemAuthzCtx,
  itemProgress,
  loadItemBundle,
  newArtworkSinceChanges,
  nextStep,
  signoffReadiness,
  signoffRequiredFields,
  specLocked,
  stepIsMine,
  stepStillDue,
  submitBlockedReason,
  type NextStepPending,
} from "@/lib/domain/signage";
import { departmentNames } from "@/lib/domain/departments";
import {
  getEntityAudit,
  getEntityComments,
  getItemByRef,
  getItemInstances,
  getItemSnags,
  getItemVersions,
  artworkInvalidationPreview,
  panelWarning,
} from "@/lib/queries/signage";
import { editionForDeadlines } from "@/lib/queries/editions";
import { itemFormOptions } from "@/lib/queries/item-form-options";
import { blobEnabled, directUploadMode, getDownloadUrl, getInlineUrl } from "@/lib/storage";
import {
  formatDate,
  formatDateTime,
  formatMoney,
  roleLabel,
  slotLabel,
  statusLabel,
} from "@/lib/format";
import { artworkDue, effectiveDeadline, printDeadline } from "@/lib/deadlines";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { APPROVED_OR_LATER } from "@/lib/status/signage";
import { todayInLondon } from "@/lib/today";
import { orderCountdown } from "@/lib/countdown";
import { cn } from "@/lib/utils";
import { Page } from "@/components/page-header";
import { StatusBadge } from "@/components/status-badge";
import { ApprovalChain, type ChainInstance } from "@/components/approvals/chain";
import { DecideButtons } from "@/components/approvals/decide-buttons";
import { ArtworkTab, type VersionRow } from "@/components/signage/artwork-tab";
import { CommentThread } from "@/components/comments/thread";
import { DetailsEditor } from "@/components/signage/details-editor";
import { PhotoUploader } from "@/components/sponsorship/photo-uploader";
import { LifecycleButtons } from "@/components/signage/lifecycle-buttons";
import { NextStepCard } from "@/components/signage/next-step-card";
import { SnagsPanel, type SnagView } from "@/components/signage/snags-panel";
import { QuickComment } from "@/components/signage/quick-comment";
import { defaultSignoffPlan, signoffPlanSummary } from "@/components/signage/signoff-summary";
import { ITEM_SECTION } from "@/lib/edition-path";
import { PANEL_BLOCKED_MESSAGE, artworkBlockedReason, isVideoArtwork } from "@/lib/artwork-rules";
import { listStandPanels, standFormOptions } from "@/lib/queries/stand-designs";
import { StandForm } from "@/components/stand-designs/stand-form";
import { AddPanelButton } from "@/components/stand-designs/add-panel";
import { PanelDetails } from "@/components/stand-designs/panel-details";
import { AddTaskDialog } from "@/components/tasks/add-task-dialog";
import { SellButton } from "@/components/sponsorship/sell-dialog";
import {
  SPONSORSHIP_STAGE_LABELS,
  saleState,
  sponsorshipNextStep,
  sponsorshipProgress,
  sponsorshipStage,
} from "@/lib/domain/sponsorship";

export const dynamic = "force-dynamic";

/** The browser tab shows the ref and name, e.g. "SIG-BIRM27-001 · Main entrance arch banner". */
export async function generateMetadata({
  params,
}: {
  params: Promise<{ editionCode: string; ref: string }>;
}) {
  const { ref } = await params;
  const item = await getItemByRef(decodeURIComponent(ref));
  return { title: item ? `${item.ref} · ${item.name}` : "Not found" };
}

type TabId = "details" | "artwork" | "panels" | "comments" | "history";
type Tab = { id: TabId; label: string };

const TABS: Tab[] = [
  { id: "details", label: "Details" },
  { id: "artwork", label: "Artwork & sign-off" },
  { id: "comments", label: "Comments" },
  { id: "history", label: "History" },
];

/** A designed stand: its design goes for sign-off, then its panels. */
const STAND_TABS: Tab[] = [
  { id: "details", label: "Stand" },
  { id: "artwork", label: "Design & sign-off" },
  { id: "panels", label: "Panels" },
  { id: "comments", label: "Comments" },
  { id: "history", label: "History" },
];

const PANEL_TABS: Tab[] = TABS.map((t) =>
  t.id === "artwork" ? { ...t, label: "Graphic & sign-off" } : t,
);

// Older links (notifications, bookmarks) use the previous tab names.
const TAB_ALIASES: Record<string, TabId> = {
  approvals: "artwork",
  production: "details",
  install: "details",
};

function resolveTab(raw: string | undefined, tabs: Tab[]): TabId {
  if (!raw) return "details";
  if (tabs.some((t) => t.id === raw)) return raw as TabId;
  const alias = TAB_ALIASES[raw];
  return alias && tabs.some((t) => t.id === alias) ? alias : "details";
}

type Item = NonNullable<Awaited<ReturnType<typeof getItemByRef>>>;
type Bundle = NonNullable<Awaited<ReturnType<typeof loadItemBundle>>>;
type StaffSession = Awaited<ReturnType<typeof requireStaffSession>>;
type InstanceRows = Awaited<ReturnType<typeof getItemInstances>>;
type StaffRow = { id: string; fullName: string | null; email: string; role: string };
type Deadlines = Awaited<ReturnType<typeof editionForDeadlines>>;

export default async function ItemDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ editionCode: string; ref: string }>;
  searchParams: Promise<{ tab?: string; compare?: string; created?: string; edit?: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode, ref } = await params;
  const sp = await searchParams;

  const item = await getItemByRef(decodeURIComponent(ref));
  if (!item || item.deletedAt) notFound();
  const bundle = await loadItemBundle(db, item.id, { organisationId: session.organisation.id });
  // Only this organisation's items, and only under their own event's address.
  if (!bundle || bundle.edition.code !== editionCode.toUpperCase()) notFound();
  const isSponsorship = item.kind === "sponsorship_item";
  const isStand = item.kind === "stand_design";
  const isPanel = item.kind === "stand_panel";
  const tabs = isStand ? STAND_TABS : isPanel ? PANEL_TABS : TABS;
  const tab = resolveTab(sp.tab, tabs);

  const [parent, instanceRows, staffRows, deadlines, [openSnagCount], supplier] = await Promise.all(
    [
      // A panel belongs to a stand: link back to it.
      isPanel && item.parentItemId
        ? db
            .select({
              ref: signageItems.ref,
              name: signageItems.name,
              status: signageItems.status,
              standNumber: signageItems.standNumber,
              hallName: halls.name,
            })
            .from(signageItems)
            .leftJoin(halls, eq(signageItems.hallId, halls.id))
            .where(eq(signageItems.id, item.parentItemId))
            .then((r) => r[0] ?? null)
        : null,
      getItemInstances(item.id),
      // Everyone on the team (names on the sign-off list); sign-offs can be
      // handed to anyone except viewers.
      db
        .select({
          id: users.id,
          fullName: users.fullName,
          email: users.email,
          role: memberships.role,
        })
        .from(memberships)
        .innerJoin(users, eq(memberships.userId, users.id))
        .where(eq(memberships.organisationId, session.organisation.id)),
      editionForDeadlines(bundle.edition.id),
      db
        .select({ n: count() })
        .from(snagsTable)
        .where(
          and(
            eq(snagsTable.signageItemId, item.id),
            inArray(snagsTable.status, ["open", "in_progress"]),
          ),
        ),
      item.supplierId
        ? db
            .select({ name: suppliers.name })
            .from(suppliers)
            .where(
              and(
                eq(suppliers.id, item.supplierId),
                eq(suppliers.organisationId, session.organisation.id),
              ),
            )
            .then((r) => r[0] ?? null)
        : null,
    ],
  );
  const openSnags = Number(openSnagCount?.n ?? 0);
  const listSegment = ITEM_SECTION[isPanel ? "stand_design" : item.kind];
  const listLabel = isSponsorship
    ? "Sponsorship"
    : isStand || isPanel
      ? "Feature stands"
      : "Signage";
  const listHref = parent
    ? `/${editionCode}/stand-designs/${parent.ref}?tab=panels`
    : `/${editionCode}/${listSegment}`;

  const readOnly = editionIsReadOnly(bundle.edition.status);
  const itemCtx = itemAuthzCtx(bundle);
  const canSeeCosts = can(session.actor, { type: "costs.view" });
  const canEditCosts = can(session.actor, { type: "costs.edit" });
  const canEdit = can(session.actor, { type: "signage.edit", item: itemCtx }) && !readOnly;
  // Same rule as the server and the Onsite page: photos are for signs only.
  const requiresInstallPhoto =
    item.kind === "signage" && session.organisation.settings.install_photo_required;
  const uploadBlocked = ["installed", "snagged", "closed"].includes(item.status)
    ? "This item is installed — to upload new artwork, Operations or an admin can use More → Undo install first."
    : isPanel && artworkBlockedReason(item.status, { parentStatus: parent?.status ?? null })
      ? `${PANEL_BLOCKED_MESSAGE}.`
      : null;
  const can_ = {
    edit: canEdit,
    submit: can(session.actor, { type: "signage.submit", item: itemCtx }) && !readOnly,
    upload:
      can(session.actor, { type: "artwork.upload", item: itemCtx }) && !readOnly && !uploadBlocked,
    close: can(session.actor, { type: "signage.close" }) && !readOnly,
    reopen: can(session.actor, { type: "signage.reopen" }) && !readOnly,
    resume: can(session.actor, { type: "signage.resume" }) && !readOnly,
  };

  // What happens next: the current round's waiting steps and who holds each.
  const nameById = new Map(staffRows.map((u) => [u.id, u.fullName || u.email]));
  const deptNames = await departmentNames(
    db,
    instanceRows.map((r) => r.instance.assignedDepartmentId),
  );
  const currentRun = instanceRows.filter((r) => r.instance.runNumber === item.currentRunNumber);
  const whoOf = (i: InstanceRows[number]["instance"]) =>
    (i.assignedUserId && nameById.get(i.assignedUserId)) ||
    (i.assignedDepartmentId ? (deptNames.get(i.assignedDepartmentId) ?? null) : null) ||
    (i.assignedRole === "supplier"
      ? (supplier?.name ?? "the supplier")
      : roleLabel(i.assignedRole));
  const stepCtx = (i: InstanceRows[number]["instance"]): ApprovalStepCtx => ({
    assignedRole: i.assignedRole,
    assignedDepartmentId: i.assignedDepartmentId,
    stepKind: i.stepKindSnapshot,
    assignedUserId: i.assignedUserId,
    entity: { type: "signage_item", item: itemCtx },
  });
  const pendingRows = currentRun.filter(
    (r) =>
      r.instance.status === "pending" &&
      stepStillDue(
        { stepKind: r.instance.stepKindSnapshot, stepName: r.instance.stepNameSnapshot },
        item.status,
      ),
  );
  const canDecideIds = new Set<string>();
  const canDelegateIds = new Set<string>();
  // Decisions that are the viewer's own (not an admin deciding for others).
  const myDecisionIds = new Set<string>();
  for (const { instance } of pendingRows) {
    if (readOnly) break;
    if (can(session.actor, { type: "approval.decide", step: stepCtx(instance) })) {
      canDecideIds.add(instance.id);
      if (
        instance.stepKindSnapshot === "approval" &&
        session.actor.kind === "staff" &&
        stepIsMine(
          {
            stepKind: instance.stepKindSnapshot,
            assignedRole: instance.assignedRole,
            assignedUserId: instance.assignedUserId,
            assignedDepartmentId: instance.assignedDepartmentId,
          },
          session.actor,
        )
      ) {
        myDecisionIds.add(instance.id);
      }
    }
    if (can(session.actor, { type: "approval.delegate", step: stepCtx(instance) })) {
      canDelegateIds.add(instance.id);
    }
  }
  const pending: NextStepPending[] = pendingRows.map(({ instance }) => ({
    id: instance.id,
    stepName: instance.stepNameSnapshot,
    stepKind: instance.stepKindSnapshot,
    who: whoOf(instance),
    dueAt: instance.dueAt,
    canDecide:
      instance.stepKindSnapshot === "approval"
        ? myDecisionIds.has(instance.id)
        : canDecideIds.has(instance.id),
  }));
  const latest = (status: string) =>
    currentRun
      .filter((r) => r.instance.status === status)
      .sort(
        (a, b) => (b.instance.decidedAt?.getTime() ?? 0) - (a.instance.decidedAt?.getTime() ?? 0),
      )[0];
  const requested = latest("changes_requested");
  const rejected = latest("rejected");
  const decisionOf = (row: InstanceRows[number] | undefined) =>
    row
      ? {
          stepName: row.instance.stepNameSnapshot,
          deciderName: row.decider?.fullName || row.decider?.email || null,
          comment: row.instance.decisionComment,
        }
      : null;
  const readiness = signoffReadiness(item);
  const now = new Date();
  const sharedStep = nextStep({
    kind: item.kind,
    status: item.status,
    onHoldReason: item.onHoldReason,
    readiness,
    pending,
    changeRequest: decisionOf(requested),
    rejection: decisionOf(rejected),
    newArtworkSinceChanges: newArtworkSinceChanges(
      requested?.instance.lockedVersionId ?? null,
      item.currentArtworkVersionId,
    ),
    openSnags,
    can: can_,
    now,
  });
  // Sponsorship items: sold first, then the sponsor's artwork, sign-off,
  // order and delivery — the shared step worded for selling and ordering.
  const sponsorship = isSponsorship
    ? await sponsorshipContext({
        item,
        bundle,
        session,
        canEdit,
        readOnly,
      })
    : null;
  const stage = isSponsorship
    ? sponsorshipStage({
        kind: item.kind,
        sponsorId: item.sponsorId,
        hasArtwork: readiness.hasArtwork,
        status: item.status,
        previousStatus: item.previousStatus,
      })
    : null;
  const confirmation = pending.find((p) => p.stepKind === "confirmation") ?? null;
  const sponsorStep =
    sponsorship && stage
      ? sponsorshipNextStep(sharedStep, {
          stage,
          status: item.status,
          fieldsReady: readiness.fieldsReady,
          sponsorName: sponsorship.sponsorName,
          supplierName: supplier?.name ?? null,
          orderByDate: item.orderByDate,
          today: todayInLondon(),
          confirmation: confirmation
            ? { who: confirmation.who, canDecide: confirmation.canDecide }
            : null,
          canSell: sponsorship.canSell,
          canUpload: can_.upload,
          inviteHref: sponsorship.inviteHref,
        })
      : null;
  const step = sponsorStep?.step ?? sharedStep;
  const progress = stage
    ? sponsorshipProgress(stage)
    : itemProgress(item.kind, item.status, {
        fieldsReady: readiness.fieldsReady,
        hasArtwork: readiness.hasArtwork,
        previousStatus: item.previousStatus,
      });
  // The next step's confirmation button is the one place to confirm it.
  const confirmInNextStep = step.action?.type === "confirm" ? step.action.instanceId : null;

  return (
    <Page width="default" className="gap-4">
      <header className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="min-w-0 space-y-1">
          <nav aria-label="Breadcrumb" className="text-muted-foreground text-xs">
            <Link href={`/${editionCode}/${listSegment}`} className="hover:underline">
              {listLabel}
            </Link>{" "}
            {parent && (
              <>
                /{" "}
                <Link
                  href={`/${editionCode}/stand-designs/${parent.ref}?tab=panels`}
                  className="hover:underline"
                >
                  {parent.ref} {parent.name}
                </Link>{" "}
              </>
            )}
            / {item.ref}
          </nav>
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="text-xl font-semibold tracking-tight">{item.name}</h1>
            {stage ? (
              // One status for a sponsorship item: where it is in selling and ordering.
              <StatusBadge
                status={
                  item.status === "on_hold"
                    ? "on_hold"
                    : stage === "for_sale"
                      ? "draft"
                      : item.status
                }
                label={item.status === "on_hold" ? "On hold" : SPONSORSHIP_STAGE_LABELS[stage]}
              />
            ) : (
              <StatusBadge status={item.status} />
            )}
          </div>
        </div>
        <div className="flex shrink-0 flex-wrap items-center gap-2">
          {!readOnly && (
            <AddTaskDialog
              currentUserId={session.user.id}
              assignees={staffRows.map((u) => ({ id: u.id, name: u.fullName || u.email }))}
              canAssign={can(session.actor, { type: "task.assign" })}
              entity={{
                type: "signage_item",
                id: item.id,
                editionId: bundle.edition.id,
                label: item.ref,
              }}
            />
          )}
          <LifecycleButtons
            itemId={item.id}
            itemRef={item.ref}
            status={item.status}
            canHold={can(session.actor, { type: "signage.hold" }) && !readOnly}
            canReopen={can_.reopen}
            canDelete={can(session.actor, { type: "signage.delete" }) && !readOnly}
            listHref={listHref}
          />
        </div>
      </header>

      {sp.created === "1" && (
        <div
          role="status"
          className="flex items-start justify-between gap-3 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-900 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-200"
        >
          <p>
            <span className="font-medium">{item.ref} created.</span>{" "}
            {isStand
              ? "Next: upload the design."
              : isSponsorship
                ? item.sponsorId
                  ? "Next: add a photo, then upload the sponsor's artwork."
                  : "Next: add a photo, then mark it sold when a sponsor buys it."
                : isPanel
                  ? parent && APPROVED_OR_LATER.includes(parent.status)
                    ? "Next: upload its graphic."
                    : "Its graphic can be uploaded once the stand design is approved."
                  : "Next: upload the artwork."}
          </p>
          <Link
            href={`?tab=${tab}`}
            aria-label="Dismiss"
            className="-m-1 rounded p-1 hover:bg-emerald-100 dark:hover:bg-emerald-900"
          >
            <X className="size-4" aria-hidden />
          </Link>
        </div>
      )}

      {readOnly && (
        <p className="text-muted-foreground text-sm">
          This event is archived, so its items can no longer be changed.
        </p>
      )}

      <NextStepCard
        step={step}
        progress={progress}
        lines={readiness.lines}
        itemId={item.id}
        itemRef={item.ref}
        currentVersionId={item.currentArtworkVersionId}
        requiresInstallPhoto={requiresInstallPhoto}
        canEditFields={canEdit && !isStand}
        extraAction={
          sponsorStep?.sell && sponsorship ? (
            <SellButton
              item={{
                id: item.id,
                ref: item.ref,
                name: item.name,
                costEstimate: item.costEstimate,
              }}
              sponsors={sponsorship.sponsors}
              variant={step.action ? "outline" : "default"}
            />
          ) : null
        }
      />

      <nav className="flex gap-1 overflow-x-auto border-b" aria-label="Item sections">
        {tabs.map((t) => (
          <Link
            key={t.id}
            href={`?tab=${t.id}`}
            className={`inline-flex items-center gap-1.5 px-3 py-2 text-sm whitespace-nowrap ${
              tab === t.id
                ? "border-primary text-foreground border-b-2 font-medium"
                : "text-muted-foreground hover:text-foreground"
            }`}
            aria-current={tab === t.id ? "page" : undefined}
          >
            {t.label}
            {t.id === "details" && openSnags > 0 && (
              <span className="rounded-full bg-rose-100 px-1.5 text-xs font-medium text-rose-800 tabular-nums dark:bg-rose-950 dark:text-rose-300">
                {openSnags}
                <span className="sr-only"> open snag{openSnags === 1 ? "" : "s"}</span>
              </span>
            )}
          </Link>
        ))}
      </nav>

      {tab === "details" && isStand && (
        <StandDetails item={item} bundle={bundle} editionCode={editionCode} canEdit={canEdit} />
      )}
      {tab === "details" && !isStand && (
        <DetailsTab
          item={item}
          bundle={bundle}
          editionCode={editionCode}
          canEdit={canEdit}
          canSeeCosts={canSeeCosts}
          canEditCosts={canEditCosts}
          canCertificate={can(session.actor, { type: "export.run", kind: "certificate" })}
          canManageSnags={can(session.actor, { type: "snag.manage" }) && !readOnly}
          deadlines={deadlines}
          staffRows={staffRows}
          supplierName={supplier?.name ?? null}
          waitingOn={pending.map((p) => p.who)}
          startEditing={sp.edit === "1"}
          parent={parent}
        />
      )}
      {tab === "artwork" && (
        <ArtworkAndSignOff
          item={item}
          bundle={bundle}
          session={session}
          instanceRows={instanceRows}
          staffRows={staffRows}
          deptNames={deptNames}
          canDecideIds={canDecideIds}
          canDelegateIds={canDelegateIds}
          myDecisionIds={myDecisionIds}
          hideButtonsFor={confirmInNextStep}
          requiresInstallPhoto={requiresInstallPhoto}
          uploadBlocked={uploadBlocked}
          canUpload={can_.upload || Boolean(uploadBlocked && canEdit)}
          canSendForSignoff={can_.submit}
          sendBlockedReason={item.status === "draft" ? submitBlockedReason(readiness) : null}
          changeRequest={item.status === "changes_requested" ? decisionOf(requested) : null}
          initialCompare={Number(sp.compare) || null}
          justCreated={sp.created === "1"}
          now={now}
        />
      )}
      {tab === "panels" && isStand && (
        <PanelsSection
          item={item}
          bundle={bundle}
          editionCode={editionCode}
          canAdd={
            can(session.actor, { type: "stand_design.create" }) &&
            canEdit &&
            item.status !== "closed"
          }
        />
      )}
      {tab === "comments" && <CommentsSection itemId={item.id} session={session} />}
      {tab === "history" && (
        <HistorySection
          item={item}
          creatorName={item.createdBy ? (nameById.get(item.createdBy) ?? null) : null}
        />
      )}
    </Page>
  );
}

/** A fact for the read-only details: a label and its value. */
type Fact = [string, React.ReactNode];

async function DetailsTab({
  item,
  bundle,
  editionCode,
  canEdit,
  canSeeCosts,
  canEditCosts,
  canCertificate,
  canManageSnags,
  deadlines,
  staffRows,
  supplierName,
  waitingOn,
  startEditing,
  parent,
}: {
  item: Item;
  bundle: Bundle;
  editionCode: string;
  canEdit: boolean;
  canSeeCosts: boolean;
  canEditCosts: boolean;
  canCertificate: boolean;
  canManageSnags: boolean;
  deadlines: Deadlines;
  staffRows: StaffRow[];
  supplierName: string | null;
  waitingOn: string[];
  startEditing: boolean;
  /** A panel's stand: where it is and its address. */
  parent: { ref: string; name: string; hallName: string | null; standNumber: string | null } | null;
}) {
  const isSponsorship = item.kind === "sponsorship_item";
  const isPanel = item.kind === "stand_panel";
  const [options, snags, photoUrl, productPhotoUrl, contractor] = await Promise.all([
    itemFormOptions({
      organisationId: bundle.organisation.id,
      editionId: bundle.edition.id,
      kind: formKind(item.kind),
      workflowId: item.workflowId,
      includeTypeId: item.itemTypeId,
    }),
    isSponsorship ? [] : getItemSnags(item.id),
    !isSponsorship && item.installPhotoPath?.includes("/")
      ? getInlineUrl("photos", item.installPhotoPath).catch(() => null)
      : null,
    item.photoPath ? getInlineUrl("photos", item.photoPath).catch(() => null) : null,
    item.installContractorId
      ? db
          .select({ name: contractors.name })
          .from(contractors)
          .where(eq(contractors.id, item.installContractorId))
          .then((r) => r[0]?.name ?? null)
      : null,
  ]);
  const snagViews: SnagView[] = await Promise.all(
    snags.map(async (snag) => ({
      id: snag.id,
      description: snag.description,
      severity: snag.severity,
      status: snag.status,
      photoUrl: snag.photoPath
        ? await getInlineUrl("photos", snag.photoPath).catch(() => null)
        : null,
      resolutionNote: snag.resolutionNote,
      resolutionPhotoUrl: snag.resolutionPhotoPath
        ? await getInlineUrl("photos", snag.resolutionPhotoPath).catch(() => null)
        : null,
      createdAt: snag.createdAt.toISOString(),
      resolvedAt: snag.resolvedAt?.toISOString() ?? null,
    })),
  );
  const nameOf = (list: { id: string; name: string }[], id: string | null) =>
    (id && list.find((x) => x.id === id)?.name) || null;
  const today = todayInLondon();
  const eventArtworkDue = deadlines ? effectiveDeadline(deadlines, "artwork_due") : null;
  const artworkDueDate = deadlines ? artworkDue(item, deadlines) : item.artworkDueOverride;
  const artworkLate =
    Boolean(artworkDueDate && artworkDueDate < today) &&
    !item.currentArtworkVersionId &&
    ["draft", "awaiting_artwork"].includes(item.status);
  const printBy = deadlines ? printDeadline(item, deadlines) : item.printDeadline;
  const deliveryBy =
    item.deliveryDate ?? (deadlines ? effectiveDeadline(deadlines, "delivery") : null);
  const owner = item.ownerUserId
    ? (staffRows.find((u) => u.id === item.ownerUserId)?.fullName ??
      staffRows.find((u) => u.id === item.ownerUserId)?.email ??
      null)
    : null;
  const steps = options.signoffSteps ?? [];
  const plan =
    item.signoffs ??
    defaultSignoffPlan(steps, isSponsorship ? "sponsor" : (item.category ?? "organiser"));
  const planSummary = steps.length > 0 ? signoffPlanSummary(steps, plan) : null;
  // Sponsor signage without a price of its own is part of a package, not a sale.
  const sold = saleState(item) === "sold";
  const countdown = item.orderByDate
    ? orderCountdown(item.orderByDate, todayInLondon(), Boolean(item.sponsorId))
    : null;
  const profit =
    sold && item.salePrice != null && item.costEstimate != null
      ? Number(item.salePrice) - Number(item.costEstimate)
      : null;
  const dash = <span className="text-muted-foreground font-normal">—</span>;
  const costs = (rows: Fact[]): Fact[] => (canSeeCosts ? rows : []);
  const artworkDueFact: Fact = [
    "Artwork due",
    artworkDueDate ? (
      <span className={artworkLate ? "text-destructive" : undefined}>
        {formatDate(artworkDueDate)}
        {artworkLate && " — overdue"}
      </span>
    ) : (
      dash
    ),
  ];

  // The facts each team needs at a glance; "Edit details" changes them.
  const panelFacts: Fact[] = [
    [
      "Size",
      item.widthMm && item.heightMm
        ? `${item.widthMm} × ${item.heightMm} mm${item.quantity > 1 ? ` · ${item.quantity} off` : ""}`
        : dash,
    ],
    ["Printer", supplierName ?? <span className="text-muted-foreground">Not chosen yet</span>],
    ["Owner", owner ?? dash],
    ["Waiting on", waitingOn.length ? waitingOn.join(", ") : dash],
    ["Print by", printBy ? formatDate(printBy) : dash],
    ["Delivery", deliveryBy ? formatDate(deliveryBy) : dash],
    [
      "Install",
      item.installDate
        ? `${formatDate(item.installDate)}${item.installSlot ? ` ${slotLabel(item.installSlot)}` : ""}`
        : dash,
    ],
    ...costs([["Cost price", formatMoney(item.costEstimate)]]),
  ];
  const facts: Fact[] = isPanel
    ? panelFacts
    : isSponsorship
      ? [
          [
            "Sale",
            { available: "For sale", sold: "Sold", in_package: "In the sponsor's package" }[
              saleState(item)
            ],
          ],
          ["Sponsor", nameOf(options.sponsors, item.sponsorId) ?? dash],
          ["Type", nameOf(options.itemTypes, item.itemTypeId) ?? dash],
          ["Quantity", item.quantity.toLocaleString("en-GB")],
          ["Supplier", supplierName ?? dash],
          ...costs([["Cost price", formatMoney(item.costEstimate)]]),
          ...(sold
            ? costs([
                ["Sale price", formatMoney(item.salePrice)],
                ["Profit", profit != null ? formatMoney(profit) : "—"],
              ])
            : []),
          [
            "Order by",
            item.orderByDate ? (
              <span>
                {formatDate(item.orderByDate)}
                {countdown && (
                  <span
                    className={
                      countdown.warning || countdown.tone === "overdue"
                        ? "text-destructive font-medium"
                        : "text-muted-foreground"
                    }
                  >
                    {" "}
                    — {countdown.warning ?? countdown.label}
                  </span>
                )}
              </span>
            ) : (
              dash
            ),
          ],
          artworkDueFact,
          ["Waiting on", waitingOn.length ? waitingOn.join(", ") : dash],
        ]
      : [
          [
            "Where",
            [nameOf(options.halls, item.hallId), nameOf(options.locations, item.locationId)]
              .filter(Boolean)
              .join(" · ") || dash,
          ],
          ["Stand no.", item.standNumber || dash],
          [
            "Size",
            item.widthMm && item.heightMm
              ? `${item.widthMm} × ${item.heightMm} mm${item.quantity > 1 ? ` · ${item.quantity} off` : ""}`
              : dash,
          ],
          ["Fixing", item.fixingMethod ? statusLabel(item.fixingMethod) : dash],
          ["Type", nameOf(options.itemTypes, item.itemTypeId) ?? dash],
          ...(item.category === "sponsor"
            ? ([["Sponsor", nameOf(options.sponsors, item.sponsorId) ?? dash]] as Fact[])
            : []),
          ["Owner", owner ?? dash],
          ["Waiting on", waitingOn.length ? waitingOn.join(", ") : dash],
          artworkDueFact,
          ["Print by", printBy ? formatDate(printBy) : dash],
          ["Delivery", deliveryBy ? formatDate(deliveryBy) : dash],
          [
            "Install",
            item.installDate
              ? `${formatDate(item.installDate)}${item.installSlot ? ` ${slotLabel(item.installSlot)}` : ""}`
              : dash,
          ],
          ["Supplier", supplierName ?? <span className="text-muted-foreground">Not set yet</span>],
          ...costs([["Cost price", formatMoney(item.costEstimate)]]),
        ];
  // Everything else that has been filled in.
  const extra: Fact[] = [
    ...(item.material ? ([["Material", item.material]] as Fact[]) : []),
    ...(item.finish ? ([["Finish", item.finish]] as Fact[]) : []),
    ...(item.depthMm ? ([["Depth", `${item.depthMm} mm`]] as Fact[]) : []),
    ...(item.sided === "double" ? ([["Sided", "Double"]] as Fact[]) : []),
    ...(item.weightKg ? ([["Weight", `${item.weightKg} kg`]] as Fact[]) : []),
    ...(item.requiresVenueApproval ? ([["Venue approval", "Needed"]] as Fact[]) : []),
    ...(contractor ? ([["Install contractor", contractor]] as Fact[]) : []),
    ...(item.sponsorEntitlementId
      ? ([
          [
            "Entitlement",
            options.entitlements.find((e) => e.id === item.sponsorEntitlementId)?.description ??
              dash,
          ],
        ] as Fact[])
      : []),
    ...costs([
      ...(item.costActual ? ([["Actual cost", formatMoney(item.costActual)]] as Fact[]) : []),
      ...(item.poNumber ? ([["PO number", item.poNumber]] as Fact[]) : []),
      ...(item.budgetLine ? ([["Budget line", item.budgetLine]] as Fact[]) : []),
    ]),
    ...(planSummary && !isPanel ? ([["Sign-off", planSummary]] as Fact[]) : []),
  ];
  const snagsCard = !isSponsorship &&
    (snagViews.length > 0 || ["installed", "snagged"].includes(item.status)) && (
      <SnagsPanel
        itemId={item.id}
        itemRef={item.ref}
        snags={snagViews}
        canManage={canManageSnags}
        canRaise={["installed", "snagged"].includes(item.status)}
      />
    );
  const snagsFirst = ["installed", "snagged"].includes(item.status);
  const factList = (list: Fact[]) => (
    <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 sm:grid-cols-[auto_1fr_auto_1fr]">
      {list.map(([label, value]) => (
        <div key={label} className="contents">
          <dt className="text-muted-foreground">{label}</dt>
          <dd className="min-w-0 font-medium break-words">{value}</dd>
        </div>
      ))}
    </dl>
  );

  // The facts, the same whichever form edits them.
  const glance = (
    <div className={cn("grid gap-4", isSponsorship && "sm:grid-cols-[14rem_1fr]")}>
      {isSponsorship && (
        <PhotoUploader
          itemId={item.id}
          photoUrl={productPhotoUrl}
          alt={item.name}
          canEdit={canEdit}
        />
      )}
      <div className="flex flex-col gap-3">
        {factList([...facts, ...extra])}
        {item.description && (
          <div className="border-t pt-3">
            <p className="text-muted-foreground">Notes</p>
            <p className="whitespace-pre-line">{item.description}</p>
          </div>
        )}
        {!isSponsorship && (
          <p>
            <span className="text-muted-foreground">Installed: </span>
            {item.installedAt ? formatDateTime(item.installedAt) : "Not yet"}
            {photoUrl ? (
              <>
                {" · "}
                <a className="link" href={photoUrl} target="_blank" rel="noreferrer">
                  View photo
                </a>
              </>
            ) : item.installPhotoPath ? (
              " · photo on file"
            ) : null}
          </p>
        )}
        {(!isSponsorship || canCertificate) && (
          <div className="flex flex-wrap gap-x-4 gap-y-1 border-t pt-3">
            {/* A spec label goes on a sign; sponsorship items don't have one. */}
            {!isSponsorship && (
              <a className="link" href={`/api/exports/spec-label/${item.ref}`}>
                Spec label (PDF)
              </a>
            )}
            {canCertificate &&
              (APPROVED_OR_LATER.includes(item.status) ? (
                <a className="link" href={`/api/exports/certificate/${item.ref}`}>
                  Approval certificate (PDF)
                </a>
              ) : (
                <span className="text-muted-foreground">Approval certificate: once signed off</span>
              ))}
          </div>
        )}
      </div>
    </div>
  );
  // A panel's place and sign-off come from its stand; they are changed there.
  const fromStand = isPanel && parent && (
    <p className="bg-muted/50 rounded-md px-3 py-2 text-sm">
      <span className="text-muted-foreground">From the stand: </span>
      {[
        parent.hallName,
        parent.standNumber ? `Stand ${parent.standNumber}` : null,
        planSummary ? `Signed off by ${planSummary}` : null,
      ]
        .filter(Boolean)
        .join(" · ") || parent.name}
      {" — "}
      <Link href={`/${editionCode}/stand-designs/${parent.ref}`} className="link">
        change these on the stand
      </Link>
    </p>
  );

  return (
    <div className="grid gap-4">
      {snagsFirst && snagsCard}
      {isPanel ? (
        <PanelDetails
          canEdit={canEdit}
          initialEditing={startEditing}
          lockSpec={specLocked(item.status)}
          status={item.status}
          suppliers={options.suppliers.map((sup) => ({ id: sup.id, name: sup.name }))}
          fromStand={fromStand}
          values={{
            id: item.id,
            ref: item.ref,
            name: item.name,
            widthMm: item.widthMm,
            heightMm: item.heightMm,
            quantity: item.quantity,
            supplierId: item.supplierId,
            material: item.material,
            finish: item.finish,
            description: item.description,
            installDate: item.installDate,
          }}
        >
          {glance}
        </PanelDetails>
      ) : (
        <DetailsEditor
          canEdit={canEdit}
          initialEditing={startEditing}
          formProps={{
            kind: formKind(item.kind),
            status: item.status,
            requiredFields: signoffRequiredFields(item.kind),
            lockSpec: specLocked(item.status),
            eventArtworkDue,
            values: {
              id: item.id,
              name: item.name,
              description: item.description,
              category: item.category,
              itemTypeId: item.itemTypeId,
              hallId: item.hallId,
              locationId: item.locationId,
              standNumber: item.standNumber,
              ownerRole: item.ownerRole,
              ownerUserId: item.ownerUserId,
              sponsorId: item.sponsorId,
              sponsorEntitlementId: item.sponsorEntitlementId,
              widthMm: item.widthMm,
              heightMm: item.heightMm,
              depthMm: item.depthMm,
              quantity: item.quantity,
              sided: item.sided,
              material: item.material,
              finish: item.finish,
              fixingMethod: item.fixingMethod,
              weightKg: item.weightKg,
              requiresVenueApproval: item.requiresVenueApproval,
              signoffs: item.signoffs ?? null,
              // Costs stay on the server for people who can't see them.
              budgetLine: canSeeCosts ? item.budgetLine : null,
              costEstimate: canSeeCosts ? item.costEstimate : null,
              costActual: canSeeCosts ? item.costActual : null,
              poNumber: canSeeCosts ? item.poNumber : null,
              supplierId: item.supplierId,
              artworkDueOverride: item.artworkDueOverride,
              printDeadline: item.printDeadline,
              orderByDate: item.orderByDate,
              salePrice: canSeeCosts ? item.salePrice : null,
              deliveryDate: item.deliveryDate,
              installDate: item.installDate,
              installSlot: item.installSlot,
              installContractorId: item.installContractorId,
            },
            options,
            canSeeCosts,
            canEditCosts,
            editionCode,
          }}
        >
          {glance}
        </DetailsEditor>
      )}
      {!snagsFirst && snagsCard}
      {!canEdit && (
        <p className="text-muted-foreground text-sm">
          {editionIsReadOnly(bundle.edition.status)
            ? "This event is archived, so its items can no longer be changed."
            : "You can view this item but not change it."}
        </p>
      )}
    </div>
  );
}

async function ArtworkAndSignOff({
  item,
  bundle,
  session,
  instanceRows,
  staffRows,
  deptNames,
  canDecideIds,
  canDelegateIds,
  myDecisionIds,
  hideButtonsFor,
  requiresInstallPhoto,
  uploadBlocked,
  canUpload,
  canSendForSignoff,
  sendBlockedReason,
  changeRequest,
  initialCompare,
  justCreated,
  now,
}: {
  item: Item;
  bundle: Bundle;
  session: StaffSession;
  now: Date;
  instanceRows: InstanceRows;
  staffRows: StaffRow[];
  deptNames: Map<string, string>;
  canDecideIds: Set<string>;
  canDelegateIds: Set<string>;
  myDecisionIds: Set<string>;
  /** The confirmation the next-step card already offers. */
  hideButtonsFor: string | null;
  requiresInstallPhoto: boolean;
  uploadBlocked: string | null;
  canUpload: boolean;
  canSendForSignoff: boolean;
  sendBlockedReason: string | null;
  changeRequest: { stepName: string; deciderName: string | null; comment: string | null } | null;
  initialCompare: number | null;
  justCreated: boolean;
}) {
  const [versions, invalidation, [comments]] = await Promise.all([
    getItemVersions(item.id),
    artworkInvalidationPreview(item.id),
    db
      .select({ n: count() })
      .from(commentsTable)
      .where(
        and(eq(commentsTable.entityType, "signage_item"), eq(commentsTable.entityId, item.id)),
      ),
  ]);
  const commentCount = Number(comments?.n ?? 0);

  const versionById = new Map(versions.map((v) => [v.version.id, v.version.versionNumber]));
  const nameById = new Map(staffRows.map((u) => [u.id, u.fullName || u.email]));
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
    deciderName: decider?.fullName || decider?.email || null,
    decidedAt: instance.decidedAt,
    decisionComment: instance.decisionComment,
    conditionsText: instance.conditionsText,
    lockedVersionLabel: instance.lockedVersionId
      ? `v${versionById.get(instance.lockedVersionId) ?? "?"}`
      : null,
    dueAt: instance.dueAt,
    noSupplierFallback: instance.noSupplierFallback,
    assigneeName: instance.assignedUserId ? (nameById.get(instance.assignedUserId) ?? null) : null,
    confirmedOn: instance.confirmedOn,
  }));
  // Sign-off is the decisions on the artwork; production and install are
  // the confirmations that follow (this round only).
  const signoffChain = chain.filter((c) => c.stepKind === "approval");
  const productionChain = chain.filter(
    (c) => c.stepKind === "confirmation" && c.runNumber === item.currentRunNumber,
  );
  // The viewer's own decision sits under the preview; the next step's
  // confirmation sits in the card. Neither is repeated in the chain.
  const chainDecideIds = new Set(
    [...canDecideIds].filter((id) => !myDecisionIds.has(id) && id !== hideButtonsFor),
  );
  const myDecisions = chain.filter((c) => myDecisionIds.has(c.id));

  const versionRows: VersionRow[] = await Promise.all(
    versions.map(async ({ version, uploader }) => {
      const sample = version.filePath.startsWith("seed/");
      const [downloadUrl, previewUrl] = await Promise.all([
        sample ? null : getDownloadUrl("artwork", version.filePath).catch(() => null),
        version.previewPath
          ? getInlineUrl("artwork", version.previewPath).catch(() => null)
          : (version.mimeType === "application/pdf" ||
                isVideoArtwork(version.mimeType, version.fileName)) &&
              !sample
            ? getInlineUrl("artwork", version.filePath).catch(() => null)
            : null,
      ]);
      return {
        id: version.id,
        versionNumber: version.versionNumber,
        fileName: version.fileName,
        fileSize: version.fileSize,
        sha256: version.sha256,
        proofStatus: version.proofStatus,
        notes: version.notes,
        uploaderName: uploader?.fullName || uploader?.email || null,
        createdAt: version.createdAt.toISOString(),
        downloadUrl,
        previewUrl,
        mimeType: version.mimeType,
        isCurrent: version.id === item.currentArtworkVersionId,
        sample,
      };
    }),
  );
  const delegatableUsers = staffRows
    .filter((u) => u.role !== "viewer")
    .map((u) => ({ id: u.id, name: u.fullName || u.email }));
  const noun =
    item.kind === "stand_design" ? "design" : item.kind === "stand_panel" ? "graphic" : "artwork";

  const decision =
    myDecisions.length > 0 ? (
      <div id="your-decision" className="scroll-mt-20 space-y-2">
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
                {versions.length > 0
                  ? `On v${versionById.get(item.currentArtworkVersionId ?? "") ?? versions[0].version.versionNumber}, shown above.`
                  : "No artwork uploaded yet."}
                {d.dueAt && (
                  <span className={overdue ? "text-destructive font-medium" : undefined}>
                    {" "}
                    {overdue ? "Overdue since" : "Due"} {formatDate(d.dueAt)}.
                  </span>
                )}
              </p>
              <DecideButtons
                instanceId={d.id}
                stepKind="approval"
                stepName={d.stepName}
                expectedStatus="pending"
                expectedLockedVersionId={item.currentArtworkVersionId}
              />
            </section>
          );
        })}
      </div>
    ) : null;

  return (
    <div className="grid gap-8">
      <ArtworkTab
        itemId={item.id}
        versions={versionRows}
        canUpload={canUpload}
        invalidationCount={invalidation.count}
        invalidationSteps={invalidation.steps}
        panelWarning={panelWarning(invalidation.panels)}
        uploadBlocked={uploadBlocked}
        directUpload={directUploadMode()}
        uploadPrefix={
          blobEnabled()
            ? `artwork/${bundle.organisation.id}/${bundle.edition.id}/signage_item/${item.id}/`
            : null
        }
        status={item.status}
        initialCompare={initialCompare}
        changeRequest={changeRequest}
        canSendForSignoff={canSendForSignoff}
        sendBlockedReason={sendBlockedReason}
        autoFocusUpload={justCreated}
        noun={noun}
        decision={decision}
      />
      <section className="space-y-3" aria-labelledby="signoff-heading">
        <h2 id="signoff-heading" className="text-sm font-semibold">
          Sign-off
        </h2>
        {signoffChain.length === 0 ? (
          <p className="text-muted-foreground text-sm">
            Not sent for sign-off yet — add the {noun}, then use Send for sign-off.
          </p>
        ) : (
          <ApprovalChain
            instances={signoffChain}
            currentRun={item.currentRunNumber}
            canDecideIds={chainDecideIds}
            canDelegateIds={canDelegateIds}
            currentVersionId={item.currentArtworkVersionId}
            requiresInstallPhoto={requiresInstallPhoto}
            delegatableUsers={delegatableUsers}
          />
        )}
      </section>
      {productionChain.length > 0 && (
        <section className="space-y-3" aria-labelledby="production-heading">
          <h2 id="production-heading" className="text-sm font-semibold">
            Production &amp; install
          </h2>
          <ApprovalChain
            instances={productionChain}
            currentRun={item.currentRunNumber}
            canDecideIds={chainDecideIds}
            canDelegateIds={canDelegateIds}
            currentVersionId={item.currentArtworkVersionId}
            requiresInstallPhoto={requiresInstallPhoto}
            delegatableUsers={delegatableUsers}
          />
        </section>
      )}
      {can(session.actor, { type: "comment.internal.write" }) && (
        <section className="max-w-2xl">
          <QuickComment itemId={item.id} count={commentCount} />
        </section>
      )}
    </div>
  );
}

async function CommentsSection({ itemId, session }: { itemId: string; session: StaffSession }) {
  const comments = await getEntityComments("signage_item", itemId, true);
  return (
    <CommentThread
      entityType="signage_item"
      entityId={itemId}
      comments={comments.map(({ comment, author }) => ({
        id: comment.id,
        body: comment.body,
        isInternal: comment.isInternal,
        authorName: author.fullName || author.email,
        createdAt: comment.createdAt.toISOString(),
      }))}
      canWriteInternal={can(session.actor, { type: "comment.internal.write" })}
      canWriteExternal={false}
      isStaff
    />
  );
}

/** Every change, newest first, ending with when (and by whom) it was created. */
async function HistorySection({ item, creatorName }: { item: Item; creatorName: string | null }) {
  const audit = await getEntityAudit("signage_item", item.id);
  const hasCreate = audit.some(({ entry }) => entry.action === "create");
  return (
    <div className="grid max-w-3xl gap-3">
      {audit.length === 0 && (
        <p className="text-muted-foreground rounded-lg border border-dashed px-4 py-6 text-center text-sm">
          No changes recorded yet. Edits, uploads and sign-off decisions will appear here.
        </p>
      )}
      <ol className="space-y-2 text-sm" aria-label="History">
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
        {!hasCreate && (
          <li className="text-muted-foreground flex flex-col gap-1 rounded-lg border border-dashed p-3 sm:flex-row sm:gap-3">
            <span className="shrink-0 text-xs sm:w-40">{formatDateTime(item.createdAt)}</span>
            <p>
              Created {item.ref}
              {creatorName ? ` — by ${creatorName}` : " (imported or set up before History began)"}
            </p>
          </li>
        )}
      </ol>
    </div>
  );
}

/** Panels edit like signs; everything else uses its own form. */
function formKind(kind: Item["kind"]): "signage" | "sponsorship_item" {
  return kind === "sponsorship_item" ? "sponsorship_item" : "signage";
}

async function StandDetails({
  item,
  bundle,
  editionCode,
  canEdit,
}: {
  item: Item;
  bundle: Bundle;
  editionCode: string;
  canEdit: boolean;
}) {
  const options = await standFormOptions({
    organisationId: bundle.organisation.id,
    editionId: bundle.edition.id,
    workflowId: item.workflowId,
  });
  return (
    <div className="grid gap-4">
      {!canEdit && (
        <p className="text-muted-foreground text-sm">
          {editionIsReadOnly(bundle.edition.status)
            ? "This event is archived, so its stands can no longer be changed."
            : "You can view this stand but not change it."}
        </p>
      )}
      <StandForm
        mode="edit"
        editionId={bundle.edition.id}
        editionCode={editionCode}
        status={item.status}
        readOnly={!canEdit}
        values={{
          id: item.id,
          name: item.name,
          standNumber: item.standNumber,
          hallId: item.hallId,
          locationId: item.locationId,
          widthMm: item.widthMm,
          depthMm: item.depthMm,
          heightMm: item.heightMm,
          category: item.category,
          sponsorId: item.sponsorId,
          description: item.description,
          signoffs: item.signoffs ?? null,
        }}
        options={options}
      />
    </div>
  );
}

async function PanelsSection({
  item,
  bundle,
  editionCode,
  canAdd,
}: {
  item: Item;
  bundle: Bundle;
  editionCode: string;
  canAdd: boolean;
}) {
  const [panels, options] = await Promise.all([
    listStandPanels(item.id),
    standFormOptions({
      organisationId: bundle.organisation.id,
      editionId: bundle.edition.id,
      workflowId: item.workflowId,
    }),
  ]);
  const designApproved = APPROVED_OR_LATER.includes(item.status);
  const approved = panels.filter((p) =>
    APPROVED_OR_LATER.includes(p.status as typeof item.status),
  ).length;
  return (
    <div className="grid gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-sm font-semibold">Panels</h2>
          <p className="text-muted-foreground text-xs">
            {panels.length === 0
              ? "The graphics that go on this stand."
              : `${approved} of ${panels.length} approved`}
          </p>
        </div>
        <AddPanelButton
          standId={item.id}
          editionCode={editionCode}
          enabled={canAdd}
          suppliers={options.suppliers}
          designApproved={designApproved}
        />
      </div>
      {!designApproved &&
        (() => {
          // Panels already signed off or being made while the design is back in sign-off.
          const warning = panelWarning({
            approved: panels.filter((p) =>
              ["approved", "approved_with_conditions"].includes(p.status),
            ).length,
            inProduction: panels.filter((p) =>
              ["in_production", "delivered", "installed", "snagged", "closed"].includes(p.status),
            ).length,
          });
          return warning ? (
            <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:bg-amber-950 dark:text-amber-200">
              The design has gone back for sign-off since its panels were approved. {warning}
            </p>
          ) : (
            <p className="bg-muted/50 text-muted-foreground rounded-lg px-3 py-2 text-sm">
              You can list panels now; their graphics go for sign-off once the design is approved.
            </p>
          );
        })()}
      {panels.length > 0 && (
        <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3" aria-label="Panels">
          {panels.map((p) => (
            <li key={p.id}>
              <Link
                href={`/${editionCode}/stand-panels/${p.ref}`}
                className="hover:border-primary/50 flex h-full gap-3 rounded-lg border p-3 transition-colors"
                aria-label={p.name}
              >
                <div className="bg-muted flex size-20 shrink-0 items-center justify-center overflow-hidden rounded">
                  {p.previewUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={p.previewUrl} alt="" className="size-full object-contain" />
                  ) : (
                    <span className="text-muted-foreground text-center text-[10px]">
                      {p.version ? `v${p.version}` : "No graphic"}
                    </span>
                  )}
                </div>
                <div className="flex min-w-0 flex-col gap-1">
                  <p className="truncate text-sm font-medium">{p.name}</p>
                  <p className="text-muted-foreground text-xs">
                    {[p.ref, p.size, p.quantity > 1 ? `${p.quantity} off` : null, p.supplierName]
                      .filter(Boolean)
                      .join(" · ")}
                  </p>
                  <StatusBadge status={p.status} className="w-fit" />
                  {p.waitingOn.length > 0 && (
                    <p
                      className={`text-xs ${p.waitingOn.some((w) => w.overdue) ? "text-destructive font-medium" : "text-muted-foreground"}`}
                    >
                      Next: {p.waitingOn.map((w) => w.name).join(", ")}
                    </p>
                  )}
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/** What a sponsorship item's page needs to sell it and to invite its sponsor. */
async function sponsorshipContext({
  item,
  bundle,
  session,
  canEdit,
  readOnly,
}: {
  item: Item;
  bundle: Bundle;
  session: StaffSession;
  canEdit: boolean;
  readOnly: boolean;
}) {
  const isAdmin = can(session.actor, { type: "users.manage" });
  const [sponsorRows, grants] = await Promise.all([
    db
      .select({ id: sponsorsTable.id, name: sponsorsTable.companyName })
      .from(sponsorsTable)
      .where(eq(sponsorsTable.editionId, bundle.edition.id))
      .orderBy(sponsorsTable.companyName),
    isAdmin && item.sponsorId
      ? db
          .select({ n: count() })
          .from(externalGrants)
          .where(
            and(
              eq(externalGrants.scopeType, "sponsor"),
              eq(externalGrants.scopeId, item.sponsorId),
              isNull(externalGrants.revokedAt),
            ),
          )
      : [{ n: 0 }],
  ]);
  return {
    sponsors: sponsorRows,
    sponsorName: sponsorRows.find((sp) => sp.id === item.sponsorId)?.name ?? null,
    canSell: can(session.actor, { type: "sponsorship.create" }) && canEdit,
    // Admins invite the sponsor to the portal, unless someone there already has access.
    inviteHref:
      isAdmin && !readOnly && item.sponsorId && Number(grants[0]?.n ?? 0) === 0
        ? `/users?tab=external&invite=1&role=sponsor&scopeId=${item.sponsorId}&edition=${bundle.edition.id}`
        : null,
  };
}
