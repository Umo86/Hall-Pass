import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("wide tables and the side menu", () => {
  test("the signage table scrolls sideways from the top bar", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/signage`);

    const table = page.locator("main table");
    const box = table.locator("xpath=..");
    await expect(table).toBeVisible();
    await expect(page.getByTestId("scroll-x-bar")).toBeVisible();
    const left = page.getByRole("button", { name: "Scroll schedule left" });
    const right = page.getByRole("button", { name: "Scroll schedule right" });
    await expect(left).toBeDisabled();

    await right.click();
    await expect.poll(() => box.evaluate((el) => el.scrollLeft)).toBeGreaterThan(0);
    await expect(left).toBeEnabled();
    // The top bar follows the table.
    await expect
      .poll(() => page.getByTestId("scroll-x-bar").evaluate((el) => el.scrollLeft))
      .toBeGreaterThan(0);
    await ctx.close();
  });

  test("the side menu can be hidden, and stays hidden", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/signage`);

    const menu = page.getByRole("complementary");
    await expect(menu).toBeVisible();
    await page.getByRole("button", { name: "Hide menu" }).click();
    await expect(menu).toBeHidden();

    await page.reload();
    await expect(menu).toBeHidden();
    await page.getByRole("button", { name: "Show menu" }).click();
    await expect(menu).toBeVisible();
    await ctx.close();
  });
});
