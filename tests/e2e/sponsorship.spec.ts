import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

// A 1×1 PNG stands in for a product photo.
const PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  "base64",
);
const inDays = (n: number) => new Date(Date.now() + n * 86_400_000).toISOString().slice(0, 10);

test.describe("sponsorship items", () => {
  test("sales adds an item to sell, adds a photo, then marks it sold to a new sponsor", async ({
    browser,
    baseURL,
  }) => {
    const n = String(Date.now()).slice(-6);
    const name = `E2E pens ${n}`;
    const sponsor = `PenCo ${n}`;
    const ctx = await browser.newContext();
    await signInAs(ctx, "sales@media10.test", baseURL!);
    const page = await ctx.newPage();
    page.on("dialog", (d) => d.accept());

    await page.goto(`${baseURL}/BIRM27/sponsorship`);
    await expect(page.getByRole("heading", { name: "Sponsorship", exact: true })).toBeVisible();
    await page.getByRole("link", { name: "Add item" }).click();
    await page.waitForURL("**/sponsorship/new");
    // Only what sales needs: the item, buying and the sale.
    await expect(page.getByLabel("Width (mm)")).toBeHidden();
    await page.getByLabel("Name", { exact: true }).fill(name);
    await page.getByLabel("Item type").selectOption({ label: "Other sponsorship item" });
    await page.getByLabel("Quantity").fill("1500");
    const bigPrint = await page
      .locator("#supplierId option", { hasText: "Big Print Co" })
      .getAttribute("value");
    await page.getByLabel("Supplier").selectOption(bigPrint!);
    await page.getByLabel("Cost price (£)").fill("600");
    await page.getByLabel("Order by").fill(inDays(10));
    await expect(page.getByLabel("Sponsor", { exact: true })).toHaveValue("");
    await page.getByRole("button", { name: "Create item" }).click();
    await page.waitForURL("**/sponsorship/SIG-BIRM27-*");
    const ref = new URL(page.url()).pathname.split("/").pop()!;
    await expect(page.getByRole("heading", { name })).toBeVisible();

    // At a glance: available, the countdown warning, and a photo added here.
    const glance = page.getByRole("region", { name: "At a glance" });
    await expect(glance.getByText("Available")).toBeVisible();
    await expect(glance.getByText(/Less than 1 month to sell/)).toBeVisible();
    await page.getByLabel("Item photo").setInputFiles({
      name: "pens.png",
      mimeType: "image/png",
      buffer: PNG,
    });
    await expect(glance.getByRole("img", { name })).toBeVisible();

    // The card: photo, cost, supplier, countdown and the warning.
    await page.goto(`${baseURL}/BIRM27/sponsorship`);
    const card = page.getByRole("listitem", { name });
    await expect(card.getByRole("img", { name })).toBeVisible();
    await expect(card.getByText("Available")).toBeVisible();
    await expect(card.getByText("£600")).toBeVisible();
    await expect(card.getByText("Big Print Co")).toBeVisible();
    await expect(card.getByText(/Order by .* — 10 days left/)).toBeVisible();
    await expect(card.getByText("Less than 1 month to sell")).toBeVisible();
    await page.getByRole("button", { name: /Under a month to sell/ }).click();
    await expect(page.getByRole("listitem", { name })).toBeVisible();
    await page.getByRole("button", { name: /^All/ }).click();

    // Mark as sold to a sponsor who isn't on the list yet.
    await card.getByRole("button", { name: "Mark as sold" }).click();
    const dialog = page.getByRole("dialog");
    await dialog.getByLabel("Sponsor").selectOption({ label: "+ New sponsor…" });
    await dialog.getByLabel("New sponsor's company name").fill(sponsor);
    await dialog.getByLabel("Sale price (£)").fill("1500");
    await dialog.getByRole("button", { name: "Save sale" }).click();
    await expect(dialog).toHaveCount(0);
    await expect(card.getByText("Sold", { exact: true })).toBeVisible();
    await expect(card.getByText("£1,500")).toBeVisible();
    await expect(card.getByText("£900")).toBeVisible(); // profit
    await expect(card.getByText(sponsor)).toBeVisible();
    await expect(card.getByText("Less than 1 month to sell")).toHaveCount(0);

    // The new sponsor is under Sponsors with what they spent.
    await page
      .getByRole("navigation", { name: "Sponsorship sections" })
      .getByRole("link", { name: /^Sponsors/ })
      .click();
    await expect(page.getByText(sponsor)).toBeVisible();
    await expect(page.getByText("1 item bought · £1,500").first()).toBeVisible();

    // History has the sale, and the item page shows the sale price.
    await page.goto(`${baseURL}/BIRM27/sponsorship/${ref}?tab=history`);
    await expect(page.getByText(new RegExp(`Sold ${ref} to ${sponsor}`))).toBeVisible();
    await page.goto(`${baseURL}/BIRM27/sponsorship/${ref}`);
    await expect(page.getByLabel("Sale price (£)")).toHaveValue("1500.00");

    // Undo the sale: back to available.
    await page.goto(`${baseURL}/BIRM27/sponsorship`);
    await page.getByRole("listitem", { name }).getByRole("button", { name: "Undo sale" }).click();
    await expect(page.getByRole("listitem", { name }).getByText("Available")).toBeVisible();

    // It's in the signage schedule too, as sponsor signage.
    await page.goto(`${baseURL}/BIRM27/signage?q=${encodeURIComponent(ref)}`);
    await expect(page.locator("tr", { hasText: ref })).toBeVisible();
    await ctx.close();
  });

  test("the seeded cards show sales totals and warnings", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "marketing@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/sponsorship`);
    const summary = page.getByLabel("Sales summary");
    await expect(summary.getByText("Profit on sales")).toBeVisible();
    const bottles = page.getByRole("listitem", { name: "Water bottles" });
    await expect(bottles.getByText("Less than 1 month to sell")).toBeVisible();
    const lanyards = page.getByRole("listitem", { name: "Branded lanyards — BuildCo" });
    await expect(lanyards.getByText("Sold", { exact: true })).toBeVisible();
    await expect(lanyards.getByText("£9,000")).toBeVisible();
    // Everyone sees prices; marketing can't sell.
    await expect(lanyards.getByText("Cost price")).toBeVisible();
    await expect(lanyards.getByText("£4,500").first()).toBeVisible();
    await expect(page.getByRole("button", { name: "Mark as sold" })).toHaveCount(0);
    await ctx.close();
  });

  test("viewers cannot add sponsorship items", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "viewer@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/sponsorship`);
    await expect(page.getByRole("heading", { name: "Sponsorship", exact: true })).toBeVisible();
    await expect(page.getByRole("link", { name: "Add item" })).toHaveCount(0);
    await page.goto(`${baseURL}/BIRM27/sponsorship/new`);
    await page.waitForURL("**/sponsorship");
    await ctx.close();
  });
});
