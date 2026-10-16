import { randomUUID } from "node:crypto";
import { expect, test, type Browser } from "@playwright/test";
import postgres from "postgres";
import { signInAs } from "./helpers";

/*
 * The review queue on Approvals, chasing from Everyone's, My Work's "Needs
 * you" and the bell. The signs are made straight in the database in BIRM27
 * (sign-off steps already running) and removed afterwards; audit rows stay,
 * as the audit log is append-only.
 */
const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";
const n = String(Date.now()).slice(-6);
const day = 86_400_000;

let sql: ReturnType<typeof postgres>;
type Made = { id: string; ref: string; instanceId: string };
const made: Record<string, Made> = {};

async function as(browser: Browser, email: string, baseURL: string, width = 1280) {
  const ctx = await browser.newContext({ viewport: { width, height: 900 } });
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

test.describe.serial("review queue", () => {
  test.beforeAll(async () => {
    sql = postgres(DB, { max: 1, onnotice: () => {} });
    const [ed] = await sql`
      select e.id, s.organisation_id from editions e join events s on s.id = e.event_id
      where e.code = 'BIRM27'`;
    const steps = await sql`
      select ws.id, ws.name, ws.department_id from workflow_steps ws
      join workflows w on w.id = ws.workflow_id
      where w.organisation_id = ${ed.organisation_id} and w.applies_to = 'signage'
        and w.is_archived = false and ws.name in ('Marketing sign-off', 'Sent to print')`;
    const mktStep = steps.find((s) => s.name === "Marketing sign-off")!;
    const printStep = steps.find((s) => s.name === "Sent to print")!;
    const [supplier] = await sql`
      select id from suppliers where organisation_id = ${ed.organisation_id} limit 1`;
    const [ops] = await sql`select id from users where email = 'ops@media10.test'`;

    const make = async (
      key: string,
      name: string,
      status: string,
      step: { id: string; name: string; kind: string; role?: string; dept?: string },
      dueInDays: number,
    ) => {
      const id = randomUUID();
      const ref = `SIG-BIRM27-Q${n}${Object.keys(made).length}`;
      await sql`insert into signage_items
        (id, edition_id, ref, seq, name, status, current_run_number, created_by, supplier_id)
        values (${id}, ${ed.id}, ${ref}, ${900000 + Number(n.slice(-4)) * 10 + Object.keys(made).length},
          ${name}, ${status}, 1, ${ops.id}, ${supplier?.id ?? null})`;
      const instanceId = randomUUID();
      await sql`insert into approval_instances
        (id, entity_type, entity_id, run_number, workflow_step_id, step_name_snapshot,
         step_kind_snapshot, sort_order_snapshot, status, assigned_role, assigned_department_id,
         pending_since, due_at)
        values (${instanceId}, 'signage_item', ${id}, 1, ${step.id}, ${step.name}, ${step.kind},
          1, 'pending', ${step.role ?? null}, ${step.dept ?? null}, now(),
          ${new Date(Date.now() + dueInDays * day)})`;
      made[key] = { id, ref, instanceId };
    };
    const mkt = {
      id: mktStep.id,
      name: "Marketing sign-off",
      kind: "approval",
      dept: mktStep.department_id,
    };
    await make("a1", `Queue test banner ${n}`, "in_review", mkt, -5);
    await make("a2", `Queue test totem ${n}`, "in_review", mkt, 3);
    const print = {
      id: printStep.id,
      name: "Sent to print",
      kind: "confirmation",
      role: "supplier",
    };
    await make("c1", `Queue confirm flag ${n}`, "approved", print, -2);
    await make("c2", `Queue confirm board ${n}`, "approved", print, -1);
    await make("chase", `Queue chase arch ${n}`, "in_review", mkt, -60);
  });

  test.afterAll(async () => {
    const ids = Object.values(made).map((m) => m.id);
    if (ids.length) {
      await sql`delete from reminder_log where target_id in
        (select id from approval_instances where entity_id = any(${ids}::uuid[]))`;
      await sql`delete from approval_instances where entity_id = any(${ids}::uuid[])`;
      await sql`delete from notifications where entity_id = any(${ids}::uuid[])`;
      await sql`delete from notifications where title like ${`%Q${n}%`}`;
      await sql`delete from signage_items where id = any(${ids}::uuid[])`;
    }
    await sql?.end();
  });

  test("an approver reviews artwork in the sheet and moves straight on", async ({
    browser,
    baseURL,
  }) => {
    const mkt = await as(browser, "marketing@media10.test", baseURL!);
    await mkt.goto(`${baseURL}/approvals?tab=mine&q=${encodeURIComponent(`Queue test`)}`);
    await expect(mkt.getByRole("heading", { name: /^Artwork to sign off \(\d+\)$/ })).toBeVisible();
    const row = mkt.locator("li", { hasText: made.a1.ref });
    await expect(row.getByText("Overdue 5 days")).toBeVisible();
    await expect(row.getByText("Pending", { exact: true })).toHaveCount(0);
    // The common decision is one click; the rarer ones are in a menu.
    await expect(row.getByRole("button", { name: "Approve", exact: true })).toBeVisible();
    await expect(row.getByRole("button", { name: "Reject" })).toHaveCount(0);
    await row.getByRole("button", { name: `More decisions on ${made.a1.ref}` }).click();
    await expect(mkt.getByRole("menuitem", { name: "Reject…" })).toBeVisible();
    await mkt.keyboard.press("Escape");

    await row.getByRole("button", { name: "Review artwork" }).click();
    const sheet = mkt.getByRole("dialog", { name: "Review sign-off" });
    await expect(sheet).toBeVisible();
    await expect(sheet.getByRole("heading", { name: new RegExp(made.a1.ref) })).toBeVisible();
    // Asking for changes needs a comment.
    await sheet.getByRole("button", { name: "Request changes" }).click();
    await expect(sheet.getByRole("alert")).toHaveText("Say what needs to change in a comment");
    await sheet.getByLabel(/^Comment/).fill("The logo needs more clear space");
    await sheet.getByRole("button", { name: "Request changes" }).click();
    await expect(mkt.getByText("Changes requested — Marketing sign-off")).toBeVisible();
    // On to the next one without going back to the list.
    await expect(sheet.getByRole("heading", { name: new RegExp(made.a2.ref) })).toBeVisible();
    await expect(sheet.getByLabel(/^Comment/)).toHaveValue("");
    await sheet.getByRole("button", { name: /^Approve( & next)?$/ }).click();
    await expect(mkt.getByText("Approved — Marketing sign-off").first()).toBeVisible();
    await sheet.getByRole("button", { name: "Close review" }).click();
    await expect(mkt.locator("li", { hasText: made.a1.ref })).toHaveCount(0);
    await expect(mkt.locator("li", { hasText: made.a2.ref })).toHaveCount(0);

    const [a1] = await sql`select status from signage_items where id = ${made.a1.id}`;
    const [a2] = await sql`select status from signage_items where id = ${made.a2.id}`;
    expect(a1.status).toBe("changes_requested");
    expect(a2.status).toBe("approved");
  });

  test("Operations confirm several prints at once with one date", async ({ browser, baseURL }) => {
    const ops = await as(browser, "ops@media10.test", baseURL!);
    await ops.goto(`${baseURL}/approvals?tab=mine&q=${encodeURIComponent("Queue confirm")}`);
    await expect(
      ops.getByRole("heading", { name: "To confirm: print, delivery, install (2)" }),
    ).toBeVisible();
    await ops.getByLabel(`Select ${made.c1.ref} (Sent to print)`).check();
    await ops.getByLabel(`Select ${made.c2.ref} (Sent to print)`).check();
    const bar = ops.getByRole("region", { name: "Confirm selected" });
    await expect(bar.getByText("2 selected")).toBeVisible();
    await bar.getByRole("button", { name: "Confirm 2 as Sent to print" }).click();
    await expect(ops.getByText("2 confirmed")).toBeVisible();
    await expect(ops.locator("li", { hasText: made.c1.ref })).toHaveCount(0);
    const rows = await sql`
      select status from signage_items where id = any(${[made.c1.id, made.c2.id]}::uuid[])`;
    expect(rows.map((r) => r.status)).toEqual(["in_production", "in_production"]);
  });

  test("admins chase from Everyone's, and decide for others only on purpose", async ({
    browser,
    baseURL,
  }) => {
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(
      `${baseURL}/approvals?tab=mine&all=1&q=${encodeURIComponent(`Queue chase arch ${n}`)}`,
    );
    const group = admin.getByRole("region", { name: "Waiting on Marketing" });
    await expect(
      group.getByRole("heading", { name: /Marketing: 1 waiting, 1 overdue/ }),
    ).toBeVisible();
    const row = group.locator("li", { hasText: made.chase.ref });
    await expect(row.getByText("Waiting on:")).toBeVisible();
    // No decision buttons here…
    await expect(row.getByRole("button", { name: "Approve", exact: true })).toHaveCount(0);
    // …only behind "Decide on their behalf…", with a warning.
    await row.getByRole("button", { name: `More for ${made.chase.ref}` }).click();
    await admin.getByRole("menuitem", { name: "Decide on their behalf…" }).click();
    const dialog = admin.getByRole("dialog");
    await expect(
      dialog.getByText(/You are deciding for Marketing\..*will be told\./),
    ).toBeVisible();
    await dialog.getByRole("button", { name: "Cancel" }).click();

    await row.getByRole("button", { name: `Remind about ${made.chase.ref}` }).click();
    await expect(admin.getByText("Reminder sent")).toBeVisible();
    await expect(row.getByText("Reminded today")).toBeVisible();

    // Marketing hears about it, with a link to the item.
    const mkt = await as(browser, "marketing@media10.test", baseURL!);
    await mkt.goto(`${baseURL}/notifications?filter=unread`);
    await expect(
      mkt.getByRole("link", {
        name: new RegExp(`Reminder from Alex Admin: Marketing sign-off on ${made.chase.ref}`),
      }),
    ).toBeVisible();
  });

  test("My Work puts sign-offs first and Review opens the sheet", async ({ browser, baseURL }) => {
    const mkt = await as(browser, "marketing@media10.test", baseURL!);
    await mkt.goto(`${baseURL}/my-work`);
    await expect(mkt.getByRole("heading", { name: "Needs you" })).toBeVisible();
    await expect(mkt.getByRole("link", { name: /Sign-offs\s*\d+ waiting on you/ })).toBeVisible();
    // The navigation counts what is waiting.
    await expect(mkt.getByRole("link", { name: /^Approvals\s*\d+$/ }).first()).toBeVisible();
    // The chase item is due longest ago, so it is first.
    await mkt.getByRole("link", { name: `Review ${made.chase.ref}` }).click();
    await mkt.waitForURL(/\/approvals\?tab=mine&review=/);
    await expect(
      mkt.getByRole("dialog", { name: "Review sign-off" }).getByRole("heading", {
        name: new RegExp(made.chase.ref),
      }),
    ).toBeVisible();
  });

  test("the bell: Mark all read by keyboard, See all and settings", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, "director@media10.test", baseURL!);
    await page.goto(`${baseURL}/my-work`);
    const bell = page.getByRole("button", { name: /^Notifications \(\d+ unread\)$/ });
    await bell.focus();
    await page.keyboard.press("Enter");
    const menu = page.getByRole("menu");
    await expect(menu.getByRole("menuitem", { name: "See all" })).toBeVisible();
    await expect(menu.getByRole("menuitem", { name: "Notification settings" })).toHaveAttribute(
      "href",
      "/account",
    );
    const markAll = menu.getByRole("menuitem", { name: "Mark all read" });
    if (await markAll.count()) {
      await markAll.focus();
      await page.keyboard.press("Enter");
      // The menu stays open, labelled by the bell.
      await expect(page.getByRole("menu", { name: "Notifications (0 unread)" })).toBeVisible();
    }
    await page.keyboard.press("Escape");
    await bell.click();
    await page.getByRole("menuitem", { name: "See all" }).click();
    await page.waitForURL("**/notifications");
    await expect(page.getByRole("heading", { name: "Notifications" })).toBeVisible();
  });
});
