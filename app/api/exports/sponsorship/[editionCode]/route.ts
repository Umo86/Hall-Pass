import { can } from "@/lib/authz";
import { buildSponsorWorkbook } from "@/lib/exports/excel";
import {
  exportEdition,
  exportError,
  exportSession,
  recordAndServeExport,
  serveOrError,
} from "@/lib/exports/serve";

export async function GET(
  req: Request,
  { params }: { params: Promise<{ editionCode: string }> },
) {
  const auth = await exportSession(req);
  if (auth.response) return auth.response;
  const { session } = auth;
  if (!can(session.actor, { type: "export.run", kind: "sponsor_report" })) {
    return exportError(403, "Your role can't download the sponsor report.");
  }
  const { editionCode } = await params;
  const edition = await exportEdition(session, editionCode);
  if (!edition) return exportError(404, "That show could not be found.");
  return serveOrError(async () => {
    const { workbook } = await buildSponsorWorkbook(edition.id, can(session.actor, { type: "costs.view" }));
    const data = Buffer.from(await workbook.xlsx.writeBuffer());
    return recordAndServeExport({
      session,
      editionId: edition.id,
      kind: "sponsor_report",
      fileName: `${edition.code}-sponsor-report.xlsx`,
      ext: "xlsx",
      data,
    });
  });
}
