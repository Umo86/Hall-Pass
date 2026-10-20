import { NextResponse } from "next/server";
import { describeDbError } from "@/lib/db/diagnose";
import { checkDatabases } from "@/lib/db/move/check";
import { connectForMove, MoveRefused, type MoveSql } from "@/lib/db/move/connect";
import { copyDatabase } from "@/lib/db/move/copy";
import { checkFiles, readFileRefs } from "@/lib/db/move/files";
import { finishMove } from "@/lib/db/move/finish";
import { freeze, unfreeze } from "@/lib/db/move/freeze";
import { authoriseMove, type MoveDb, type MoveRequest } from "@/lib/db/move/route-auth";
import { schemaSignature, verifyDatabases } from "@/lib/db/move/verify";
import {
  databaseHostPort,
  databaseProjectOf,
  databaseProviderOf,
  databaseRegionOf,
  moveDatabaseUrls,
  regionCity,
} from "@/lib/db/urls";
import { s3Enabled, s3List } from "@/lib/storage";

export const dynamic = "force-dynamic";
export const maxDuration = 300;

/**
 * One-off move of the database from Supabase to Neon (and back, for a
 * lossless rollback). Off unless MOVE_DATABASE_TOKEN is set (32+ characters,
 * not "off"). A machine route like /api/cron/daily — secret-gated, no actor —
 * so it doesn't go through authz.can(); it never writes app data except
 * finish's one audit row, and never copies into the database the app runs on.
 *
 *   GET /api/admin/move-database?step=<step>&token=<MOVE_DATABASE_TOKEN>[&…]
 *
 * Steps (README → "Moving the database to Neon" has the runbook):
 * - check            read-only preflight of from → to (default supabase → neon)
 * - files            every file the database refers to exists in the bucket (db=, default live)
 * - freeze           db=supabase|neon, confirm=freeze: that database becomes read-only
 * - unfreeze         db=…, confirm=unfreeze
 * - copy             confirm=copy [&from=&to=] [&replace=1] [&batch=50–2000]; a live
 *                    source must be frozen first (unfrozen=1 only when it can't be)
 * - verify           [&from=&to=] [&detail=1]: live comparison
 * - finish           confirm=finish&expect=<copy's fingerprint>, once the app is on Neon
 * - back-copy        confirm=back-copy: copy neon → supabase, replacing Supabase's data
 * Replies are JSON { ok, step, …, warnings }: 200 when ok, 409 when refused
 * (nothing changed), 500 on an unexpected error. Hosts only, never URLs,
 * passwords or the token.
 */
async function handle(request: Request) {
  const decision = authoriseMove(request, process.env);
  if (!decision.ok) {
    log(
      new URL(request.url).searchParams.get("step") ?? "-",
      "-",
      "-",
      `refused-${decision.status}`,
    );
    return NextResponse.json({ ok: false, error: decision.error }, { status: decision.status });
  }
  const r = decision.request;
  const token = (process.env.MOVE_DATABASE_TOKEN ?? "").trim();
  const urls = moveDatabaseUrls(process.env);
  const opened: MoveSql[] = [];
  const open = async (which: MoveDb): Promise<MoveSql> => {
    const end = urls[which];
    if ("error" in end) throw new MoveRefused(`${which}: ${end.error}`);
    const sql = connectForMove(end.url);
    opened.push(sql);
    try {
      await sql`SELECT 1`;
    } catch (err) {
      throw new MoveRefused(
        `Could not connect to ${which} (${end.host}): ${describeDbError(err, end.url)}`,
      );
    }
    return sql;
  };
  const describe = (which: MoveDb) => {
    const end = urls[which];
    if ("error" in end) return { error: end.error };
    return {
      host: databaseHostPort(end.url),
      provider: databaseProviderOf(end.url),
      project: databaseProjectOf(end.url, process.env),
      region: databaseRegionOf(end.url),
    };
  };

  try {
    const body = await runStep(r, open, describe, urls);
    const ok = body.ok !== false;
    log(r.step, r.from, r.to, ok ? "ok" : "not-ok");
    return NextResponse.json(
      {
        ...body,
        ok,
        step: r.step,
        warnings: [...r.warnings, ...((body.warnings as string[]) ?? [])],
      },
      { status: ok ? 200 : 409 },
    );
  } catch (err) {
    const refused = err instanceof MoveRefused;
    const message = redact(err instanceof Error ? err.message : String(err), token);
    log(r.step, r.from, r.to, refused ? "refused" : "error");
    if (!refused) console.error("move-database failed:", message);
    return NextResponse.json(
      {
        ok: false,
        step: r.step,
        error: message,
        ...(refused && err.reasons.length
          ? { reasons: err.reasons.map((x) => redact(x, token)) }
          : {}),
        warnings: r.warnings,
      },
      { status: refused ? 409 : 500 },
    );
  } finally {
    await Promise.all(opened.map((sql) => sql.end({ timeout: 5 }).catch(() => {})));
  }
}

