import { can } from "@/lib/authz";
import { buildVenuePack } from "@/lib/exports/excel";
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
  if (!can(session.actor, { type: "export.run", kind: "venue_pack" })) {
    return exportError(403, "Your role can't download the venue pack.");
  }
  const { editionCode } = await params;
  const edition = await exportEdition(session, editionCode);
  if (!edition) return exportError(404, "That show could not be found.");
  return serveOrError(async () => {
    const { workbook } = await buildVenuePack(edition.id);
    const data = Buffer.from(await workbook.xlsx.writeBuffer());
    return recordAndServeExport({
      session,
      editionId: edition.id,
      kind: "venue_pack",
      fileName: `${edition.code}-venue-submission-pack.xlsx`,
      ext: "xlsx",
      data,
    });
  });
}
