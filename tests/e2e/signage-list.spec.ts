import { expect, test, type Browser, type Page } from "@playwright/test";
import { signInAs } from "./helpers";

async function as(
  browser: Browser,
  email: string,
  baseURL: string,
  viewport = { width: 1366, height: 900 },
): Promise<Page> {
  const ctx = await browser.newContext({ viewport });
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

/** The status words of every row the table shows. */
const statuses = (page: Page) =>
  page.locator("main table tbody tr td:nth-child(4)").allInnerTexts();

test.describe("the signage list", () => {
  test("status chips with counts, the filters menu and links from other pages", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, "ops@media10.test", baseURL!);
    await page.goto(`${baseURL}/BIRM27/signage`);
    await expect(page.getByRole("heading", { name: "Signage", exact: true })).toBeVisible();
    await expect(page.getByText("Every sign for UKCW Birmingham 2027")).toBeVisible();

    // Default columns: what people work from.
    const headers = (await page.locator("main table thead th").allInnerTexts()).map((h) =>
      h.trim(),
    );
    expect(headers.slice(1)).toEqual([
      "Ref",
      "Name",
      "Status",
      "Waiting on",
      "Hall · Location",
      "Install",
      "Artwork due",
    ]);

    // A chip shows its count and narrows the list to its statuses.
    const chips = page.getByRole("group", { name: "Show" });
    const ready = chips.getByRole("button", { name: /^Ready to print \d+$/ });
    await ready.click();
    await expect(ready).toHaveAttribute("aria-pressed", "true");
    await expect(page).toHaveURL(/show=ready_to_print/);
    for (const s of await statuses(page))
      expect(["Approved", "Approved (conditions)"]).toContain(s);

    // The dashboard links by stage.
    await page.goto(`${baseURL}/BIRM27/signage?stage=in_signoff`);
    await expect(
      page.getByRole("button", { name: "Remove filter: Stage: In sign-off" }),
    ).toBeVisible();
    for (const s of await statuses(page)) expect(["In sign-off", "Changes requested"]).toContain(s);
    await page.getByRole("button", { name: "Remove filter: Stage: In sign-off" }).click();
    await expect(page).not.toHaveURL(/stage=/);

    // Hall and "no location yet" (from the halls page).
    await page.getByRole("button", { name: "Filters" }).click();
    await page.getByRole("menuitemradio", { name: "Hall 1", exact: true }).click();
    await page.keyboard.press("Escape");
    await expect(page.getByRole("button", { name: "Remove filter: Hall: Hall 1" })).toBeVisible();
    const places = await page.locator("main table tbody tr td:nth-child(6)").allInnerTexts();
    expect(places.length).toBeGreaterThan(0);
    for (const p of places) expect(p).toMatch(/^Hall 1/);
    const hallId = new URL(page.url()).searchParams.get("hall");
    await page.goto(`${baseURL}/BIRM27/signage?hall=${hallId}&location=none`);
    await expect(
      page.getByRole("button", { name: "Remove filter: Location: No location" }),
    ).toBeVisible();
    await page.getByRole("button", { name: "Clear filters" }).first().click();
    await expect(page).toHaveURL(/\/BIRM27\/signage$/);

    // The view toggles say what they are.
    await expect(page.getByRole("button", { name: "Table view" })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    await page.getByRole("button", { name: "Kanban view" }).click();
    await expect(page.getByRole("button", { name: "Kanban view" })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    await page.context().close();
  });

  test("bulk confirmations say why each item was left alone and keep it selected", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, "ops@media10.test", baseURL!);
    await page.goto(`${baseURL}/BIRM27/signage?show=in_signoff`, { waitUntil: "networkidle" });
    const rows = page.locator("main table tbody tr");
    await rows.nth(0).getByRole("checkbox").check();
    await rows.nth(1).getByRole("checkbox").check();
    const bar = page.getByRole("region", { name: "Selected items" });
    await expect(bar).toContainText("2 selected");
    await bar.getByRole("button", { name: "Confirm sent to print" }).click();
    const dialog = page.getByRole("dialog");
    await expect(dialog.getByLabel("When did this happen?")).toBeVisible();
    await dialog.getByRole("button", { name: "Confirm sent to print" }).click();
    const result = page.getByRole("status").filter({ hasText: "left as they were" });
    await expect(result).toContainText("0 confirmed sent to print, 2 left as they were");
    await expect(result.getByText(/not signed off yet/)).toHaveCount(2);
    await expect(result).toContainText("They are still selected");
    await expect(bar).toContainText("2 selected");
    await page.context().close();
  });

  test("deleted signs can be restored from Recently deleted", async ({ browser, baseURL }) => {
    const page = await as(browser, "ops@media10.test", baseURL!);
    const name = `E2E restore me ${Date.now()}`;
    await page.goto(`${baseURL}/BIRM27/signage/new`);
    await page.getByLabel("Name", { exact: true }).fill(name);
    await page.getByRole("button", { name: "Create item" }).click();
    await page.waitForURL("**/signage/SIG-BIRM27-*");
    const ref = new URL(page.url()).pathname.split("/").pop()!;
    await page.getByRole("button", { name: "More" }).click();
    await page.getByRole("menuitem", { name: "Delete" }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Delete" }).click();
    await page.waitForURL("**/BIRM27/signage");

    await page.getByRole("link", { name: /Recently deleted \(\d+\)/ }).click();
    await expect(page.getByRole("heading", { name: "Recently deleted" })).toBeVisible();
    const row = page.getByRole("row", { name: new RegExp(ref) });
    await expect(row).toContainText(name);
    await expect(row).toContainText("Olivia Ops");
    await row.getByRole("button", { name: `Restore ${ref}` }).click();
    await expect(page.getByText(`Restored ${ref}`)).toBeVisible();
    await expect(page.getByRole("row", { name: new RegExp(ref) })).toHaveCount(0);
    await page.getByRole("button", { name: `Open ${ref}` }).click();
    await page.waitForURL(`**/signage/${ref}`);
    await expect(page.getByRole("heading", { name, exact: true })).toBeVisible();
    await page.context().close();
  });

  test("Import from Excel is one click from the Signage page", async ({ browser, baseURL }) => {
    const page = await as(browser, "ops@media10.test", baseURL!);
    await page.goto(`${baseURL}/BIRM27/signage`);
    await page.getByRole("button", { name: "New sign" }).click();
    await expect(page.getByRole("menuitem", { name: "Add a sign" })).toBeVisible();
    await page.getByRole("menuitem", { name: "Import from Excel" }).click();
    const sheet = page.getByRole("dialog");
    await expect(sheet.getByText("Import signs from Excel")).toBeVisible();
    await expect(sheet.getByRole("link", { name: "Download the template" })).toBeVisible();
    await expect(sheet.getByRole("button", { name: "Import", exact: true })).toBeDisabled();
    await page.context().close();
  });

  test("on a phone: cards, twenty at a time, and no Columns menu", async ({ browser, baseURL }) => {
    const page = await as(browser, "ops@media10.test", baseURL!, { width: 390, height: 844 });
    await page.goto(`${baseURL}/BIRM27/signage`);
    const cards = page.locator("main ul > li > a");
    await expect(cards).toHaveCount(20);
    await expect(page.getByText(/Showing 20 of \d+/)).toBeVisible();
    await page.getByRole("button", { name: "Show 20 more" }).click();
    await expect(cards).toHaveCount(40);
    await expect(page.getByRole("button", { name: "Columns" })).toBeHidden();
    // Grouping works on phones too.
    await page.goto(`${baseURL}/BIRM27/signage?group=hall`);
    await expect(page.locator("main summary", { hasText: /^Hall 1 · \d+$/ })).toBeVisible();
    await page.context().close();
  });
});
