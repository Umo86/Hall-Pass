import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("sponsorship items", () => {
  test("sales adds a sponsorship item; it stays out of the signage schedule", async ({
    browser,
    baseURL,
  }) => {
    const name = `E2E sponsorship ${Date.now()}`;
    const ctx = await browser.newContext();
    await signInAs(ctx, "sales@media10.test", baseURL!);
    const page = await ctx.newPage();

    await page.goto(`${baseURL}/BIRM27/sponsorship`);
    await expect(page.getByRole("heading", { name: "Sponsorship items" })).toBeVisible();
    await page.getByRole("link", { name: "Add sponsorship item" }).click();
    await page.waitForURL("**/sponsorship/new");
    await page.getByLabel("Name", { exact: true }).fill(name);
    await page.getByLabel("Item type").selectOption({ label: "Show bags" });
    await page.getByLabel("Sponsor", { exact: true }).selectOption({ label: "BuildCo" });
    await page.getByRole("button", { name: "Create item" }).click();
    await page.waitForURL("**/signage/SIG-BIRM27-*");
    await expect(page.getByRole("heading", { name })).toBeVisible();

    // A sponsorship item has no hall or location, and can still go for sign-off.
    await page.getByRole("button", { name: "Submit for review" }).click();
    await expect(page.getByText("Awaiting artwork", { exact: true })).toBeVisible();

    // Listed in the sponsorship register…
    await page.goto(`${baseURL}/BIRM27/sponsorship`);
    await expect(page.getByText(name)).toBeVisible();
    // …but not in the signage schedule.
    await page.goto(`${baseURL}/BIRM27/signage`);
    await expect(page.getByText(name)).toHaveCount(0);
    await ctx.close();
  });

  test("viewers cannot add sponsorship items", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "viewer@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/sponsorship`);
    await expect(page.getByRole("heading", { name: "Sponsorship items" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Add sponsorship item" })).toHaveCount(0);
    await page.goto(`${baseURL}/BIRM27/sponsorship/new`);
    await page.waitForURL("**/sponsorship");
    await ctx.close();
  });
});
