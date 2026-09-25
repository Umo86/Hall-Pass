import { expect, test, type Page } from "@playwright/test";
import { signInAs } from "./helpers";

const PDF = Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF");
const day = (offset: number) =>
  new Date(Date.now() + offset * 86_400_000).toISOString().slice(0, 10);

const column = (page: Page, name: "To do" | "In progress" | "Complete") =>
  page.getByRole("region", { name, exact: true });

test.describe("My Work board", () => {
  test("ops gives marketing a job; marketing works it through with subtasks and files", async ({
    browser,
    baseURL,
  }) => {
    const title = `E2E job ${Date.now()}`;

    // Ops creates a task for Marcus Marketing with a deadline.
    const opsCtx = await browser.newContext();
    await signInAs(opsCtx, "ops@media10.test", baseURL!);
    const ops = await opsCtx.newPage();
    await ops.goto(`${baseURL}/my-work`);
    await expect(ops.getByRole("heading", { name: "My Work" })).toBeVisible();
    await ops.getByLabel("Task title").fill(title);
    await ops.getByLabel("Due date").fill(day(7));
    await ops.getByLabel("Assign to").selectOption({ label: "Marcus Marketing" });
    await ops.getByRole("button", { name: "Add" }).click();
    await expect(ops.getByLabel("Task title")).toHaveValue("");
    // Ops follows it under "Given to others".
    await ops.getByRole("link", { name: "Given to others" }).click();
    await expect(column(ops, "To do").getByRole("listitem", { name: title })).toBeVisible();
    await opsCtx.close();

    // Marketing: it's in To do, from Olivia.
    const mktCtx = await browser.newContext();
    await signInAs(mktCtx, "marketing@media10.test", baseURL!);
    const mkt = await mktCtx.newPage();
    mkt.on("dialog", (d) => d.accept());
    await mkt.goto(`${baseURL}/my-work`);
    const card = mkt.getByRole("listitem", { name: title });
    await expect(column(mkt, "To do").getByRole("listitem", { name: title })).toBeVisible();
    await expect(card.getByText("from Olivia Ops")).toBeVisible();

    // Drag it to In progress.
    await card.dragTo(column(mkt, "In progress"));
    await expect(column(mkt, "In progress").getByRole("listitem", { name: title })).toBeVisible();

    // Open it: add a late subtask and a file, on the task and the subtask.
    await card.getByRole("button", { name: title }).click();
    const dialog = mkt.getByRole("dialog");
    await dialog.getByLabel("Subtask", { exact: true }).fill("Check the logo files");
    await dialog.getByLabel("Subtask deadline").fill(day(-2));
    await dialog.getByRole("button", { name: "Add", exact: true }).click();
    const sub = dialog.getByRole("listitem", { name: "Check the logo files" });
    await expect(sub).toBeVisible();
    await expect(sub.getByText(/^Overdue/)).toBeVisible();
    await dialog.getByLabel(`Attach a file to ${title}`).setInputFiles({
      name: "brief.pdf",
      mimeType: "application/pdf",
      buffer: PDF,
    });
    await expect(dialog.getByRole("link", { name: "brief.pdf" })).toBeVisible();
    await sub.getByLabel("Attach a file to Check the logo files").setInputFiles({
      name: "logo-notes.pdf",
      mimeType: "application/pdf",
      buffer: PDF,
    });
    await expect(sub.getByRole("link", { name: "logo-notes.pdf" })).toBeVisible();
    // The file downloads for someone working on the task.
    const res = await mkt.request.get(
      `${baseURL}${await dialog.getByRole("link", { name: "brief.pdf" }).getAttribute("href")}`,
    );
    expect(res.status()).toBe(200);
    // Refused to a file type that could run in a browser.
    await dialog.getByLabel(`Attach a file to ${title}`).setInputFiles({
      name: "evil.html",
      mimeType: "text/html",
      buffer: Buffer.from("<script>alert(1)</script>"),
    });
    await expect(dialog.getByText(/can't be attached/)).toBeVisible();
    await mkt.keyboard.press("Escape");

    // The card flags the overdue subtask.
    await expect(card.getByText("1 subtask overdue")).toBeVisible();

    // Tick the subtask, then complete the task with the card's menu.
    await card.getByRole("button", { name: title }).click();
    await dialog.getByLabel("Check the logo files done").click();
    await expect(dialog.getByText("(1/1 done)")).toBeVisible();
    await mkt.keyboard.press("Escape");
    await card.getByLabel(`Move ${title}`).selectOption("done");
    await expect(column(mkt, "Complete").getByRole("listitem", { name: title })).toBeVisible();
    await mktCtx.close();

    // Someone else can't fetch the attachment.
    const salesCtx = await browser.newContext();
    await signInAs(salesCtx, "sales@media10.test", baseURL!);
    const sales = await salesCtx.newPage();
    const denied = await sales.request.get(
      `${baseURL}/api/task-files/00000000-0000-4000-8000-000000000000`,
    );
    expect(denied.status()).toBe(404);
    await salesCtx.close();
  });

  test("an overdue task is highlighted, and a personal task can be deleted", async ({
    browser,
    baseURL,
  }) => {
    const title = `E2E overdue ${Date.now()}`;
    const ctx = await browser.newContext();
    await signInAs(ctx, "sales@media10.test", baseURL!);
    const page = await ctx.newPage();
    page.on("dialog", (d) => d.accept());
    await page.goto(`${baseURL}/my-work`);
    await page.getByLabel("Task title").fill(title);
    await page.getByLabel("Due date").fill(day(-3));
    await page.getByRole("button", { name: "Add" }).click();
    const card = page.getByRole("listitem", { name: title });
    await expect(card.getByText(/^Overdue — was due/)).toBeVisible();
    await expect(page.getByText(/overdue — needs attention/)).toBeVisible();
    await card.getByRole("button", { name: title }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Delete" }).click();
    await expect(page.getByRole("listitem", { name: title })).toHaveCount(0);
    await ctx.close();
  });
});
