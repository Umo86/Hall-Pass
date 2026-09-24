import Link from "next/link";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { events, venues } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { listEditions } from "@/lib/queries/editions";
import { formatDate } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import {
  CloneEditionDialog,
  CreateEditionDialog,
  EditEditionDialog,
} from "@/components/editions/edition-forms";
import { Scene } from "@/components/scene";
import { brandImage } from "@/lib/brand-images";

export const metadata = { title: "Editions" };
export const dynamic = "force-dynamic";

export default async function EditionsPage() {
  const session = await requireStaffSession();
  const orgId = session.organisation.id;
  const [rows, eventRows, venueRows] = await Promise.all([
    listEditions(session.organisation.id),
    db.select().from(events).where(eq(events.organisationId, orgId)),
    db.select().from(venues).where(eq(venues.organisationId, orgId)),
  ]);
  const canManage = can(session.actor, { type: "settings.manage" });
  const canArchive = can(session.actor, { type: "users.manage" });

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
                {canManage && <th className="px-3 py-2" />}
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
                  {canManage && (
                    <td className="px-3 py-2 text-right">
                      <EditEditionDialog
                        edition={{
                          id: r.edition.id,
                          code: r.edition.code,
                          name: r.edition.name,
                          status: r.edition.status,
                          buildStart: r.edition.buildStart,
                          buildEnd: r.edition.buildEnd,
                          openStart: r.edition.openStart,
                          openEnd: r.edition.openEnd,
                          breakdownEnd: r.edition.breakdownEnd,
                          signageBudget: r.edition.signageBudget,
                        }}
                        canArchive={canArchive}
                      />
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