type Body = Record<string, unknown> & { ok?: boolean; warnings?: string[] };

async function runStep(
  r: MoveRequest,
  open: (which: MoveDb) => Promise<MoveSql>,
  describe: (which: MoveDb) => Record<string, unknown>,
  urls: ReturnType<typeof moveDatabaseUrls>,
): Promise<Body> {
  const functionRegion = process.env.VERCEL_REGION ?? null;
  switch (r.step) {
    case "check": {
      const src = await open(r.from);
      const dst = await open(r.to);
      const report = await checkDatabases(src, dst, {
        liveSource: r.from === r.live ? r.from : undefined,
      });
      return {
        live: r.live,
        functionRegion,
        from: r.from,
        to: r.to,
        ...report,
        source: { ...describe(r.from), ...report.source },
        target: { ...describe(r.to), ...report.target },
        ...(r.detail ? { sourceSchema: await schemaSignature(src, { detail: true }) } : {}),
      };
    }
    case "files": {
      if (!s3Enabled()) throw new MoveRefused("No file storage bucket is configured (S3_*)");
      const sql = await open(r.db);
      const report = await checkFiles(await readFileRefs(sql), s3List);
      return {
        db: r.db,
        bucket: process.env.S3_BUCKET ?? null,
        ...report,
        missingCount: report.missing.length,
        missing: report.missing.slice(0, 200),
      };
    }
    case "freeze": {
      const state = await freeze(await open(r.db));
      return { db: r.db, ...state };
    }
    case "unfreeze": {
      console.warn(`move-database: unfreezing ${r.db}`);
      const state = await unfreeze(await open(r.db));
      return { ok: !state.frozen, db: r.db, ...state };
    }
    case "copy":
    case "back-copy": {
      const src = await open(r.from);
      const dst = await open(r.to);
      const report = await copyDatabase(src, dst, {
        replace: r.replace,
        batchRows: r.batch,
        budgetMs: 270_000,
        liveSource: r.from === r.live ? r.from : undefined,
        allowUnfrozenSource: r.unfrozen,
      });
      return {
        live: r.live,
        functionRegion,
        from: r.from,
        to: r.to,
        ...report,
        warnings: report.check.warnings,
      };
    }
    case "verify": {
      const src = await open(r.from);
      const dst = await open(r.to);
      const report = await verifyDatabases(src, dst, { detail: r.detail });
      return { live: r.live, from: r.from, to: r.to, ...report };
    }
    case "finish": {
      const src = await open("supabase");
      const dst = await open("neon");
      const neon = urls.neon;
      const city = "url" in neon ? regionCity(databaseRegionOf(neon.url)) : null;
      const report = await finishMove(src, dst, {
        expect: r.expect!,
        summary: (n) =>
          `Database moved from Supabase to Neon${city ? ` (${city})` : ""}: ${n} rows verified`,
      });
      return { ok: report.sourceUnchanged, live: r.live, ...report };
    }
  }
}

function log(step: string, from: string, to: string, outcome: string) {
  console.log(`move-database step=${step} from=${from} to=${to} outcome=${outcome}`);
}

/** No URLs, credentials or the token in replies or logs. */
function redact(message: string, token: string): string {
  let out = message
    .replace(/postgres(ql)?:\/\/\S+/gi, "<database URL>")
    .replace(/\/\/[^@/\s]+@/g, "//***@");
  if (token) out = out.replaceAll(token, "<token>");
  return out.slice(0, 2000);
}

export const GET = handle;
export const POST = handle;
