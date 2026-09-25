import Link from "next/link";
import { notFound } from "next/navigation";
import { requireStaffSession } from "@/lib/auth/actor";
import { getEditionByCode, editionForDeadlines } from "@/lib/queries/editions";
import { listStandRows } from "@/lib/queries/stands";
import { standDesignDue } from "@/lib/deadlines";
import { daysUntil, formatDate, statusLabel } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";

export const metadata = { title: "Stand approvals" };
export const dynamic = "force-dynamic";

export default async function StandsPage({
  params,
  searchParams,
}: {
  params: Promise<{ editionCode: string }>;
  searchParams: Promise<{ status?: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  const { status } = await searchParams;
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();
  const rows = await listStandRows(ed.edition.id);
  const deadlines = await editionForDeadlines(ed.edition.id);
  const due = deadlines ? standDesignDue(deadlines) : null;
  const dueIn = due ? daysUntil(due) : null;

  const filtered = status
    ? rows.filter((r) => (r.sub?.status ?? "not_submitted") === status)
    : rows;

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="text-xl font-semibold tracking-tight">Stand approvals</h1>
        <span className="text-muted-foreground text-sm">
          {rows.length} exhibitors
          {due
            ? ` · designs due ${formatDate(due)}${dueIn != null ? ` (${dueIn >= 0 ? `in ${dueIn} days` : `${-dueIn} days overdue`})` : ""}`
            : ""}
        </span>
        {status && (
          <Link href={`/${editionCode}/stands`} className="text-sm underline">
            Clear filter: {statusLabel(status)}
          </Link>
        )}
      </div>

      <div className="overflow-x-auto rounded-lg border">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-muted/50 text-muted-foreground border-b text-left">
              <th className="px-3 py-2 font-medium">Stand</th>
              <th className="px-3 py-2 font-medium">Exhibitor</th>
              <th className="px-3 py-2 font-medium">Type</th>
              <th className="px-3 py-2 font-medium">Contractor</th>
              <th className="px-3 py-2 font-medium">Submission</th>
              <th className="px-3 py-2 font-medium">Complexity</th>
              <th className="px-3 py-2 font-medium">Insurance</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((r) => {
              const subStatus = r.sub?.status ?? "not_submitted";
              const insuranceExpiring =
                r.contractor?.insuranceExpiry && r.contractor.insuranceExpiry < ed.edition.buildEnd;
              return (
                <tr key={r.exhibitor.id} className="hover:bg-muted/30 border-b last:border-0">
                  <td className="px-3 py-2 font-medium">
                    {r.sub ? (
                      <Link
                        href={`/${editionCode}/stands/${r.sub.ref}`}
                        className="hover:underline"
                      >
                        {r.exhibitor.standNumber}
                      </Link>
                    ) : (
                      r.exhibitor.standNumber
                    )}
                  </td>
                  <td className="px-3 py-2">{r.exhibitor.companyName}</td>
                  <td className="text-muted-foreground px-3 py-2">
                    {statusLabel(r.exhibitor.standType)}
                  </td>
                  <td className="text-muted-foreground px-3 py-2">{r.contractor?.name ?? "—"}</td>
                  <td className="px-3 py-2">
                    {r.exhibitor.standType === "space_only" ? (
                      <StatusBadge status={subStatus} />
                    ) : (
                      <span className="text-muted-foreground">n/a (shell)</span>
                    )}
                  </td>
                  <td className="px-3 py-2">
                    {r.sub?.isComplex ? (
                      <span className="font-medium text-orange-700 dark:text-orange-400">
                        Complex structure
                      </span>
                    ) : r.sub ? (
                      "Standard"
                    ) : (
                      "—"
                    )}
                  </td>
                  <td className="px-3 py-2">
                    {insuranceExpiring ? (
                      <span className="text-destructive font-medium">
                        Expires {formatDate(r.contractor!.insuranceExpiry)}
                      </span>
                    ) : r.contractor?.insuranceExpiry ? (
                      <span className="text-muted-foreground">
                        Valid to {formatDate(r.contractor.insuranceExpiry)}
                      </span>
                    ) : (
                      "—"
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
