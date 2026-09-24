import { notFound } from "next/navigation";
import { asc, desc, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { exports as exportsTable, halls, users } from "@/lib/db/schema";
import { standsEnabled } from "@/lib/config";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { getEditionByCode } from "@/lib/queries/editions";
import { formatDateTime, statusLabel } from "@/lib/format";
import { ImportPanel } from "@/components/reports/import-panel";

export const metadata = { title: "Reports" };
export const dynamic = "force-dynamic";

export default async function ReportsPage({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  const ed = await getEditionByCode(editionCode.toUpperCase());
  if (!ed) notFound();

  const canImport = can(session.actor, { type: "signage.create" });
  const [recent, hallRows] = await Promise.all([
    db
      .select({ exp: exportsTable, user: users })
      .from(exportsTable)
      .leftJoin(users, eq(exportsTable.generatedBy, users.id))
      .where(eq(exportsTable.editionId, ed.edition.id))
      .orderBy(desc(exportsTable.createdAt))
      .limit(20),
    db
      .select({ id: halls.id, name: halls.name })
      .from(halls)
      .where(eq(halls.editionId, ed.edition.id))
      .orderBy(asc(halls.sortOrder), asc(halls.name)),
  ]);

  const code = ed.edition.code;
  const exportsList = [
    {
      kind: "schedule",
      title: "Signage schedule (Excel)",
      description: "One sheet per hall plus a summary; sign-off status per step as columns.",
      href: `/api/exports/schedule/${code}`,
    },
    {
      kind: "sponsor_report",
      title: "Sponsor report (Excel)",
      description: "Everything sold to each sponsor — signage and sponsorship items — with sign-off status.",
      href: `/api/exports/sponsorship/${code}`,
    },
    {
      kind: "contractor_schedule",
      title: "Contractor install schedule (Excel)",
      description: "What goes up where and when — a sheet per install contractor, plus deliveries.",
      href: `/api/exports/contractor-schedule/${code}`,
    },
    {
      kind: "venue_pack",
      title: "Venue submission pack (Excel)",
      description: "Every rigged or venue-approval item with weights, fixings and approval state.",
      href: `/api/exports/venue-pack/${code}`,
    },
    ...(standsEnabled
      ? [
          {
            kind: "stand_register",
            title: "Stand approval register (Excel)",
            description: "Exhibitors, complexity, outcome, conditions, approver names and dates.",
            href: `/api/exports/stand-register/${code}`,
          },
        ]
      : []),
  ].filter((e) => can(session.actor, { type: "export.run", kind: e.kind }));
  const canLabels = can(session.actor, { type: "export.run", kind: "spec_labels" });

  return (
    <div className="flex max-w-4xl flex-col gap-6 p-4 sm:p-6">
      <h1 className="text-xl font-semibold tracking-tight">Reports & exports</h1>

      {(exportsList.length > 0 || canLabels) && (
        <section className="grid gap-3 sm:grid-cols-2">
          {exportsList.map((e) => (
            <a
              key={e.kind}
              href={e.href}
              className="hover:bg-muted/40 rounded-lg border p-4 transition-colors"
            >
              <p className="text-sm font-semibold">{e.title}</p>
              <p className="text-muted-foreground mt-1 text-sm">{e.description}</p>
            </a>
          ))}
          {canLabels && (
            <div className="rounded-lg border p-4">
              <p className="text-sm font-semibold">Spec labels (PDF)</p>
              <p className="text-muted-foreground mt-1 text-sm">
                One A6 label per item showing where it goes, install slot and a QR code — print
                them all or one hall at a time.
              </p>
              <div className="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-sm">
                <a className="text-primary hover:underline" href={`/api/exports/spec-labels/${code}`}>
                  All items
                </a>
                {hallRows.map((h) => (
                  <a
                    key={h.id}
                    className="text-primary hover:underline"
                    href={`/api/exports/spec-labels/${code}?hall=${h.id}`}
                  >
                    {h.name}
                  </a>
                ))}
              </div>
              <p className="text-muted-foreground mt-2 text-xs">
                Approval certificates are on each item&apos;s Production tab once it is signed off.
              </p>
            </div>
          )}
        </section>
      )}

      {canImport && <ImportPanel editionId={ed.edition.id} />}

      <section>
        <h2 className="mb-2 text-sm font-semibold">Recently generated</h2>
        {recent.length === 0 ? (
          <p className="text-muted-foreground text-sm">
            Nothing yet — each download is listed here so you can see who took what, and when.
          </p>
        ) : (
          <ul className="space-y-1 text-sm">
            {recent.map(({ exp, user }) => (
              <li key={exp.id} className="flex justify-between gap-3 rounded-md border px-3 py-2">
                <span>{statusLabel(exp.kind)}</span>
                <span className="text-muted-foreground">
                  {user?.fullName ?? "—"} · {formatDateTime(exp.createdAt)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
