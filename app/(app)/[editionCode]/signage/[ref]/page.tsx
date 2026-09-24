import Link from "next/link";
import { notFound } from "next/navigation";
import { and, count, eq, ne } from "drizzle-orm";
import { alias } from "drizzle-orm/pg-core";
import { desc as descOrder } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { changeRequests, memberships, users } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, type ApprovalStepCtx } from "@/lib/authz";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import {
  getEntityAudit,
  getEntityComments,
  getItemByRef,
  getItemInstances,
  getItemSnags,
  getItemVersions,
} from "@/lib/queries/signage";
import { itemFormOptions } from "@/lib/queries/item-form-options";
import { artworkInvalidationPreview } from "@/app/actions/artwork";
import { blobEnabled, getDownloadUrl, getInlineUrl } from "@/lib/storage";
import { formatDateTime, statusLabel } from "@/lib/format";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { APPROVED_OR_LATER } from "@/lib/status/signage";
import { StatusBadge } from "@/components/status-badge";
import { ApprovalChain, type ChainInstance } from "@/components/approvals/chain";
import { ArtworkTab, type VersionRow } from "@/components/signage/artwork-tab";
import { CommentThread } from "@/components/comments/thread";
import { ItemForm } from "@/components/signage/item-form";
import { LifecycleButtons } from "@/components/signage/lifecycle-buttons";
import { ChangesTab, type ChangeRequestRow } from "@/components/signage/changes-tab";

export const dynamic = "force-dynamic";

const TABS = [
  { id: "details", label: "Details" },
  { id: "artwork", label: "Artwork & sign-off" },
  { id: "changes", label: "Change requests" },
  { id: "comments", label: "Comments" },
  { id: "history", label: "History" },
] as const;
type TabId = (typeof TABS)[number]["id"];

// Older links (notifications, bookmarks) use the previous tab names.
const TAB_ALIASES: Record<string, TabId> = {
  approvals: "artwork",
  production: "details",
  install: "details",
};

