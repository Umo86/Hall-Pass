import { randomUUID } from "node:crypto";
import { expect, test, type Browser } from "@playwright/test";
import postgres from "postgres";
import { signInAs } from "./helpers";

const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";

/** Today in London, as the app works it out. */
function londonIso(offsetDays: number) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/London",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date(Date.now() + offsetDays * 86_400_000));
}

/**
 * Two of ops's own tasks on BIRM27, dated from today so the test never goes
 * stale: one due in three days, one five days ago (overdue).
 */
async function withTasks(
  browser: Browser,
  viewport: { width: number; height: number },
  run: (
    page: Awaited<ReturnType<Browser["newPage"]>>,
    t: { soon: string; late: string },
  ) => Promise<void>,
  baseURL: string,
) {
  const sql = postgres(DB, { max: 1, onnotice: () => {} });
  const n = String(Date.now()).slice(-6);
  const [ed] = await sql`
    select e.id, s.organisation_id from editions e join events s on s.id = e.event_id
    where e.code = 'BIRM27'`;
  const [ops] = await sql`select id from users where email = 'ops@media10.test'`;
  const soon = { id: randomUUID(), title: `E2E cal soon ${n}`, due: londonIso(3) };
  const late = { id: randomUUID(), title: `E2E cal late ${n}`, due: londonIso(-5) };
  for (const t of [soon, late]) {
    await sql`
      insert into tasks (id, organisation_id, edition_id, title, due_date,
        assigned_to_user_id, created_by_user_id)
      values (${t.id}, ${ed.organisation_id}, ${ed.id}, ${t.title}, ${t.due}, ${ops.id}, ${ops.id})`;
  }
  const ctx = await browser.newContext({ viewport });
  try {
    await signInAs(ctx, "ops@media10.test", baseURL);
    await run(await ctx.newPage(), { soon: soon.title, late: late.title });
  } finally {
    await sql`delete from tasks where id in (${soon.id}, ${late.id})`;
    await sql.end();
    await ctx.close();
  }
}

test.describe("event calendar", () => {
  test("overdue work is listed above the month, chips show names, filters narrow it", async ({
    browser,
    baseURL,
  }) => {
    await withTasks(
      browser,
      { width: 1280, height: 900 },
      async (page, t) => {
        await page.goto(`${baseURL}/BIRM27/calendar?m=${londonIso(3).slice(0, 7)}`);
        const main = page.getByRole("main");
        await expect(page).toHaveTitle(/Calendar · BIRM27/);
        // The overdue strip lists the late task whatever month is showing.
        const strip = main.locator("details").filter({ hasText: /^Overdue \(\d+\)/ });
        await expect(strip).toBeVisible();
        await expect(
          strip.getByRole("link", { name: `Task due: ${t.late} — overdue` }),
        ).toBeVisible();
        await page.goto(`${baseURL}/BIRM27/calendar?m=2027-10`);
        await expect(
          main
            .locator("details")
            .filter({ hasText: /^Overdue/ })
            .getByRole("link", {
              name: `Task due: ${t.late} — overdue`,
            }),
        ).toBeVisible();

        // In the month, a chip shows the name; the full words are its name.
        // (It may sit under "+n more" on a busy day, so look it up by its label.)
        await page.goto(`${baseURL}/BIRM27/calendar?m=${londonIso(3).slice(0, 7)}`);
        const table = main.getByRole("table");
        const chip = table.locator(`a[aria-label="Task due: ${t.soon}"]`);
        await expect(chip).toHaveText(t.soon);
        await expect(chip).toHaveClass(/bg-red-600/);
        await expect(
          main.getByLabel("Key").getByText("Event dates", { exact: true }),
        ).toBeVisible();

        // Filters live in the address.
        await main.getByRole("link", { name: "Deliveries & installs" }).click();
        await expect(page).toHaveURL(/f=deliveries/);
        await expect(main.locator(`a[aria-label="Task due: ${t.soon}"]`)).toHaveCount(0);
        await main.getByRole("link", { name: "Only mine" }).click();
        await expect(page).toHaveURL(/f=mine/);
        await expect(table.locator(`a[aria-label="Task due: ${t.soon}"]`)).toHaveCount(1);
      },
      baseURL!,
    );
  });

  test("event deadlines open the work they are about", async ({ browser, baseURL }) => {
    const sql = postgres(DB, { max: 1, onnotice: () => {} });
    const [row] = await sql`
      select coalesce(d.override_date, e.build_start - d.days_before_build_start)::text as date
      from edition_deadlines d join editions e on e.id = d.edition_id
      where e.code = 'BIRM27' and d.key = 'artwork_due'`;
    await sql.end();
    test.skip(!row, "BIRM27 has no artwork deadline");
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/calendar?m=${String(row.date).slice(0, 7)}`);
    await expect(
      page
        .getByRole("main")
        .getByRole("table")
        .getByRole("link", { name: /^Deadline: Artwork due/ }),
    ).toHaveAttribute("href", "/BIRM27/signage?show=needs_artwork");
    await ctx.close();
  });

  test("phones open on the next 30 days, with a month view a tap away", async ({
    browser,
    baseURL,
  }) => {
    await withTasks(
      browser,
      { width: 390, height: 844 },
      async (page, t) => {
        await page.goto(`${baseURL}/BIRM27/calendar`);
        const main = page.getByRole("main");
        const views = main.getByRole("group", { name: "View" }).first();
        await expect(views.getByRole("link", { name: "Upcoming" })).toHaveAttribute(
          "aria-current",
          "page",
        );
        const list = main.getByRole("list", { name: "Coming up in the next 30 days" });
        await expect(list.getByRole("heading", { level: 3 }).first()).toBeVisible();
        // Three days away: shown, under its own day, unless a week of busier days comes first.
        const soon = list.getByRole("link", { name: `Task due: ${t.soon}` });
        if (!(await soon.count())) await main.getByRole("button", { name: /^Show more/ }).click();
        await expect(soon).toBeVisible();

        await views.getByRole("link", { name: "Month" }).click();
        await expect(page).toHaveURL(/view=month/);
        await expect(main.getByRole("link", { name: "Previous month" })).toBeVisible();
      },
      baseURL!,
    );
  });

  test("Add to calendar gives the personal feed with how to use it", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/calendar`);
    await page.getByRole("button", { name: "Add to calendar" }).click();
    const dialog = page.getByRole("dialog", { name: "Add to your calendar" });
    await expect(dialog).toBeVisible();
    const feed = dialog.getByLabel("Your calendar feed link");
    if (await feed.count()) {
      await expect(feed).toHaveValue(/\/api\/ical\//);
      await expect(dialog.getByRole("link", { name: "Open in my calendar app" })).toHaveAttribute(
        "href",
        /^webcal:\/\//,
      );
      await expect(dialog.getByText(/Subscribe from web/)).toBeVisible();
    } else {
      await expect(dialog.getByText(/need the site's address/)).toBeVisible();
    }
    await page.keyboard.press("Escape");
    await expect(dialog).toHaveCount(0);
    await ctx.close();
  });
});
