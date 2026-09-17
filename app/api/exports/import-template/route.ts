import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { buildImportTemplate } from "@/lib/exports/import-template";

export async function GET() {
  const session = await getSession();
  if (!session) return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  if (!can(session.actor, { type: "signage.create" })) {
    return NextResponse.json({ error: "Not permitted" }, { status: 403 });
  }
  const data = await buildImportTemplate();
  return new NextResponse(new Uint8Array(data), {
    headers: {
      "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "Content-Disposition": 'attachment; filename="hall-pass-import-template.xlsx"',
    },
  });
}
