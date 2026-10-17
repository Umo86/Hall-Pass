import Link from "next/link";
import { notFound } from "next/navigation";
import { and, asc, desc, eq, inArray, isNull, sql } from "drizzle-orm";
import {
  ChevronRight,
  FileSpreadsheet,
  FileText,
  History,
  Lock,
  Tag,
  type LucideIcon,
} from "lucide-react";
import { db } from "@/lib/db/client";
import { exhibitors, exports as exportsTable, halls, signageItems, users } from "@/lib/db/schema";
import { standsEnabled } from "@/lib/config";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, hasFeature } from "@/lib/authz";
import { getEditionByCode } from "@/lib/queries/editions";
import { formatDateTime, statusLabel } from "@/lib/format";
import { SIGNAGE_KINDS } from "@/lib/edition-path";
import { Page, PageHeader } from "@/components/page-header";
import { EmptyState } from "@/components/empty-state";
import { SectionUnavailable } from "@/components/section-unavailable";
import { DownloadButton } from "@/components/reports/download-button";
import {
  EXPORT_LOG_KIND,
  scopeLine,
  visibleGroups,
  type ReportCounts,
  type ReportKind,
} from "@/components/reports/report-rules";

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: { params: Promise<{ editionCode: string }> }) {
  const { editionCode } = await params;
  return { title: `Reports · ${editionCode.toUpperCase()}` };
}

type Report = {
  title: string;
  purpose: string;
  href: (code: string) => string;
  format: "Excel" | "PDF";
  file: (code: string) => string;
  icon: LucideIcon;
};

const REPORTS: Record<ReportKind, Report> = {
  venue_pack: {
    title: "Venue submission pack",
    purpose: "Every rigged or venue-approval item with weights, fixings and approval state.",
    href: (c) => `/api/exports/venue-pack/${c}`,
    format: "Excel",
    file: (c) => `${c}-venue-pack.xlsx`,
    icon: FileSpreadsheet,
  },
  contractor_schedule: {
    title: "Contractor install schedule",
    purpose: "What goes up where and when: a sheet per install contractor, plus deliveries.",
    href: (c) => `/api/exports/contractor-schedule/${c}`,
    format: "Excel",
    file: (c) => `${c}-install-schedule.xlsx`,
    icon: FileSpreadsheet,
  },
  spec_labels: {
    title: "Spec labels",
    purpose: "One A6 label per item with where it goes, its install slot and a QR code.",
    href: (c) => `/api/exports/spec-labels/${c}`,
    format: "PDF",
    file: (c) => `${c}-spec-labels.pdf`,
    icon: Tag,
  },
  sponsor_report: {
    title: "Sponsor report",
    purpose:
      "Everything sold to each sponsor, signage and sponsorship items, with sign-off status.",
    href: (c) => `/api/exports/sponsorship/${c}`,
    format: "Excel",
    file: (c) => `${c}-sponsor-report.xlsx`,
    icon: FileSpreadsheet,
  },
  schedule: {
    title: "Signage schedule",
    purpose: "One sheet per hall plus a summary, with each sign-off step as a column.",
    href: (c) => `/api/exports/schedule/${c}`,
    format: "Excel",
    file: (c) => `${c}-signage-schedule.xlsx`,
    icon: FileSpreadsheet,
  },
  stand_register: {
    title: "Stand approval register",
    purpose: "Exhibitors, complexity, outcome, conditions, approver names and dates.",
    href: (c) => `/api/exports/stand-register/${c}`,
    format: "Excel",
    file: (c) => `${c}-stand-register.xlsx`,
    icon: FileText,
  },
};

/**
 * Reports: the files people send out, grouped by who receives them, each
 * with what it covers and who last downloaded it. Downloads are logged; the
 * last ten are under Download history.
 */
