import { expect, test, type Browser, type Page } from "@playwright/test";
import { signInAs } from "./helpers";

/** Today in the show's time zone, as the date inputs want it. */
const todayLondon = () =>
  new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/London",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());

// A 1×1 PNG stands in for the installer's camera photo.
const PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  "base64",
);

async function as(browser: Browser, email: string, baseURL: string): Promise<Page> {
  const ctx = await browser.newContext();
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

/** Decide the step waiting on this person for `ref` from My Sign-offs. */
async function decide(
  page: Page,
  baseURL: string,
  ref: string,
  button: "Approve" | "Confirm",
  opts: { photo?: boolean; date?: string } = {},
) {
  await page.goto(`${baseURL}/approvals`);
  const row = page.locator("li", { hasText: ref });
  await row.getByRole("button", { name: button, exact: true }).click();
  const dialog = page.getByRole("dialog");
  if (opts.date) await dialog.getByLabel("When did this happen?").fill(opts.date);
  if (opts.photo) {
    await dialog
      .getByLabel(/photo of the installed item/i)
      .setInputFiles({ name: "install.png", mimeType: "image/png", buffer: PNG });
    await expect(dialog.getByAltText("Install photo preview")).toBeVisible();
  }
  await dialog.getByRole("button", { name: button, exact: true }).click();
  await expect(dialog).toHaveCount(0);
}

test.describe("lifecycle: print → install → snag → reopen → close", () => {
  test("ops takes a sign from approval to closed, with the Onsite checklist", async ({
    browser,
    baseURL,
  }) => {
    test.setTimeout(180_000);
    const today = todayLondon();
    const ops = await as(browser, "ops@media10.test", baseURL!);

    // A sign with a supplier, a place in Hall 1 and today's install date.
    await ops.goto(`${baseURL}/BIRM27/signage/new`);
    const name = `E2E lifecycle sign ${Date.now()}`;
    await ops.getByLabel("Name", { exact: true }).fill(name);
    await ops.getByLabel("Needs Senior management sign-off").uncheck();
    await ops.getByLabel("Item type").selectOption({ label: "Foamex board" });
    await ops.getByLabel("Hall", { exact: true }).selectOption({ label: "Hall 1" });
    await ops.getByLabel("Location").selectOption({ label: "Registration" });
    await ops.getByLabel("Width (mm)").fill("1000");
    await ops.getByLabel("Height (mm)").fill("500");
    await ops.getByLabel("Fixing method").selectOption("wall_mounted");
    await ops.getByLabel("Supplier").selectOption({ index: 1 });
    await ops.getByLabel("Install date").fill(today);
    await ops.getByRole("button", { name: "Create item" }).click();
    await ops.waitForURL("**/signage/SIG-BIRM27-*");
    const itemUrl = ops.url().split("?")[0];
    const ref = itemUrl.split("/").pop()!;

    // Change requests are gone: editing is the one way to change an item.
    await expect(ops.getByRole("link", { name: "Change requests" })).toHaveCount(0);

    // Artwork, review, approvals.
    await ops.goto(`${itemUrl}?tab=artwork`);
    await ops.setInputFiles('input[type="file"]', {
      name: "artwork.pdf",
      mimeType: "application/pdf",
      buffer: Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF"),
    });
    await ops.getByRole("button", { name: "Upload" }).click();
    await expect(ops.getByText("v1 — artwork.pdf")).toBeVisible();
    await ops.goto(itemUrl);
    await ops.getByRole("button", { name: "Submit for review" }).click();
    await expect(ops.getByText("In review", { exact: true })).toBeVisible();
    const mkt = await as(browser, "marketing@media10.test", baseURL!);
    await decide(mkt, baseURL!, ref, "Approve");
    await decide(ops, baseURL!, ref, "Approve");
    await ops.goto(itemUrl);
    await expect(ops.getByText("Approved", { exact: true }).first()).toBeVisible();

    // Ops confirms the supplier steps with the real dates ("or Operations").
    await ops.goto(`${itemUrl}?tab=artwork`);
    await expect(ops.getByText("or Operations").first()).toBeVisible();
    // A real-world date in the past (the server refuses future dates).
    await decide(ops, baseURL!, ref, "Confirm", { date: "2026-09-20" }); // Sent to print
    await ops.goto(`${itemUrl}?tab=artwork`);
    await expect(ops.getByText(/done 20 Sept 2026/)).toBeVisible();
    await decide(ops, baseURL!, ref, "Confirm"); // Delivered
    await ops.goto(itemUrl);
    await expect(ops.getByText("Delivered", { exact: true }).first()).toBeVisible();

    // Onsite: the sign is due today under its hall; tick it off with a photo.
    await ops.goto(`${baseURL}/BIRM27/onsite`);
    await expect(ops.getByRole("heading", { name: "Onsite" })).toBeVisible();
    const card = ops.locator("article", { hasText: ref });
    await expect(card).toBeVisible();
    await expect(ops.getByRole("heading", { name: /Hall 1 · Registration/ })).toBeVisible();
    await card.getByRole("button", { name: "Installed ✓" }).click();
    const installDialog = ops.getByRole("dialog");
    await installDialog
      .getByLabel(/photo of the installed item/i)
      .setInputFiles({ name: "install.png", mimeType: "image/png", buffer: PNG });
    await expect(installDialog.getByAltText("Install photo preview")).toBeVisible();
    await installDialog.getByRole("button", { name: "Confirm", exact: true }).click();
    await expect(installDialog).toHaveCount(0);
    // Installed items leave the to-do list; "Everything" still shows them.
    await expect(card).toHaveCount(0);
    await ops.getByRole("button", { name: "Everything" }).click();
    await expect(card).toBeVisible();
    await expect(card.getByText("Installed", { exact: true })).toBeVisible();

    // A snag raised on the spot marks it Snagged.
    await card.getByRole("button", { name: "Raise snag" }).click();
    const snagDialog = ops.getByRole("dialog");
    await snagDialog.getByLabel("What's wrong?").fill("Left edge peeling");
    await snagDialog.getByLabel("How bad is it?").selectOption("high");
    await snagDialog.getByRole("button", { name: "Raise snag" }).click();
    await expect(snagDialog).toHaveCount(0);
    await expect(card.getByText("Snagged", { exact: true })).toBeVisible();
    await expect(card.getByText("1 snag")).toBeVisible();

    // Resolving it on the item page takes it back to Installed.
    await ops.goto(itemUrl);
    await expect(ops.getByText("Left edge peeling")).toBeVisible();
    await ops.getByRole("button", { name: "Resolved", exact: true }).click();
    await ops.getByRole("dialog").getByPlaceholder("What was done").fill("Re-stuck the edge");
    await ops.getByRole("dialog").getByRole("button", { name: "Resolved", exact: true }).click();
    await expect(ops.getByText("All snags cleared — item back to Installed")).toBeVisible();
    await expect(ops.getByText("Installed", { exact: true }).first()).toBeVisible();

    // Reopen undoes the install: back to Delivered, photo cleared.
    await ops.getByRole("button", { name: "Reopen", exact: true }).click();
    const reopenDialog = ops.getByRole("dialog");
    await reopenDialog.getByPlaceholder(/Why\?/).fill("Hung in the wrong place");
    await reopenDialog.getByRole("button", { name: "Reopen", exact: true }).click();
    await expect(reopenDialog).toHaveCount(0);
    await expect(ops.getByText("Delivered", { exact: true }).first()).toBeVisible();
    await expect(ops.getByText(/Installed:\s*Not yet/)).toBeVisible();

    // Installed again, then closed.
    await decide(ops, baseURL!, ref, "Confirm", { photo: true });
    await ops.goto(itemUrl);
    await expect(ops.getByText("Installed", { exact: true }).first()).toBeVisible();
    await ops.getByRole("button", { name: "Close", exact: true }).click();
    await expect(ops.getByText("Closed", { exact: true }).first()).toBeVisible();
    await expect(ops.getByRole("button", { name: "Close", exact: true })).toHaveCount(0);
  });

  test("a show's print deadline can be pinned to a date", async ({ browser, baseURL }) => {
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/editions`);
    const row = admin.locator("li", { hasText: "BIRM27" }).first();
    await row.getByRole("button", { name: "Edit" }).click();
    const dialog = admin.getByRole("dialog");
    const fixed = dialog.getByLabel("Print deadline: fixed date");
    await fixed.fill("2027-09-14");
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);

    // The calendar shows it on that day; the dialog remembers it.
    await admin.goto(`${baseURL}/BIRM27/calendar?m=2027-09`);
    await expect(admin.getByRole("cell", { name: /^14 Deadline: Print deadline/ })).toBeVisible();
    await admin.goto(`${baseURL}/editions`);
    await row.getByRole("button", { name: "Edit" }).click();
    await expect(dialog.getByLabel("Print deadline: fixed date")).toHaveValue("2027-09-14");
    // Put it back so other runs see the standard offset.
    await dialog.getByLabel("Print deadline: fixed date").fill("");
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
  });
});
