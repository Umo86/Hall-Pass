import { randomUUID } from "node:crypto";
import { expect, test } from "@playwright/test";
import postgres from "postgres";
import { signInAs } from "./helpers";

const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";

test.describe("event dashboard", () => {
  test("Operations see their next steps and every number opens its list", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/dashboard`);
    const main = page.getByRole("main");
    await expect(page).toHaveTitle(/Dashboard · BIRM27/);
    await expect(
      main.getByRole("heading", { level: 1, name: "UKCW Birmingham 2027" }),
    ).toBeVisible();
    // Venue and dates on their own lines, with a countdown.
    await expect(main.getByText("NEC Birmingham", { exact: true })).toBeVisible();
    await expect(main.getByText(/^Build-up 1–4 Oct 2027 · Open 5–7 Oct 2027$/)).toBeVisible();
    await expect(
      main.getByText(
        /^(Build-up starts (in \d+ days|tomorrow)|Build-up now|Open now|Open today|Breakdown ends|Finished)/,
      ),
    ).toBeVisible();
    await expect(main.getByRole("link", { name: "Edit event details" })).toHaveAttribute(
      "href",
      "/BIRM27/setup#details",
    );
    await expect(main.getByRole("link", { name: "New sign" })).toHaveAttribute(
      "href",
      "/BIRM27/signage/new",
    );

    // Your next steps: the sign-offs waiting on Operations, for this event.
    const next = main.getByRole("region", { name: "Your next steps" });
    await expect(
      next.getByRole("link", { name: /sign-offs? (is|are) waiting on you/ }),
    ).toHaveAttribute("href", "/approvals?tab=mine&event=BIRM27");

    // Signage progress: one link per stage, Rejected apart, statuses folded away.
    const progress = main.getByRole("region", { name: "Signage progress" });
    for (const stage of ["getting_ready", "in_signoff", "production", "onsite"]) {
      await expect(progress.locator(`a[href="/BIRM27/signage?stage=${stage}"]`)).toHaveCount(1);
    }
    await expect(progress.getByText("Signage by status")).toBeVisible();
    await expect(progress.locator('a[href="/BIRM27/signage?status=draft"]')).toBeHidden();
    await progress.getByText("Signage by status").click();
    await expect(progress.locator('a[href="/BIRM27/signage?status=draft"]')).toBeVisible();

    // Budget: over (red) or what is left (green).
    const budget = main.getByRole("region", { name: "Signage budget" });
    await expect(
      budget.getByText(/^(Over budget by £[\d,]+|£[\d,]+ left|Exactly on budget)$/),
    ).toBeVisible();

    // Sponsorship: sold of what is for sale, linked to the filtered list.
    const sponsorship = main.getByRole("region", { name: "Sponsorship" });
    await expect(sponsorship.getByRole("link", { name: /^\d+ of \d+ sold$/ })).toHaveAttribute(
      "href",
      "/BIRM27/sponsorship?filter=sold",
    );

    // Sign-offs: who they sit with and what is overdue click through.
    const sitting = main.getByRole("region", { name: "Sitting with" });
    await expect(sitting.getByRole("link").first()).toHaveAttribute(
      "href",
      "/approvals?tab=mine&all=1&event=BIRM27",
    );
    const overdue = main.getByRole("region", { name: "Overdue sign-offs" });
    const first = overdue.getByRole("listitem").first();
    await expect(first).toContainText(/SIG-BIRM27-\d+ · with .+ · (\d+ days? late|due today)/);
    const seeAll = overdue.getByRole("link", { name: /^See all \d+ overdue$/ });
    if (await seeAll.count()) {
      await expect(seeAll).toHaveAttribute(
        "href",
        "/approvals?tab=mine&all=1&overdue=1&event=BIRM27",
      );
    }
    await ctx.close();
  });

  test("viewers get the overview without next steps or actions", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInAs(ctx, "viewer@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/dashboard`);
    const main = page.getByRole("main");
    await expect(main.getByRole("region", { name: "Signage progress" })).toBeVisible();
    await expect(main.getByRole("region", { name: "Your next steps" })).toHaveCount(0);
    await expect(main.getByRole("link", { name: "New sign" })).toHaveCount(0);
    await expect(main.getByRole("link", { name: "Edit event details" })).toHaveCount(0);
    // Sign-offs open the artwork list for people who don't chase the team.
    await expect(
      main.getByRole("region", { name: "Sitting with" }).getByRole("link").first(),
    ).toHaveAttribute("href", "/approvals?tab=artwork&event=BIRM27&filter=waiting");
    await ctx.close();
  });

  test("an event with nothing waiting says so, and links set a budget", async ({
    browser,
    baseURL,
  }) => {
    const sql = postgres(DB, { max: 1, onnotice: () => {} });
    const n = String(Date.now()).slice(-7);
    const code = `DASH${n}`;
    const [org] = await sql`
      select s.organisation_id as id from editions e join events s on s.id = e.event_id
      where e.code = 'BIRM27'`;
    const eventId = randomUUID();
    const venueId = randomUUID();
    const editionId = randomUUID();
    await sql`insert into events (id, organisation_id, name, code)
      values (${eventId}, ${org.id}, ${`Dashboard check ${n}`}, ${`DC${n}`})`;
    await sql`insert into venues (id, organisation_id, name, code)
      values (${venueId}, ${org.id}, ${`Check venue ${n}`}, ${`CV${n}`})`;
    await sql`insert into editions (id, event_id, venue_id, name, code, build_start, build_end,
        open_start, open_end, breakdown_end)
      values (${editionId}, ${eventId}, ${venueId}, ${`Dashboard check ${n}`}, ${code},
        '2030-03-01', '2030-03-03', '2030-03-04', '2030-03-05', '2030-03-06')`;
    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
    try {
      await signInAs(ctx, "marketing@media10.test", baseURL!);
      const page = await ctx.newPage();
      await page.goto(`${baseURL}/${code}/dashboard`);
      const main = page.getByRole("main");
      await expect(
        main
          .getByRole("region", { name: "Your next steps" })
          .getByText(`You're all caught up on Dashboard check ${n}.`),
      ).toBeVisible();
      await expect(main.getByText("No signs yet")).toBeVisible();
      await expect(main.getByText(/^Build-up starts in \d+ days$/)).toBeVisible();
      // Marketing can't set the budget; they are told who can.
      const budget = main.getByRole("region", { name: "Signage budget" });
      await expect(budget.getByText("An admin or Operations can set one.")).toBeVisible();

      await signInAs(ctx, "ops@media10.test", baseURL!);
      await page.goto(`${baseURL}/${code}/dashboard`);
      await expect(
        page.getByRole("main").getByRole("link", { name: "Set a budget" }),
      ).toHaveAttribute("href", `/${code}/setup#details`);
    } finally {
      await ctx.close();
      await sql`delete from editions where id = ${editionId}`.catch(() => {});
      await sql`delete from venues where id = ${venueId}`.catch(() => {});
      await sql`delete from events where id = ${eventId}`.catch(() => {});
      await sql.end();
    }
  });
});
