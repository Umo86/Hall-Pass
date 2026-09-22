import Link from "next/link";
import { db } from "@/lib/db/client";
import { events, venues } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { listEditions } from "@/lib/queries/editions";
import { formatDate } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import { CloneEditionDialog, CreateEditionDialog } from "@/components/editions/edition-forms";
import { Scene } from "@/components/scene";
import { brandImage } from "@/lib/brand-images";

export const metadata = { title: "Editions" };
export const dynamic = "force-dynamic";

export default async function EditionsPage() {
  const session = await requireStaffSession();
  const rows = await listEditions();
  const eventRows = await db.select().from(events);
  const venueRows = await db.select().from(venues);
  const canManage = can(session.actor, { type: "settings.manage" });

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-xl font-semibold tracking-tight">Editions</h1>
        {canManage && (
          <div className="flex gap-2">
            <CloneEditionDialog
              editions={rows.map((r) => ({
                id: r.edition.id,
                code: r.edition.code,
                name: r.edition.name,
              }))}
            />
            <CreateEditionDialog
              events={eventRows.map((e) => ({ id: e.id, name: e.name }))}
              venues={venueRows.map((v) => ({ id: v.id, name: v.name }))}
            />
          </div>
        )}
      </div>

      <Scene
        kind="hall"
        photo={brandImage("hero")}
        alt="Crew installing event signage in an exhibition hall"
        className="max-h-44 [&>svg]:h-44 [&>img]:h-44"
      />

      {rows.length === 0 ? (
        <div className="border-border text-muted-foreground flex h-48 flex-col items-center justify-center gap-3 rounded-lg border border-dashed text-sm">
          No editions yet.
        </div>
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-muted/50 text-muted-foreground border-b text-left">
                <th className="px-3 py-2 font-medium">Code</th>
                <th className="px-3 py-2 font-medium">Name</th>
                <th className="px-3 py-2 font-medium">Venue</th>
                <th className="px-3 py-2 font-medium">Build</th>
                <th className="px-3 py-2 font-medium">Open</th>
                <th className="px-3 py-2 font-medium">Status</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.edition.id} className="hover:bg-muted/30 border-b last:border-0">
                  <td className="px-3 py-2 font-medium">
                    <Link href={`/${r.edition.code}/dashboard`} className="hover:underline">
                      {r.edition.code}
                    </Link>
                  </td>
                  <td className="px-3 py-2">{r.edition.name}</td>
                  <td className="px-3 py-2">{r.venue.name}</td>
                  <td className="text-muted-foreground px-3 py-2">
                    {formatDate(r.edition.buildStart)} – {formatDate(r.edition.buildEnd)}
                  </td>
                  <td className="text-muted-foreground px-3 py-2">
                    {formatDate(r.edition.openStart)} – {formatDate(r.edition.openEnd)}
                  </td>
                  <td className="px-3 py-2">
                    <StatusBadge status={r.edition.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
