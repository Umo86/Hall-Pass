import Link from "next/link";
import { notFound } from "next/navigation";
import { Box, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { StatusBadge } from "@/components/status-badge";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { getEditionByCode } from "@/lib/queries/editions";
import { listStandDesigns } from "@/lib/queries/stand-designs";

export const metadata = { title: "Stand designs" };
export const dynamic = "force-dynamic";

/**
 * Stands the organiser designs: each card shows the latest design, where
 * its sign-off is up to, and how many of its panels are approved.
 */
export default async function StandDesignsPage({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();
  const stands = await listStandDesigns(ed.edition.id);
  const canCreate =
    can(session.actor, { type: "stand_design.create" }) && !editionIsReadOnly(ed.edition.status);

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Stand designs</h1>
          <p className="text-muted-foreground text-sm">
            Stands we design: the team approves each design, then the graphics for every panel.
          </p>
        </div>
        {canCreate && (
          <Button asChild size="sm">
            <Link href={`/${editionCode}/stand-designs/new`}>
              <Plus className="size-4" /> New stand
            </Link>
          </Button>
        )}
      </div>

      {stands.length === 0 ? (
        <div className="text-muted-foreground flex h-48 flex-col items-center justify-center gap-2 rounded-lg border border-dashed p-6 text-center text-sm">
          <Box className="size-6 opacity-50" aria-hidden />
          <p>No stands yet.</p>
          <p className="max-w-md">
            Create a stand, choose who approves it, and upload the design. Once it&apos;s approved,
            add its panels and their graphics.
          </p>
          {canCreate && (
            <Button size="sm" variant="outline" asChild>
              <Link href={`/${editionCode}/stand-designs/new`}>Create the first stand</Link>
            </Button>
          )}
        </div>
      ) : (
        <ul className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3" aria-label="Stands">
          {stands.map((s) => (
            <li key={s.id}>
              <Link
                href={`/${editionCode}/stand-designs/${s.ref}`}
                className="hover:border-primary/50 flex h-full flex-col overflow-hidden rounded-lg border transition-colors"
                aria-label={s.name}
              >
                <div className="bg-muted flex aspect-[16/9] items-center justify-center overflow-hidden">
                  {s.previewUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={s.previewUrl}
                      alt={`${s.name} design`}
                      className="size-full object-contain"
                    />
                  ) : (
                    <span className="text-muted-foreground flex flex-col items-center gap-1 text-xs">
                      <Box className="size-8 opacity-40" aria-hidden />
                      {s.designVersion ? `Design v${s.designVersion}` : "No design yet"}
                    </span>
                  )}
                </div>
                <div className="flex flex-1 flex-col gap-2 p-3">
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <p className="truncate font-medium">{s.name}</p>
                      <p className="text-muted-foreground text-xs">
                        {[
                          s.ref,
                          s.standNumber ? `Stand ${s.standNumber}` : null,
                          s.hallName,
                          s.sponsorName,
                        ]
                          .filter(Boolean)
                          .join(" · ")}
                      </p>
                    </div>
                    <StatusBadge status={s.status} />
                  </div>
                  {s.size && <p className="text-muted-foreground text-xs">{s.size}</p>}
                  {s.waitingOn.length > 0 && (
                    <p
                      className={`text-xs ${s.waitingOn.some((w) => w.overdue) ? "text-destructive font-medium" : ""}`}
                    >
                      Waiting on {s.waitingOn.map((w) => w.who ?? w.name).join(", ")}
                    </p>
                  )}
                  <p className="text-muted-foreground mt-auto text-xs">
                    Panels:{" "}
                    {s.panels.total === 0
                      ? "none yet"
                      : `${s.panels.approved} of ${s.panels.total} approved`}
                  </p>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
