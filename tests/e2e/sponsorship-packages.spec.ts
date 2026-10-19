import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

/**
 * Sponsorship packages: a priced catalogue per event, selling one at an
 * agreed price (what's included lands on the sponsor's entitlements), and
 * package revenue on the page and the dashboard. Each run makes its own
 * package and sponsor and removes them again; nothing here asserts totals
 * other specs change (exact figures are in sponsorship-packages.db.test.ts).
 */
test.describe("sponsorship packages", () => {
  test("sales add a package, sell it to a new sponsor at a discount, see it on both tabs and take it back", async ({
    browser,
    baseURL,
  }) => {
    const n = String(Date.now()).slice(-6);
    const pkg = `Gold ${n}`;
    const company = `Gold Co ${n}`;
    const ctx = await browser.newContext();
    await signInAs(ctx, "sales@media10.test", baseURL!);
    const page = await ctx.newPage();
    const main = page.getByRole("main");

    await page.goto(`${baseURL}/BIRM27/sponsorship`);
    await main.getByRole("link", { name: /^Packages \(\d+\)$/ }).click();
    await page.waitForURL("**/sponsorship?tab=packages");
    await main.getByRole("link", { name: "Add package" }).click();
    let dialog = page.getByRole("dialog");
    await expect(dialog.getByRole("heading", { name: "Add package" })).toBeVisible();
    await dialog.getByLabel("Name").fill(pkg);
    await dialog.getByLabel("Price (£, optional)").fill("10000");
    await dialog.getByLabel("How many to sell (optional)").fill("2");
    await dialog
      .getByLabel("What's included (one per line)")
      .fill("2 x Banners\nLogo in the event guide");
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    await expect(page.getByText(`${pkg} added`)).toBeVisible();

    const card = main.getByRole("listitem", { name: pkg, exact: true });
    await expect(card.getByText("Not sold yet · 2 places")).toBeVisible();
    await expect(card.getByText("£10,000", { exact: true })).toBeVisible();
    await expect(card.getByText("2 × Banners")).toBeVisible();

    // Sell to a new sponsor below the list price: a reason is asked for.
    await card.getByRole("button", { name: "Sell", exact: true }).click();
    dialog = page.getByRole("dialog");
    await expect(dialog.getByRole("heading", { name: `Sell ${pkg}` })).toBeVisible();
    await dialog.getByLabel("Sponsor").selectOption({ label: "+ New sponsor…" });
    await dialog.getByLabel("New sponsor's company name").fill(company);
    await expect(dialog.getByLabel("Agreed price (£)")).toHaveValue("10000");
    await expect(dialog.getByLabel("Why is it different?")).toHaveCount(0);
    await dialog.getByLabel("Agreed price (£)").fill("9000");
    await expect(dialog.getByText("List price £10,000 — £1,000 less")).toBeVisible();
    await expect(dialog.getByText(`Added to ${company}'s entitlements`)).toBeVisible();
    await dialog.getByLabel("Why is it different?").fill("Early booking");
    await dialog.getByRole("button", { name: "Save sale" }).click();
    await expect(dialog).toHaveCount(0);
    await expect(page.getByText(`${company} bought ${pkg}`)).toBeVisible();
    await expect(card.getByText("1 of 2 sold · 1 left")).toBeVisible();
    await expect(card.getByText("£9,000 (Early booking)")).toBeVisible();

    // The sponsor's card: their package, price and the lines it added.
    await main.getByRole("link", { name: /^Sponsors \(\d+\)$/ }).click();
    await page.waitForURL("**/sponsorship?tab=sponsors");
    const sponsor = main.getByRole("listitem", { name: company, exact: true });
    const block = sponsor.getByLabel(`${company}'s package`);
    await expect(block.getByText(pkg)).toBeVisible();
    await expect(block.getByText(/£9,000/)).toBeVisible();
    await expect(sponsor.getByText("2 × Banners")).toBeVisible();
    await expect(sponsor.getByText(`· from ${pkg}`).first()).toBeVisible();
    // While they have a package, "Remove sponsor" isn't offered.
    await sponsor.getByRole("button", { name: `Change ${company}` }).click();
    await expect(page.getByRole("menuitem", { name: "Edit sponsor" })).toBeVisible();
    await expect(page.getByRole("menuitem", { name: "Remove sponsor" })).toHaveCount(0);
    await page.keyboard.press("Escape");

    // Take the package back: the confirm says what goes.
    await block.getByRole("button", { name: "Remove", exact: true }).click();
    dialog = page.getByRole("dialog");
    await expect(
      dialog.getByRole("heading", { name: `Remove ${pkg} from ${company}?` }),
    ).toBeVisible();
    await expect(dialog).toContainText(
      "Their agreed price (£9,000) comes off sponsorship revenue.",
    );
    await expect(dialog).toContainText("2 × Banners");
    await expect(dialog).toContainText("Logo in the event guide");
    await dialog.getByRole("button", { name: "Remove package" }).click();
    await expect(page.getByText(`Removed ${pkg} from ${company}`)).toBeVisible();
    await expect(block.getByText("No package")).toBeVisible();
    await expect(sponsor.getByText("2 × Banners")).toHaveCount(0);

    // Clean up through the app: the package was never kept, so it can be deleted…
    await page.goto(`${baseURL}/BIRM27/sponsorship?tab=packages`);
    await card.getByRole("button", { name: `Change ${pkg}` }).click();
    await page.getByRole("menuitem", { name: "Delete package" }).click();
    dialog = page.getByRole("dialog");
    await expect(dialog).toContainText("It has never been sold");
    await dialog.getByRole("button", { name: "Delete package" }).click();
    await expect(page.getByText(`Removed ${pkg}`)).toBeVisible();
    await expect(card).toHaveCount(0);
    // …and the sponsor removed.
    await page.goto(`${baseURL}/BIRM27/sponsorship?tab=sponsors`);
    await sponsor.getByRole("button", { name: `Change ${company}` }).click();
    await page.getByRole("menuitem", { name: "Remove sponsor" }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Remove sponsor" }).click();
    await expect(page.getByText(`Removed ${company}`)).toBeVisible();
    await ctx.close();
  });

  test("the seeded catalogue shows sold out, places left and revenue", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    const main = page.getByRole("main");
    await page.goto(`${baseURL}/BIRM27/sponsorship?tab=packages`);
    const headline = main.getByRole("listitem", { name: "Headline sponsor", exact: true });
    await expect(headline.getByText("Sold out").first()).toBeVisible();
    await expect(headline.getByRole("button", { name: "Sell", exact: true })).toBeDisabled();
    const feature = main.getByRole("listitem", { name: "Feature area sponsor", exact: true });
    await expect(feature.getByText("Not sold yet · 3 places")).toBeVisible();
    await expect(feature.getByRole("button", { name: "Sell", exact: true })).toBeEnabled();
    // Revenue tiles (no exact sums: other specs sell items in BIRM27).
    const tiles = main.getByLabel("Revenue summary");
    await expect(tiles.getByText("Total revenue")).toBeVisible();
    await expect(tiles.getByText("Still to sell")).toBeVisible();
    await expect(tiles.getByText(/^£[\d,]+$/).first()).toBeVisible();
    await ctx.close();
  });

  test("viewers see packages read-only", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "viewer@media10.test", baseURL!);
    const page = await ctx.newPage();
    const main = page.getByRole("main");
    await page.goto(`${baseURL}/BIRM27/sponsorship?tab=packages`);
    await expect(
      main.getByRole("listitem", { name: "Headline sponsor", exact: true }),
    ).toBeVisible();
    await expect(main.getByRole("link", { name: "Add package" })).toHaveCount(0);
    await expect(main.getByRole("button", { name: "Sell", exact: true })).toHaveCount(0);
    await expect(main.getByRole("button", { name: /^Change / })).toHaveCount(0);
    await ctx.close();
  });

  test("the dashboard card shows package revenue", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    const main = page.getByRole("main");
    await page.goto(`${baseURL}/BIRM27/dashboard`);
    const sponsorship = main.getByRole("region", { name: "Sponsorship" });
    await expect(sponsorship.getByRole("link", { name: /^\d+ packages? sold/ })).toHaveAttribute(
      "href",
      "/BIRM27/sponsorship?tab=packages",
    );
    const revenue = sponsorship.getByLabel("Sponsorship revenue");
    await expect(revenue.getByText("Total revenue")).toBeVisible();
    await expect(revenue.getByText("Still to sell in packages")).toBeVisible();
    // The items line is as it was.
    await expect(sponsorship.getByRole("link", { name: /^\d+ of \d+ sold$/ })).toHaveAttribute(
      "href",
      "/BIRM27/sponsorship?filter=sold",
    );
    await ctx.close();
  });

  test("the Packages tab fits a phone", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
    await signInAs(ctx, "sales@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/sponsorship?tab=packages`);
    await expect(
      page.getByRole("main").getByRole("listitem", { name: "Headline sponsor", exact: true }),
    ).toBeVisible();
    const sideways = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(sideways).toBeLessThanOrEqual(0);
    const sell = page
      .getByRole("main")
      .getByRole("listitem", { name: "Feature area sponsor", exact: true })
      .getByRole("button", { name: "Sell", exact: true });
    const box = await sell.boundingBox();
    expect(box?.height ?? 0).toBeGreaterThanOrEqual(44);
    await ctx.close();
  });
});
