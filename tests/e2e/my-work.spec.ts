import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("My Work tasks", () => {
  test("ops assigns a task to marketing; marketing sees, completes it", async ({
    browser,
    baseURL,
  }) => {
    const title = `E2E task ${Date.now()}`;

    // Ops creates a task assigned to Marcus Marketing.
    const opsCtx = await browser.newContext();
    await signInAs(opsCtx, "ops@media10.test", baseURL!);
    const ops = await opsCtx.newPage();
    await ops.goto(`${baseURL}/my-work`);
    await expect(ops.getByRole("heading", { name: "My Work" })).toBeVisible();
    await ops.getByLabel("Task title").fill(title);
    await ops.getByLabel("Assign to").selectOption({ label: "Marcus Marketing" });
    await ops.getByRole("button", { name: "Add" }).click();
    // The new task is assigned to Marcus, so it does NOT appear in ops' list.
    await expect(ops.getByLabel("Task title")).toHaveValue("");
    await opsCtx.close();

    // Marketing sees it (plus a notification) and completes it.
    const mktCtx = await browser.newContext();
    await signInAs(mktCtx, "marketing@media10.test", baseURL!);
    const mkt = await mktCtx.newPage();
    await mkt.goto(`${baseURL}/my-work`);
    const taskRow = mkt.locator("li", { hasText: title });
    await expect(taskRow).toBeVisible();
    await expect(taskRow.getByText("from Olivia Ops")).toBeVisible();
    // Controlled checkbox: it flips only after the server action + refresh,
    // moving the task into the collapsed "Recently completed" disclosure.
    await mkt.getByRole("checkbox", { name: `Mark "${title}" done` }).click();
    await expect(mkt.getByRole("checkbox", { name: `Mark "${title}" done` })).toHaveCount(0);
    await mkt.getByText(/^Recently completed/).click();
    await expect(mkt.getByRole("checkbox", { name: `Mark "${title}" open` })).toBeVisible();
    await mktCtx.close();
  });

  test("a personal task can be added and deleted", async ({ browser, baseURL }) => {
    const title = `E2E personal ${Date.now()}`;
    const ctx = await browser.newContext();
    await signInAs(ctx, "sales@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/my-work`);
    await page.getByLabel("Task title").fill(title);
    await page.getByRole("button", { name: "Add" }).click();
    await expect(page.getByText(title)).toBeVisible();
    await page.getByRole("button", { name: `Delete "${title}"` }).click();
    await expect(page.getByText(title)).toHaveCount(0);
    await ctx.close();
  });
});
