import { notFound } from "next/navigation";
import { desc, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { exports as exportsTable, users } from "@/lib/db/schema";
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

  const canExport = can(session.actor, { type: "export.run", kind: "schedule" });
  const canImport = can(session.actor, { type: "signage.create" });
  const recent = await db
    .select({ exp: exportsTable, user: users })
    .from(exportsTable)
    .leftJoin(users, eq(exportsTable.generatedBy, users.id))
    .where(eq(exportsTable.editionId, ed.edition.id))
    .orderBy(desc(exportsTable.createdAt))
    .limit(20);

  const exportsList = [
    {
      kind: "signage_schedule",
      title: "Signage schedule (Excel)",
      description: "One sheet per hall plus a summary; approval status per step as columns.",
      href: `/api/exports/schedule/${ed.edition.code}`,
    },
    {
      kind: "stand_register",
      title: "Stand approval register (Excel)",
      description: "Exhibitors, complexity, outcome, conditions, approver names and dates.",
      href: `/api/exports/stand-register/${ed.edition.code}`,
    },
    {
      kind: "contractor_schedule",
      title: "Contractor install schedule (Excel)",
      description:
        "What goes up where and when — a sheet per install contractor, plus deliveries.",
      href: `/api/exports/contractor-schedule/${ed.edition.code}`,
    },
    {
      kind: "venue_pack",
      title: "Venue submission pack (Excel)",
      description:
        "Every rigged or venue-approval item with weights, fixings and approval state.",
      href: `/api/exports/venue-pack/${ed.edition.code}`,
    },
  ];

  return (
    <div className="flex max-w-4xl flex-col gap-6 p-6">
      <h1 className="text-xl font-semibold tracking-tight">Reports & exports</h1>

      {canExport && (
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
          <div className="rounded-lg border p-4">
            <p className="text-sm font-semibold">Approval certificate & spec label (PDF)</p>
            <p className="text-muted-foreground mt-1 text-sm">
              Generated per item from its detail page (Production tab), with the locked versions,
              SHA-256 prefixes and a QR code to the live record.
            </p>
          </div>
        </section>
      )}

      {canImport && <ImportPanel editionId={ed.edition.id} />}

      <section>
        <h2 className="mb-2 text-sm font-semibold">Recently generated</h2>
        {recent.length === 0 ? (
          <p className="text-muted-foreground text-sm">
            Nothing yet — generated files are listed here and expire after 7 days.
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
