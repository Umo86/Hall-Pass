/**
 * The gate of app/api/admin/move-database: pure (request + environment in,
 * decision out), unit-tested in tests/unit/move-route-auth.test.ts.
 *
 * 1. MOVE_DATABASE_TOKEN unset, "off" or shorter than 32 characters → 404:
 *    the tool doesn't exist unless switched on.
 * 2. The token comes from `Authorization: Bearer <t>` or `?token=<t>`
 *    (the Vercel MCP can only send a GET with no headers); compared in
 *    constant time → else 401.
 * 3. `step` must be known → else 400; steps that change something also need
 *    `confirm=<step>`.
 * 4. Guards that need no database: the tool never copies into the live
 *    database, and `finish` runs only once the app is on Neon. (Copying
 *    from the live database needs it frozen: copy checks that, as it needs
 *    the database; `unfrozen=1` overrides it when freezing is refused.)
 */
import { createHash, timingSafeEqual } from "node:crypto";
import { databaseTarget, type Env } from "../urls";

export const MOVE_STEPS = [
  "check",
  "files",
  "freeze",
  "unfreeze",
  "copy",
  "verify",
  "finish",
  "back-copy",
] as const;
export type MoveStep = (typeof MOVE_STEPS)[number];
export type MoveDb = "supabase" | "neon";

const MUTATING: ReadonlySet<MoveStep> = new Set([
  "freeze",
  "unfreeze",
  "copy",
  "finish",
  "back-copy",
]);
const DBS: readonly MoveDb[] = ["supabase", "neon"];

export type MoveRequest = {
  step: MoveStep;
  from: MoveDb;
  to: MoveDb;
  /** files, freeze, unfreeze: the database acted on. */
  db: MoveDb;
  live: MoveDb;
  replace: boolean;
  /** copy, back-copy: copy from the live database although it isn't frozen. */
  unfrozen: boolean;
  batch: number;
  detail: boolean;
  expect: string | null;
  warnings: string[];
};

export type MoveDecision =
  { ok: true; request: MoveRequest } | { ok: false; status: 400 | 401 | 404 | 409; error: string };

const sha = (s: string) => createHash("sha256").update(s).digest();

/** Constant-time comparison (equal-length digests, so the length isn't leaked either). */
export function tokenMatches(given: string, expected: string): boolean {
  return timingSafeEqual(sha(given), sha(expected));
}

export function authoriseMove(
  request: { url: string; headers: Pick<Headers, "get"> },
  env: Env,
): MoveDecision {
  const expected = (env.MOVE_DATABASE_TOKEN ?? "").trim();
  if (expected.length < 32 || expected.toLowerCase() === "off") {
    return { ok: false, status: 404, error: "Not found" };
  }
  const url = new URL(request.url);
  const params = url.searchParams;
  const bearer = /^Bearer\s+(.+)$/i.exec(request.headers.get("authorization") ?? "")?.[1]?.trim();
  const given = bearer ?? params.get("token") ?? "";
  if (!given || !tokenMatches(given, expected)) {
    return { ok: false, status: 401, error: "Unauthorised" };
  }

  const step = params.get("step") as MoveStep | null;
  if (!step || !MOVE_STEPS.includes(step)) {
    return { ok: false, status: 400, error: `step must be one of ${MOVE_STEPS.join(", ")}` };
  }
  if (MUTATING.has(step) && params.get("confirm") !== step) {
    return { ok: false, status: 400, error: `This step changes a database: add confirm=${step}` };
  }

  const pick = (name: string): MoveDb | null | "bad" => {
    const v = params.get(name);
    if (v === null || v === "") return null;
    return (DBS as readonly string[]).includes(v) ? (v as MoveDb) : "bad";
  };
  const fromParam = pick("from");
  const toParam = pick("to");
  const dbParam = pick("db");
  if (fromParam === "bad" || toParam === "bad" || dbParam === "bad") {
    return { ok: false, status: 400, error: "from, to and db must be supabase or neon" };
  }
  const batchRaw = params.get("batch");
  const batch = batchRaw === null || batchRaw === "" ? 500 : Number(batchRaw);
  if (!Number.isInteger(batch) || batch < 50 || batch > 2000) {
    return { ok: false, status: 400, error: "batch must be a whole number from 50 to 2000" };
  }

  const live: MoveDb = databaseTarget(env) === "neon" ? "neon" : "supabase";
  const warnings: string[] = [];
  let from: MoveDb = fromParam ?? "supabase";
  let to: MoveDb = toParam ?? (from === "supabase" ? "neon" : "supabase");
  let replace = params.get("replace") === "1";

  if (step === "back-copy") {
    // Neon → Supabase, after people have used Neon (a lossless rollback).
    if ((fromParam && fromParam !== "neon") || (toParam && toParam !== "supabase")) {
      return { ok: false, status: 400, error: "back-copy always copies neon to supabase" };
    }
    from = "neon";
    to = "supabase";
    // Supabase always holds the earlier data, so a back-copy always replaces it.
    replace = true;
  }
  if (from === to) return { ok: false, status: 400, error: "from and to must differ" };

  if ((step === "freeze" || step === "unfreeze") && !dbParam) {
    return { ok: false, status: 400, error: `${step} needs db=supabase or db=neon` };
  }
  const db: MoveDb = dbParam ?? live;

  if ((step === "copy" || step === "back-copy") && to === live) {
    return {
      ok: false,
      status: 409,
      error: `Refused: ${to} is the live database (the app runs on it), and the tool never copies into it`,
    };
  }
  if (step === "finish") {
    if (live !== "neon") {
      return {
        ok: false,
        status: 409,
        error: "Refused: finish runs only once the app is on Neon (DATABASE_TARGET=neon)",
      };
    }
    if (!params.get("expect")) {
      return {
        ok: false,
        status: 400,
        error: "finish needs expect=<the fingerprint copy returned>",
      };
    }
    from = "supabase";
    to = "neon";
  }
  if (step === "freeze" && db === live) {
    warnings.push(`${db} is the live database: the app is read-only until unfreeze`);
  }

  return {
    ok: true,
    request: {
      step,
      from,
      to,
      db,
      live,
      replace,
      unfrozen: params.get("unfrozen") === "1",
      batch,
      detail: params.get("detail") === "1",
      expect: params.get("expect"),
      warnings,
    },
  };
}
