import Link from "next/link";
import { notFound } from "next/navigation";
import { and, count, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { comments as commentsTable, memberships, signageItems, users } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, type ApprovalStepCtx } from "@/lib/authz";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
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
import { itemFormOptions } from "@/lib/queries/item-form-options";
import { blobEnabled, directUploadMode, getDownloadUrl, getInlineUrl } from "@/lib/storage";
import { formatDate, formatDateTime, formatMoney, statusLabel } from "@/lib/format";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { APPROVED_OR_LATER } from "@/lib/status/signage";
import { StatusBadge } from "@/components/status-badge";
import { ApprovalChain, type ChainInstance } from "@/components/approvals/chain";
import { ArtworkTab, type VersionRow } from "@/components/signage/artwork-tab";
import { CommentThread } from "@/components/comments/thread";
import { ItemForm } from "@/components/signage/item-form";
import { PhotoUploader } from "@/components/sponsorship/photo-uploader";
import { orderCountdown } from "@/lib/countdown";
import { todayInLondon } from "@/lib/today";
import { LifecycleButtons } from "@/components/signage/lifecycle-buttons";
import { SnagsPanel, type SnagView } from "@/components/signage/snags-panel";
import { QuickComment } from "@/components/signage/quick-comment";
import { ITEM_SECTION } from "@/lib/edition-path";
import { PANEL_BLOCKED_MESSAGE, artworkBlockedReason } from "@/lib/artwork-rules";
import { listStandPanels, standFormOptions } from "@/lib/queries/stand-designs";
import { StandForm } from "@/components/stand-designs/stand-form";
import { AddPanelButton } from "@/components/stand-designs/add-panel";

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

export default async function ItemDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ editionCode: string; ref: string }>;
  searchParams: Promise<{ tab?: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode, ref } = await params;
  const { tab: rawTab } = await searchParams;

  const item = await getItemByRef(decodeURIComponent(ref));
  if (!item || item.deletedAt) notFound();
  const bundle = await loadItemBundle(db, item.id, { organisationId: session.organisation.id });
  // Only this organisation's items, and only under their own show's address.
  if (!bundle || bundle.edition.code !== editionCode.toUpperCase()) notFound();
  const isSponsorship = item.kind === "sponsorship_item";
  const isStand = item.kind === "stand_design";
  const isPanel = item.kind === "stand_panel";
  const tabs = isStand ? STAND_TABS : isPanel ? PANEL_TABS : TABS;
  const tab = resolveTab(rawTab, tabs);
  // A panel belongs to a stand: link back to it.
  const parent =
    isPanel && item.parentItemId
      ? await db
          .select({ ref: signageItems.ref, name: signageItems.name, status: signageItems.status })
          .from(signageItems)
          .where(eq(signageItems.id, item.parentItemId))
          .then((r) => r[0] ?? null)
      : null;
  const listSegment = ITEM_SECTION[isPanel ? "stand_design" : item.kind];
  const listLabel = isSponsorship
    ? "Sponsorship"
    : isStand || isPanel
      ? "Stand designs"
      : "Signage";
  const listHref = parent
    ? `/${editionCode}/stand-designs/${parent.ref}?tab=panels`
    : `/${editionCode}/${listSegment}`;

  const itemCtx = itemAuthzCtx(bundle);
  const canSeeCosts = can(session.actor, { type: "costs.view" });
  const canEditCosts = can(session.actor, { type: "costs.edit" });
  const canEdit =
    can(session.actor, { type: "signage.edit", item: itemCtx }) &&
    !editionIsReadOnly(bundle.edition.status);
  const requiresInstallPhoto =
    !isSponsorship && !isStand && session.organisation.settings.install_photo_required;

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <div className="flex flex-wrap items-center gap-3">
        <div className="min-w-0">
          <p className="text-muted-foreground text-xs">
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
          </p>
          <h1 className="text-xl font-semibold tracking-tight">{item.name}</h1>
        </div>
        <StatusBadge status={item.status} className="mt-1" />
        {item.status === "on_hold" && item.onHoldReason && (
          <span className="text-muted-foreground text-sm">({item.onHoldReason})</span>
        )}
        <div className="ml-auto">
          <LifecycleButtons
            itemId={item.id}
            status={item.status}
            canSubmit={can(session.actor, { type: "signage.submit", item: itemCtx })}
            canHold={can(session.actor, { type: "signage.hold" })}
            canClose={can(session.actor, { type: "signage.close" })}
            canDelete={can(session.actor, { type: "signage.delete" })}
            listHref={listHref}
          />
        </div>
      </div>

      <nav className="flex gap-1 overflow-x-auto border-b" aria-label="Item sections">
        {tabs.map((t) => (
          <Link
            key={t.id}
            href={`?tab=${t.id}`}
            className={`px-3 py-2 text-sm whitespace-nowrap ${
              tab === t.id
                ? "border-primary text-foreground border-b-2 font-medium"
                : "text-muted-foreground hover:text-foreground"
            }`}
            aria-current={tab === t.id ? "page" : undefined}
          >
            {t.label}
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
          canManageSnags={can(session.actor, { type: "snag.manage" })}
        />
      )}
      {tab === "artwork" && (
        <ArtworkAndSignOff
          item={item}
          bundle={bundle}
          session={session}
          requiresInstallPhoto={requiresInstallPhoto}
          parentStatus={parent?.status ?? null}
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
            APPROVED_OR_LATER.includes(item.status)
          }
        />
      )}
      {tab === "comments" && <CommentsSection itemId={item.id} session={session} />}
      {tab === "history" && <HistorySection itemId={item.id} />}
    </div>
  );
}

