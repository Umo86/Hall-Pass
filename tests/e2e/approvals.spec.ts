import { expect, test, type Browser, type Page } from "@playwright/test";
import { signInAs } from "./helpers";

const PDF = Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF");

async function as(browser: Browser, email: string, baseURL: string): Promise<Page> {
  const ctx = await browser.newContext();
  await signInAs(ctx, email, baseURL);
  const page = await ctx.newPage();
  page.on("dialog", (d) => d.accept());
  return page;
}

test.describe("Approvals", () => {
  test("admin adds a department and an approver; the approver sets up an account and signs off", async ({
    browser,
    baseURL,
  }) => {
    const n = String(Date.now()).slice(-6);
    const dept = `Legal ${n}`;
    const person = `Lara Legal ${n}`;
    const email = `lara-${n}@approver.test`;

    // 1. Admin: Approvals → Approvers — the seeded departments are there.
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/approvals?tab=approvers`);
    for (const name of ["Operations", "Marketing", "Sales", "Senior management"]) {
      await expect(admin.getByRole("region", { name: `${name} approvers` })).toBeVisible();
    }
    await expect(
      admin
        .getByRole("region", { name: "Senior management approvers" })
        .getByRole("listitem")
        .filter({ hasText: "Dana Director" })
        .getByText("Main approver"),
    ).toBeVisible();

    // Add a department that only signs off when ticked on an item.
    const addDept = admin.getByRole("form", { name: "Add a department" });
    await addDept.getByLabel("Department name").fill(dept);
    await addDept.getByLabel("Organiser signage").uncheck();
    await addDept.getByLabel("Sponsor signage").uncheck();
    await addDept.getByRole("button", { name: "Add department" }).click();
    const card = admin.getByRole("region", { name: `${dept} approvers` });
    await expect(card).toBeVisible();
    await expect(card.getByText("Only when ticked on an item")).toBeVisible();

    // Add the approver: name, job title, email, main approver.
    const addPerson = card.getByRole("form", { name: "Add an approver" });
    await addPerson.getByLabel("Name").fill(person);
    await addPerson.getByLabel("Job title").fill("Legal Counsel");
    await addPerson.getByLabel("Email").fill(email);
    await addPerson.getByLabel("Main approver").check();
    await addPerson.getByRole("button", { name: "Add approver" }).click();
    // Email isn't set up locally, so the invitation link is shown to share.
    const link = admin.getByLabel("Invitation link");
    await expect(link).toBeVisible();
    const inviteUrl = await link.inputValue();
    await expect(card.getByText(person)).toBeVisible();
    await expect(card.getByText(`Legal Counsel · ${email}`)).toBeVisible();
    await expect(card.getByText("Invite sent — not set up yet")).toBeVisible();

    // 2. The approver opens the invitation and creates their account.
    const lctx = await browser.newContext();
    const lara = await lctx.newPage();
    await lara.goto(inviteUrl);
    await expect(lara.getByText("You're invited to sign off signage artwork")).toBeVisible();
    await expect(lara.getByLabel("Your name")).toHaveValue(person);
    await lara.getByLabel("Choose a password").fill("s3cure-pass");
    await lara.getByLabel("Type it again").fill("s3cure-pass");
    await lara.getByRole("button", { name: "Create my account" }).click();
    await lara.waitForURL("**/my-work");

    await admin.reload();
    await expect(
      admin.getByRole("region", { name: `${dept} approvers` }).getByText("Active"),
    ).toBeVisible();

    // 3. Ops adds signage that only the new department signs off, naming Lara.
    const ops = await as(browser, "ops@media10.test", baseURL!);
    await ops.goto(`${baseURL}/BIRM27/signage/new`);
    await ops.getByLabel("Name", { exact: true }).fill(`Legal notice ${n}`);
    await ops.getByLabel("Item type").selectOption({ label: "Foamex board" });
    await ops.getByLabel("Hall", { exact: true }).selectOption({ label: "Hall 1" });
    await ops.getByLabel("Location").selectOption({ label: "Registration" });
    await ops.getByLabel("Width (mm)").fill("600");
    await ops.getByLabel("Height (mm)").fill("400");
    await ops.getByLabel("Fixing method").selectOption("wall_mounted");
    for (const step of ["Operations sign-off", "Marketing sign-off", "Senior management sign-off"]) {
      await ops.getByLabel(`Needs ${step}`).uncheck();
    }
    await ops.getByLabel(`Needs ${dept} sign-off`).check();
    const who = ops.getByLabel(`Who signs ${dept} sign-off`);
    await expect(who.locator("option", { hasText: `${person} — Legal Counsel` })).toHaveCount(1);
    await who.selectOption({ label: `${person} — Legal Counsel (main approver)` });
    await ops.getByRole("button", { name: "Create item" }).click();
    await ops.waitForURL("**/signage/SIG-BIRM27-*");
    const ref = new URL(ops.url()).pathname.split("/").pop()!;
    await ops.goto(`${baseURL}/BIRM27/signage/${ref}?tab=artwork`);
    await ops.setInputFiles('input[type="file"]', {
      name: "notice.pdf",
      mimeType: "application/pdf",
      buffer: PDF,
    });
    await ops.getByRole("button", { name: "Upload" }).click();
    await expect(ops.getByText("v1 — notice.pdf")).toBeVisible();
    await ops.goto(`${baseURL}/BIRM27/signage/${ref}`);
    await ops.getByRole("button", { name: "Submit for review" }).click();
    await expect(ops.getByText("In review", { exact: true })).toBeVisible();

    // All artwork: waiting on Lara by name.
    await ops.goto(`${baseURL}/approvals?tab=artwork&filter=waiting&q=${ref}`);
    const tile = ops.getByRole("listitem").filter({ hasText: ref });
    await expect(tile.getByText(`${dept} sign-off:`)).toBeVisible();
    await expect(tile.getByText(`waiting on ${person}`)).toBeVisible();

    // 4. Lara sees it waiting on her and approves with a comment.
    await lara.goto(`${baseURL}/approvals`);
    const row = lara.locator("li", { hasText: ref });
    await expect(row).toBeVisible();
    await expect(row.getByText(`${dept} sign-off`)).toBeVisible();
    await row.getByRole("button", { name: "Approve", exact: true }).click();
    const dialog = lara.getByRole("dialog");
    await dialog.getByLabel(/Comment/).fill("Wording checked");
    await dialog.getByRole("button", { name: "Approve", exact: true }).click();
    await expect(dialog).toHaveCount(0);
    await expect(row).toHaveCount(0);

    // The item is signed off; the decision and comment show under All artwork.
    await ops.goto(`${baseURL}/approvals?tab=artwork&filter=approved&q=${ref}`);
    const done = ops.getByRole("listitem").filter({ hasText: ref });
    await expect(done.getByText("Approved", { exact: true }).first()).toBeVisible();
    await expect(done.getByText(/Wording checked/)).toBeVisible();
    await expect(done.getByText(new RegExp(`— ${person}`))).toBeVisible();

    // History has it too.
    await ops.goto(`${baseURL}/BIRM27/signage/${ref}?tab=history`);
    await expect(ops.getByText(/sign-off: approved/i).first()).toBeVisible();

    // Tidy up: remove the department from sign-off.
    await admin.goto(`${baseURL}/approvals?tab=approvers`);
    await admin
      .getByRole("region", { name: `${dept} approvers` })
      .getByRole("button", { name: "Remove", exact: true })
      .first()
      .click();
    await expect(admin.getByRole("region", { name: `${dept} approvers` })).toHaveCount(0);
  });

  test("non-admins see approvers read-only and My Work links to their sign-offs", async ({
    browser,
    baseURL,
  }) => {
    const mkt = await as(browser, "marketing@media10.test", baseURL!);
    await mkt.goto(`${baseURL}/approvals?tab=approvers`);
    await expect(mkt.getByRole("region", { name: "Marketing approvers" })).toBeVisible();
    await expect(mkt.getByRole("form", { name: "Add a department" })).toHaveCount(0);
    await expect(mkt.getByRole("button", { name: "Add approver" })).toHaveCount(0);
    await mkt.goto(`${baseURL}/my-work`);
    await expect(mkt.getByRole("heading", { name: "Sign-offs" })).toBeVisible();
    // The old Settings tab now points here.
    await mkt.goto(`${baseURL}/settings?tab=signoff`);
    await mkt.waitForURL("**/approvals?tab=approvers");
  });
});
