import { describe, expect, it } from "vitest";
import { authoriseMove, tokenMatches } from "@/lib/db/move/route-auth";

const TOKEN = "a".repeat(64);
const BASE = "https://hall-pass.example/api/admin/move-database";

function call(query: string, env: Record<string, string | undefined> = {}, auth?: string) {
  const headers = new Headers(auth ? { authorization: auth } : {});
  return authoriseMove(
    { url: `${BASE}?${query}`, headers },
    { MOVE_DATABASE_TOKEN: TOKEN, ...env },
  );
}

describe("authoriseMove: the tool exists only when switched on", () => {
  it.each([
    [undefined, 404],
    ["", 404],
    ["off", 404],
    ["OFF", 404],
    ["short-token", 404],
  ])("MOVE_DATABASE_TOKEN=%j → %i", (value, status) => {
    const r = authoriseMove(
      { url: `${BASE}?step=check&token=${value ?? ""}`, headers: new Headers() },
      { MOVE_DATABASE_TOKEN: value },
    );
    expect(r).toEqual({ ok: false, status, error: "Not found" });
  });

  it("a wrong or missing token → 401", () => {
    expect(call("step=check&token=wrong")).toMatchObject({ ok: false, status: 401 });
    expect(call("step=check")).toMatchObject({ ok: false, status: 401 });
    expect(call("step=check", {}, `Bearer ${"b".repeat(64)}`)).toMatchObject({ status: 401 });
  });

  it("accepts the token as a query parameter or a Bearer header", () => {
    expect(call(`step=check&token=${TOKEN}`).ok).toBe(true);
    expect(call("step=check", {}, `Bearer ${TOKEN}`).ok).toBe(true);
  });

  it("compares tokens of any length safely", () => {
    expect(tokenMatches(TOKEN, TOKEN)).toBe(true);
    expect(tokenMatches("a", TOKEN)).toBe(false);
  });
});

describe("authoriseMove: steps and parameters", () => {
  it("an unknown step → 400", () => {
    expect(call(`step=drop&token=${TOKEN}`)).toMatchObject({ ok: false, status: 400 });
    expect(call(`token=${TOKEN}`)).toMatchObject({ ok: false, status: 400 });
  });

  it.each(["freeze", "unfreeze", "copy", "finish", "back-copy"])(
    "%s without confirm=<step> → 400",
    (step) => {
      const r = call(`step=${step}&db=supabase&expect=f&token=${TOKEN}`, {
        DATABASE_TARGET: "neon",
      });
      expect(r).toMatchObject({ ok: false, status: 400 });
      expect(!r.ok && r.error).toMatch(/confirm=/);
    },
  );

  it("read-only steps need no confirm; defaults are supabase → neon, live supabase", () => {
    const r = call(`step=verify&token=${TOKEN}`);
    expect(r.ok && r.request).toMatchObject({
      step: "verify",
      from: "supabase",
      to: "neon",
      live: "supabase",
      db: "supabase",
      batch: 500,
      replace: false,
      detail: false,
    });
  });

  it("rejects bad from/to/db values, equal ends and an out-of-range batch", () => {
    expect(call(`step=check&from=mysql&token=${TOKEN}`)).toMatchObject({ status: 400 });
    expect(call(`step=check&from=neon&to=neon&token=${TOKEN}`)).toMatchObject({ status: 400 });
    expect(call(`step=check&batch=10&token=${TOKEN}`)).toMatchObject({ status: 400 });
    expect(call(`step=check&batch=abc&token=${TOKEN}`)).toMatchObject({ status: 400 });
    expect(call(`step=check&batch=2000&token=${TOKEN}`).ok).toBe(true);
  });

  it("freeze and unfreeze need db", () => {
    expect(call(`step=freeze&confirm=freeze&token=${TOKEN}`)).toMatchObject({ status: 400 });
    expect(call(`step=unfreeze&confirm=unfreeze&token=${TOKEN}`)).toMatchObject({ status: 400 });
  });
});

describe("authoriseMove: never into the live database", () => {
  it("copy into the live database is refused (409)", () => {
    // Before the switch Supabase is live: copying into it is refused.
    expect(call(`step=copy&confirm=copy&from=neon&to=supabase&token=${TOKEN}`)).toMatchObject({
      ok: false,
      status: 409,
    });
    // After the switch Neon is live.
    expect(
      call(`step=copy&confirm=copy&token=${TOKEN}`, { DATABASE_TARGET: "neon" }),
    ).toMatchObject({ ok: false, status: 409 });
    // Supabase → Neon before the switch is the move itself.
    expect(call(`step=copy&confirm=copy&replace=1&token=${TOKEN}`)).toMatchObject({
      ok: true,
      request: { from: "supabase", to: "neon", replace: true },
    });
  });

  it("back-copy is Neon → Supabase, replacing, and only once Neon is live", () => {
    expect(
      call(`step=back-copy&confirm=back-copy&token=${TOKEN}`, { DATABASE_TARGET: "neon" }),
    ).toMatchObject({ ok: true, request: { from: "neon", to: "supabase", replace: true } });
    expect(call(`step=back-copy&confirm=back-copy&token=${TOKEN}`)).toMatchObject({
      ok: false,
      status: 409,
    });
    expect(
      call(`step=back-copy&confirm=back-copy&from=supabase&token=${TOKEN}`, {
        DATABASE_TARGET: "neon",
      }),
    ).toMatchObject({ ok: false, status: 400 });
  });

  it("freezing the live database is allowed, with a warning (the lossless rollback freezes Neon)", () => {
    const live = call(`step=freeze&confirm=freeze&db=neon&token=${TOKEN}`, {
      DATABASE_TARGET: "neon",
    });
    expect(live.ok && live.request.warnings).toEqual([
      "neon is the live database: the app is read-only until unfreeze",
    ]);
    const other = call(`step=freeze&confirm=freeze&db=supabase&token=${TOKEN}`, {
      DATABASE_TARGET: "neon",
    });
    expect(other.ok && other.request.warnings).toEqual([]);
  });

  it("finish only once the app is on Neon, and only with expect", () => {
    expect(call(`step=finish&confirm=finish&expect=abc&token=${TOKEN}`)).toMatchObject({
      ok: false,
      status: 409,
    });
    expect(
      call(`step=finish&confirm=finish&token=${TOKEN}`, { DATABASE_TARGET: "neon" }),
    ).toMatchObject({ ok: false, status: 400 });
    expect(
      call(`step=finish&confirm=finish&expect=abc&token=${TOKEN}`, { DATABASE_TARGET: "neon" }),
    ).toMatchObject({ ok: true, request: { from: "supabase", to: "neon", expect: "abc" } });
  });
});
