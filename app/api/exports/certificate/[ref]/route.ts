import { appUrl } from "@/lib/app-url";
import { db } from "@/lib/db/client";
import { can } from "@/lib/authz";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { getItemByRef, getItemInstances, getItemVersions, getLabelRows } from "@/lib/queries/signage";
import { renderApprovalCertificate, type CertificateStep } from "@/lib/exports/pdf";
import { labelWhere } from "@/lib/exports/label-fields";
import { exportError, exportSession, recordAndServeExport, serveOrError } from "@/lib/exports/serve";
import { APPROVED_OR_LATER } from "@/lib/status/signage";
import { formatDate, statusLabel } from "@/lib/format";

export async function GET(req: Request, { params }: { params: Promise<{ ref: string }> }) {
  const auth = await exportSession(req);
  if (auth.response) return auth.response;
  const { session } = auth;
  const { ref } = await params;
  const item = await getItemByRef(decodeURIComponent(ref));
  if (!item || item.deletedAt) return exportError(404, "That item could not be found.");
  const bundle = await loadItemBundle(db, item.id);
  if (!bundle) return exportError(404, "That item could not be found.");
  if (
    !can(session.actor, { type: "export.run", kind: "certificate" }) ||
    !can(session.actor, { type: "signage.view", item: itemAuthzCtx(bundle) })
  ) {
    return exportError(403, "Your role can't download approval certificates.");
  }
  if (!APPROVED_OR_LATER.includes(item.status)) {
    return exportError(
      409,
      `${item.ref} is not signed off yet (${statusLabel(item.status).toLowerCase()}) — the certificate is available once every sign-off is in.`,
    );
  }

  return serveOrError(async () => {
    const [instances, versions, [label]] = await Promise.all([
      getItemInstances(item.id),
      getItemVersions(item.id),
      getLabelRows({ itemIds: [item.id] }),
    ]);
    const versionById = new Map(versions.map((v) => [v.version.id, v.version.versionNumber]));
    const steps: CertificateStep[] = instances
      .filter(
        ({ instance }) =>
          instance.runNumber === item.currentRunNumber &&
          instance.status !== "skipped" &&
          instance.status !== "invalidated",
      )
      .sort((a, b) => a.instance.sortOrderSnapshot - b.instance.sortOrderSnapshot)
      .map(({ instance, decider }) => ({
        name: instance.stepNameSnapshot,
        status: instance.status,
        deciderName: decider?.fullName || decider?.email || null,
        decidedAt: instance.decidedAt,
        versionLabel: instance.lockedVersionId
          ? `v${versionById.get(instance.lockedVersionId) ?? "?"}`
          : null,
        shaPrefix: instance.lockedSha256?.slice(0, 12) ?? null,
        conditions: instance.conditionsText,
      }));

    const where = label ? labelWhere(label) : null;
    const fields: Array<[string, string]> = [
      ["Status", statusLabel(item.status)],
      ...(where ? ([["Where", where]] as Array<[string, string]>) : []),
      ["Size", item.widthMm && item.heightMm ? `${item.widthMm} × ${item.heightMm} mm` : "—"],
      ["Quantity", String(item.quantity)],
    ];
    if (item.kind === "signage") {
      fields.push(
        ["Fixing", item.fixingMethod ? statusLabel(item.fixingMethod) : "—"],
        ["Install", item.installDate ? formatDate(item.installDate) : "—"],
      );
    } else if (label?.sponsorName) {
      fields.push(["Sponsor", label.sponsorName]);
    }

    const data = await renderApprovalCertificate({
      brandName: session.organisation.brandName,
      ref: item.ref,
      title: item.name,
      editionName: bundle.edition.name,
      fields,
      steps,
      recordUrl: `${appUrl()}/q/${item.ref}`,
    });
    return recordAndServeExport({
      session,
      editionId: bundle.edition.id,
      kind: "approval_certificate",
      fileName: `${item.ref}-approval-certificate.pdf`,
      ext: "pdf",
      data,
    });
  });
}
