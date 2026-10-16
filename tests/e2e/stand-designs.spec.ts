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

/** Upload a draft's first file: it goes for sign-off in the same step. */
async function uploadAndSubmit(page: Page, url: string, fileName: string) {
  await page.goto(`${url}?tab=artwork`);
  const upload = page.getByRole("button", { name: "Upload", exact: true });
  // A file chosen before React has hydrated is lost; choose again until the
  // Upload button wakes up.
  for (let attempt = 0; attempt < 4; attempt++) {
    await page.setInputFiles('input[type="file"]', {
      name: fileName,
      mimeType: "application/pdf",
      buffer: PDF,
    });
    if (await upload.isEnabled({ timeout: 2_000 }).catch(() => false)) break;
    await page.waitForTimeout(1_000);
  }
  await upload.click();
  await expect(page.getByText(`v1 — ${fileName}`)).toBeVisible();
  await page.goto(url);
  await expect(page.getByText("In sign-off", { exact: true }).first()).toBeVisible();
}

test.describe("stand designs", () => {
  test("design approved by the chosen people, then a panel's graphic", async ({
    browser,
    baseURL,
  }) => {
    test.setTimeout(180_000); // two full sign-off rounds on a dev server
    const name = `E2E feature stand ${Date.now()}`;
    const ops = await as(browser, "ops@media10.test", baseURL!);

    // Ops sets up the stand and chooses who approves it.
    await ops.goto(`${baseURL}/BIRM27/stand-designs`);
    await expect(ops.getByRole("heading", { name: "Feature stands", exact: true })).toBeVisible();
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

    // Panels can be listed before the design is approved (printers quote early).
    await ops.goto(`${standUrl}?tab=panels`);
    await expect(
      ops.getByText(
        "You can list panels now; their graphics go for sign-off once the design is approved.",
      ),
    ).toBeVisible();
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

    // The panel's own details are the slim set; place and sign-off come from the stand.
    const glance = ops.getByRole("region", { name: "At a glance" });
    await expect(
      glance.getByText(/From the stand: Hall 1 · Stand Z99 · Signed off by/),
    ).toBeVisible();
    await expect(glance.getByText(/Operations, Marketing \(Marcus Marketing\)/)).toBeVisible();
    await ops.getByRole("button", { name: "Edit details" }).click();
    await expect(ops.getByLabel("Panel name")).toHaveValue("Back wall");
    await expect(ops.getByLabel("Printer")).toBeVisible();
    await expect(ops.getByText("Whose signage is it?")).toHaveCount(0);
    await expect(ops.getByLabel("Fixing method")).toHaveCount(0);
    await ops.getByRole("button", { name: "Cancel" }).click();

    // Moving the stand moves its panel (still a draft) too.
    await ops.goto(standUrl);
    await ops.getByLabel("Stand no.").fill("Z98");
    await ops.getByRole("button", { name: "Save changes" }).click();
    await expect(ops.getByText(/1 panel updated to match/)).toBeVisible();
    await ops.goto(panelUrl);
    await expect(ops.getByText(/From the stand: Hall 1 · Stand Z98/)).toBeVisible();

    // The design goes for sign-off to the named marketer and operations.
    await uploadAndSubmit(ops, standUrl, "stand-design.pdf");
    const mkt = await as(browser, "marketing@media10.test", baseURL!);
    await mkt.goto(`${baseURL}/approvals`);
    await expect(mkt.getByText(`Stand design: ${name}`)).toBeVisible();
    await decide(mkt, baseURL!, standRef, "Approve");
    await decide(ops, baseURL!, standRef, "Approve");
    await ops.goto(standUrl);
    await expect(ops.getByText("Approved", { exact: true }).first()).toBeVisible();

    // Now the panel's graphic goes to the same approvers.
    await uploadAndSubmit(ops, panelUrl, "back-wall.pdf");
    await decide(mkt, baseURL!, panelRef, "Approve");
    await decide(ops, baseURL!, panelRef, "Approve");
    await ops.goto(`${panelUrl}?tab=artwork`);
    await expect(ops.getByText("Approved", { exact: true }).first()).toBeVisible();
    // Next it's printed, delivered and installed like a sign.
    await expect(ops.getByText("Sent to print").first()).toBeVisible();

    // The stand's card shows its panels' progress and opens on Panels.
    await ops.goto(`${baseURL}/BIRM27/stand-designs?q=${encodeURIComponent(name)}`);
    const standCard = ops.getByRole("link", { name });
    await expect(standCard.getByText("Panels: 1 of 1 approved")).toBeVisible();
    await expect(standCard).toHaveAttribute("href", new RegExp(`${standRef}\\?tab=panels$`));

    // Stands and panels stay out of the Signage table.
    await ops.goto(`${baseURL}/BIRM27/signage`);
    await ops.getByPlaceholder(/Search ref/).fill("Z99");
    await expect(ops.locator("main table tbody tr")).toHaveCount(0);

    for (const p of [ops, mkt]) await p.context().close();
  });

  test("only admins and operations set up stands", async ({ browser, baseURL }) => {
    const mkt = await as(browser, "marketing@media10.test", baseURL!);
    await mkt.goto(`${baseURL}/BIRM27/stand-designs`);
    await expect(mkt.getByRole("heading", { name: "Feature stands" })).toBeVisible();
    await expect(mkt.getByRole("link", { name: "New stand" })).toHaveCount(0);
    await mkt.goto(`${baseURL}/BIRM27/stand-designs/new`);
    await mkt.waitForURL("**/BIRM27/stand-designs");
    await mkt.context().close();
  });
});
