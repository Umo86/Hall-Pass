import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("platform review fixes", () => {
  test("dashboard groups sign-offs by name and lists the week's deadlines", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/dashboard`);
    // "Operations" the department and "ops" the role are one line.
    const sitting = page.locator("section", { hasText: "Sitting with" }).first();
    await expect(sitting.getByText("Operations", { exact: true })).toHaveCount(1);
    // Overdue sign-offs link to the right section for their kind.
    const overdue = page.locator("h2", { hasText: "Overdue sign-offs" }).locator("..");
    const hrefs = await overdue
      .locator("a")
      .evaluateAll((as) => as.map((a) => a.getAttribute("href")));
    expect(hrefs.length).toBeGreaterThan(0);
    for (const h of hrefs)
      expect(h).toMatch(/\/BIRM27\/(signage|sponsorship|stand-designs|stand-panels)\//);
    await ctx.close();
  });

  test("switching show from an item page opens that show's list", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/signage/SIG-BIRM27-001?tab=artwork`);
    await page.getByRole("button", { name: /^Event: .*BIRM27/ }).click();
    const other = page
      .locator("[role=menuitem][data-code]")
      .filter({ hasNotText: "BIRM27" })
      .first();
    const code = (await other.getAttribute("data-code"))!;
    await other.click();
    await page.waitForURL(`**/${code}/signage`);
    await expect(page.getByRole("heading", { name: "Signage", exact: true })).toBeVisible();
    await ctx.close();
  });

  test("a missing item shows a friendly not-found page, and item tabs are titled", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/signage/SIG-BIRM27-999`);
    await expect(page.getByRole("heading", { name: "Not found" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to My Work" })).toBeVisible();
    await page.goto(`${baseURL}/BIRM27/signage/SIG-BIRM27-001`);
    await expect(page).toHaveTitle(/SIG-BIRM27-001 · Main entrance arch banner/);
    await ctx.close();
  });

  test("copying an event keeps its sponsors, sponsor signage and stands", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInAs(ctx, "admin@media10.test", baseURL!);
    const page = await ctx.newPage();
    const code = `CP${String(Date.now()).slice(-6)}`;
    await page.goto(`${baseURL}/start?mode=copy`, { waitUntil: "networkidle" });
    const source = page.getByLabel("Copy from");
    const value = await source
      .locator("option", { hasText: /^UKCW Birmingham 2027 · NEC Birmingham/ })
      .first()
      .getAttribute("value");
    await source.selectOption(value!);
    // Next year's name and dates are suggested from the source.
    await expect(page.getByLabel("Event name")).toHaveValue("UKCW Birmingham 2028");
    await expect(page.getByLabel("Opens to visitors")).toHaveValue("2028-10-03");
    await page.getByLabel("Event name").fill(`Copy of BIRM27 ${code}`);
    await page.getByRole("button", { name: "Change" }).click();
    await page.getByLabel("Reference code").fill(code);
    await page.getByLabel("Opens to visitors").fill("2028-10-05");
    await page.getByLabel("Closes to visitors").fill("2028-10-07");
    await expect(page.getByLabel(/^Halls & locations \(2 halls/)).toBeChecked();
    await expect(page.getByLabel(/^Signs and sponsorship items as drafts/)).toBeChecked();
    await page.getByRole("button", { name: "Copy event" }).click();

    // Setup: what came across is done; the dates and deadlines need a look.
    await page.waitForURL(`**/${code}/setup`);
    await expect(page.getByText(/Copied from UKCW Birmingham 2027 — 2 halls/)).toBeVisible();
    await expect(
      page.getByRole("button", { name: /^2\. Halls and locations\s*, Done/ }),
    ).toBeVisible();
    await expect(page.getByRole("button", { name: /^8\. First signs\s*, Done/ })).toContainText(
      "copied as drafts",
    );
    await expect(
      page.getByRole("button", { name: /^1\. Dates, venue and budget\s*, To do/ }),
    ).toBeVisible();
    await expect(page.getByRole("button", { name: /^3\. Deadlines\s*, To do/ })).toBeVisible();

    // Sponsors and sponsor signage come across; stands keep their own refs.
    await page.goto(`${baseURL}/${code}/sponsorship?tab=sponsors`);
    await expect(page.getByText("BuildCo", { exact: true }).first()).toBeVisible();
    await page.goto(`${baseURL}/${code}/signage`);
    await page.getByPlaceholder(/Search ref/).fill("Main entrance arch banner");
    await page.getByRole("button", { name: "Columns" }).click();
    await page.getByRole("menuitemcheckbox", { name: "Sponsor", exact: true }).click();
    await page.keyboard.press("Escape");
    const row = page.locator("main table tbody tr").first();
    await expect(row).toContainText("BuildCo");
    await page.goto(`${baseURL}/${code}/stand-designs`);
    await expect(page.getByText(`STB-${code}-001`)).toBeVisible();
    await ctx.close();
  });
});
