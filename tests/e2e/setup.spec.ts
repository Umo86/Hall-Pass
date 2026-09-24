import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("setting up a show", () => {
  test("ops adds and removes a hall and a location", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    page.on("dialog", (d) => d.accept());
    const hall = `E2E Hall ${Date.now()}`;

    await page.goto(`${baseURL}/BIRM27/halls`);
    await expect(page.getByRole("heading", { name: "Halls & locations" })).toBeVisible();
    await page.getByLabel("Add hall").fill(hall);
    await page.getByRole("button", { name: "Add hall" }).click();
    const card = page.locator("section", { has: page.getByRole("heading", { name: hall }) });
    await expect(card).toBeVisible();

    await card.getByLabel("Add location").fill("Loading bay");
    await card.getByRole("button", { name: "Add location" }).click();
    await expect(card.getByText("Loading bay")).toBeVisible();

    // The new location is offered on the item form.
    await page.goto(`${baseURL}/BIRM27/signage/new`);
    await page.getByLabel("Hall", { exact: true }).selectOption({ label: hall });
    await expect(page.getByLabel("Location").locator("option", { hasText: "Loading bay" })).toHaveCount(1);

    // Clean up: remove the location, then the hall.
    await page.goto(`${baseURL}/BIRM27/halls`);
    await card.getByRole("button", { name: "Remove location Loading bay" }).click();
    await expect(card.getByText("Loading bay")).toHaveCount(0);
    await card.getByRole("button", { name: `Remove hall ${hall}` }).click();
    await expect(page.getByRole("heading", { name: hall })).toHaveCount(0);
    await ctx.close();
  });

  test("an edition can be edited and bad dates are refused", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "admin@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/editions`);
    const row = page.locator("tr", { hasText: "BIRM27" });
    await row.getByRole("button", { name: "Edit" }).click();
    const dialog = page.getByRole("dialog");
    const buildEnd = dialog.getByLabel("Build end");
    const original = await buildEnd.inputValue();
    await buildEnd.fill("2020-01-01"); // before build start
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog.getByText(/can't be before/)).toBeVisible();
    await buildEnd.fill(original);
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    await ctx.close();
  });
});
