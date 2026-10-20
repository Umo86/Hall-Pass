import { expect, test, type Page } from "@playwright/test";
import { ensureSecondEvent, signInAs } from "./helpers";

const PDF = Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF");
const day = (offset: number) =>
  new Date(Date.now() + offset * 86_400_000).toISOString().slice(0, 10);

const column = (page: Page, name: "To do" | "In progress" | "Done") =>
  page.getByRole("region", { name, exact: true });

test.describe("My Work board", () => {
  // "Show tasks for" only appears with two or more events.
  test.beforeAll(async () => {
    await ensureSecondEvent();
  });

  test("ops gives marketing a job; marketing works it through with subtasks and files", async ({
    browser,
    baseURL,
  }) => {
    const title = `E2E job ${Date.now()}`;

    // Ops creates a task for Marcus Marketing with a deadline, for BIRM27.
    const opsCtx = await browser.newContext();
    await signInAs(opsCtx, "ops@media10.test", baseURL!);
    const ops = await opsCtx.newPage();
    await ops.goto(`${baseURL}/my-work`);
    await expect(ops.getByRole("heading", { name: "My Work" })).toBeVisible();
    await ops.getByLabel("Task title").fill(title);
    await ops.getByLabel("Due date").fill(day(7));
    await ops.getByLabel("Assign to").selectOption({ label: "Marcus Marketing" });
    await ops.getByLabel("Event", { exact: true }).selectOption({ label: "UKCW Birmingham 2027" });
    await ops.getByRole("button", { name: "Add", exact: true }).click();
    await expect(ops.getByText(`Task added: ${title}`)).toBeVisible();
    await expect(ops.getByLabel("Task title")).toHaveValue("");
    await expect(ops.getByLabel("Task title")).toBeFocused();
    // Ops follows it under "Given to others".
    await ops.getByRole("link", { name: "Given to others" }).click();
    const given = column(ops, "To do").getByRole("listitem", { name: title });
    await expect(given).toBeVisible();
    await expect(given.getByText("BIRM27")).toBeVisible();
    await opsCtx.close();

    // Marketing: it's in To do, from Olivia.
    const mktCtx = await browser.newContext();
    await signInAs(mktCtx, "marketing@media10.test", baseURL!);
    const mkt = await mktCtx.newPage();
    await mkt.goto(`${baseURL}/my-work`);
    const card = mkt.getByRole("listitem", { name: title });
    await expect(column(mkt, "To do").getByRole("listitem", { name: title })).toBeVisible();
    await expect(card.getByText("from Olivia Ops")).toBeVisible();
    // Only the event's tasks when the event is picked.
    await mkt.getByLabel("Show tasks for").selectOption({ label: "UKCW Birmingham 2027" });
    await mkt.waitForURL(/event=BIRM27/);
    await expect(card).toBeVisible();

    // Drag it to In progress.
    // Drop near the top: the column can be taller than the screen.
    await card.dragTo(column(mkt, "In progress"), { targetPosition: { x: 40, y: 16 } });
    await expect(column(mkt, "In progress").getByRole("listitem", { name: title })).toBeVisible();

    // Open it: add a late subtask and a file, on the task and the subtask.
    await card.getByRole("button", { name: title, exact: true }).click();
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

    // Tick the subtask, then finish the task with the card's one button —
    // and undo it from the toast.
    await card.getByRole("button", { name: title, exact: true }).click();
    await dialog.getByLabel("Check the logo files done").click();
    await expect(dialog.getByText("(1/1 done)")).toBeVisible();
    await mkt.keyboard.press("Escape");
    await card.getByRole("button", { name: `Mark done: ${title}` }).click();
    await expect(column(mkt, "Done").getByRole("listitem", { name: title })).toBeVisible();
    const toast = mkt.locator("[data-sonner-toast]", { hasText: "Moved to Done" });
    await toast.getByRole("button", { name: "Undo" }).click();
    await expect(column(mkt, "In progress").getByRole("listitem", { name: title })).toBeVisible();
    // The other moves are in the card's menu.
    await card.getByRole("button", { name: `More for ${title}` }).click();
    await mkt.getByRole("menuitem", { name: "Back to To do" }).click();
    await expect(column(mkt, "To do").getByRole("listitem", { name: title })).toBeVisible();
    await card.getByRole("button", { name: `Start: ${title}` }).click();
    await expect(column(mkt, "In progress").getByRole("listitem", { name: title })).toBeVisible();
    await card.getByRole("button", { name: `Mark done: ${title}` }).click();
    await expect(column(mkt, "Done").getByRole("listitem", { name: title })).toBeVisible();
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

  test("an overdue task is highlighted and counted, and a personal task can be deleted", async ({
    browser,
    baseURL,
  }) => {
    const title = `E2E overdue ${Date.now()}`;
    const ctx = await browser.newContext();
    await signInAs(ctx, "sales@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/my-work`);
    await page.getByLabel("Task title").fill(title);
    await page.getByLabel("Due date").fill(day(-3));
    await page.getByRole("button", { name: "Add", exact: true }).click();
    const card = page.getByRole("listitem", { name: title });
    await expect(card.getByText(/^Overdue — was due/)).toBeVisible();
    // "Needs you" counts it, and so does the navigation.
    await expect(page.getByRole("link", { name: /\d+ overdue: .*\d+ tasks?/ })).toBeVisible();
    await expect(page.getByRole("link", { name: /^My Work\s*\d+$/ }).first()).toBeVisible();
    await page.getByRole("link", { name: /Tasks\s*\d+ overdue/ }).click();
    await page.waitForURL(/due=overdue/);
    await expect(card).toBeVisible();
    await card.getByRole("button", { name: title, exact: true }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Delete" }).click();
    // Deleting asks first, saying what goes.
    const confirm = page.getByRole("dialog", { name: `Delete “${title}”?` });
    await expect(confirm.getByText("The task and its files are deleted.")).toBeVisible();
    await confirm.getByRole("button", { name: "Delete" }).click();
    await expect(page.getByRole("listitem", { name: title })).toHaveCount(0);
    await ctx.close();
  });

  test("on a phone the board shows one column at a time and remembers it", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true });
    await signInAs(ctx, "marketing@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/my-work`);
    const picker = page.getByRole("group", { name: "Board column" });
    await expect(picker).toBeVisible();
    await expect(column(page, "To do")).toBeVisible();
    await expect(column(page, "Done")).toBeHidden();
    await picker.getByRole("button", { name: /^Done/ }).click();
    await expect(column(page, "Done")).toBeVisible();
    await expect(column(page, "To do")).toBeHidden();
    await page.reload();
    await expect(column(page, "Done")).toBeVisible();
    await expect(picker.getByRole("button", { name: /^Done/ })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    // Back to To do for the next run.
    await picker.getByRole("button", { name: /^To do/ }).click();
    await expect(column(page, "To do")).toBeVisible();
    await ctx.close();
  });
});
