import { can } from "@/lib/authz";
import { buildStandRegister } from "@/lib/exports/excel";
import {
  exportEdition,
  exportError,
  exportSession,
  recordAndServeExport,
  serveOrError,
} from "@/lib/exports/serve";
import { standsEnabled } from "@/lib/config";

export async function GET(req: Request, { params }: { params: Promise<{ editionCode: string }> }) {
  const auth = await exportSession(req);
  if (auth.response) return auth.response;
  const { session } = auth;
  if (!standsEnabled) return exportError(404, "Stand exports are switched off.");
  if (!can(session.actor, { type: "export.run", kind: "stand_register" })) {
    return exportError(403, "Your role can't download the stand register.");
  }
  const { editionCode } = await params;
  const edition = await exportEdition(session, editionCode);
  if (!edition) return exportError(404, "That event could not be found.");
  return serveOrError(async () => {
    const { workbook } = await buildStandRegister(edition.id);
    const data = Buffer.from(await workbook.xlsx.writeBuffer());
    return recordAndServeExport({
      session,
      editionId: edition.id,
      kind: "stand_register",
      fileName: `${edition.code}-stand-approval-register.xlsx`,
      ext: "xlsx",
      data,
    });
  });
}
