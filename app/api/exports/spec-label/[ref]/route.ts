import { NextResponse } from "next/server";
import { db } from "@/lib/db/client";
import { getSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { getItemByRef } from "@/lib/queries/signage";
import { renderSpecLabel } from "@/lib/exports/pdf";
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
  if (!can(session.actor, { type: "signage.view", item: itemAuthzCtx(bundle) })) {
    return NextResponse.json({ error: "Not permitted" }, { status: 403 });
  }

  const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? "";
  const data = await renderSpecLabel({
    brandName: session.organisation.brandName,
    ref: item.ref,
    name: item.name,
    fields: [
      ["Size", item.widthMm && item.heightMm ? `${item.widthMm} × ${item.heightMm} mm` : "—"],
      ["Quantity", String(item.quantity)],
      ["Material", item.material ?? "—"],
      ["Finish", item.finish ?? "—"],
      ["Fixing", item.fixingMethod ? statusLabel(item.fixingMethod) : "—"],
      ["Install", item.installDate ? formatDate(item.installDate) : "—"],
    ],
    qrUrl: `${appUrl}/q/${item.ref}`,
  });
  return recordAndServeExport({
    session,
    editionId: bundle.edition.id,
    kind: "spec_label",
    fileName: `${item.ref}-spec-label.pdf`,
    ext: "pdf",
    data,
  });
}
