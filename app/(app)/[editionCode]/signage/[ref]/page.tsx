import Link from "next/link";
import { notFound } from "next/navigation";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  contractors,
  halls,
  itemTypes,
  locations,
  memberships,
  sponsorEntitlements,
  sponsors,
  suppliers,
  users,
  workflows,
} from "@/lib/db/schema";
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
import { artworkInvalidationPreview } from "@/app/actions/artwork";
import { blobEnabled, getDownloadUrl, getInlineUrl } from "@/lib/storage";
import { formatDate, formatDateTime, formatMoney, statusLabel } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import { ApprovalChain, type ChainInstance } from "@/components/approvals/chain";
import { ArtworkTab, type VersionRow } from "@/components/signage/artwork-tab";
import { CommentThread } from "@/components/comments/thread";
import { ItemForm } from "@/components/signage/item-form";
import { LifecycleButtons } from "@/components/signage/lifecycle-buttons";
import { ChangesTab, type ChangeRequestRow } from "@/components/signage/changes-tab";
import { changeRequests } from "@/lib/db/schema";
import { desc as descOrder } from "drizzle-orm";
import { alias } from "drizzle-orm/pg-core";

export const dynamic = "force-dynamic";

const TABS = ["details", "artwork", "approvals", "production", "install", "comments", "changes", "history"] as const;

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
  const tab = (TABS as readonly string[]).includes(rawTab ?? "") ? rawTab! : "details";

  const item = await getItemByRef(decodeURIComponent(ref));
  if (!item || item.deletedAt) notFound();
  const bundle = await loadItemBundle(db, item.id);
  if (!bundle) notFound();

  const [versions, instanceRows, comments, audit, snags, invalidation] = await Promise.all([
    getItemVersions(item.id),
    getItemInstances(item.id),
    getEntityComments("signage_item", item.id, true),
    getEntityAudit("signage_item", item.id),
    getItemSnags(item.id),
    artworkInvalidationPreview(item.id),
  ]);

  const [typeRows, hallRows, locationRows, sponsorRows, entRows, supplierRows, contractorRows, wfRows, staffRows] =
    await Promise.all([
      db.select().from(itemTypes).where(eq(itemTypes.organisationId, session.organisation.id)),
      db.select().from(halls).where(eq(halls.editionId, bundle.edition.id)),
      db
        .select({ id: locations.id, name: locations.name, hallId: locations.hallId })
        .from(locations)
        .innerJoin(halls, eq(locations.hallId, halls.id))
        .where(eq(halls.editionId, bundle.edition.id)),
      db.select().from(sponsors).where(eq(sponsors.editionId, bundle.edition.id)),
      db
        .select()
        .from(sponsorEntitlements)
        .innerJoin(sponsors, eq(sponsorEntitlements.sponsorId, sponsors.id))
        .where(eq(sponsors.editionId, bundle.edition.id)),
      db.select().from(suppliers).where(eq(suppliers.organisationId, session.organisation.id)),
      db.select().from(contractors).where(eq(contractors.organisationId, session.organisation.id)),
      db.select().from(workflows).where(eq(workflows.organisationId, session.organisation.id)),
      db
        .select({ user: users })
        .from(memberships)
        .innerJoin(users, eq(memberships.userId, users.id))
        .where(eq(memberships.organisationId, session.organisation.id)),
    ]);

  const itemCtx = itemAuthzCtx(bundle);
  const canSeeCosts = can(session.actor, { type: "costs.view" });
  const canEditCosts = can(session.actor, { type: "costs.edit" });
  const canUploadArtwork = can(session.actor, { type: "artwork.upload", item: itemCtx });

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
  const chain: ChainInstance[] = await Promise.all(
    instanceRows.map(async ({ instance, decider }) => ({
      id: instance.id,
      runNumber: instance.runNumber,
      stepName: instance.stepNameSnapshot,
      stepKind: instance.stepKindSnapshot,
      sortOrder: instance.sortOrderSnapshot,
      status: instance.status,
      assignedRole: instance.assignedRole,
      assignedUserId: instance.assignedUserId,
      deciderName: decider?.fullName ?? decider?.email ?? null,
      decidedAt: instance.decidedAt,
      decisionComment: instance.decisionComment,
      conditionsText: instance.conditionsText,
      lockedVersionLabel: instance.lockedVersionId
        ? `v${versionById.get(instance.lockedVersionId) ?? "?"} (${instance.lockedSha256?.slice(0, 12) ?? "no hash"}…)`
        : null,
      dueAt: instance.dueAt,
      noSupplierFallback: instance.noSupplierFallback,
    })),
  );

  const versionRows: VersionRow[] = await Promise.all(
    versions.map(async ({ version, uploader }) => ({
      id: version.id,
      versionNumber: version.versionNumber,
      fileName: version.fileName,
      fileSize: version.fileSize,
      sha256: version.sha256,
      proofStatus: version.proofStatus,
      notes: version.notes,
      uploaderName: uploader?.fullName ?? uploader?.email ?? null,
      createdAt: version.createdAt.toISOString(),
      downloadUrl: version.filePath.startsWith("seed/")
        ? null
        : await getDownloadUrl("artwork", version.filePath).catch(() => null),
      previewUrl: version.previewPath
        ? await getInlineUrl("artwork", version.previewPath).catch(() => null)
        : version.mimeType === "application/pdf" && !version.filePath.startsWith("seed/")
          ? await getInlineUrl("artwork", version.filePath).catch(() => null)
          : null,
      mimeType: version.mimeType,
      isCurrent: version.id === item.currentArtworkVersionId,
    })),
  );

  const crRequester = alias(users, "cr_requester");
  const crDecider = alias(users, "cr_decider");
  const crRows = await db
    .select({ cr: changeRequests, requester: crRequester, decider: crDecider })
    .from(changeRequests)
    .innerJoin(crRequester, eq(changeRequests.requestedBy, crRequester.id))
    .leftJoin(crDecider, eq(changeRequests.decidedBy, crDecider.id))
    .where(
      and(eq(changeRequests.entityType, "signage_item"), eq(changeRequests.entityId, item.id)),
    )
    .orderBy(descOrder(changeRequests.createdAt));
  const changeRequestRows: ChangeRequestRow[] = crRows.map(({ cr, requester, decider }) => ({
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

  const uploadBlocked = ["installed", "snagged", "closed"].includes(item.status)
    ? "This item is installed — an admin or ops user must reopen it before new artwork can be uploaded."
    : null;

  const formOptions = {
    itemTypes: typeRows.map((t) => ({ id: t.id, name: t.name })),
    halls: hallRows.map((h) => ({ id: h.id, name: h.name })),
    locations: locationRows,
    sponsors: sponsorRows.map((sp) => ({ id: sp.id, name: sp.companyName })),
    entitlements: entRows.map((e) => ({
      id: e.sponsor_entitlements.id,
      sponsorId: e.sponsor_entitlements.sponsorId,
      description: e.sponsor_entitlements.description,
    })),
    suppliers: supplierRows.map((sp) => ({ id: sp.id, name: sp.name })),
    contractors: contractorRows.map((c) => ({ id: c.id, name: c.name })),
    workflows: wfRows.map((w) => ({ id: w.id, name: w.name })),
  };

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <div className="flex flex-wrap items-center gap-3">
        <div>
          <p className="text-muted-foreground text-xs">
            <Link href={`/${editionCode}/signage`} className="hover:underline">
              Signage
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
          />
        </div>
      </div>

      <nav className="flex gap-1 overflow-x-auto border-b" aria-label="Item sections">
        {TABS.map((t) => (
          <Link
            key={t}
            href={`?tab=${t}`}
            className={`px-3 py-2 text-sm whitespace-nowrap ${
              tab === t
                ? "border-primary text-foreground border-b-2 font-medium"
                : "text-muted-foreground hover:text-foreground"
            }`}
            aria-current={tab === t ? "page" : undefined}
          >
            {t === "history" ? "History" : statusLabel(t)}
          </Link>
        ))}
      </nav>

      {tab === "details" && (
        <ItemForm
          mode="edit"
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
          options={formOptions}
          canSeeCosts={canSeeCosts}
          canEditCosts={canEditCosts}
          editionCode={editionCode}
        />
      )}

      {tab === "artwork" && (
        <ArtworkTab
          itemId={item.id}
          versions={versionRows}
          canUpload={canUploadArtwork}
          invalidationCount={invalidation.count}
          invalidationSteps={invalidation.steps}
          uploadBlocked={uploadBlocked}
          uploadPrefix={
            blobEnabled()
              ? `artwork/${bundle.organisation.id}/${bundle.edition.id}/signage_item/${item.id}/`
              : null
          }
        />
      )}

      {tab === "approvals" &&
        (chain.length === 0 ? (
          <p className="text-muted-foreground text-sm">
            No approval run yet — submit the item for review to start one.
          </p>
        ) : (
          <ApprovalChain
            instances={chain}
            currentRun={item.currentRunNumber}
            canDecideIds={canDecideIds}
            canDelegateIds={canDelegateIds}
            currentVersionId={item.currentArtworkVersionId}
            requiresInstallPhoto={session.organisation.settings.install_photo_required}
            delegatableUsers={staffRows.map(({ user }) => ({
              id: user.id,
              name: user.fullName || user.email,
            }))}
          />
        ))}

      {tab === "production" && (
        <dl className="grid max-w-2xl grid-cols-1 gap-x-6 gap-y-3 text-sm sm:grid-cols-2">
          <dt className="text-muted-foreground">Supplier</dt>
          <dd>{supplierRows.find((s) => s.id === item.supplierId)?.name ?? "—"}</dd>
          {canSeeCosts && (
            <>
              <dt className="text-muted-foreground">PO number</dt>
              <dd>{item.poNumber ?? "—"}</dd>
              <dt className="text-muted-foreground">Cost estimate</dt>
              <dd>{formatMoney(item.costEstimate)}</dd>
              <dt className="text-muted-foreground">Cost actual</dt>
              <dd>{formatMoney(item.costActual)}</dd>
            </>
          )}
          <dt className="text-muted-foreground">Print deadline</dt>
          <dd>{formatDate(item.printDeadline)}</dd>
          <dt className="text-muted-foreground">Delivery date</dt>
          <dd>{formatDate(item.deliveryDate)}</dd>
          <dt className="text-muted-foreground">Spec label</dt>
          <dd>
            <a className="text-primary hover:underline" href={`/api/exports/spec-label/${item.ref}`}>
              Download A6 spec label (PDF)
            </a>
          </dd>
        </dl>
      )}

      {tab === "install" && (
        <div className="max-w-2xl space-y-4 text-sm">
          <dl className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            <dt className="text-muted-foreground">Install date</dt>
            <dd>
              {formatDate(item.installDate)}
              {item.installSlot ? ` (${item.installSlot.toUpperCase()})` : ""}
            </dd>
            <dt className="text-muted-foreground">Contractor</dt>
            <dd>{contractorRows.find((c) => c.id === item.installContractorId)?.name ?? "—"}</dd>
            <dt className="text-muted-foreground">Installed</dt>
            <dd>
              {item.installedAt
                ? `${formatDateTime(item.installedAt)}${item.installPhotoPath ? " · photo on file" : ""}`
                : "Not yet"}
            </dd>
          </dl>
          <div>
            <h3 className="mb-2 font-semibold">Snags</h3>
            {snags.length === 0 ? (
              <p className="text-muted-foreground">No snags recorded.</p>
            ) : (
              <ul className="space-y-2">
                {snags.map((snag) => (
                  <li key={snag.id} className="flex items-center gap-2 rounded-lg border p-3">
                    <StatusBadge status={snag.status} />
                    <span>{snag.description}</span>
                    <span className="text-muted-foreground ml-auto text-xs">
                      {statusLabel(snag.severity)}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      )}

      {tab === "comments" && (
        <CommentThread
          entityType="signage_item"
          entityId={item.id}
          comments={comments.map(({ comment, author }) => ({
            id: comment.id,
            body: comment.body,
            isInternal: comment.isInternal,
            authorName: author.fullName || author.email,
            createdAt: comment.createdAt.toISOString(),
          }))}
          canWriteInternal={can(session.actor, { type: "comment.internal.write" })}
          canWriteExternal={can(session.actor, { type: "comment.external.write", entity: itemCtx })}
          isStaff
        />
      )}

      {tab === "changes" && (
        <ChangesTab
          itemId={item.id}
          requests={changeRequestRows}
          canRaise={can(session.actor, { type: "change_request.raise" })}
          canDecide={can(session.actor, { type: "change_request.approve" })}
        />
      )}

      {tab === "history" && (
        <ol className="max-w-3xl space-y-2 text-sm">
          {audit.map(({ entry, actor }) => (
            <li key={entry.id} className="flex gap-3 rounded-lg border p-3">
              <span className="text-muted-foreground w-40 shrink-0 text-xs">
                {formatDateTime(entry.createdAt)}
              </span>
              <div>
                <p>{entry.summary}</p>
                <p className="text-muted-foreground text-xs">
                  {actor?.fullName ?? actor?.email ?? entry.actorType} · {entry.action}
                </p>
              </div>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}
