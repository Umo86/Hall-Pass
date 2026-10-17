import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("setting up an event", () => {
  test("ops adds and removes a hall and a location", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    const hall = `E2E Hall ${Date.now()}`;

    await page.goto(`${baseURL}/BIRM27/halls`, { waitUntil: "networkidle" });
    await expect(page.getByRole("heading", { name: "Halls & locations" })).toBeVisible();
    await page.getByLabel("New hall name").fill(hall);
    await page.getByRole("button", { name: "Add hall" }).click();
    const card = page.locator("section", { has: page.getByRole("heading", { name: hall }) });
    await expect(card).toBeVisible();

    // A location with a zone (zones already used are suggested).
    await card.getByLabel(`Location name in ${hall}`).fill("Loading bay");
    await card.getByLabel(`Zone in ${hall} (optional)`).fill("North");
    await card.getByRole("button", { name: "Add location" }).click();
    await expect(card.getByText("Loading bay")).toBeVisible();
    await expect(card.getByText("North", { exact: true })).toBeVisible();

    // Renaming edits the name and the zone together.
    await card.getByRole("button", { name: "Edit location Loading bay" }).click();
    await card.getByLabel(`Location name in ${hall}`).first().fill("Loading bay 2");
    await card.getByRole("button", { name: "Save" }).click();
    await expect(card.getByText("Loading bay 2")).toBeVisible();

    // The new location is offered on the item form.
    await page.goto(`${baseURL}/BIRM27/signage/new`);
    await page.getByLabel("Hall", { exact: true }).selectOption({ label: hall });
    await expect(
      page.getByLabel("Location").locator("option", { hasText: "Loading bay 2" }),
    ).toHaveCount(1);

    // Clean up: remove the location, then the hall — each asks first.
    await page.goto(`${baseURL}/BIRM27/halls`, { waitUntil: "networkidle" });
    await card.getByRole("button", { name: "Remove location Loading bay 2" }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Remove location" }).click();
    await expect(card.getByText("Loading bay 2")).toHaveCount(0);
    await card.getByRole("button", { name: `Remove hall ${hall}` }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Remove hall" }).click();
    await expect(page.getByRole("heading", { name: hall })).toHaveCount(0);
    await ctx.close();
  });

  test("a hall still used by signs can't be removed, and says why", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/halls`, { waitUntil: "networkidle" });
    const card = page.locator("section", { has: page.getByRole("heading", { name: "Hall 1" }) });
    await card.getByRole("button", { name: "Remove hall Hall 1" }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Remove hall" }).click();
    await expect(card.getByText(/are in Hall 1 — move them to another hall first/)).toBeVisible();
    // Signs without a location are pointed out, with a way to place them.
    await expect(card.getByRole("link", { name: "Place them →" })).toHaveAttribute(
      "href",
      /\/BIRM27\/signage\?hall=.+&location=none/,
    );
    await ctx.close();
  });

  test("event details refuse dates out of order", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "admin@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/setup#details`, { waitUntil: "networkidle" });
    const step = page.getByRole("button", { name: /^1\. Dates, venue and budget/ });
    await expect(step).toHaveAttribute("aria-expanded", "true");
    await page.getByLabel("Build-up ends").fill("2020-01-01"); // before build-up starts
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Build-up ends can't be before build-up starts")).toBeVisible();
    // Nothing was saved: the step is still to do.
    await expect(
      page.getByRole("button", { name: /^1\. Dates, venue and budget\s*, To do/ }),
    ).toBeVisible();
    await ctx.close();
  });

  test("everyone can see the setup checklist; only admins and Operations change it", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "viewer@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/setup`);
    await expect(
      page.getByRole("heading", { name: "Get UKCW Birmingham 2027 ready" }),
    ).toBeVisible();
    await expect(page.getByText(/of 6 essentials done|is ready/)).toBeVisible();
    await expect(page.getByRole("button", { name: /^Save/ })).toHaveCount(0);
    // Halls are listed, but can't be added here.
    await page.goto(`${baseURL}/BIRM27/halls`);
    await expect(
      page.getByText(/You need “Manage halls and locations” for that — ask a super admin\./),
    ).toBeVisible();
    await expect(page.getByRole("button", { name: "Add hall" })).toHaveCount(0);
    await ctx.close();
  });

  test("the Events list groups events and links to their setup", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInAs(ctx, "admin@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/editions`, { waitUntil: "networkidle" });
    await expect(page).toHaveURL(/\/events$/);
    await expect(page.getByRole("heading", { name: "Events", exact: true })).toBeVisible();
    await expect(page.getByRole("link", { name: /New event/ })).toHaveAttribute("href", "/start");
    await expect(page.getByRole("link", { name: /Copy an event/ })).toHaveAttribute(
      "href",
      "/start?mode=copy",
    );
    const card = page.locator("li", { hasText: "BIRM27" }).first();
    await expect(card.getByText("Open 5–7 Oct 2027 · NEC Birmingham")).toBeVisible();
    await card.getByRole("button", { name: "More for UKCW Birmingham 2027" }).click();
    await expect(page.getByRole("menuitem", { name: "Edit details" })).toHaveAttribute(
      "href",
      "/BIRM27/setup#details",
    );
    await expect(page.getByRole("menuitem", { name: "Archive event…" })).toBeVisible();
    await page.keyboard.press("Escape");
    await page.getByRole("link", { name: /^Archived/ }).click();
    await expect(page).toHaveURL(/view=archived/);
    await ctx.close();
  });

  test("the event switcher lists events and offers a new one", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInAs(ctx, "admin@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/dashboard`, { waitUntil: "networkidle" });
    await page.getByRole("button", { name: /^Event: UKCW Birmingham 2027 \(BIRM27\)/ }).click();
    const menu = page.getByRole("menu");
    await expect(
      menu.getByRole("menuitem", { name: /^UKCW Birmingham 2027 BIRM27/ }),
    ).toHaveAttribute("aria-current", "true");
    await expect(menu.getByRole("menuitem", { name: "All events" })).toHaveAttribute(
      "href",
      "/events",
    );
    await expect(menu.getByRole("menuitem", { name: "New event" })).toHaveAttribute(
      "href",
      "/start",
    );
    await ctx.close();
  });
});
