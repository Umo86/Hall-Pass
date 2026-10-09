import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

// A few bytes stand in for a screen's video file; the type check is by name and MIME.
const MP4 = Buffer.from("00000018667479706d703432", "hex");

test.describe("video artwork", () => {
  test("a digital sign takes a video and plays it on the item page", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/signage/new`);
    const name = `E2E screen ${Date.now()}`;
    await page.getByLabel("Name", { exact: true }).fill(name);
    await page.getByRole("button", { name: "Create item" }).click();
    await page.waitForURL("**/signage/SIG-BIRM27-*");
    const itemUrl = page.url().split("?")[0];

    await page.goto(`${itemUrl}?tab=artwork`);
    const upload = page.getByRole("button", { name: "Upload" });
    for (let attempt = 0; attempt < 4; attempt++) {
      await page.setInputFiles('input[type="file"]', {
        name: "promo.mp4",
        mimeType: "video/mp4",
        buffer: MP4,
      });
      if (await upload.isEnabled({ timeout: 2_000 }).catch(() => false)) break;
      await page.waitForTimeout(1_000);
    }
    await upload.click();
    await expect(page.getByText("v1 — promo.mp4")).toBeVisible();
    // Played inline rather than "no preview — download to view".
    const player = page.locator("video");
    await expect(player).toHaveCount(1);
    await expect(player).toHaveAttribute("src", /\/api\/files\/artwork\/.*promo\.mp4\?inline=1$/);
    await expect(page.getByText("No preview for this file type")).toHaveCount(0);

    // Something that is not artwork is still refused.
    await page.setInputFiles('input[type="file"]', {
      name: "notes.html",
      mimeType: "text/html",
      buffer: Buffer.from("<p>hi</p>"),
    });
    await upload.click();
    await expect(page.getByText(/Unsupported file type/)).toBeVisible();
    await ctx.close();
  });
});