export default async function ReportsPage({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  if (!hasFeature(session.actor, "reports")) {
    return <SectionUnavailable feature="reports" backHref={`/${editionCode}/dashboard`} />;
  }
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();
  const editionId = ed.edition.id;
  const code = ed.edition.code;

  const allowed = (kind: ReportKind) =>
    (kind !== "stand_register" || standsEnabled) &&
    can(session.actor, { type: "export.run", kind });
  const groups = visibleGroups(allowed);
  const header = (
    <PageHeader
      title="Reports"
      description="Download schedules and packs for the venue, contractors and sponsors."
    />
  );
  if (groups.length === 0) {
    return (
      <Page width="narrow">
        {header}
        <EmptyState
          icon={Lock}
          title="Downloads are limited to editors"
          description="Ask a super admin if you need the signage schedule or the venue pack."
        />
      </Page>
    );
  }

  const live = and(eq(signageItems.editionId, editionId), isNull(signageItems.deletedAt));
  const [recent, lastByKind, hallRows, signageRow, allRows, exhibitorRow] = await Promise.all([
    db
      .select({ exp: exportsTable, user: users })
      .from(exportsTable)
      .leftJoin(users, eq(exportsTable.generatedBy, users.id))
      .where(eq(exportsTable.editionId, editionId))
      .orderBy(desc(exportsTable.createdAt))
      .limit(10),
    db
      .selectDistinctOn([exportsTable.kind], {
        kind: exportsTable.kind,
        at: exportsTable.createdAt,
        name: users.fullName,
        email: users.email,
      })
      .from(exportsTable)
      .leftJoin(users, eq(exportsTable.generatedBy, users.id))
      .where(eq(exportsTable.editionId, editionId))
      .orderBy(exportsTable.kind, desc(exportsTable.createdAt)),
    db
      .select({ id: halls.id, name: halls.name })
      .from(halls)
      .where(eq(halls.editionId, editionId))
      .orderBy(asc(halls.sortOrder), asc(halls.name)),
    // The schedule, install and sponsor exports cover signage and sponsorship items.
    db
      .select({
        items: sql<number>`count(*)::int`,
        withInstallDate: sql<number>`(count(*) filter (where ${signageItems.installDate} is not null))::int`,
        sponsored: sql<number>`(count(*) filter (where ${signageItems.sponsorId} is not null))::int`,
        sponsors: sql<number>`count(distinct ${signageItems.sponsorId})::int`,
      })
      .from(signageItems)
      .where(and(live, inArray(signageItems.kind, [...SIGNAGE_KINDS]))),
    // The venue pack and the labels cover every live item.
    db
      .select({
        hallId: signageItems.hallId,
        n: sql<number>`count(*)::int`,
        venue: sql<number>`(count(*) filter (where ${signageItems.requiresVenueApproval}))::int`,
      })
      .from(signageItems)
      .where(live)
      .groupBy(signageItems.hallId),
    standsEnabled
      ? db
          .select({ n: sql<number>`count(*)::int` })
          .from(exhibitors)
          .where(eq(exhibitors.editionId, editionId))
      : Promise.resolve([{ n: 0 }]),
  ]);

  const perHall = new Map(allRows.map((r) => [r.hallId, Number(r.n)]));
  const counts: ReportCounts = {
    items: Number(signageRow[0]?.items ?? 0),
    halls: hallRows.length,
    withInstallDate: Number(signageRow[0]?.withInstallDate ?? 0),
    sponsored: Number(signageRow[0]?.sponsored ?? 0),
    sponsors: Number(signageRow[0]?.sponsors ?? 0),
    venueItems: allRows.reduce((n, r) => n + Number(r.venue), 0),
    labels: allRows.reduce((n, r) => n + Number(r.n), 0),
    exhibitors: Number(exhibitorRow[0]?.n ?? 0),
  };
  const last = new Map(lastByKind.map((r) => [r.kind, r]));
  const canImport =
    can(session.actor, { type: "signage.create" }) && hasFeature(session.actor, "signage");

  return (
    <Page width="narrow" className="max-w-4xl">
      {header}

      {groups.map((group) => (
        <section key={group.id} aria-labelledby={`reports-${group.id}`} className="space-y-2">
          <h2 id={`reports-${group.id}`} className="text-sm font-semibold">
            {group.title}
          </h2>
          <ul className="divide-y rounded-lg border">
            {group.kinds.map((kind) => {
              const r = REPORTS[kind];
              const Icon = r.icon;
              const lastRow = last.get(EXPORT_LOG_KIND[kind]);
              return (
                <li
                  key={kind}
                  id={kind === "venue_pack" ? "venue" : undefined}
                  className="flex scroll-mt-20 flex-col gap-3 p-4 sm:flex-row sm:items-start"
                >
                  <span className="bg-muted text-muted-foreground hidden size-9 shrink-0 items-center justify-center rounded-full sm:flex">
                    <Icon className="size-4" aria-hidden />
                  </span>
                  <div className="min-w-0 flex-1 space-y-1">
                    <h3 className="text-sm font-semibold">
                      {r.title}{" "}
                      <span className="text-muted-foreground text-xs font-normal">{r.format}</span>
                    </h3>
                    <p className="text-muted-foreground text-sm">{r.purpose}</p>
                    <p className="text-sm">{scopeLine(kind, counts)}</p>
                    <p className="text-muted-foreground text-xs">
                      {lastRow
                        ? `Last downloaded by ${lastRow.name || lastRow.email || "someone"} · ${formatDateTime(lastRow.at)}`
                        : "Not downloaded yet"}
                    </p>
                    {kind === "spec_labels" && hallRows.length > 1 && (
                      <div className="flex flex-wrap items-center gap-2 pt-1">
                        <span className="text-muted-foreground text-xs">One hall:</span>
                        {hallRows.map((h) => (
                          <DownloadButton
                            key={h.id}
                            href={`${r.href(code)}?hall=${h.id}`}
                            label={`${h.name} (${perHall.get(h.id) ?? 0})`}
                            ariaLabel={`${h.name} (${perHall.get(h.id) ?? 0}): download its spec labels`}
                            reportName={`Spec labels for ${h.name}`}
                            fallbackName={`${code}-spec-labels.pdf`}
                            variant="ghost"
                          />
                        ))}
                      </div>
                    )}
                  </div>
                  <div className="shrink-0">
                    <DownloadButton
                      href={r.href(code)}
                      label={`Download ${r.format}`}
                      ariaLabel={`Download ${r.format}: ${r.title}`}
                      reportName={r.title}
                      fallbackName={r.file(code)}
                    />
                  </div>
                </li>
              );
            })}
          </ul>
          {group.id === "venue" && (
            <p className="text-muted-foreground text-xs">
              Approval certificates are on each item&apos;s page once it is signed off.
            </p>
          )}
        </section>
      ))}

      {canImport && (
        <p className="text-muted-foreground text-sm">
          Bringing in a schedule from a spreadsheet?{" "}
          <Link href={`/${code}/signage?import=1`} className="link">
            Import a schedule from the Signage page
          </Link>
        </p>
      )}

      <details className="group rounded-lg border">
        <summary className="flex cursor-pointer list-none items-center gap-2 px-4 py-3 text-sm font-semibold select-none [&::-webkit-details-marker]:hidden">
          <History className="text-muted-foreground size-4" aria-hidden />
          Download history
          <span className="text-muted-foreground font-normal">
            (last {Math.min(recent.length, 10)})
          </span>
          <ChevronRight
            className="text-muted-foreground ml-auto size-4 transition-transform group-open:rotate-90"
            aria-hidden
          />
        </summary>
        {recent.length === 0 ? (
          <p className="text-muted-foreground px-4 pb-4 text-sm">
            Nothing yet. Each download is listed here so you can see who took what, and when.
          </p>
        ) : (
          <ul className="divide-y border-t text-sm">
            {recent.map(({ exp, user }) => (
              <li
                key={exp.id}
                className="flex flex-wrap justify-between gap-x-3 gap-y-0.5 px-4 py-2"
              >
                <span>{statusLabel(exp.kind)}</span>
                <span className="text-muted-foreground">
                  {user?.fullName || user?.email || "Someone"} · {formatDateTime(exp.createdAt)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </details>
    </Page>
  );
}
