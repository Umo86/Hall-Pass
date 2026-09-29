import { expect, test, type Browser, type Page } from "@playwright/test";
import { signInAs } from "./helpers";

const PDF = Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF");

async function as(browser: Browser, email: string, baseURL: string): Promise<Page> {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  await signInAs(ctx, email, baseURL);
  const page = await ctx.newPage();
  page.on("dialog", (d) => d.accept());
  return page;
}

/** Decide the step waiting on this person for exactly `ref` (stand refs prefix panel refs). */
async function decide(page: Page, baseURL: string, ref: string, button: string) {
  await page.goto(`${baseURL}/approvals`);
  const row = page
    .locator("li")
    .filter({ has: page.getByRole("link", { name: ref, exact: true }) });
  await row.getByRole("button", { name: button, exact: true }).click();
  const dialog = page.getByRole("dialog");
  await dialog.getByRole("button", { name: button, exact: true }).click();
  await expect(dialog).toHaveCount(0);
}

async function uploadAndSubmit(page: Page, url: string, fileName: string) {
  await page.goto(`${url}?tab=artwork`);
  await page.setInputFiles('input[type="file"]', {
    name: fileName,
    mimeType: "application/pdf",
    buffer: PDF,
  });
  await page.getByRole("button", { name: "Upload" }).click();
  await expect(page.getByText(`v1 — ${fileName}`)).toBeVisible();
  await page.goto(url);
  await page.getByRole("button", { name: "Submit for review" }).click();
  await expect(page.getByText("In review", { exact: true }).first()).toBeVisible();
}

test.describe("stand designs", () => {
  test("design approved by the chosen people, then a panel's graphic", async ({
    browser,
    baseURL,
  }) => {
    const name = `E2E feature stand ${Date.now()}`;
    const ops = await as(browser, "ops@media10.test", baseURL!);

    // Ops sets up the stand and chooses who approves it.
    await ops.goto(`${baseURL}/BIRM27/stand-designs`);
    await ops.getByRole("link", { name: "New stand" }).click();
    await ops.getByLabel("Stand name").fill(name);
    await ops.getByLabel("Stand no.").fill("Z99");
    await ops.getByLabel("Hall", { exact: true }).selectOption({ label: "Hall 1" });
    await ops.getByLabel("Width").fill("6000");
    await ops.getByLabel("Depth").fill("3000");
    await ops.getByLabel("Height").fill("3500");
    await ops.getByLabel("Needs Senior management sign-off").uncheck();
    await expect(ops.getByLabel("Needs Operations sign-off")).toBeChecked();
    await expect(ops.getByLabel("Needs Marketing sign-off")).toBeChecked();
    await ops
      .getByLabel("Who signs Marketing sign-off")
      .selectOption({ label: "Marcus Marketing — Marketing Manager" });
    await ops.getByRole("button", { name: "Create stand" }).click();
    await ops.waitForURL("**/stand-designs/STB-BIRM27-*");
    const standUrl = ops.url().split("?")[0];
    const standRef = standUrl.split("/").pop()!;

    // No panels until the design is approved.
    await ops.goto(`${standUrl}?tab=panels`);
    await expect(ops.getByRole("button", { name: "Add panel" })).toBeDisabled();
    await expect(
      ops.getByText("Panels can be added once the stand design is approved."),
    ).toBeVisible();

    // The design goes for sign-off to the named marketer and operations.
    await uploadAndSubmit(ops, standUrl, "stand-design.pdf");
    const mkt = await as(browser, "marketing@media10.test", baseURL!);
    await mkt.goto(`${baseURL}/approvals`);
    await expect(mkt.getByText(`Stand design: ${name}`)).toBeVisible();
    await decide(mkt, baseURL!, standRef, "Approve");
    await decide(ops, baseURL!, standRef, "Approve");
    await ops.goto(standUrl);
    await expect(ops.getByText("Approved", { exact: true }).first()).toBeVisible();

    // Now a panel can be added; it goes to the same approvers.
    await ops.goto(`${standUrl}?tab=panels`);
    await ops.getByRole("button", { name: "Add panel" }).click();
    const dialog = ops.getByRole("dialog");
    await dialog.getByLabel("Panel name").fill("Back wall");
    await dialog.getByLabel("Width (mm)").fill("3000");
    await dialog.getByLabel("Height (mm)").fill("2500");
    await dialog.getByRole("button", { name: "Add panel" }).click();
    await ops.waitForURL(`**/stand-panels/${standRef}-P1**`);
    const panelUrl = ops.url().split("?")[0];
    const panelRef = `${standRef}-P1`;
    await expect(ops.getByRole("link", { name: new RegExp(standRef) })).toBeVisible();

    await ops.goto(panelUrl);
    await expect(ops.getByLabel("Needs Operations sign-off")).toBeChecked();
    await expect(ops.getByLabel("Needs Marketing sign-off")).toBeChecked();
    await expect(ops.getByLabel("Needs Senior management sign-off")).not.toBeChecked();
    await expect(ops.getByLabel("Who signs Marketing sign-off")).toHaveValue(/.+/);

    await uploadAndSubmit(ops, panelUrl, "back-wall.pdf");
    await decide(mkt, baseURL!, panelRef, "Approve");
    await decide(ops, baseURL!, panelRef, "Approve");
    await ops.goto(`${panelUrl}?tab=artwork`);
    await expect(ops.getByText("Approved", { exact: true }).first()).toBeVisible();
    // Next it's printed, delivered and installed like a sign.
    await expect(ops.getByText("Sent to print").first()).toBeVisible();

    // The stand shows its panels' progress.
    await ops.goto(`${baseURL}/BIRM27/stand-designs`);
    await expect(
      ops.getByRole("link", { name }).getByText("Panels: 1 of 1 approved"),
    ).toBeVisible();

    // Stands and panels stay out of the Signage table.
    await ops.goto(`${baseURL}/BIRM27/signage`);
    await ops.getByPlaceholder(/Search ref/).fill("Z99");
    await expect(ops.locator("main table tbody tr")).toHaveCount(0);

    for (const p of [ops, mkt]) await p.context().close();
  });

  test("only admins and operations set up stands", async ({ browser, baseURL }) => {
    const mkt = await as(browser, "marketing@media10.test", baseURL!);
    await mkt.goto(`${baseURL}/BIRM27/stand-designs`);
    await expect(mkt.getByRole("heading", { name: "Stand designs" })).toBeVisible();
    await expect(mkt.getByRole("link", { name: "New stand" })).toHaveCount(0);
    await mkt.goto(`${baseURL}/BIRM27/stand-designs/new`);
    await mkt.waitForURL("**/BIRM27/stand-designs");
    await mkt.context().close();
  });
});