type Item = NonNullable<Awaited<ReturnType<typeof getItemByRef>>>;
type Bundle = NonNullable<Awaited<ReturnType<typeof loadItemBundle>>>;
type StaffSession = Awaited<ReturnType<typeof requireStaffSession>>;

async function DetailsTab({
  item,
  bundle,
  editionCode,
  canEdit,
  canSeeCosts,
  canEditCosts,
  canCertificate,
  canManageSnags,
}: {
  item: Item;
  bundle: Bundle;
  editionCode: string;
  canEdit: boolean;
  canSeeCosts: boolean;
  canEditCosts: boolean;
  canCertificate: boolean;
  canManageSnags: boolean;
}) {
  const isSponsorship = item.kind === "sponsorship_item";
  const [options, snags, photoUrl, productPhotoUrl] = await Promise.all([
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
  ]);
  const readOnly = editionIsReadOnly(bundle.edition.status);
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
  const sold = Boolean(item.sponsorId);
  const countdown = item.orderByDate
    ? orderCountdown(item.orderByDate, todayInLondon(), sold)
    : null;
  const profit =
    sold && item.salePrice != null && item.costEstimate != null
      ? Number(item.salePrice) - Number(item.costEstimate)
      : null;
  // The few facts each team needs at a glance; everything else is in the form.
  const facts: [string, React.ReactNode][] = isSponsorship
    ? [
        ["Status", sold ? "Sold" : "Available"],
        ["Sponsor", nameOf(options.sponsors, item.sponsorId) ?? "—"],
        ["Type", nameOf(options.itemTypes, item.itemTypeId) ?? "—"],
        ["Quantity", item.quantity.toLocaleString("en-GB")],
        ["Supplier", nameOf(options.suppliers, item.supplierId) ?? "—"],
        ["Cost price", formatMoney(item.costEstimate)],
        ...(sold
          ? ([
              ["Sale price", formatMoney(item.salePrice)],
              ["Profit", profit != null ? formatMoney(profit) : "—"],
            ] as [string, React.ReactNode][])
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
            "—"
          ),
        ],
      ]
    : [
        [
          "Where",
          [nameOf(options.halls, item.hallId), nameOf(options.locations, item.locationId)]
            .filter(Boolean)
            .join(" · ") || "—",
        ],
        ["Stand no.", item.standNumber || "—"],
        [
          "Size",
          item.widthMm && item.heightMm
            ? `${item.widthMm} × ${item.heightMm} mm${item.quantity > 1 ? ` · ${item.quantity} off` : ""}`
            : "—",
        ],
        ["Fixing", item.fixingMethod ? statusLabel(item.fixingMethod) : "—"],
        ["Type", nameOf(options.itemTypes, item.itemTypeId) ?? "—"],
        ...(item.category === "sponsor"
          ? ([["Sponsor", nameOf(options.sponsors, item.sponsorId) ?? "—"]] as [
              string,
              React.ReactNode,
            ][])
          : []),
        ["Supplier", nameOf(options.suppliers, item.supplierId) ?? "—"],
        ["Cost price", formatMoney(item.costEstimate)],
        ["Install", item.installDate ? formatDate(item.installDate) : "—"],
      ];

  return (
    <div className="grid gap-6">
      <section
        className={`grid max-w-4xl gap-4 rounded-lg border p-4 text-sm ${
          isSponsorship ? "sm:grid-cols-[14rem_1fr]" : ""
        }`}
        aria-label="At a glance"
      >
        {isSponsorship && (
          <PhotoUploader
            itemId={item.id}
            photoUrl={productPhotoUrl}
            alt={item.name}
            canEdit={canEdit}
          />
        )}
        <div className="flex flex-col gap-3">
          <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 sm:grid-cols-[auto_1fr_auto_1fr]">
            {facts.map(([label, value]) => (
              <div key={label} className="contents">
                <dt className="text-muted-foreground">{label}</dt>
                <dd className="font-medium">{value}</dd>
              </div>
            ))}
          </dl>
          <div className="flex flex-wrap gap-x-4 gap-y-1 border-t pt-2">
            <a
              className="text-primary hover:underline"
              href={`/api/exports/spec-label/${item.ref}`}
            >
              Spec label (PDF)
            </a>
            {canCertificate &&
              (APPROVED_OR_LATER.includes(item.status) ? (
                <a
                  className="text-primary hover:underline"
                  href={`/api/exports/certificate/${item.ref}`}
                >
                  Approval certificate (PDF)
                </a>
              ) : (
                <span className="text-muted-foreground">Approval certificate: once signed off</span>
              ))}
          </div>
          {!isSponsorship && (
            <p>
              <span className="text-muted-foreground">Installed: </span>
              {item.installedAt ? formatDateTime(item.installedAt) : "Not yet"}
              {photoUrl ? (
                <>
                  {" · "}
                  <a
                    className="text-primary hover:underline"
                    href={photoUrl}
                    target="_blank"
                    rel="noreferrer"
                  >
                    View photo
                  </a>
                </>
              ) : item.installPhotoPath ? (
                " · photo on file"
              ) : null}
            </p>
          )}
          {!isSponsorship && (
            <SnagsPanel
              itemId={item.id}
              itemRef={item.ref}
              snags={snagViews}
              canManage={canManageSnags && !readOnly}
              canRaise={["installed", "snagged"].includes(item.status)}
            />
          )}
        </div>
      </section>

      {!canEdit && (
        <p className="text-muted-foreground text-sm">
          {editionIsReadOnly(bundle.edition.status)
            ? "This show is archived, so its items can no longer be changed."
            : "You can view this item but not change it."}
        </p>
      )}
      <ItemForm
        mode="edit"
        kind={formKind(item.kind)}
        status={item.status}
        readOnly={!canEdit}
        values={{
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
          salePrice: item.salePrice,
          deliveryDate: item.deliveryDate,
          installDate: item.installDate,
          installSlot: item.installSlot,
          installContractorId: item.installContractorId,
        }}
        options={options}
        canSeeCosts={canSeeCosts}
        canEditCosts={canEditCosts}
        editionCode={editionCode}
      />
    </div>
  );
}

