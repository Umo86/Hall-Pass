import { appUrl } from "@/lib/app-url";
import { db } from "@/lib/db/client";
import { can } from "@/lib/authz";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { getItemByRef, getLabelRows } from "@/lib/queries/signage";
import { renderSpecLabels } from "@/lib/exports/pdf";
import { labelWhen, labelWhere, specLabelFields } from "@/lib/exports/label-fields";
import { exportError, exportSession, recordAndServeExport, serveOrError } from "@/lib/exports/serve";

export async function GET(req: Request, { params }: { params: Promise<{ ref: string }> }) {
  const auth = await exportSession(req);
  if (auth.response) return auth.response;
  const { session } = auth;
  const { ref } = await params;
  const item = await getItemByRef(decodeURIComponent(ref));
  if (!item || item.deletedAt) return exportError(404, "That item could not be found.");
  const bundle = await loadItemBundle(db, item.id);
  if (!bundle || !can(session.actor, { type: "signage.view", item: itemAuthzCtx(bundle) })) {
    return exportError(404, "That item could not be found.");
  }

  return serveOrError(async () => {
    const [row] = await getLabelRows({ itemIds: [item.id] });
    const base = appUrl();
    const data = await renderSpecLabels({
      brandName: session.organisation.brandName,
      labels: [
        {
          ref: row.ref,
          name: row.name,
          where: labelWhere(row),
          when: labelWhen(row),
          fields: specLabelFields(row),
          qrUrl: `${base}/q/${row.ref}`,
        },
      ],
    });
    return recordAndServeExport({
      session,
      editionId: bundle.edition.id,
      kind: "spec_label",
      fileName: `${item.ref}-spec-label.pdf`,
      ext: "pdf",
      data,
    });
  });
}
