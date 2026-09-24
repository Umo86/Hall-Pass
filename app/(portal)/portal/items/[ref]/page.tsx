import Link from "next/link";
import { notFound } from "next/navigation";
import { db } from "@/lib/db/client";
import { requirePortalSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { getItemByRef, getItemInstances, getItemVersions, getLabelRows } from "@/lib/queries/signage";
import { labelWhen, labelWhere, specLabelFields } from "@/lib/exports/label-fields";
import { APPROVED_OR_LATER } from "@/lib/status/signage";
import { getDownloadUrl, getInlineUrl } from "@/lib/storage";
import { formatDate, formatDateTime } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import { DecideButtons } from "@/components/approvals/decide-buttons";

export const metadata = { title: "Item" };
export const dynamic = "force-dynamic";

/**
 * What an external user (venue, sponsor, supplier…) needs to act on one
 * item: where it goes, its spec, the artwork, and their sign-off buttons.
 * QR codes on labels land here for external users.
 */
export default async function PortalItemPage({ params }: { params: Promise<{ ref: string }> }) {
  const session = await requirePortalSession();
  const { ref } = await params;
  const item = await getItemByRef(decodeURIComponent(ref).toUpperCase());
  if (!item || item.deletedAt) notFound();
  const bundle = await loadItemBundle(db, item.id);
  if (!bundle || !can(session.actor, { type: "signage.view", item: itemAuthzCtx(bundle) })) {
    notFound();
  }

  const [[label], versions, instances] = await Promise.all([
    getLabelRows({ itemIds: [item.id] }),
    getItemVersions(item.id),
    getItemInstances(item.id),
  ]);

  // Suppliers only get artwork once it is signed off (the locked version);
  // everyone else sees the version currently under review.
  const isSupplierOnly = session.actor.grants.every((g) => g.role === "supplier");
  const artworkReleased = !isSupplierOnly || APPROVED_OR_LATER.includes(item.status);
  const current = versions.find((v) => v.version.id === item.currentArtworkVersionId)?.version;
  const isSeed = current?.filePath.startsWith("seed/") ?? false;
  const [artworkUrl, previewUrl] =
    current && artworkReleased && !isSeed
      ? await Promise.all([
          getDownloadUrl("artwork", current.filePath).catch(() => null),
          getInlineUrl("artwork", current.previewPath ?? current.filePath).catch(() => null),
        ])
      : [null, null];
  const previewIsImage = Boolean(current?.previewPath) || /\.(png|jpe?g|webp|gif)$/i.test(current?.fileName ?? "");

  const run = instances
    .filter(({ instance }) => instance.runNumber === item.currentRunNumber)
    .filter(({ instance }) => instance.status !== "invalidated" && instance.status !== "skipped")
    .sort((a, b) => a.instance.sortOrderSnapshot - b.instance.sortOrderSnapshot);
  const itemCtx = itemAuthzCtx(bundle);
  const mine = run.filter(
    ({ instance }) =>
      instance.status === "pending" &&
      can(session.actor, {
        type: "approval.decide",
        step: {
          assignedRole: instance.assignedRole,
          assignedUserId: instance.assignedUserId,
          entity: { type: "signage_item", item: itemCtx },
        },
      }),
  );

  const where = label ? labelWhere(label) : null;
  const when = label ? labelWhen(label) : null;
  const fields = label ? specLabelFields(label) : [];

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-5 p-4 sm:p-6">
      <div>
        <Link href="/portal/approvals" className="text-muted-foreground text-sm hover:underline">
          ← My Sign-offs
        </Link>
        <div className="mt-1 flex flex-wrap items-center gap-2">
          <h1 className="text-xl font-semibold tracking-tight">{item.name}</h1>
          <StatusBadge status={item.status} />
        </div>
        <p className="text-muted-foreground text-sm">
          {item.ref} · {bundle.edition.name}
        </p>
      </div>

      {mine.length > 0 && (
        <section className="space-y-3 rounded-lg border border-amber-300 bg-amber-50 p-4 dark:border-amber-900 dark:bg-amber-950/30">
          <h2 className="text-sm font-semibold">Waiting on you</h2>
          {mine.map(({ instance }) => (
            <div key={instance.id} className="space-y-2">
              <p className="text-sm">
                {instance.stepNameSnapshot}
                {instance.dueAt ? (
                  <span className="text-muted-foreground"> · due {formatDateTime(instance.dueAt)}</span>
                ) : null}
              </p>
              <DecideButtons
                instanceId={instance.id}
                stepKind={instance.stepKindSnapshot}
                stepName={instance.stepNameSnapshot}
                expectedStatus="pending"
                expectedLockedVersionId={item.currentArtworkVersionId ?? null}
                requiresPhoto={
                  instance.stepNameSnapshot === "Installed" &&
                  session.organisation.settings.install_photo_required
                }
              />
            </div>
          ))}
        </section>
      )}

      <section className="space-y-2">
        <h2 className="text-sm font-semibold">Artwork</h2>
        {!current ? (
          <p className="text-muted-foreground text-sm">No artwork uploaded yet.</p>
        ) : !artworkReleased ? (
          <p className="text-muted-foreground text-sm">
            Artwork is released to suppliers once it is signed off.
          </p>
        ) : isSeed ? (
          <p className="text-muted-foreground text-sm">
            v{current.versionNumber} · {current.fileName} (sample record — no file attached)
          </p>
        ) : (
          <div className="space-y-2">
            {previewUrl && previewIsImage && (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={previewUrl}
                alt={`Artwork v${current.versionNumber}`}
                className="max-h-96 w-full rounded-md border object-contain"
              />
            )}
            <p className="text-sm">
              v{current.versionNumber} · {current.fileName}
              {artworkUrl && (
                <>
                  {" · "}
                  <a className="text-primary hover:underline" href={artworkUrl} target="_blank" rel="noreferrer">
                    Open full size
                  </a>
                </>
              )}
            </p>
          </div>
        )}
      </section>

      <section className="space-y-2">
        <h2 className="text-sm font-semibold">Details</h2>
        {where && <p className="text-base font-semibold">{where}</p>}
        {when && <p className="text-muted-foreground text-sm">{when}</p>}
        <dl className="grid grid-cols-[8rem_1fr] gap-x-4 gap-y-1.5 text-sm">
          {fields.map(([k, v]) => (
            <div key={k} className="contents">
              <dt className="text-muted-foreground">{k}</dt>
              <dd>{v}</dd>
            </div>
          ))}
          {item.deliveryDate && item.kind === "signage" && (
            <div className="contents">
              <dt className="text-muted-foreground">Delivery</dt>
              <dd>{formatDate(item.deliveryDate)}</dd>
            </div>
          )}
        </dl>
        <p className="text-sm">
          <a className="text-primary hover:underline" href={`/api/exports/spec-label/${item.ref}`}>
            Download spec label (PDF)
          </a>
        </p>
      </section>

      {run.length > 0 && (
        <section className="space-y-2">
          <h2 className="text-sm font-semibold">Sign-off progress</h2>
          <ol className="space-y-1 text-sm">
            {run.map(({ instance, decider }) => (
              <li key={instance.id} className="flex flex-wrap items-center gap-2">
                <StatusBadge status={instance.status} />
                <span>{instance.stepNameSnapshot}</span>
                {instance.decidedAt && (
                  <span className="text-muted-foreground text-xs">
                    {decider?.fullName || decider?.email || ""} · {formatDateTime(instance.decidedAt)}
                  </span>
                )}
                {instance.conditionsText && (
                  <span className="text-muted-foreground w-full text-xs">
                    Conditions: {instance.conditionsText}
                  </span>
                )}
              </li>
            ))}
          </ol>
          {item.status === "on_hold" && (
            <p className="text-muted-foreground text-xs">
              This item is on hold{item.onHoldReason ? `: ${item.onHoldReason}` : ""}.
            </p>
          )}
        </section>
      )}
    </div>
  );
}
