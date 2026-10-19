import { SectionUnavailable } from "@/components/section-unavailable";
import { hasFeature } from "@/lib/authz";
import Link from "next/link";
import { notFound } from "next/navigation";
import { HardHat } from "lucide-react";
import { requireStaffSession } from "@/lib/auth/actor";
import { getEditionByCode, editionForDeadlines } from "@/lib/queries/editions";
import { listStandRows } from "@/lib/queries/stands";
import { standDesignDue } from "@/lib/deadlines";
import { daysUntil, formatDate, plural, statusLabel } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import { EmptyState } from "@/components/empty-state";
import { Page, PageHeader } from "@/components/page-header";
import { cn } from "@/lib/utils";

export const metadata = { title: "Exhibitor stands" };
export const dynamic = "force-dynamic";

/** The chips above the list; each counts the submission statuses it covers. */
const CHIPS: { id: string; label: string; statuses: string[] }[] = [
  { id: "not_submitted", label: "Not submitted", statuses: ["not_submitted"] },
  { id: "in_review", label: "In sign-off", statuses: ["submitted", "in_review"] },
  { id: "changes_requested", label: "Changes requested", statuses: ["changes_requested"] },
  {
    id: "approved",
    label: "Approved",
    statuses: ["approved", "approved_with_conditions", "build_checked", "closed"],
  },
  { id: "rejected", label: "Rejected", statuses: ["rejected"] },
  { id: "on_hold", label: "On hold", statuses: ["on_hold"] },
];
const SHELL = "shell";

type Row = Awaited<ReturnType<typeof listStandRows>>[number];

/** Shell-scheme exhibitors submit nothing; everyone else has a submission status. */
function rowStatus(r: Row): string {
  return r.exhibitor.standType === "space_only" ? (r.sub?.status ?? "not_submitted") : SHELL;
}

/**
 * Exhibitor stands: each space-only exhibitor's stand plan and where its
 * check is up to. `?status=` takes a chip (in_review, approved, shell…) or
 * any single submission status (links from the dashboard).
 */
