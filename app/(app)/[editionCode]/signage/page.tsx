import Link from "next/link";
import { notFound } from "next/navigation";
import { Trash2 } from "lucide-react";
import { and, asc, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { suppliers } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { plural } from "@/lib/format";
import { can, hasFeature } from "@/lib/authz";
import { getEditionByCode } from "@/lib/queries/editions";
import { countDeletedItems, listScheduleRows } from "@/lib/queries/signage";
import {
  QUICK_FILTERS,
  QUICK_FILTER_LABELS,
  SIGNAGE_STAGES,
  STAGE_LABELS,
  type SignageStage,
} from "@/lib/domain/signage";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { Page, PageHeader } from "@/components/page-header";
import { SectionUnavailable } from "@/components/section-unavailable";
import { ScheduleView } from "@/components/schedule/schedule-view";
import { loadTeam, personOptionsForAny } from "@/lib/people";
import { NewSignMenu } from "@/components/schedule/new-sign-menu";

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: { params: Promise<{ editionCode: string }> }) {
  const { editionCode } = await params;
  return { title: `Signage · ${editionCode.toUpperCase()}` };
}

const STAGES = Object.fromEntries(
  (Object.keys(SIGNAGE_STAGES) as SignageStage[]).map((key) => [
    key,
    { label: STAGE_LABELS[key], statuses: [...SIGNAGE_STAGES[key]] as string[] },
  ]),
);

const QUICK = QUICK_FILTERS.map((key) => ({ key, label: QUICK_FILTER_LABELS[key] }));

export default async function SignagePage({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  if (!hasFeature(session.actor, "signage")) {
    return <SectionUnavailable feature="signage" backHref={`/${editionCode}/dashboard`} />;
  }
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();
  const canSeeCosts = can(session.actor, { type: "costs.view" });
  const readOnly = editionIsReadOnly(ed.edition.status);
  const canCreate = can(session.actor, { type: "signage.create" }) && !readOnly;
  const canBulk = can(session.actor, { type: "signage.bulk" }) && !readOnly;
  const canImport = can(session.actor, { type: "signage.import" }) && !readOnly;
  const canRestore = can(session.actor, { type: "signage.restore" });
  const [allRows, supplierRows, deletedCount] = await Promise.all([
    listScheduleRows(ed.edition.id, {
      viewer: session.actor.kind === "staff" ? session.actor : undefined,
    }),
    // The bulk "Set supplier" picker: archived suppliers can't be chosen.
    db
      .select({ id: suppliers.id, name: suppliers.name })
      .from(suppliers)
      .where(
        and(eq(suppliers.organisationId, session.organisation.id), eq(suppliers.isArchived, false)),
      )
      .orderBy(asc(suppliers.name)),
    canRestore ? countDeletedItems(ed.edition.id) : 0,
  ]);
  // Bulk "Change owner": people who can own organiser or sponsor signage
  // (each item is checked again on the server).
  const owners = canBulk
    ? personOptionsForAny(
        await loadTeam(db, session.organisation.id),
        [
          { type: "owner", item: { kind: "signage", sponsored: false } },
          { type: "owner", item: { kind: "signage", sponsored: true } },
        ],
        { organisationId: session.organisation.id },
      )
    : [];
  // Cost figures never leave the server for people who can't see costs.
  const rows = allRows.map((r) =>
    canSeeCosts ? r : { ...r, costEstimate: null, costActual: null, poNumber: null },
  );

  return (
    <Page width="full" className="gap-4">
      <PageHeader
        title="Signage"
        description={`Every sign for ${ed.edition.name}: specs, artwork, sign-off and install.`}
        meta={plural(rows.length, "item")}
        actions={
          canCreate && (
            <NewSignMenu
              editionCode={ed.edition.code}
              editionId={ed.edition.id}
              canImport={canImport}
            />
          )
        }
      />
      <ScheduleView
        editionCode={ed.edition.code}
        editionId={ed.edition.id}
        rows={rows}
        suppliers={supplierRows}
        quickFilters={QUICK}
        stages={STAGES}
        canSeeCosts={canSeeCosts}
        canEdit={canCreate}
        canBulk={canBulk}
        canEditCosts={can(session.actor, { type: "costs.edit" })}
        canDelete={can(session.actor, { type: "signage.delete" })}
        canClose={can(session.actor, { type: "signage.close" })}
        owners={owners}
        meId={session.user.id}
      />
      {canRestore && deletedCount > 0 && (
        <p className="text-sm">
          <Link
            href={`/${ed.edition.code}/signage/deleted`}
            className="text-muted-foreground hover:text-foreground inline-flex items-center gap-1.5 py-2"
          >
            <Trash2 className="size-4" aria-hidden />
            Recently deleted ({deletedCount})
          </Link>
        </p>
      )}
    </Page>
  );
}