function resolveTab(raw: string | undefined): TabId {
  if (!raw) return "details";
  if (TABS.some((t) => t.id === raw)) return raw as TabId;
  return TAB_ALIASES[raw] ?? "details";
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
  const tab = resolveTab(rawTab);

  const item = await getItemByRef(decodeURIComponent(ref));
  if (!item || item.deletedAt) notFound();
  const bundle = await loadItemBundle(db, item.id);
  if (!bundle) notFound();
  const isSponsorship = item.kind === "sponsorship_item";
  const listSegment = isSponsorship ? "sponsorship" : "signage";

  const [openChanges] = await db
    .select({ n: count() })
    .from(changeRequests)
    .where(
      and(
        eq(changeRequests.entityType, "signage_item"),
        eq(changeRequests.entityId, item.id),
        eq(changeRequests.status, "open"),
      ),
    );
  const openChangeCount = Number(openChanges?.n ?? 0);

  const itemCtx = itemAuthzCtx(bundle);
  const canSeeCosts = can(session.actor, { type: "costs.view" });
  const canEditCosts = can(session.actor, { type: "costs.edit" });
  const canEdit =
    can(session.actor, { type: "signage.edit", item: itemCtx }) &&
    !editionIsReadOnly(bundle.edition.status);
  const requiresInstallPhoto =
    !isSponsorship && session.organisation.settings.install_photo_required;

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <div className="flex flex-wrap items-center gap-3">
        <div className="min-w-0">
          <p className="text-muted-foreground text-xs">
            <Link href={`/${editionCode}/${listSegment}`} className="hover:underline">
              {isSponsorship ? "Sponsorship" : "Signage"}
            </Link>{" "}
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
            canDelete={can(session.actor, { type: "signage.delete" })}
            listHref={`/${editionCode}/${listSegment}`}
          />
        </div>
      </div>

      <nav className="flex gap-1 overflow-x-auto border-b" aria-label="Item sections">
        {TABS.map((t) => (
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
            {t.id === "changes" && openChangeCount > 0 ? ` (${openChangeCount} open)` : ""}
          </Link>
        ))}
      </nav>

      {tab === "details" && (
        <DetailsTab
          item={item}
          bundle={bundle}
          editionCode={editionCode}
          canEdit={canEdit}
          canSeeCosts={canSeeCosts}
          canEditCosts={canEditCosts}
          canCertificate={can(session.actor, { type: "export.run", kind: "certificate" })}
        />
      )}
      {tab === "artwork" && (
        <ArtworkAndSignOff
          item={item}
          bundle={bundle}
          session={session}
          requiresInstallPhoto={requiresInstallPhoto}
        />
      )}
      {tab === "changes" && <ChangesSection item={item} session={session} />}
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
}: {
  item: Item;
  bundle: Bundle;
  editionCode: string;
  canEdit: boolean;
  canSeeCosts: boolean;
  canEditCosts: boolean;
  canCertificate: boolean;
}) {
  const isSponsorship = item.kind === "sponsorship_item";
  const [options, snags, photoUrl] = await Promise.all([
    itemFormOptions({
      organisationId: bundle.organisation.id,
      editionId: bundle.edition.id,
      kind: item.kind,
    }),
    isSponsorship ? [] : getItemSnags(item.id),
    !isSponsorship && item.installPhotoPath?.includes("/")
      ? getInlineUrl("photos", item.installPhotoPath).catch(() => null)
      : null,
  ]);

  return (
    <div className="grid gap-6">
      <section className="bg-muted/30 flex max-w-4xl flex-col gap-2 rounded-lg border p-4 text-sm">
        <h2 className="font-semibold">Labels &amp; paperwork</h2>
        <div className="flex flex-wrap gap-x-4 gap-y-1">
          <a className="text-primary hover:underline" href={`/api/exports/spec-label/${item.ref}`}>
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
        {snags.length > 0 && (
          <div>
            <p className="text-muted-foreground">Snags</p>
            <ul className="mt-1 space-y-1">
              {snags.map((snag) => (
                <li key={snag.id} className="flex flex-wrap items-center gap-2">
                  <StatusBadge status={snag.status} />
                  <span>{snag.description}</span>
                  <span className="text-muted-foreground text-xs">
                    {statusLabel(snag.severity)}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </section>

      {!canEdit && (
        <p className="text-muted-foreground text-sm">
          {editionIsReadOnly(bundle.edition.status)
            ? "This show is closed, so its items can no longer be changed."
            : "You can view this item but not change it."}
        </p>
      )}
      <ItemForm
        mode="edit"
        kind={item.kind}
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
          ownerRole: item.ownerRole,
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
          requiresEventDirector: item.requiresEventDirector,
          budgetLine: item.budgetLine,
          costEstimate: item.costEstimate,
          costActual: item.costActual,
          poNumber: item.poNumber,
          supplierId: item.supplierId,
          artworkDueOverride: item.artworkDueOverride,
          printDeadline: item.printDeadline,
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
}: {
  item: Item;
  bundle: Bundle;
  session: StaffSession;
  requiresInstallPhoto: boolean;
}) {
  const itemCtx = itemAuthzCtx(bundle);
  const [versions, instanceRows, invalidation, staffRows] = await Promise.all([
    getItemVersions(item.id),
    getItemInstances(item.id),
    artworkInvalidationPreview(item.id),
    // Sign-offs can be handed to anyone on the team except viewers.
    db
      .select({ id: users.id, fullName: users.fullName, email: users.email })
      .from(memberships)
      .innerJoin(users, eq(memberships.userId, users.id))
      .where(
        and(
          eq(memberships.organisationId, session.organisation.id),
          ne(memberships.role, "viewer"),
        ),
      ),
  ]);

  const canDecideIds = new Set<string>();
  const canDelegateIds = new Set<string>();
  for (const { instance } of instanceRows) {
    if (instance.status !== "pending" || instance.runNumber !== item.currentRunNumber) continue;
    const step: ApprovalStepCtx = {
      assignedRole: instance.assignedRole,
      assignedUserId: instance.assignedUserId,
      entity: { type: "signage_item", item: itemCtx },
    };
    if (can(session.actor, { type: "approval.decide", step })) canDecideIds.add(instance.id);
    if (can(session.actor, { type: "approval.delegate", step })) canDelegateIds.add(instance.id);
  }

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
    : null;

  return (
    <div className="grid gap-8">
      <ArtworkTab
        itemId={item.id}
        versions={versionRows}
        canUpload={can(session.actor, { type: "artwork.upload", item: itemCtx })}
        invalidationCount={invalidation.count}
        invalidationSteps={invalidation.steps}
        uploadBlocked={uploadBlocked}
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
            Not sent for sign-off yet — add artwork, then use Submit for review.
          </p>
        ) : (
          <ApprovalChain
            instances={chain}
            currentRun={item.currentRunNumber}
            canDecideIds={canDecideIds}
            canDelegateIds={canDelegateIds}
            currentVersionId={item.currentArtworkVersionId}
            requiresInstallPhoto={requiresInstallPhoto}
            delegatableUsers={staffRows.map((u) => ({ id: u.id, name: u.fullName || u.email }))}
          />
        )}
      </section>
    </div>
  );
}

async function ChangesSection({ item, session }: { item: Item; session: StaffSession }) {
  const crRequester = alias(users, "cr_requester");
  const crDecider = alias(users, "cr_decider");
  const crRows = await db
    .select({ cr: changeRequests, requester: crRequester, decider: crDecider })
    .from(changeRequests)
    .innerJoin(crRequester, eq(changeRequests.requestedBy, crRequester.id))
    .leftJoin(crDecider, eq(changeRequests.decidedBy, crDecider.id))
    .where(and(eq(changeRequests.entityType, "signage_item"), eq(changeRequests.entityId, item.id)))
    .orderBy(descOrder(changeRequests.createdAt));
  const rows: ChangeRequestRow[] = crRows.map(({ cr, requester, decider }) => ({
    id: cr.id,
    reason: cr.reason,
    status: cr.status,
    requesterName: requester.fullName || requester.email,
    deciderName: decider ? decider.fullName || decider.email : null,
    decidedAt: cr.decidedAt?.toISOString() ?? null,
    createdAt: cr.createdAt.toISOString(),
    reopenedCount: cr.reopenedInstanceIds?.length ?? 0,
    fieldChanges: cr.fieldChanges,
  }));
  return (
    <ChangesTab
      itemId={item.id}
      requests={rows}
      canRaise={can(session.actor, { type: "change_request.raise" })}
      canDecide={can(session.actor, { type: "change_request.approve" })}
      status={item.status}
      kind={item.kind}
      current={{
        name: item.name,
        widthMm: item.widthMm,
        heightMm: item.heightMm,
        depthMm: item.depthMm,
        quantity: item.quantity,
        material: item.material,
        finish: item.finish,
        installDate: item.installDate,
        deliveryDate: item.deliveryDate,
      }}
    />
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
