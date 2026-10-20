import { randomUUID } from "node:crypto";
import { expect, test } from "@playwright/test";
import postgres from "postgres";
import { signInAs } from "./helpers";

const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";

const STAFF_PAGES = [
  "/my-work",
  "/approvals",
  "/approvals?tab=artwork",
  "/approvals?tab=approvers",
  "/approvals?tab=mine&overdue=1",
  "/notifications",
  "/notifications?filter=unread",
  "/events",
  "/events?view=past",
  "/events?view=archived",
  "/start",
  "/suppliers",
  "/suppliers?tab=contractors",
  "/suppliers?manage=services",
  "/settings",
  "/settings/organisation",
  "/settings/item-types",
  "/settings/venues",
  "/settings/recycle-bin",
  "/settings/system",
  // An old link: sent on to its new home.
  "/settings?tab=types",
  "/account",
  "/users",
  "/BIRM27/dashboard",
  "/BIRM27/setup",
  "/BIRM27/signage",
  "/BIRM27/signage/SIG-BIRM27-001",
  "/BIRM27/signage/SIG-BIRM27-001?tab=artwork",
  "/BIRM27/signage/SIG-BIRM27-001?tab=history",
  "/BIRM27/sponsorship",
  "/BIRM27/sponsorship?tab=sponsors",
  "/BIRM27/sponsorship/SIG-BIRM27-031",
  "/BIRM27/calendar",
  "/BIRM27/reports",
  "/BIRM27/halls",
];

test.describe("every page, every role", () => {
  for (const email of [
    "admin@media10.test",
    "ops@media10.test",
    "marketing@media10.test",
    "sales@media10.test",
    "director@media10.test",
    "viewer@media10.test",
  ]) {
    test(`staff pages load for ${email}`, async ({ browser, baseURL }) => {
      // Around thirty pages, each compiled on first visit in development.
      test.setTimeout(600_000);
      const ctx = await browser.newContext();
      await signInAs(ctx, email, baseURL!);
      const page = await ctx.newPage();
      const errors: string[] = [];
      page.on("pageerror", (e) => errors.push(e.message));
      for (const path of STAFF_PAGES) {
        const res = await page.goto(`${baseURL}${path}`);
        expect(res?.status(), path).toBeLessThan(400);
        // Some pages send people elsewhere once loaded (/settings without
        // settings → /users); let that finish before the next page.
        await page.waitForLoadState("networkidle");
        await expect(page.getByRole("heading", { name: "Something went wrong" }), path).toHaveCount(
          0,
        );
      }
      expect(errors).toEqual([]);
      await ctx.close();
    });
  }

  test("signed-out visitors only see the sign-in page", async ({ page, baseURL }) => {
    for (const path of ["/my-work", "/approvals", "/BIRM27/signage", "/settings", "/suppliers"]) {
      await page.goto(`${baseURL}${path}`);
      await expect(page).toHaveURL(/\/login/);
    }
    // Downloads send you to sign in rather than serving the file.
    const res = await page.request.get(`${baseURL}/api/exports/schedule/BIRM27`, {
      maxRedirects: 0,
    });
    expect(res.status()).toBe(307);
    expect(res.headers()["location"]).toContain("/login");
    const files = await page.request.get(
      `${baseURL}/api/task-files/00000000-0000-4000-8000-000000000000`,
    );
    expect(files.status()).toBe(401);
  });

  test("health names the database actually used; the move tool is off", async ({
    request,
    baseURL,
  }) => {
    const health = await (await request.get(`${baseURL}/api/health`)).json();
    // Local and CI: no DATABASE_TARGET, so the first variable that answers (local Postgres).
    expect(health).toMatchObject({
      database: "ok",
      databaseTarget: "auto",
      databaseProvider: "local",
      databaseVia: "DATABASE_URL",
      databaseProject: null,
      databaseRegion: null,
      functionRegion: null,
      schema: "current",
      seeded: true,
    });
    expect(health).not.toHaveProperty("databaseError");
    // The one-off move tool doesn't exist unless MOVE_DATABASE_TOKEN is set.
    const move = await request.get(`${baseURL}/api/admin/move-database?step=check&token=x`);
    expect(move.status()).toBe(404);
  });

  test("there is no sign-up: the invitation page needs a real invitation", async ({
    page,
    baseURL,
  }) => {
    await page.goto(`${baseURL}/invite/not-a-real-token-123456`);
    await expect(page.getByText("This invitation link is not valid.")).toBeVisible();
    await page.goto(`${baseURL}/auth/accept`);
    await expect(
      page.getByText(/Sign-in isn't set up on this site|Open this page from the invitation email/),
    ).toBeVisible();
  });

  test("hostile input is stored and shown as plain text", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    let alerted = false;
    page.on("dialog", async (d) => {
      alerted = true;
      await d.dismiss();
    });
    const nasty = `Robert'); DROP TABLE tasks;-- <img src=x onerror=alert(1)> ${Date.now()}`;
    await page.goto(`${baseURL}/my-work`);
    await page.getByLabel("Task title").fill(nasty);
    await page.getByRole("button", { name: "Add" }).click();
    await expect(page.getByRole("listitem", { name: nasty })).toBeVisible();
    await page.reload();
    await expect(page.getByRole("listitem", { name: nasty })).toBeVisible();
    // Search boxes take it too.
    await page.goto(`${baseURL}/BIRM27/signage?q=${encodeURIComponent("' OR 1=1 --")}`);
    await expect(page.getByRole("heading", { name: "Signage", exact: true })).toBeVisible();
    await page.goto(`${baseURL}/approvals?tab=artwork&q=${encodeURIComponent("%' OR '1'='1")}`);
    await expect(page.getByRole("heading", { name: "Approvals" })).toBeVisible();
    expect(alerted).toBe(false);
    await ctx.close();
  });
});

