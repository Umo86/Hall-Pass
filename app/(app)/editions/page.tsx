import Link from "next/link";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { events, venues } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { listEditions, showLogoUrl } from "@/lib/queries/editions";
import { formatDate } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import {
  CloneEditionDialog,
  CreateEditionDialog,
  EditEditionDialog,
} from "@/components/editions/edition-forms";

export const metadata = { title: "Shows" };
export const dynamic = "force-dynamic";

export default async function ShowsPage() {
  const session = await requireStaffSession();
  const orgId = session.organisation.id;
  const [rows, eventRows, venueRows] = await Promise.all([
    listEditions(orgId),
    db.select().from(events).where(eq(events.organisationId, orgId)).orderBy(events.name),
    db.select().from(venues).where(eq(venues.organisationId, orgId)).orderBy(venues.name),
  ]);
  const logos = await Promise.all(rows.map((r) => showLogoUrl(r.edition.logoPath)));
  const canManage = can(session.actor, { type: "settings.manage" });
  const canArchive = can(session.actor, { type: "users.manage" });
  const venueOptions = venueRows.map((v) => ({ id: v.id, name: v.name, address: v.address }));

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Shows</h1>
          <p className="text-muted-foreground text-sm">
            Each show has its own signage, sponsorship, sign-offs and deadlines.
          </p>
        </div>
        {canManage && (
          <div className="flex gap-2">
            {rows.length > 0 && (
              <CloneEditionDialog
                editions={rows.map((r) => ({
                  id: r.edition.id,
                  code: r.edition.code,
                  name: r.edition.name,
                }))}
              />
            )}
            <CreateEditionDialog
              events={eventRows.map((e) => ({ id: e.id, name: e.name }))}
              venues={venueOptions}
            />
          </div>
        )}
      </div>

      {rows.length === 0 ? (
        <div className="border-border text-muted-foreground flex h-48 flex-col items-center justify-center gap-3 rounded-lg border border-dashed text-sm">
          No shows yet.{canManage ? " Use New show to set up the first one." : ""}
        </div>
      ) : (
        <ul className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {rows.map((r, i) => (
            <li key={r.edition.id} className="flex flex-col gap-3 rounded-lg border p-4">
              <div className="flex items-start gap-3">
                <div className="bg-muted/40 flex size-14 shrink-0 items-center justify-center overflow-hidden rounded-md border">
                  {logos[i] ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={logos[i]!}
                      alt={`${r.edition.name} logo`}
                      className="max-h-full max-w-full object-contain"
                    />
                  ) : (
                    <span className="text-muted-foreground text-xs font-semibold">
                      {r.edition.code.slice(0, 4)}
                    </span>
                  )}
                </div>
                <div className="min-w-0 flex-1">
                  <Link
                    href={`/${r.edition.code}/dashboard`}
                    className="font-semibold hover:underline"
                  >
                    {r.edition.name}
                  </Link>
                  <p className="text-muted-foreground text-xs">
                    {r.edition.code} · {r.event.name}
                  </p>
                </div>
                <StatusBadge status={r.edition.status} />
              </div>
              <dl className="text-muted-foreground grid grid-cols-[5.5rem_1fr] gap-x-2 gap-y-1 text-sm">
                <dt>Venue</dt>
                <dd className="text-foreground">
                  {r.venue.name}
                  {r.venue.address && (
                    <span className="text-muted-foreground block text-xs">{r.venue.address}</span>
                  )}
                </dd>
                <dt>Build</dt>
                <dd>
                  {formatDate(r.edition.buildStart)} – {formatDate(r.edition.buildEnd)}
                </dd>
                <dt>Open</dt>
                <dd>
                  {formatDate(r.edition.openStart)} – {formatDate(r.edition.openEnd)}
                </dd>
                <dt>Breakdown</dt>
                <dd>ends {formatDate(r.edition.breakdownEnd)}</dd>
              </dl>
              <div className="mt-auto flex flex-wrap gap-2">
                <Link
                  href={`/${r.edition.code}/signage`}
                  className="text-primary text-sm hover:underline"
                >
                  Signage →
                </Link>
                {canManage && (
                  <span className="ml-auto">
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
                        venueId: r.edition.venueId,
                        logoUrl: logos[i],
                      }}
                      venues={venueOptions}
                      canArchive={canArchive}
                    />
                  </span>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
