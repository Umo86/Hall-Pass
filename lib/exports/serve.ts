import "server-only";
import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { editions, events, exports as exportsTable } from "@/lib/db/schema";
import { writeAudit } from "@/lib/audit";
import { getSession, type Session } from "@/lib/auth/actor";

const CONTENT_TYPES: Record<string, string> = {
  xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  pdf: "application/pdf",
};

function escapeHtml(s: string) {
  return s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

/**
 * A small readable page for a failed download — people click export links
 * directly, so raw JSON or a blank 500 would be all they see.
 */
export function exportError(status: number, message: string): NextResponse {
  const body = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Download not available</title></head><body style="font-family:system-ui,sans-serif;max-width:32rem;margin:4rem auto;padding:0 1rem;color:#171717"><h1 style="font-size:1.25rem">Download not available</h1><p>${escapeHtml(message)}</p><p><a href="javascript:history.back()" style="color:#4f46e5">Go back</a></p></body></html>`;
  return new NextResponse(body, {
    status,
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" },
  });
}

/** The session for an export route, or a redirect to sign in (then back here). */
export async function exportSession(
  req: Request,
): Promise<{ session: Session; response?: never } | { session?: never; response: NextResponse }> {
  const session = await getSession();
  if (session) return { session };
  const url = new URL(req.url);
  const next = `${url.pathname}${url.search}`;
  return { response: NextResponse.redirect(new URL(`/login?next=${encodeURIComponent(next)}`, url)) };
}

/** An edition of the signed-in organisation, looked up by its code. */
export async function exportEdition(session: Session, editionCode: string) {
  const [row] = await db
    .select({ edition: editions })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(
      and(
        eq(editions.code, editionCode.toUpperCase()),
        eq(events.organisationId, session.organisation.id),
      ),
    )
    .limit(1);
  return row?.edition ?? null;
}

/**
 * Record, audit-log and stream an export. Files are generated on demand and
 * not stored — the exports row is the history. A failed audit write is
 * logged rather than throwing away a file that rendered fine.
 */
export async function recordAndServeExport(opts: {
  session: Session;
  editionId: string;
  kind: string;
  fileName: string;
  ext: "xlsx" | "pdf";
  data: Buffer;
  filters?: Record<string, unknown>;
}): Promise<NextResponse> {
  try {
    await db.transaction(async (tx) => {
      await tx.insert(exportsTable).values({
        editionId: opts.editionId,
        kind: opts.kind,
        filters: opts.filters ?? {},
        filePath: opts.fileName,
        generatedBy: opts.session.user.id,
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
  } catch (err) {
    console.error("export: could not record", opts.kind, err);
  }
  return new NextResponse(new Uint8Array(opts.data), {
    headers: {
      "Content-Type": CONTENT_TYPES[opts.ext],
      "Content-Disposition": `attachment; filename="${opts.fileName.replace(/[^\w.-]/g, "_")}"`,
      "Cache-Control": "private, no-store",
    },
  });
}

/** Run an export's build step; any failure becomes a readable error page. */
export async function serveOrError(build: () => Promise<NextResponse>): Promise<NextResponse> {
  try {
    return await build();
  } catch (err) {
    console.error("export failed", err);
    return exportError(500, "Something went wrong building this file. Try again in a moment.");
  }
}