test.describe("calendar and suppliers", () => {
  test("the calendar shows deadlines in red and has a key", async ({ browser, baseURL }) => {
    // Two of ops's own tasks on BIRM27, dated from today so the test never
    // goes stale: one due in ten days (red), one three days ago (passed).
    const sql = postgres(DB, { max: 1, onnotice: () => {} });
    const n = String(Date.now()).slice(-6);
    const iso = (offsetDays: number) =>
      new Date(Date.now() + offsetDays * 86_400_000).toISOString().slice(0, 10);
    const [ed] = await sql`
      select e.id, s.organisation_id from editions e join events s on s.id = e.event_id
      where e.code = 'BIRM27'`;
    const [ops] = await sql`select id from users where email = 'ops@media10.test'`;
    const soon = { id: randomUUID(), title: `E2E calendar soon ${n}`, due: iso(10) };
    const passed = { id: randomUUID(), title: `E2E calendar passed ${n}`, due: iso(-3) };
    for (const t of [soon, passed]) {
      await sql`
        insert into tasks (id, organisation_id, edition_id, title, due_date,
          assigned_to_user_id, created_by_user_id)
        values (${t.id}, ${ed.organisation_id}, ${ed.id}, ${t.title}, ${t.due}, ${ops.id}, ${ops.id})`;
    }
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    try {
      await signInAs(ctx, "ops@media10.test", baseURL!);
      const page = await ctx.newPage();
      await page.goto(`${baseURL}/BIRM27/calendar?m=${soon.due.slice(0, 7)}`);
      const key = page.getByLabel("Key");
      for (const label of ["Deadline", "Deadline passed"]) {
        await expect(key.getByText(label, { exact: true })).toBeVisible();
      }
      const chip = page.getByRole("link", { name: new RegExp(`Task due: ${soon.title}`) }).first();
      await expect(chip).toBeVisible();
      await expect(chip).toHaveClass(/bg-red-600/);

      // Once passed, the same kind of deadline turns dark red.
      await page.goto(`${baseURL}/BIRM27/calendar?m=${passed.due.slice(0, 7)}`);
      const late = page
        .getByRole("link", { name: new RegExp(`Task due: ${passed.title}`) })
        .first();
      await expect(late).toBeVisible();
      await expect(late).toHaveClass(/bg-red-900/);
    } finally {
      await sql`delete from tasks where id in (${soon.id}, ${passed.id})`;
      await sql.end();
      await ctx.close();
    }
  });

  test("a new 'what they do' can be added from the supplier popup", async ({
    browser,
    baseURL,
  }) => {
    const n = String(Date.now()).slice(-6);
    const name = `E2E Crew ${n}`;
    const service = `Cloakroom staff ${n}`;
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/suppliers`);
    await page.getByRole("button", { name: "Add supplier" }).first().click();
    const dialog = page.getByRole("dialog");
    await dialog.getByLabel("Company name").fill(name);
    await dialog.getByLabel("Add something they do").fill(service);
    await dialog.getByRole("button", { name: "Add", exact: true }).click();
    await expect(dialog.getByLabel(`${service} (new)`)).toBeChecked();
    // Typing an existing one just ticks it.
    await dialog.getByLabel("Add something they do").fill("staffing");
    await dialog.getByLabel("Add something they do").press("Enter");
    await expect(dialog.getByLabel("Staffing", { exact: true })).toBeChecked();
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    const row = page.getByRole("main").getByRole("row", { name: new RegExp(name) });
    await expect(row.getByText(service)).toBeVisible();
    await expect(row.getByText("Staffing")).toBeVisible();
    // It's now on the shared list for everyone (the old Settings link opens it).
    await page.goto(`${baseURL}/settings?tab=services`);
    await expect(page).toHaveURL(/\/suppliers\?manage=services/);
    const manage = page.getByRole("dialog", { name: "What suppliers do" });
    await expect(manage.getByText(service, { exact: true })).toBeVisible();
    // Tidy up: archive the service, then archive and delete the unused supplier.
    await manage.getByRole("button", { name: `Archive ${service}` }).click();
    await page
      .getByRole("dialog", { name: `Archive ${service}?` })
      .getByRole("button", { name: "Archive" })
      .click();
    await expect(manage.getByText(/Archived \(\d+\)/)).toBeVisible();
    await page.keyboard.press("Escape");
    await row.getByRole("button", { name: `Edit ${name}` }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Archive" }).click();
    await page
      .getByRole("dialog", { name: `Archive ${name}?` })
      .getByRole("button", { name: "Archive" })
      .click();
    await expect(row).toHaveCount(0);
    await page.getByText(/^Archived \(\d+\)$/).click();
    await page.getByRole("button", { name: `Delete ${name}` }).click();
    await page
      .getByRole("dialog", { name: `Delete ${name} for good?` })
      .getByRole("button", { name: "Delete" })
      .click();
    await expect(page.getByRole("button", { name: `Restore ${name}` })).toHaveCount(0);
    await ctx.close();
  });
});
