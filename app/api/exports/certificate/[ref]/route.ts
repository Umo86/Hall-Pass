import { NextResponse } from "next/server";
import { db } from "@/lib/db/client";
import { getSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { getItemByRef, getItemInstances, getItemVersions } from "@/lib/queries/signage";
import { renderApprovalCertificate, type CertificateStep } from "@/lib/exports/pdf";
import { recordAndServeExport } from "@/lib/exports/serve";
import { formatDate, statusLabel } from "@/lib/format";

export async function GET(_req: Request, { params }: { params: Promise<{ ref: string }> }) {
  const session = await getSession();
  if (!session) return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  const { ref } = await params;
  const item = await getItemByRef(decodeURIComponent(ref));
  if (!item || item.deletedAt) return NextResponse.json({ error: "Not found" }, { status: 404 });
  const bundle = await loadItemBundle(db, item.id);
  if (!bundle) return NextResponse.json({ error: "Not found" }, { status: 404 });
  if (
    !can(session.actor, { type: "export.run", kind: "certificate" }) ||
    !can(session.actor, { type: "signage.view", item: itemAuthzCtx(bundle) })
  ) {
    return NextResponse.json({ error: "Not permitted" }, { status: 403 });
  }

  const [instances, versions] = await Promise.all([
    getItemInstances(item.id),
    getItemVersions(item.id),
  ]);
  const versionById = new Map(versions.map((v) => [v.version.id, v.version.versionNumber]));
  const steps: CertificateStep[] = instances
    .filter(
      ({ instance }) =>
        instance.runNumber === item.currentRunNumber && instance.status !== "skipped",
    )
    .sort((a, b) => a.instance.sortOrderSnapshot - b.instance.sortOrderSnapshot)
    .map(({ instance, decider }) => ({
      name: instance.stepNameSnapshot,
      status: instance.status,
      deciderName: decider?.fullName ?? decider?.email ?? null,
      decidedAt: instance.decidedAt,
      versionLabel: instance.lockedVersionId
        ? `v${versionById.get(instance.lockedVersionId) ?? "?"}`
        : null,
      shaPrefix: instance.lockedSha256?.slice(0, 12) ?? null,
      conditions: instance.conditionsText,
    }));

  const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? "";
  const data = await renderApprovalCertificate({
    brandName: session.organisation.brandName,
    ref: item.ref,
    title: item.name,
    editionName: bundle.edition.name,
    fields: [
      ["Status", statusLabel(item.status)],
      ["Size", item.widthMm && item.heightMm ? `${item.widthMm} × ${item.heightMm} mm` : "—"],
      ["Quantity", String(item.quantity)],
      ["Fixing", item.fixingMethod ? statusLabel(item.fixingMethod) : "—"],
      ["Install", item.installDate ? formatDate(item.installDate) : "—"],
      ["Run", `#${item.currentRunNumber}`],
    ],
    steps,
    recordUrl: `${appUrl}/q/${item.ref}`,
  });
  return recordAndServeExport({
    session,
    editionId: bundle.edition.id,
    kind: "approval_certificate",
    fileName: `${item.ref}-approval-certificate.pdf`,
    ext: "pdf",
    data,
  });
}
