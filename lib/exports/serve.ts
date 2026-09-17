import "server-only";
import { NextResponse } from "next/server";
import { db } from "@/lib/db/client";
import { exports as exportsTable } from "@/lib/db/schema";
import { writeAudit } from "@/lib/audit";
import { putObject } from "@/lib/storage";
import type { Session } from "@/lib/auth/actor";

const CONTENT_TYPES: Record<string, string> = {
  xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  pdf: "application/pdf",
};

/** Store, record, audit-log and stream an export in one go. */
export async function recordAndServeExport(opts: {
  session: Session;
  editionId: string;
  kind: string;
  fileName: string;
  ext: "xlsx" | "pdf";
  data: Buffer;
  filters?: Record<string, unknown>;
}): Promise<NextResponse> {
  const storagePath = `${opts.session.organisation.id}/${opts.editionId}/${Date.now()}-${opts.fileName}`;
  await putObject("exports", storagePath, opts.data).catch(() => {
    // Storage is best-effort for exports; the download still succeeds.
  });
  await db.transaction(async (tx) => {
    await tx.insert(exportsTable).values({
      editionId: opts.editionId,
      kind: opts.kind,
      filters: opts.filters ?? {},
      filePath: storagePath,
      generatedBy: opts.session.user.id,
      expiresAt: new Date(Date.now() + 7 * 86_400_000),
    });
    await writeAudit(tx, {
      organisationId: opts.session.organisation.id,
      editionId: opts.editionId,
      actorUserId: opts.session.user.id,
      entityType: "export",
      action: "export",
      after: { kind: opts.kind, fileName: opts.fileName },
      summary: `Export generated: ${opts.kind}`,
    });
  });
  return new NextResponse(new Uint8Array(opts.data), {
    headers: {
      "Content-Type": CONTENT_TYPES[opts.ext],
      "Content-Disposition": `attachment; filename="${opts.fileName}"`,
    },
  });
}