async function ArtworkAndSignOff({
  item,
  bundle,
  session,
  requiresInstallPhoto,
  parentStatus,
}: {
  item: Item;
  bundle: Bundle;
  session: StaffSession;
  requiresInstallPhoto: boolean;
  parentStatus: string | null;
}) {
  const itemCtx = itemAuthzCtx(bundle);
  const [versions, instanceRows, invalidation, staffRows, [comments]] = await Promise.all([
    getItemVersions(item.id),
    getItemInstances(item.id),
    artworkInvalidationPreview(item.id),
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
    db
      .select({ n: count() })
      .from(commentsTable)
      .where(
        and(eq(commentsTable.entityType, "signage_item"), eq(commentsTable.entityId, item.id)),
      ),
  ]);
  const commentCount = Number(comments?.n ?? 0);

  const canDecideIds = new Set<string>();
  const canDelegateIds = new Set<string>();
  for (const { instance } of instanceRows) {
    if (instance.status !== "pending" || instance.runNumber !== item.currentRunNumber) continue;
    const step: ApprovalStepCtx = {
      assignedRole: instance.assignedRole,
      assignedDepartmentId: instance.assignedDepartmentId,
      stepKind: instance.stepKindSnapshot,
      assignedUserId: instance.assignedUserId,
      entity: { type: "signage_item", item: itemCtx },
    };
    if (can(session.actor, { type: "approval.decide", step })) canDecideIds.add(instance.id);
    if (can(session.actor, { type: "approval.delegate", step })) canDelegateIds.add(instance.id);
  }

  const versionById = new Map(versions.map((v) => [v.version.id, v.version.versionNumber]));
  const nameById = new Map(staffRows.map((u) => [u.id, u.fullName || u.email]));
  const deptNames = await departmentNames(
    db,
    instanceRows.map((r) => r.instance.assignedDepartmentId),
  );
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

  const versionRows: VersionRow[] = await Promise.all(
    versions.map(async ({ version, uploader }) => {
      const sample = version.filePath.startsWith("seed/");
      const [downloadUrl, previewUrl] = await Promise.all([
        sample ? null : getDownloadUrl("artwork", version.filePath).catch(() => null),
        version.previewPath
          ? getInlineUrl("artwork", version.previewPath).catch(() => null)
          : version.mimeType === "application/pdf" && !sample
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

  const uploadBlocked = ["installed", "snagged", "closed"].includes(item.status)
    ? "This item is installed — an admin or ops user must reopen it before new artwork can be uploaded."
    : item.kind === "stand_panel" && artworkBlockedReason(item.status, { parentStatus })
      ? `${PANEL_BLOCKED_MESSAGE}.`
      : null;

  return (
    <div className="grid gap-8">
      <ArtworkTab
        itemId={item.id}
        versions={versionRows}
        canUpload={can(session.actor, { type: "artwork.upload", item: itemCtx })}
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
      />
      <section className="space-y-3">
        <h2 className="text-sm font-semibold">Sign-off</h2>
        {chain.length === 0 ? (
          <p className="text-muted-foreground text-sm">
            {item.kind === "stand_design"
              ? "Not sent for sign-off yet — upload the design, then use Submit for review."
              : "Not sent for sign-off yet — add artwork, then use Submit for review."}
          </p>
        ) : (
          <ApprovalChain
            instances={chain}
            currentRun={item.currentRunNumber}
            canDecideIds={canDecideIds}
            canDelegateIds={canDelegateIds}
            currentVersionId={item.currentArtworkVersionId}
            requiresInstallPhoto={requiresInstallPhoto}
            delegatableUsers={staffRows
              .filter((u) => u.role !== "viewer")
              .map((u) => ({ id: u.id, name: u.fullName || u.email }))}
          />
        )}
      </section>
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

async function HistorySection({ itemId }: { itemId: string }) {
  const audit = await getEntityAudit("signage_item", itemId);
  return (
    <ol className="max-w-3xl space-y-2 text-sm">
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
            ? "This show is archived, so its stands can no longer be changed."
            : "You can view this stand but not change it."}
        </p>
      )}
      <StandForm
        mode="edit"
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
        />
      </div>
      {!designApproved && (
        <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:bg-amber-950 dark:text-amber-200">
          {panels.length > 0
            ? `The design has gone back for sign-off since panels were added. ${
                panelWarning({
                  approved: panels.filter((p) =>
                    ["approved", "approved_with_conditions"].includes(p.status),
                  ).length,
                  inProduction: panels.filter((p) =>
                    ["in_production", "delivered", "installed", "snagged", "closed"].includes(
                      p.status,
                    ),
                  ).length,
                }) ?? "Check the panels still fit."
              }`
            : "Panels can be added once the stand design is approved."}
        </p>
      )}
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
