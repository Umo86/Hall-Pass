import Link from "next/link";
import { CheckCircle2, FileText } from "lucide-react";
import { requirePortalSession } from "@/lib/auth/actor";
import { pendingInstancesForUser } from "@/lib/queries/approvals";
import { reviewArtworkForItems } from "@/lib/queries/artwork-approvals";
import { itemAuthzCtx, type ItemBundle } from "@/lib/domain/signage";
import { externalSeesArtwork } from "@/lib/users/external";
import { formatDateTime } from "@/lib/format";
import { DecideButtons } from "@/components/approvals/decide-buttons";
import { OverduePill } from "@/components/approvals/review-sheet";
import { daysOverdue } from "@/components/approvals/step-words";
import { Page, PageHeader } from "@/components/page-header";
import { EmptyState } from "@/components/empty-state";
import { Button } from "@/components/ui/button";

export const metadata = { title: "My Sign-offs" };
export const dynamic = "force-dynamic";

/**
 * What is waiting on an external approver. Artwork is never approved from
 * the list: each row shows the artwork and opens the item, where the
 * decision sits under it.
 */
export default async function PortalApprovalsPage() {
  const session = await requirePortalSession();
  const rows = await pendingInstancesForUser(session);
  // Suppliers only see artwork once it is signed off (as on the item page),
  // decided per item by the grants that show it.
  const itemIds = rows
    .filter(({ isSignage, bundle }) => {
      if (!isSignage) return false;
      const b = bundle as ItemBundle;
      return externalSeesArtwork(session.actor, { ...itemAuthzCtx(b), status: b.item.status });
    })
    .map(({ bundle }) => (bundle as ItemBundle).item.id);
  const artwork = await reviewArtworkForItems(session.organisation.id, itemIds);

  return (
    <Page width="narrow" className="mx-auto">
      <PageHeader
        title="My Sign-offs"
        description="Open each item to look at the artwork, then approve it or ask for changes underneath."
        meta={`${rows.length} waiting on you`}
      />

      {rows.length === 0 ? (
        <EmptyState
          icon={CheckCircle2}
          title="Nothing is waiting on you"
          description="When something needs your sign-off it appears here, and you are emailed a link."
        />
      ) : (
        <ol className="space-y-2">
          {rows.map(({ raw, bundle, isSignage, isOverdue }) => {
            const b = bundle as never as {
              item?: {
                id: string;
                ref: string;
                name: string;
                kind: string;
                currentArtworkVersionId: string | null;
              };
              sub?: { ref: string; submissionVersion: number };
              exhibitor?: { companyName: string; standNumber: string };
            };
            const ref = isSignage ? b.item!.ref : b.sub!.ref;
            const title = isSignage
              ? b.item!.name
              : `${b.exhibitor!.companyName} — stand ${b.exhibitor!.standNumber}`;
            const thumb = isSignage ? artwork.get(b.item!.id)?.current.thumbUrl : null;
            const href = `/portal/items/${encodeURIComponent(ref)}`;
            const isConfirmation = raw.stepKindSnapshot === "confirmation";
            return (
              <li key={raw.id} className="flex flex-wrap items-center gap-3 rounded-lg border p-3">
                {isSignage && (
                  <Link
                    href={href}
                    className="bg-muted flex size-14 shrink-0 items-center justify-center overflow-hidden rounded-md border"
                    aria-label={`Open ${ref}`}
                  >
                    {thumb ? (
                      // eslint-disable-next-line @next/next/no-img-element -- signed artwork URL
                      <img src={thumb} alt="" className="size-full object-contain" />
                    ) : (
                      <FileText className="text-muted-foreground size-5" aria-hidden />
                    )}
                  </Link>
                )}
                <div className="min-w-0 flex-1">
                  <p className="text-sm">
                    {isSignage ? (
                      <Link href={href} className="link font-medium">
                        {ref}
                      </Link>
                    ) : (
                      <span className="font-medium">{ref}</span>
                    )}{" "}
                    — {title}
                  </p>
                  <p className="text-muted-foreground flex flex-wrap items-center gap-x-1.5 gap-y-1 text-xs">
                    <span>{raw.stepNameSnapshot}</span>
                    {raw.dueAt && (
                      <span className={isOverdue ? "text-destructive font-medium" : undefined}>
                        · due {formatDateTime(raw.dueAt)}
                      </span>
                    )}
                    {isOverdue && raw.dueAt && <OverduePill days={daysOverdue(raw.dueAt)} />}
                  </p>
                </div>
                {isSignage ? (
                  <Button asChild size="sm" className="w-full sm:w-auto">
                    <Link href={href}>{isConfirmation ? "Open to confirm" : "Review artwork"}</Link>
                  </Button>
                ) : (
                  // Stand reviews have no portal page of their own yet.
                  <DecideButtons
                    instanceId={raw.id}
                    stepKind={raw.stepKindSnapshot}
                    stepName={raw.stepNameSnapshot}
                    expectedStatus="pending"
                    expectedLockedVersionId={String(b.sub!.submissionVersion)}
                    itemRef={ref}
                    compact
                  />
                )}
              </li>
            );
          })}
        </ol>
      )}
    </Page>
  );
}
