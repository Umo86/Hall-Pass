import { and, eq } from "drizzle-orm";
import { appUrl } from "@/lib/app-url";
import { db } from "@/lib/db/client";
import { halls } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { getLabelRows } from "@/lib/queries/signage";
import { renderSpecLabels } from "@/lib/exports/pdf";
import { labelWhen, labelWhere, specLabelFields } from "@/lib/exports/label-fields";
import {
  exportEdition,
  exportError,
  exportSession,
  recordAndServeExport,
  serveOrError,
} from "@/lib/exports/serve";

/** All spec labels for a show (or one hall, ?hall=<id>) in one PDF, A6 per page. */
export async function GET(
  req: Request,
  { params }: { params: Promise<{ editionCode: string }> },
) {
  const auth = await exportSession(req);
  if (auth.response) return auth.response;
  const { session } = auth;
  if (!can(session.actor, { type: "export.run", kind: "spec_labels" })) {
    return exportError(403, "Your role can't print spec labels in bulk.");
  }
  const { editionCode } = await params;
  const edition = await exportEdition(session, editionCode);
  if (!edition) return exportError(404, "That show could not be found.");

  const hallId = new URL(req.url).searchParams.get("hall");
  let hallName: string | null = null;
  if (hallId) {
    const [hall] = await db
      .select({ name: halls.name })
      .from(halls)
      .where(and(eq(halls.id, hallId), eq(halls.editionId, edition.id)))
      .limit(1)
      .catch(() => []);
    if (!hall) return exportError(404, "That hall could not be found.");
    hallName = hall.name;
  }

  const rows = await getLabelRows({ editionId: edition.id, hallId: hallId ?? undefined });
  if (rows.length === 0) return exportError(404, "There are no items to label yet.");

  return serveOrError(async () => {
    const base = appUrl();
    const data = await renderSpecLabels({
      brandName: session.organisation.brandName,
      labels: rows.map((row) => ({
        ref: row.ref,
        name: row.name,
        where: labelWhere(row),
        when: labelWhen(row),
        fields: specLabelFields(row),
        qrUrl: `${base}/q/${row.ref}`,
      })),
    });
    const suffix = hallName ? `-${hallName.toLowerCase().replace(/[^a-z0-9]+/g, "-")}` : "";
    return recordAndServeExport({
      session,
      editionId: edition.id,
      kind: "spec_labels",
      fileName: `${edition.code}${suffix}-spec-labels.pdf`,
      ext: "pdf",
      data,
      filters: hallId ? { hallId } : {},
    });
  });
}
