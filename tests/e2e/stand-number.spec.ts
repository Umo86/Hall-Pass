import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("stand numbers and supplier types", () => {
  test("a sign's stand no. is saved and shown next to Location", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    const name = `E2E stand sign ${Date.now()}`;

    await page.goto(`${baseURL}/BIRM27/signage/new`);
    await page.getByLabel("Name", { exact: true }).fill(name);
    await page.getByLabel("Item type").selectOption({ label: "Foamex board" });
    await page.getByLabel("Hall", { exact: true }).selectOption({ label: "Hall 1" });
    await page.getByLabel("Location").selectOption({ label: "Registration" });
    await page.getByLabel("Stand no.").fill("B12");
    await page.getByRole("button", { name: "Create item" }).click();
    await page.waitForURL("**/signage/SIG-BIRM27-*");
    await expect(page.getByText("Stand no.").first()).toBeVisible();
    await expect(page.getByText("B12").first()).toBeVisible();

    // In the table, Stand no. comes straight after Location.
    await page.goto(`${baseURL}/BIRM27/signage`);
    const headers = await page.locator("main table thead th").allInnerTexts();
    const at = headers.findIndex((h) => h.trim() === "Location");
    expect(at).toBeGreaterThan(-1);
    expect(headers[at + 1].trim()).toBe("Stand no.");
    await page.getByPlaceholder(/Search ref/).fill(name);
    const row = page.locator("main table tbody tr", { hasText: name });
    await expect(row).toHaveCount(1);
    const cells = await row.locator("td").allInnerTexts();
    expect(cells[at + 1].trim()).toBe("B12");

    // Searching by stand finds it too.
    await page.getByPlaceholder(/Search ref/).fill("B12");
    await expect(page.locator("main table tbody tr", { hasText: name })).toHaveCount(1);
    await ctx.close();
  });

  test("Floor Manager and Security are supplier types", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/suppliers`);
    await page.getByRole("button", { name: "Add supplier" }).click();
    const dialog = page.getByRole("dialog");
    await expect(dialog.getByLabel("Floor Manager")).toBeVisible();
    await expect(dialog.getByLabel("Security")).toBeVisible();
    await ctx.close();
  });
});
