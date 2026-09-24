import Link from "next/link";
import { requirePortalSession } from "@/lib/auth/actor";
import { pendingInstancesForUser } from "@/lib/queries/approvals";
import { formatDateTime } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import { DecideButtons } from "@/components/approvals/decide-buttons";

export const metadata = { title: "My Sign-offs" };
export const dynamic = "force-dynamic";

export default async function PortalApprovalsPage() {
  const session = await requirePortalSession();
  const rows = await pendingInstancesForUser();

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-4 p-4 sm:p-6">
      <h1 className="text-xl font-semibold tracking-tight">
        My Sign-offs{" "}
        <span className="text-muted-foreground text-base font-normal">
          ({rows.length} waiting on you)
        </span>
      </h1>

      {rows.length === 0 ? (
        <div className="border-border text-muted-foreground flex h-40 items-center justify-center rounded-lg border border-dashed text-sm">
          Nothing is waiting on you.
        </div>
      ) : (
        <ol className="space-y-2">
          {rows.map(({ raw, bundle, isSignage, isOverdue }) => {
            const b = bundle as never as {
              item?: { ref: string; name: string; currentArtworkVersionId: string | null };
              sub?: { ref: string; submissionVersion: number };
              exhibitor?: { companyName: string; standNumber: string };
            };
            const ref = isSignage ? b.item!.ref : b.sub!.ref;
            const title = isSignage
              ? b.item!.name
              : `${b.exhibitor!.companyName} — stand ${b.exhibitor!.standNumber}`;
            return (
              <li key={raw.id} className="flex flex-wrap items-center gap-3 rounded-lg border p-3">
                <StatusBadge status="pending" />
                <div className="min-w-0 flex-1">
                  <p className="text-sm">
                    {isSignage ? (
                      <Link href={`/portal/items/${ref}`} className="font-medium hover:underline">
                        {ref}
                      </Link>
                    ) : (
                      <span className="font-medium">{ref}</span>
                    )}{" "}
                    — {title}
                  </p>
                  <p
                    className={`text-xs ${isOverdue ? "text-destructive font-medium" : "text-muted-foreground"}`}
                  >
                    {raw.stepNameSnapshot}
                    {raw.dueAt ? ` · due ${formatDateTime(raw.dueAt)}` : ""}
                    {isOverdue ? " — overdue" : ""}
                  </p>
                </div>
                <DecideButtons
                  instanceId={raw.id}
                  stepKind={raw.stepKindSnapshot}
                  stepName={raw.stepNameSnapshot}
                  expectedStatus="pending"
                  expectedLockedVersionId={
                    isSignage
                      ? (b.item!.currentArtworkVersionId ?? null)
                      : String(b.sub!.submissionVersion)
                  }
                  requiresPhoto={
                    raw.stepNameSnapshot === "Installed" &&
                    session.organisation.settings.install_photo_required
                  }
                  compact
                />
              </li>
            );
          })}
        </ol>
      )}
    </div>
  );
}
