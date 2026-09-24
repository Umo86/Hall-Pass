import { can } from "@/lib/authz";
import { buildContractorSchedule } from "@/lib/exports/excel";
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
  if (!can(session.actor, { type: "export.run", kind: "contractor_schedule" })) {
    return exportError(403, "Your role can't download the install schedule.");
  }
  const { editionCode } = await params;
  const edition = await exportEdition(session, editionCode);
  if (!edition) return exportError(404, "That show could not be found.");
  return serveOrError(async () => {
    const { workbook } = await buildContractorSchedule(edition.id);
    const data = Buffer.from(await workbook.xlsx.writeBuffer());
    return recordAndServeExport({
      session,
      editionId: edition.id,
      kind: "contractor_schedule",
      fileName: `${edition.code}-install-schedule.xlsx`,
      ext: "xlsx",
      data,
    });
  });
}
