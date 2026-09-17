import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { getEditionByCode } from "@/lib/queries/editions";
import { buildScheduleWorkbook } from "@/lib/exports/excel";
import { recordAndServeExport } from "@/lib/exports/serve";

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ editionCode: string }> },
) {
  const session = await getSession();
  if (!session) return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  if (!can(session.actor, { type: "export.run", kind: "schedule" })) {
    return NextResponse.json({ error: "Not permitted" }, { status: 403 });
  }
  const { editionCode } = await params;
  const ed = await getEditionByCode(editionCode.toUpperCase());
  if (!ed) return NextResponse.json({ error: "Not found" }, { status: 404 });
  const includeCosts = can(session.actor, { type: "costs.view" });
  const { workbook } = await buildScheduleWorkbook(ed.edition.id, includeCosts);
  const data = Buffer.from(await workbook.xlsx.writeBuffer());
  return recordAndServeExport({
    session,
    editionId: ed.edition.id,
    kind: "signage_schedule",
    fileName: `${ed.edition.code}-signage-schedule.xlsx`,
    ext: "xlsx",
    data,
  });
}
