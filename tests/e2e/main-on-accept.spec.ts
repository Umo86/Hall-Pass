import { expect, test, type Browser, type Page } from "@playwright/test";
import postgres from "postgres";
import { signInAs } from "./helpers";

/*
 * Main approver when they accept: someone invited as a department's main
 * approver while the main can sign takes over when they accept. Everything
 * happens in a department of its own ("Press {n}", signing off only when
 * ticked on an item), so seeded routing isn't disturbed; it is archived and
 * the people made here are removed afterwards.
 */
const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";
const n = String(Date.now()).slice(-6);
const press = `Press ${n}`;
const pia = `Pia ${n}`;
const piaEmail = `pia-${n}@moa.test`;
const quinn = `Quinn ${n}`;
const quinnEmail = `quinn-${n}@moa.test`;

async function as(browser: Browser, email: string, baseURL: string, width = 1280): Promise<Page> {
  const ctx = await browser.newContext({ viewport: { width, height: width < 640 ? 844 : 900 } });
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

/** Users → Add one person, signing off for Press as main approver. */
async function inviteAsMain(admin: Page, baseURL: string, name: string, email: string) {
  await admin.goto(`${baseURL}/users/new`);
  await admin.getByLabel("Full name").fill(name);
  await admin.getByLabel("Email").fill(email);
  await admin.getByLabel("Department", { exact: true }).selectOption({ label: press });
  await admin.getByRole("radio", { name: /^Marketing Adds/ }).check();
  await admin.getByRole("checkbox", { name: `Signs off ${press} artwork` }).check();
  const main = admin.getByRole("checkbox", { name: /^Main approver/ });
  // A main who can sign exists: unticked by default, and tickable.
  await expect(main).not.toBeChecked();
  await expect(main).toBeEnabled();
  await main.check();
}

test.describe.configure({ mode: "serial" });

test.describe("Main approver when they accept", () => {
  const sql = postgres(DB, { max: 1, onnotice: () => {} });
  let quinnInviteId = "";

  test.afterAll(async () => {
    const emails = [piaEmail, quinnEmail];
    const users = await sql`select id from users where email in ${sql(emails)}`;
    const ids = users.map((u) => u.id as string);
    await sql`delete from notifications where kind = 'main_approver' and title like ${`%${press}%`}`;
    await sql`delete from approvers where email in ${sql(emails)}`;
    if (ids.length) await sql`delete from memberships where user_id in ${sql(ids)}`;
    await sql`update staff_invites set revoked_at = now()
      where invited_email in ${sql(emails)} and accepted_at is null and revoked_at is null`;
    // The department is archived from the page below; this only catches a failed run.
    const depts = await sql`select id from departments where name = ${press}`;
    if (depts.length) {
      await sql`delete from approvers where department_id in ${sql(depts.map((d) => d.id))}`;
      await sql`update departments set is_archived = true where name = ${press}`;
    }
    await sql.end();
  });

  test("admin invites someone as main approver; Departments says they take over when they accept; after accepting they are main and the old main is told", async ({
    browser,
    baseURL,
  }) => {
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/users?tab=departments`);

    // A department of its own that signs off only when ticked on an item.
    const add = admin.getByRole("form", { name: "Add a department" });
    await add.getByLabel("Department name").fill(press);
    await add.getByRole("switch", { name: "New department signs off artwork" }).click();
    await add.getByRole("button", { name: "Add department" }).click();
    const card = admin.getByRole("region", { name: `${press} department` });
    await expect(card).toBeVisible();
    await card.getByRole("button", { name: `Edit ${press}` }).click();
    await card.getByLabel("Organiser signage").uncheck();
    await card.getByLabel("Sponsor signage").uncheck();
    await card.getByRole("button", { name: "Save", exact: true }).click();
    await expect(card.getByText("Signs off only when ticked on an item")).toBeVisible();

    // Olivia signs off for it, then is starred as its main approver.
    await card
      .getByLabel(`Team member to add to ${press} approvers`)
      .selectOption({ label: "Olivia Ops" });
    await card.getByRole("checkbox", { name: "Main approver" }).uncheck();
    await card.getByRole("button", { name: "Add", exact: true }).click();
    await expect(admin.getByText(`Olivia Ops now signs off for ${press}`)).toBeVisible();
    await card
      .getByRole("button", { name: `Make Olivia Ops the main approver for ${press}` })
      .click();
    await expect(
      admin.getByText(`Olivia Ops is now the main approver for ${press}`).first(),
    ).toBeVisible();

    // Pia is invited as main approver: Olivia stays until Pia accepts.
    await inviteAsMain(admin, baseURL!, pia, piaEmail);
    await expect(
      admin.getByText(`Olivia stays main approver until Pia accepts, then Pia takes over.`),
    ).toBeVisible();
    await admin.getByRole("button", { name: "Send invitation" }).click();
    const words = `Pia becomes the main approver for ${press} when they accept — Olivia Ops stays until then`;
    await expect(admin.getByText(words, { exact: false }).first()).toBeVisible();
    const inviteUrl = await admin.getByLabel("Invitation link").inputValue();
    expect(inviteUrl).toContain("/invite/");

    // Departments shows the ask; Olivia is still main approver.
    await admin.goto(`${baseURL}/users?tab=departments`);
    const piaRow = card.getByRole("listitem").filter({ hasText: pia });
    await expect(piaRow).toContainText(`${pia} · main approver when they accept`);
    await expect(piaRow).toContainText("Invited — not set up yet");
    await expect(
      piaRow.getByRole("button", {
        name: `${pia} becomes the main approver for ${press} when they accept — cancel`,
      }),
    ).toHaveAttribute("aria-pressed", "true");
    await expect(
      piaRow.getByRole("button", { name: `${pia} won't become the main approver for ${press}` }),
    ).toHaveText("Don't make main");
    const oliviaRow = card.getByRole("listitem").filter({ hasText: "Olivia Ops" });
    await expect(oliviaRow).toContainText("Olivia Ops · main approver");
    await expect(oliviaRow).not.toContainText("when they accept");

    // The Team list chip has the outlined star.
    await admin.goto(`${baseURL}/users?q=${piaEmail}`);
    await expect(
      admin
        .getByRole("row")
        .filter({ hasText: piaEmail })
        .getByRole("img", { name: "Main approver when they accept" }),
    ).toBeVisible();

    // Pia accepts in a fresh browser.
    const pctx = await browser.newContext();
    const p = await pctx.newPage();
    await p.goto(inviteUrl);
    await expect(
      p.getByText(`You'll also sign off signage artwork, as the main approver for ${press}`),
    ).toBeVisible();
    await p.getByLabel("Choose a password").fill("s3cure-pass");
    await p.getByLabel("Type it again").fill("s3cure-pass");
    await p.getByRole("button", { name: "Create my account" }).click();
    await p.waitForURL("**/my-work");
    await pctx.close();

    // Pia is main approver now; Olivia isn't, and is told.
    await admin.goto(`${baseURL}/users?tab=departments`);
    await expect(piaRow).toContainText(`${pia} · main approver`);
    await expect(piaRow).not.toContainText("when they accept");
    await expect(oliviaRow).not.toContainText("main approver");
    const olivia = await as(browser, "ops@media10.test", baseURL!);
    await olivia.goto(`${baseURL}/notifications`);
    await expect(
      olivia.getByText(`${pia} is now the main approver for ${press}`).first(),
    ).toBeVisible();
    await olivia.context().close();
    await admin.context().close();
  });

  test("admin cancels a pending main approver from Departments", async ({ browser, baseURL }) => {
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await inviteAsMain(admin, baseURL!, quinn, quinnEmail);
    await expect(
      admin.getByText(`Pia stays main approver until Quinn accepts, then Quinn takes over.`),
    ).toBeVisible();
    await admin.getByRole("button", { name: "Send invitation" }).click();
    await expect(
      admin
        .getByText(`Quinn becomes the main approver for ${press} when they accept — ${pia} stays`, {
          exact: false,
        })
        .first(),
    ).toBeVisible();
    await admin.getByRole("link", { name: "Open their page" }).click();
    await admin.waitForURL(/\/users\/[0-9a-f-]{36}$/);
    quinnInviteId = admin.url().split("/").pop()!;
    const box = admin.getByRole("region", { name: "Invitation" });
    await expect(box).toContainText(`Becomes main approver for ${press} when they accept.`);

    await admin.goto(`${baseURL}/users?tab=departments`);
    const card = admin.getByRole("region", { name: `${press} department` });
    const quinnRow = card.getByRole("listitem").filter({ hasText: quinn });
    await expect(quinnRow).toContainText(`${quinn} · main approver when they accept`);
    await quinnRow
      .getByRole("button", { name: `${quinn} won't become the main approver for ${press}` })
      .click();
    await expect(
      admin
        .getByText(
          `${quinn} won't become the main approver for ${press} — ${pia} stays main approver`,
        )
        .first(),
    ).toBeVisible();
    await expect(quinnRow).not.toContainText("when they accept");

    await admin.goto(`${baseURL}/users/${quinnInviteId}`);
    await expect(admin.getByRole("region", { name: "Invitation" })).not.toContainText(
      "Becomes main approver",
    );
    await admin.context().close();
  });

  test("at phone width the Departments row with a pending main approver doesn't scroll sideways", async ({
    browser,
    baseURL,
  }) => {
    test.skip(!quinnInviteId, "needs the invitation above");
    const phone = await as(browser, "admin@media10.test", baseURL!, 390);
    await phone.goto(`${baseURL}/users?tab=departments`);
    const card = phone.getByRole("region", { name: `${press} department` });
    const quinnRow = card.getByRole("listitem").filter({ hasText: quinn });
    // The star on an invitee asks rather than refusing.
    await quinnRow
      .getByRole("button", { name: `Make ${quinn} the main approver for ${press}` })
      .click();
    await expect(
      phone
        .getByText(
          `${quinn} becomes the main approver for ${press} when they accept — ${pia} stays until then`,
        )
        .first(),
    ).toBeVisible();
    const dontMake = quinnRow.getByRole("button", {
      name: `${quinn} won't become the main approver for ${press}`,
    });
    await expect(dontMake).toBeVisible();
    const size = await dontMake.boundingBox();
    expect(size!.height).toBeGreaterThanOrEqual(44);
    const { scroll, inner } = await phone.evaluate(() => ({
      scroll: document.documentElement.scrollWidth,
      inner: window.innerWidth,
    }));
    expect(scroll).toBeLessThanOrEqual(inner);
    await dontMake.click();
    await expect(quinnRow).not.toContainText("when they accept");

    // Tidy up: archive the department.
    await card.getByRole("button", { name: `Archive ${press}` }).click();
    await phone.getByRole("dialog").getByRole("button", { name: "Archive" }).click();
    await expect(card).toHaveCount(0);
    await phone.context().close();
  });
});
