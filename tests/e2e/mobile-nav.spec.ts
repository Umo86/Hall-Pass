import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("mobile navigation", () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test("hamburger opens the sheet and navigates", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/dashboard`);

    // The sidebar is hidden on phones; the hamburger replaces it.
    await expect(page.getByRole("complementary")).toBeHidden();
    await page.getByRole("button", { name: "Open menu" }).click();
    const sheetNav = page.getByRole("navigation", { name: "Main navigation" });
    await expect(sheetNav).toBeVisible();

    // Placeholder sections are gone; the new ones exist.
    await expect(sheetNav.getByRole("link", { name: "Floorplan" })).toHaveCount(0);
    await expect(sheetNav.getByRole("link", { name: "Onsite" })).toHaveCount(0);
    await expect(sheetNav.getByRole("link", { name: "Sponsorship" })).toBeVisible();
    await expect(sheetNav.getByRole("link", { name: "My Work" })).toBeVisible();

    await sheetNav.getByRole("link", { name: "Signage" }).click();
    await page.waitForURL("**/BIRM27/signage");
    // Sheet closes after navigating; the schedule renders.
    await expect(sheetNav).toBeHidden();
    await expect(page.getByPlaceholder("Search ref, name, location…")).toBeVisible();
    await ctx.close();
  });
});
