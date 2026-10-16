import { expect, test, type Browser, type Page } from "@playwright/test";
import { signInAs } from "./helpers";

const PDF = Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF");

async function as(browser: Browser, email: string, baseURL: string): Promise<Page> {
  const ctx = await browser.newContext();
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

// One person goes through the whole life: added, accepts, edited, removed.
test.describe.configure({ mode: "serial" });

test.describe("Users", () => {
  const n = String(Date.now()).slice(-6);
  const sam = `Sam Signage ${n}`;
  const samEmail = `sam-${n}@users.test`;
  const legal = `Legal ${n}`;
  let samId = "";

  test("admin adds someone who uses only Signage and signs off; they accept", async ({
    browser,
    baseURL,
  }) => {
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/users`);
    await expect(admin.getByRole("heading", { name: "Users", exact: true })).toBeVisible();
    await admin.getByRole("button", { name: "Add people" }).first().click();
    await admin.getByRole("menuitem", { name: "Add one person" }).click();
    await admin.waitForURL("**/users/new");

    await admin.getByLabel("Full name").fill(sam);
    await admin.getByLabel("Email").fill(samEmail);
    await admin.getByLabel("Department", { exact: true }).selectOption({ label: "Marketing" });
    // The role with the department's name is suggested.
    await expect(admin.getByRole("radio", { name: /^Marketing Adds/ })).toBeChecked();
    await admin.getByRole("checkbox", { name: "All sections" }).uncheck();
    await admin.getByRole("checkbox", { name: "Signage", exact: true }).check();
    await admin.getByRole("checkbox", { name: "Signs off Marketing artwork" }).check();
    // Keep Marketing going to the whole department for other tests.
    await admin.getByRole("checkbox", { name: /^Main approver/ }).uncheck();
    await admin.getByRole("button", { name: "Send invitation" }).click();

    // Email isn't set up locally: the link is there to copy.
    await expect(admin.getByText(`${sam} is invited`)).toBeVisible();
    const inviteUrl = await admin.getByLabel("Invitation link").inputValue();
    expect(inviteUrl).toContain("/invite/");

    // The list shows them as invited.
    await admin.goto(`${baseURL}/users?status=invited&q=${samEmail}`);
    const row = admin.getByRole("row").filter({ hasText: samEmail });
    await expect(row.getByText(/Invited \d+ \w+ by Alex/)).toBeVisible();
    await expect(
      row.getByRole("button", { name: `Copy an invitation link for ${sam}` }),
    ).toBeVisible();

    // They accept in a fresh browser.
    const sctx = await browser.newContext();
    const s = await sctx.newPage();
    await s.goto(inviteUrl);
    await expect(
      s.getByRole("heading", { name: /You're invited to join .+ as Marketing in Marketing/ }),
    ).toBeVisible();
    await expect(s.getByText("You'll also sign off signage artwork")).toBeVisible();
    await expect(s.getByLabel("Your name")).toHaveValue(sam);
    await s.getByLabel("Choose a password").fill("s3cure-pass");
    await s.getByLabel("Type it again").fill("s3cure-pass");
    await s.getByRole("button", { name: "Create my account" }).click();
    await s.waitForURL("**/my-work");

    // Only Signage of the event sections, plus Approvals because they sign off.
    await s.goto(`${baseURL}/BIRM27/dashboard`);
    const nav = s.getByRole("navigation", { name: "Main navigation" }).first();
    await expect(nav.getByRole("link", { name: "Signage", exact: true })).toBeVisible();
    await expect(nav.getByRole("link", { name: "Sponsorship" })).toHaveCount(0);
    await expect(nav.getByRole("link", { name: "Reports" })).toHaveCount(0);
    await expect(nav.getByRole("link", { name: /Approvals/ })).toBeVisible();
    await s.goto(`${baseURL}/BIRM27/sponsorship`);
    await expect(s.getByText("Sponsorship isn't switched on for you")).toBeVisible();
    await sctx.close();

    // Now a member: Active, with their own page.
    await admin.goto(`${baseURL}/users?q=${samEmail}`);
    const member = admin.getByRole("row").filter({ hasText: samEmail });
    await expect(member.getByText("Active")).toBeVisible();
    await expect(member.getByText("1 of", { exact: false })).toBeVisible();
    await member.getByRole("link", { name: sam }).click();
    await admin.waitForURL(/\/users\/[0-9a-f-]{36}$/);
    samId = admin.url().split("/").pop()!;
    await admin.context().close();
  });

  test("admin changes their department and sections in one save", async ({ browser, baseURL }) => {
    test.skip(!samId, "needs the person added above");
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/users/${samId}`);
    await expect(admin.getByRole("heading", { name: sam })).toBeVisible();
    // No save bar until something changes.
    await expect(admin.getByRole("button", { name: "Save changes" })).toHaveCount(0);

    await admin.getByLabel("Department", { exact: true }).selectOption({ label: "Sales" });
    // They sign off for Marketing, so the move is offered (and ticked).
    await expect(
      admin.getByRole("checkbox", { name: "Move their sign-off to Sales too" }),
    ).toBeChecked();
    await admin.getByRole("checkbox", { name: "Reports", exact: true }).check();
    await admin.getByRole("button", { name: "Save changes" }).click();
    await expect(admin.getByText(/Saved — Sam sees the change/)).toBeVisible();
    await expect(admin.getByRole("button", { name: "Save changes" })).toHaveCount(0);

    await admin.reload();
    await expect(admin.locator("#p-department option:checked")).toHaveText("Sales");
    await expect(admin.getByRole("checkbox", { name: "Reports", exact: true })).toBeChecked();
    await expect(admin.getByRole("checkbox", { name: "Sales (their department)" })).toBeChecked();

    await admin.goto(`${baseURL}/users?q=${samEmail}`);
    const row = admin.getByRole("row").filter({ hasText: samEmail });
    // The first cell is the checkbox for the bulk bar.
    await expect(row.getByRole("cell").nth(2)).toHaveText("Sales");
    await expect(row.getByText(/^2 of \d$/)).toBeVisible();
    await admin.context().close();
  });

  test("admin removes a main approver after handing over their waiting sign-off", async ({
    browser,
    baseURL,
  }) => {
    test.skip(!samId, "needs the person added above");
    const admin = await as(browser, "admin@media10.test", baseURL!);
    admin.on("dialog", (d) => d.accept());
    await admin.goto(`${baseURL}/users?tab=departments`);

    // A department that signs off only when ticked on an item.
    const add = admin.getByRole("form", { name: "Add a department" });
    await add.getByLabel("Department name").fill(legal);
    await add.getByRole("switch", { name: "New department signs off artwork" }).click();
    await add.getByRole("button", { name: "Add department" }).click();
    const card = admin.getByRole("region", { name: `${legal} department` });
    await expect(card).toBeVisible();
    await card.getByRole("button", { name: `Edit ${legal}` }).click();
    await card.getByLabel("Organiser signage").uncheck();
    await card.getByLabel("Sponsor signage").uncheck();
    await card.getByRole("button", { name: "Save", exact: true }).click();
    await expect(card.getByText("Signs off only when ticked on an item")).toBeVisible();

    // Sam becomes its main approver (the first approver is main by default).
    await card.getByLabel(`Team member to add to ${legal} approvers`).selectOption({ label: sam });
    await expect(card.getByRole("checkbox", { name: "Main approver" })).toBeChecked();
    await card.getByRole("button", { name: "Add", exact: true }).click();
    await expect(card.getByText("main approver")).toBeVisible();

    // Operations adds signage that only Legal signs off; it waits on Sam.
    const ops = await as(browser, "ops@media10.test", baseURL!);
    await ops.goto(`${baseURL}/BIRM27/signage/new`);
    await ops.getByLabel("Name", { exact: true }).fill(`Contract notice ${n}`);
    await ops.getByLabel("Item type").selectOption({ label: "Foamex board" });
    await ops.getByLabel("Hall", { exact: true }).selectOption({ label: "Hall 1" });
    await ops.getByLabel("Location").selectOption({ label: "Registration" });
    await ops.getByLabel("Width (mm)").fill("600");
    await ops.getByLabel("Height (mm)").fill("400");
    await ops.getByLabel("Fixing method").selectOption("wall_mounted");
    await ops.getByRole("button", { name: "Change who signs off" }).click();
    for (const step of [
      "Operations sign-off",
      "Marketing sign-off",
      "Senior management sign-off",
    ]) {
      await ops.getByLabel(`Needs ${step}`).uncheck();
    }
    const salesStep = ops.getByLabel("Needs Sales sign-off");
    if (await salesStep.isChecked()) await salesStep.uncheck();
    await ops.getByLabel(`Needs ${legal} sign-off`).check();
    await ops
      .getByLabel(`Who signs ${legal} sign-off`)
      .selectOption({ label: `${sam} (main approver)` });
    await ops.getByRole("button", { name: "Create item" }).click();
    await ops.waitForURL("**/signage/SIG-BIRM27-*");
    const ref = new URL(ops.url()).pathname.split("/").pop()!;
    await ops.goto(`${baseURL}/BIRM27/signage/${ref}?tab=artwork`);
    // Uploading the first artwork on a draft sends it for sign-off too.
    const upload = ops.getByRole("button", { name: "Upload", exact: true });
    for (let attempt = 0; attempt < 4; attempt++) {
      await ops.setInputFiles('input[type="file"]', {
        name: "notice.pdf",
        mimeType: "application/pdf",
        buffer: PDF,
      });
      if (await upload.isEnabled({ timeout: 2_000 }).catch(() => false)) break;
      await ops.waitForTimeout(1_000);
    }
    await upload.click();
    await expect(ops.getByText(/^v1 uploaded and sent for sign-off — /).first()).toBeVisible();
    await expect(ops.getByText("v1 — notice.pdf")).toBeVisible();
    await ops.goto(`${baseURL}/BIRM27/signage/${ref}`);
    await expect(ops.getByText("In sign-off", { exact: true }).first()).toBeVisible();

    // Remove Sam: the dialog asks who takes the waiting sign-off.
    await admin.goto(`${baseURL}/users/${samId}`);
    await admin.getByRole("button", { name: "Remove Sam…" }).click();
    const dialog = admin.getByRole("dialog");
    await expect(dialog.getByText(`Sam signs off for ${legal} (main approver).`)).toBeVisible();
    await dialog.getByRole("button", { name: "Remove Sam" }).click();
    await expect(dialog.getByRole("alert")).toHaveText(/Choose who takes over/);
    // Sam is Legal's only approver, so someone must be picked for its sign-offs.
    await dialog
      .getByLabel(new RegExp(`^${legal} sign-offs`))
      .selectOption({ label: "Olivia Ops — Operations" });
    await dialog.getByRole("button", { name: "Remove Sam" }).click();
    await admin.waitForURL(/\/users$/);
    await expect(admin.getByText(`${sam} removed`)).toBeVisible();

    // The sign-off now waits on Olivia; Legal has nobody left.
    await ops.goto(`${baseURL}/approvals?tab=artwork&filter=waiting&q=${ref}`);
    const tile = ops.getByRole("listitem").filter({ hasText: ref });
    await expect(tile.getByText("waiting on Olivia Ops")).toBeVisible();
    await admin.goto(`${baseURL}/users?tab=departments`);
    await expect(card.getByText(`Nobody signs off for ${legal} yet`)).toBeVisible();

    // Tidy up: archive the department.
    await card.getByRole("button", { name: `Archive ${legal}` }).click();
    await admin.getByRole("dialog").getByRole("button", { name: "Archive" }).click();
    await expect(card).toHaveCount(0);
    await ops.context().close();
    await admin.context().close();
  });

  test("others see a read-only directory", async ({ browser, baseURL }) => {
    const ops = await as(browser, "ops@media10.test", baseURL!);
    await ops.goto(`${baseURL}/users`);
    await expect(ops.getByRole("heading", { name: "Users", exact: true })).toBeVisible();
    await expect(ops.getByRole("button", { name: "Add people" })).toHaveCount(0);
    await expect(ops.getByRole("link", { name: "External" })).toHaveCount(0);
    await expect(ops.getByText(/Inviting partners needs/)).toHaveCount(0);
    await expect(ops.getByRole("columnheader", { name: "Email" })).toBeVisible();
    const dana = ops.getByRole("row").filter({ hasText: "director@media10.test" });
    await expect(dana.getByRole("link", { name: "director@media10.test" })).toHaveAttribute(
      "href",
      "mailto:director@media10.test",
    );
    await dana.getByRole("link", { name: "Dana Director" }).click();
    await ops.waitForURL(/\/users\/[0-9a-f-]{36}$/);
    await expect(ops.getByText("Signs off artwork for")).toBeVisible();
    await expect(ops.locator("#p-name")).toHaveCount(0);
    await expect(ops.getByRole("button", { name: /Remove/ })).toHaveCount(0);
    // Admin pages stay closed.
    await ops.goto(`${baseURL}/users/new`);
    await expect(ops.getByRole("heading", { name: "Not found" })).toBeVisible();
    await expect(ops.getByLabel("Full name")).toHaveCount(0);
    // A link to invite a partner says who can, instead of quietly showing Team.
    await ops.goto(`${baseURL}/users?tab=external&invite=1&role=supplier`);
    await ops.waitForURL(/\/users\?from=external$/);
    await expect(ops.getByRole("note")).toHaveText(
      /^Inviting partners needs “Invite partners”\. Ask .+\.$/,
    );
    await expect(ops.getByRole("note").getByRole("link", { name: "Alex Admin" })).toHaveAttribute(
      "href",
      "mailto:admin@media10.test",
    );
    await expect(ops.getByRole("region", { name: "Team" })).toBeVisible();
    // The link's ?role=supplier isn't taken as a Team filter.
    await expect(ops.getByRole("row").filter({ hasText: "director@media10.test" })).toBeVisible();
    // Settings → Team moved here.
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/settings?tab=team`);
    await admin.waitForURL(/\/users$/);
    await ops.context().close();
    await admin.context().close();
  });
});
