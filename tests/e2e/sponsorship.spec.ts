import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

// A 1×1 PNG stands in for a product photo.
const PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  "base64",
);
// Dates as the app counts them: in London, not UTC (they differ around midnight).
const inDays = (n: number) =>
  new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/London",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date(Date.now() + n * 86_400_000));

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

    // Its next step is to sell it; the facts are read-only, with the countdown.
    const nextStep = page.getByRole("region", { name: "Next step" });
    await expect(nextStep.getByText("For sale. Next: find a sponsor")).toBeVisible();
    await expect(nextStep.getByRole("button", { name: "Mark as sold" })).toBeVisible();
    const glance = page.getByRole("region", { name: "At a glance" });
    await expect(glance.getByText("For sale", { exact: true })).toBeVisible();
    await expect(glance.getByText(/Less than 1 month to sell/)).toBeVisible();
    // A spec label is for signs, not giveaways.
    await expect(glance.getByRole("link", { name: "Spec label (PDF)" })).toHaveCount(0);
    await page.getByLabel("Item photo").setInputFiles({
      name: "pens.png",
      mimeType: "image/png",
      buffer: PNG,
    });
    await expect(glance.getByRole("img", { name })).toBeVisible();

    // The card: photo, cost, supplier, countdown, the warning and what's next.
    await page.goto(`${baseURL}/BIRM27/sponsorship`);
    const card = page.getByRole("main").getByRole("listitem", { name });
    await expect(card.getByRole("img", { name })).toBeVisible();
    await expect(card.getByText("Available", { exact: true })).toBeVisible();
    await expect(card.getByText("£600")).toBeVisible();
    await expect(card.getByText("Big Print Co")).toBeVisible();
    await expect(card.getByText(/Order by .* — 10 days left/)).toBeVisible();
    await expect(card.getByText("Less than 1 month to sell")).toBeVisible();
    await expect(card.getByText(/^Next: sell by /)).toBeVisible();
    // The filter lives in the address.
    await page.getByRole("button", { name: /^Under a month/ }).click();
    await expect(page).toHaveURL(/filter=soon/);
    await expect(card).toBeVisible();
    await page.getByRole("button", { name: /^All/ }).click();

    // Mark as sold to a sponsor who isn't on the list yet.
    await card.getByRole("button", { name: "Mark as sold" }).click();
    const dialog = page.getByRole("dialog");
    await dialog.getByLabel("Sponsor").selectOption({ label: "+ New sponsor…" });
    await dialog.getByLabel("New sponsor's company name").fill(sponsor);
    await dialog.getByLabel("Sale price (£)").fill("1500");
    await dialog.getByRole("button", { name: "Save sale" }).click();
    await expect(dialog).toHaveCount(0);
    await expect(page.getByText(`${ref} sold to ${sponsor}`)).toBeVisible();
    await expect(card.getByText("Sold", { exact: true })).toBeVisible();
    await expect(card.getByText("£1,500")).toBeVisible();
    await expect(card.getByText("£900")).toBeVisible(); // profit
    await expect(card.getByText(sponsor, { exact: true })).toBeVisible();
    await expect(card.getByText("Less than 1 month to sell")).toHaveCount(0);
    await expect(card.getByText(`Next: get artwork from ${sponsor}`)).toBeVisible();

    // The new sponsor is under Sponsors; what they bought links to those items.
    await page
      .getByRole("navigation", { name: "Sponsorship sections" })
      .getByRole("link", { name: /^Sponsors/ })
      .click();
    const sponsorCard = page.getByRole("main").getByRole("listitem", { name: sponsor });
    await expect(sponsorCard.getByText("£1,500")).toBeVisible();
    await sponsorCard.getByRole("link", { name: "1 item bought" }).click();
    await expect(page).toHaveURL(/sponsor=/);
    await expect(
      page.getByRole("button", { name: new RegExp(`Showing ${sponsor} only`) }),
    ).toBeVisible();
    await expect(page.getByRole("main").getByRole("listitem")).toHaveCount(1);

    // History has the sale, and the item page shows the sale price.
    await page.goto(`${baseURL}/BIRM27/sponsorship/${ref}?tab=history`);
    await expect(page.getByText(new RegExp(`Sold ${ref} to ${sponsor}`))).toBeVisible();
    await page.goto(`${baseURL}/BIRM27/sponsorship/${ref}`);
    const sold = page.getByRole("region", { name: "At a glance" });
    await expect(sold.getByText("£1,500")).toBeVisible();
    await expect(
      page
        .getByRole("region", { name: "Next step" })
        .getByText(`Sold to ${sponsor}. Next: get the sponsor's artwork`),
    ).toBeVisible();

    // Undo the sale (after a confirm): back to available.
    await page.goto(`${baseURL}/BIRM27/sponsorship`);
    await card.getByRole("button", { name: "Undo sale" }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Undo sale" }).click();
    await expect(card.getByText("Available", { exact: true })).toBeVisible();

    // Sold again from the item page; the toast's Undo takes it straight back.
    await page.goto(`${baseURL}/BIRM27/sponsorship/${ref}`);
    await page
      .getByRole("region", { name: "Next step" })
      .getByRole("button", { name: "Mark as sold" })
      .click();
    const again = page.getByRole("dialog");
    await again.getByLabel("Sponsor").selectOption({ label: sponsor });
    await again.getByLabel("Sale price (£)").fill("1200");
    await again.getByRole("button", { name: "Save sale" }).click();
    const toast = page.getByRole("listitem").filter({ hasText: `${ref} sold to ${sponsor}` });
    await toast.getByRole("button", { name: "Undo" }).click();
    await expect(page.getByText(`${ref} is for sale again`)).toBeVisible();
    await expect(
      page.getByRole("region", { name: "Next step" }).getByText("For sale. Next: find a sponsor"),
    ).toBeVisible();

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
    await expect(summary.getByText("In packages")).toBeVisible();
    const main = page.getByRole("main");
    // The seeded order-by date drifts into the past: under a month or overdue.
    const bottles = main.getByRole("listitem", { name: "Water bottles" });
    await expect(
      bottles.getByText(/Less than 1 month to sell|days? overdue|Order today/),
    ).toBeVisible();
    await expect(bottles.getByText(/^Next: sell/)).toBeVisible();
    const lanyards = main.getByRole("listitem", { name: "Branded lanyards — BuildCo" });
    await expect(lanyards.getByText("Sold", { exact: true })).toBeVisible();
    await expect(lanyards.getByText("£9,000")).toBeVisible();
    await expect(lanyards.getByText(/^Waiting on /)).toBeVisible();
    // Sponsor signage comes with a package: not a £0 sale.
    const arch = main.getByRole("listitem", { name: "Main entrance arch banner" });
    await expect(arch.getByText("In package", { exact: true })).toBeVisible();
    await expect(arch.getByText("Sale price")).toHaveCount(0);
    // Everyone sees prices; marketing can't sell.
    await expect(lanyards.getByText("Cost price")).toBeVisible();
    await expect(lanyards.getByText("£4,500").first()).toBeVisible();
    await expect(page.getByRole("button", { name: "Mark as sold" })).toHaveCount(0);
    await ctx.close();
  });

  test("sales fix a sponsor's entitlements and remove a sponsor added by mistake", async ({
    browser,
    baseURL,
  }) => {
    const n = String(Date.now()).slice(-6);
    const company = `Typo Co ${n}`;
    const ctx = await browser.newContext();
    await signInAs(ctx, "sales@media10.test", baseURL!);
    const page = await ctx.newPage();
    const main = page.getByRole("main");

    await page.goto(`${baseURL}/BIRM27/sponsorship?tab=sponsors`);
    // Only this tab's button in the header.
    await expect(main.getByRole("link", { name: "Add item" })).toHaveCount(0);
    await main.getByRole("link", { name: "Add sponsor" }).click();
    let dialog = page.getByRole("dialog");
    await dialog.getByLabel("Company").fill(company);
    await dialog.getByLabel("Entitlements (optional)").fill("3 x Banners\nLogo on bags");
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    await expect(page.getByText(`${company} added`)).toBeVisible();

    const card = main.getByRole("listitem", { name: company });
    await expect(card.getByText("3 × Banners")).toBeVisible();
    await expect(card.getByText("Nothing bought yet")).toBeVisible();

    // A typo is fixed in place.
    await card.getByRole("button", { name: "Edit Banners" }).click();
    dialog = page.getByRole("dialog");
    await dialog.getByLabel("Quantity").fill("4");
    await dialog.getByLabel("What they get").fill("Hanging banners");
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    await expect(card.getByText("4 × Hanging banners")).toBeVisible();

    // Nothing counts towards it, so it can go (after a confirm).
    await card.getByRole("button", { name: "Remove Logo on bags" }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Remove", exact: true }).click();
    await expect(card.getByText("Logo on bags")).toHaveCount(0);

    // Nothing is linked to the sponsor: "Remove sponsor" is offered.
    await card.getByRole("button", { name: `Change ${company}` }).click();
    await page.getByRole("menuitem", { name: "Remove sponsor" }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Remove sponsor" }).click();
    await expect(page.getByText(`Removed ${company}`)).toBeVisible();
    await expect(main.getByRole("listitem", { name: company })).toHaveCount(0);
    await ctx.close();
  });

  test("search, list view, grouping and filters live in the address", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
    await signInAs(ctx, "marketing@media10.test", baseURL!);
    const page = await ctx.newPage();
    const main = page.getByRole("main");

    // On a phone the list is the default.
    await page.goto(`${baseURL}/BIRM27/sponsorship?q=lanyards`);
    const lanyards = main.getByRole("listitem", { name: "Branded lanyards — BuildCo" });
    await expect(lanyards).toBeVisible();
    expect((await lanyards.boundingBox())!.height).toBeLessThan(200);
    await expect(main.getByRole("listitem")).toHaveCount(1);

    // Grouped by stage; the dashboard's ?filter=urgent marks both date chips.
    await page.goto(`${baseURL}/BIRM27/sponsorship?view=cards&group=stage&filter=urgent`);
    await expect(page.getByRole("button", { name: /^Overdue to order/ })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    await expect(page.getByRole("button", { name: /^Under a month/ })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    await expect(main.getByRole("heading", { name: /^For sale · \d+$/ })).toBeVisible();
    await page.getByRole("button", { name: /^Sold \(/ }).click();
    await expect(page).toHaveURL(/filter=sold/);
    await expect(main.getByRole("listitem", { name: "Branded lanyards — BuildCo" })).toBeVisible();
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
