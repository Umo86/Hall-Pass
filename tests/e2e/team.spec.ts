import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("team management", () => {
  test("admin changes a role, toggles an override and names a step approver", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "admin@media10.test", baseURL!);
    const page = await ctx.newPage();
    page.on("dialog", (d) => d.accept()); // role changes ask for confirmation
    await page.goto(`${baseURL}/settings?tab=team`);

    // Role change: Vic Viewer → Sales, then back.
    const vicRole = page.getByLabel("Role for viewer@media10.test");
    await vicRole.selectOption("sales");
    await expect(vicRole).toHaveValue("sales");
    await vicRole.selectOption("viewer");
    await expect(vicRole).toHaveValue("viewer");

    // Own row is locked.
    await expect(page.getByLabel("Role for admin@media10.test")).toBeDisabled();

    // Override: give Sara Sales "Edit costs", then reset. (check() is
    // idempotent, so leftovers from an interrupted earlier run don't matter.)
    const salesRow = page.locator("li", { has: page.getByText("sales@media10.test") }).first();
    await salesRow.getByText(/^Permissions/).click();
    // Controlled checkbox: it flips only after the server action + refresh.
    await salesRow.getByRole("checkbox", { name: "Edit costs" }).click();
    await expect(salesRow.getByText("Permissions (customised)")).toBeVisible();
    // A server refresh can collapse the disclosure — reopen if needed.
    const resetBtn = salesRow.getByRole("button", { name: "Reset to role defaults" });
    if (!(await resetBtn.isVisible())) await salesRow.getByText(/^Permissions/).click();
    await resetBtn.click();
    await expect(salesRow.getByText("Permissions (customised)")).toHaveCount(0);

    await ctx.close();
  });

  test("non-admin staff see the read-only team list", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "marketing@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/settings?tab=team`);
    await expect(page.getByRole("heading", { name: "Team" })).toBeVisible();
    await expect(page.getByLabel("Role for viewer@media10.test")).toHaveCount(0);
    await ctx.close();
  });
});