export default async function StandsPage({
  params,
  searchParams,
}: {
  params: Promise<{ editionCode: string }>;
  searchParams: Promise<{ status?: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  if (!hasFeature(session.actor, "stands")) {
    return <SectionUnavailable feature="stands" backHref={`/${editionCode}/dashboard`} />;
  }
  const { status } = await searchParams;
  const ed = await getEditionByCode(editionCode.toUpperCase(), session);
  if (!ed) notFound();
  const rows = await listStandRows(ed.edition.id);
  const deadlines = await editionForDeadlines(ed.edition.id);
  const due = deadlines ? standDesignDue(deadlines) : null;
  const dueIn = due ? daysUntil(due) : null;

  const chip = CHIPS.find((c) => c.id === status);
  const matches = (r: Row) => {
    if (!status) return true;
    const s = rowStatus(r);
    return chip ? chip.statuses.includes(s) : s === status;
  };
  const filtered = rows.filter(matches);
  const count = (statuses: string[]) => rows.filter((r) => statuses.includes(rowStatus(r))).length;
  const shellCount = count([SHELL]);
  const base = `/${editionCode}/stands`;
  const chipLink = (id: string | null, label: string, n: number) => {
    const active = id === null ? !status : status === id;
    return (
      <Link
        key={id ?? "all"}
        href={id ? `${base}?status=${id}` : base}
        aria-current={active ? "page" : undefined}
        className={cn(
          "inline-flex min-h-11 items-center gap-1 rounded-full border px-3 text-sm whitespace-nowrap sm:min-h-9",
          active ? "bg-foreground text-background border-foreground" : "hover:bg-muted",
        )}
      >
        {label} <span className="opacity-70">({n})</span>
      </Link>
    );
  };

  return (
    <Page width="full" className="max-w-7xl gap-4">
      <PageHeader
        title="Exhibitor stands"
        description="Space-only stand plans to check and approve."
        meta={`${plural(rows.length, "exhibitor")}${
          due
            ? ` · designs due ${formatDate(due)}${
                dueIn != null
                  ? ` (${dueIn >= 0 ? `in ${plural(dueIn, "day")}` : `${plural(-dueIn, "day")} overdue`})`
                  : ""
              }`
            : ""
        }`}
      />

      {rows.length === 0 ? (
        <EmptyState
          icon={HardHat}
          title="No exhibitors yet"
          description="Exhibitors appear here once they are added to this event; space-only ones then submit their stand plans through the portal."
        />
      ) : (
        <>
          <nav className="flex flex-wrap gap-2" aria-label="Filter by status">
            {chipLink(null, "All", rows.length)}
            {CHIPS.map((c) => ({ c, n: count(c.statuses) }))
              .filter(({ c, n }) => n > 0 || status === c.id)
              .map(({ c, n }) => chipLink(c.id, c.label, n))}
            {(shellCount > 0 || status === SHELL) && chipLink(SHELL, "Shell (n/a)", shellCount)}
            {status && !chip && status !== SHELL && (
              <span className="bg-foreground text-background inline-flex min-h-11 items-center rounded-full px-3 text-sm sm:min-h-9">
                {statusLabel(status)} ({filtered.length})
              </span>
            )}
          </nav>

          {filtered.length === 0 ? (
            <EmptyState
              icon={HardHat}
              title="Nobody here"
              description={`No exhibitors are ${chip ? chip.label.toLowerCase() : statusLabel(status ?? "").toLowerCase()} at the moment.`}
              action={
                <Link href={base} className="link text-sm">
                  Show every exhibitor
                </Link>
              }
            />
          ) : (
            <>
              {/* Phones: one card per exhibitor, status on the right. */}
              <ul className="divide-y rounded-lg border sm:hidden" aria-label="Exhibitors">
                {filtered.map((r) => (
                  <ExhibitorCard
                    key={r.exhibitor.id}
                    r={r}
                    editionCode={editionCode}
                    buildEnd={ed.edition.buildEnd}
                  />
                ))}
              </ul>
              <div className="hidden overflow-x-auto rounded-lg border sm:block">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-muted/50 text-muted-foreground border-b text-left">
                      <th className="px-3 py-2 font-medium">Stand</th>
                      <th className="px-3 py-2 font-medium">Exhibitor</th>
                      <th className="px-3 py-2 font-medium">Submission</th>
                      <th className="px-3 py-2 font-medium">Type</th>
                      <th className="px-3 py-2 font-medium">Contractor</th>
                      <th className="px-3 py-2 font-medium">Complexity</th>
                      <th className="px-3 py-2 font-medium">Insurance</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filtered.map((r) => (
                      <tr
                        key={r.exhibitor.id}
                        className={cn(
                          "border-b last:border-0",
                          // The whole row opens the submission.
                          r.sub && "hover:bg-muted/40 relative cursor-pointer",
                        )}
                      >
                        <td className="px-3 py-2 font-medium">
                          {r.sub ? (
                            <Link
                              href={`/${editionCode}/stands/${r.sub.ref}`}
                              className="after:absolute after:inset-0 hover:underline"
                            >
                              {r.exhibitor.standNumber}
                            </Link>
                          ) : (
                            r.exhibitor.standNumber
                          )}
                        </td>
                        <td className="px-3 py-2">{r.exhibitor.companyName}</td>
                        <td className="px-3 py-2">
                          <SubmissionStatus r={r} />
                        </td>
                        <td className="text-muted-foreground px-3 py-2">
                          {statusLabel(r.exhibitor.standType)}
                        </td>
                        <td className="text-muted-foreground px-3 py-2">
                          {r.contractor?.name ?? "—"}
                        </td>
                        <td className="px-3 py-2">
                          <Complexity r={r} />
                        </td>
                        <td className="px-3 py-2">
                          <Insurance r={r} buildEnd={ed.edition.buildEnd} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </>
      )}
    </Page>
  );
}

function SubmissionStatus({ r }: { r: Row }) {
  return r.exhibitor.standType === "space_only" ? (
    <StatusBadge status={r.sub?.status ?? "not_submitted"} />
  ) : (
    <span className="text-muted-foreground">n/a (shell)</span>
  );
}

function Complexity({ r }: { r: Row }) {
  if (r.sub?.isComplex) {
    return (
      <span className="font-medium text-orange-700 dark:text-orange-400">Complex structure</span>
    );
  }
  return <>{r.sub ? "Standard" : "—"}</>;
}

function Insurance({ r, buildEnd }: { r: Row; buildEnd: string }) {
  const expiry = r.contractor?.insuranceExpiry;
  if (!expiry) return <>—</>;
  return expiry < buildEnd ? (
    <span className="text-destructive font-medium">Expires {formatDate(expiry)}</span>
  ) : (
    <span className="text-muted-foreground">Valid to {formatDate(expiry)}</span>
  );
}

function ExhibitorCard({
  r,
  editionCode,
  buildEnd,
}: {
  r: Row;
  editionCode: string;
  buildEnd: string;
}) {
  const expiring = Boolean(
    r.contractor?.insuranceExpiry && r.contractor.insuranceExpiry < buildEnd,
  );
  const body = (
    <>
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <p className="font-medium">
            {r.exhibitor.standNumber} · {r.exhibitor.companyName}
          </p>
          <p className="text-muted-foreground text-xs">
            {[statusLabel(r.exhibitor.standType), r.contractor?.name ?? "No contractor yet"].join(
              " · ",
            )}
            {r.sub?.isComplex ? " · Complex structure" : ""}
          </p>
        </div>
        <SubmissionStatus r={r} />
      </div>
      {expiring && (
        <p className="text-destructive mt-1 text-xs font-medium">
          Contractor insurance expires {formatDate(r.contractor!.insuranceExpiry)}
        </p>
      )}
    </>
  );
  return (
    <li aria-label={`${r.exhibitor.standNumber} ${r.exhibitor.companyName}`}>
      {r.sub ? (
        <Link
          href={`/${editionCode}/stands/${r.sub.ref}`}
          className="hover:bg-muted/40 block min-h-11 px-3 py-3 text-sm"
        >
          {body}
        </Link>
      ) : (
        <div className="px-3 py-3 text-sm">{body}</div>
      )}
    </li>
  );
}
