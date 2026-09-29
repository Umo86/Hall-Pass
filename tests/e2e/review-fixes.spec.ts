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
    await page.getByRole("button", { name: /BIRM27/ }).click();
    const other = page.getByRole("menuitem").filter({ hasNotText: "BIRM27" }).first();
    const code = (await other.locator("span").first().textContent())!.trim();
    await other.click();
    await page.waitForURL(`**/${code}/signage`);
    await expect(page.getByRole("heading", { name: /Signage schedule/ })).toBeVisible();
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

  test("copying a show keeps its sponsors, sponsor signage and stands", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInAs(ctx, "admin@media10.test", baseURL!);
    const page = await ctx.newPage();
    const code = `CP${String(Date.now()).slice(-6)}`;
    await page.goto(`${baseURL}/editions`);
    await page.getByRole("button", { name: "Copy a show" }).click();
    const dialog = page.getByRole("dialog");
    const source = dialog.getByLabel("Copy from");
    const value = await source
      .locator("option", { hasText: "BIRM27" })
      .first()
      .getAttribute("value");
    await source.selectOption(value!);
    await dialog.getByLabel("New name").fill(`Copy of BIRM27 ${code}`);
    await dialog.getByLabel("New code").fill(code);
    await dialog.getByLabel("Build starts").fill("2028-10-01");
    await dialog.getByLabel("Build ends").fill("2028-10-04");
    await dialog.getByLabel("Show opens").fill("2028-10-05");
    await dialog.getByLabel("Show closes").fill("2028-10-07");
    await dialog.getByLabel("Breakdown ends").fill("2028-10-08");
    await dialog.getByRole("button", { name: "Copy show" }).click();
    await expect(dialog).toHaveCount(0);

    // Sponsors and sponsor signage come across; stands keep their own refs.
    await page.goto(`${baseURL}/${code}/sponsorship?tab=sponsors`);
    await expect(page.getByText("BuildCo", { exact: true }).first()).toBeVisible();
    await page.goto(`${baseURL}/${code}/signage`);
    await page.getByPlaceholder(/Search ref/).fill("Main entrance arch banner");
    const row = page.locator("main table tbody tr").first();
    await expect(row).toContainText("BuildCo");
    await page.goto(`${baseURL}/${code}/stand-designs`);
    await expect(page.getByText(`STB-${code}-001`)).toBeVisible();
    await ctx.close();
  });
});
