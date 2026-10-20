import { expect, test, type Browser, type Page } from "@playwright/test";
import { signInAs, signInWithPassword } from "./helpers";

/**
 * Real sign-in (Better Auth), as production runs it. Needs BETTER_AUTH_SECRET
 * (CI's e2e step sets it); without it the site runs on demo sign-in only and
 * these are skipped. Email isn't set up here, so in development the sign-in
 * page shows the link that would have been emailed.
 */
test.skip(!process.env.BETTER_AUTH_SECRET, "needs real sign-in (BETTER_AUTH_SECRET)");

// One person: invited, signs in and out, resets, changes their password,
// uses an email link and an admin's link, then is suspended.
test.describe.configure({ mode: "serial", timeout: 120_000 });

async function demo(browser: Browser, email: string, baseURL: string): Promise<Page> {
  const ctx = await browser.newContext();
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

async function fresh(browser: Browser): Promise<Page> {
  return (await browser.newContext()).newPage();
}

async function signOutFromMenu(page: Page, name: string) {
  await page.getByRole("button", { name: `Account: ${name}` }).click();
  await page.getByRole("menuitem", { name: "Sign out" }).click();
  await page.waitForURL(/\/login$/);
}

/** The email form on /login (the demo list shows first while demo sign-in is on too). */
async function emailForm(page: Page, baseURL: string, next?: string) {
  await page.goto(`${baseURL}/login${next ? `?next=${encodeURIComponent(next)}` : ""}`);
  const instead = page.getByRole("button", { name: "Sign in with email instead" });
  if (await instead.isVisible()) await instead.click();
}

test.describe("Real sign-in", () => {
  const n = String(Date.now()).slice(-6);
  const name = `Pat Password ${n}`;
  const email = `pw-${n}@auth.test`;
  let password = "first-pass-1";
  let userId = "";

  test("an invitation creates the account; sign out, then in with the password", async ({
    browser,
    baseURL,
  }) => {
    const admin = await demo(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/users/new`);
    await admin.getByLabel("Full name").fill(name);
    await admin.getByLabel("Email").fill(email);
    await admin.getByLabel("Department", { exact: true }).selectOption({ label: "Marketing" });
    await admin.getByRole("checkbox", { name: "Signs off Marketing artwork" }).uncheck();
    await admin.getByRole("button", { name: "Send invitation" }).click();
    await expect(admin.getByText(`${name} is invited`)).toBeVisible();
    const inviteUrl = await admin.getByLabel("Invitation link").inputValue();

    const pat = await fresh(browser);
    await pat.goto(inviteUrl);
    await expect(pat.getByLabel("Your name")).toHaveValue(name);
    await pat.getByLabel("Choose a password").fill(password);
    await pat.getByLabel("Type it again").fill(password);
    await pat.getByRole("button", { name: "Create my account" }).click();
    await pat.waitForURL("**/my-work");

    await signOutFromMenu(pat, name);
    await pat.goto(`${baseURL}/my-work`);
    await pat.waitForURL(/\/login/);

    await signInWithPassword(pat, baseURL!, email, "not-the-password");
    await expect(pat.getByText("Incorrect email or password")).toBeVisible();
    await signInWithPassword(pat, baseURL!, email, password);
    await pat.waitForURL("**/my-work");
    await expect(pat.getByRole("button", { name: `Account: ${name}` })).toBeVisible();
    await pat.context().close();

    await admin.goto(`${baseURL}/users?q=${encodeURIComponent(email)}`);
    await admin.getByRole("row").filter({ hasText: email }).getByRole("link", { name }).click();
    await admin.waitForURL(/\/users\/[0-9a-f-]{36}$/);
    userId = admin.url().split("/").pop()!;
    await admin.context().close();
  });

  test("forgot password: development shows the link; it works once", async ({
    browser,
    baseURL,
  }) => {
    test.skip(!userId, "needs the account made above");
    const pat = await fresh(browser);
    await emailForm(pat, baseURL!);
    await pat.getByRole("button", { name: "Forgot password?" }).click();
    await pat.getByLabel("Email address").fill(email);
    await pat.getByRole("button", { name: "Email me a link to reset it" }).click();
    await expect(pat.getByText(/here is the link that would have been sent/)).toBeVisible();
    const resetUrl = await pat.getByRole("link", { name: "Open the link" }).getAttribute("href");
    expect(resetUrl).toContain("/reset-password?token=");

    await pat.goto(resetUrl!);
    await expect(pat.getByText("Choose a new password")).toBeVisible();
    const newPassword = "second-pass-2";
    await pat.getByLabel("New password").fill(newPassword);
    await pat.getByLabel("Type it again").fill(newPassword);
    await pat.getByRole("button", { name: "Save password" }).click();
    // Saving signs them in.
    await pat.waitForURL("**/my-work");

    await signOutFromMenu(pat, name);
    await signInWithPassword(pat, baseURL!, email, password);
    await expect(pat.getByText("Incorrect email or password")).toBeVisible();
    password = newPassword;
    await signInWithPassword(pat, baseURL!, email, password);
    await pat.waitForURL("**/my-work");

    await pat.goto(resetUrl!);
    await expect(pat.getByText("This link has expired or was already used.")).toBeVisible();
    await pat.context().close();
  });

  test("My account: change the password; demo sign-in has none", async ({ browser, baseURL }) => {
    test.skip(!userId, "needs the account made above");
    const pat = await fresh(browser);
    await signInWithPassword(pat, baseURL!, email, password, "/account");
    await pat.waitForURL("**/account");
    await expect(
      pat.getByText(
        "Change your password. You'll stay signed in here and be signed out everywhere else.",
      ),
    ).toBeVisible();
    await pat.getByLabel("Current password").fill("wrong-current");
    await pat.getByLabel("New password").fill("third-pass-3");
    await pat.getByLabel("Type it again").fill("third-pass-3");
    await pat.getByRole("button", { name: "Change password" }).click();
    await expect(pat.getByText("Your current password isn't right")).toBeVisible();
    await pat.getByLabel("Current password").fill(password);
    await pat.getByRole("button", { name: "Change password" }).click();
    await expect(pat.getByText("Password changed")).toBeVisible();
    password = "third-pass-3";
    // Still signed in here.
    await pat.reload();
    await expect(pat).toHaveURL(/\/account$/);
    await signOutFromMenu(pat, name);
    await signInWithPassword(pat, baseURL!, email, password);
    await pat.waitForURL("**/my-work");
    await pat.context().close();

    const admin = await demo(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/account`);
    await expect(
      admin.getByText("You’re signed in with demo sign-in, which has no password."),
    ).toBeVisible();
    await admin.context().close();
  });

  test("email me a link: development shows it, and it signs in at next", async ({
    browser,
    baseURL,
  }) => {
    test.skip(!userId, "needs the account made above");
    const pat = await fresh(browser);
    await emailForm(pat, baseURL!, "/approvals");
    await pat
      .getByRole("button", { name: "First time here, or no password yet? Email me a link" })
      .click();
    await pat.getByLabel("Email address").fill(email);
    await pat.getByRole("button", { name: "Email me a link", exact: true }).click();
    await expect(pat.getByText(/here is the link that would have been sent/)).toBeVisible();
    await pat.getByRole("link", { name: "Open the link" }).click();
    await pat.waitForURL("**/approvals");
    await expect(pat.getByRole("button", { name: `Account: ${name}` })).toBeVisible();
    await pat.context().close();
  });

  test("a super admin copies a sign-in link; managers don't see it", async ({
    browser,
    baseURL,
  }) => {
    test.skip(!userId, "needs the account made above");
    const admin = await demo(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/users/${userId}`);
    await expect(admin.getByRole("heading", { name: "Sign-in help" })).toBeVisible();
    await expect(admin.getByRole("button", { name: "Copy a password reset link" })).toBeVisible();
    await admin.getByRole("button", { name: "Copy a sign-in link" }).click();
    const link = await admin.getByLabel("Sign-in link").inputValue();
    expect(link).toContain("/api/auth/magic-link/verify?token=");

    const pat = await fresh(browser);
    await pat.goto(link);
    await pat.waitForURL("**/my-work");
    await expect(pat.getByRole("button", { name: `Account: ${name}` })).toBeVisible();
    // Used once: the same link doesn't work again.
    const again = await fresh(browser);
    await again.goto(link);
    await again.waitForURL(/\/login\?error=/);
    await expect(again.getByText(/expired or was already used/)).toBeVisible();
    await again.context().close();
    await pat.context().close();

    // Partners who have accepted get one in Users → External.
    await admin.goto(`${baseURL}/users?tab=external&event=all`);
    const partnerButton = admin.getByRole("button", { name: /^Copy a sign-in link for / }).first();
    await partnerButton.click();
    const dialog = admin.getByRole("dialog");
    await expect(dialog.getByText(/Works once, for the next hour/)).toBeVisible();
    const partnerLink = await dialog.getByLabel("Sign-in link").inputValue();
    const partner = await fresh(browser);
    await partner.goto(partnerLink);
    await partner.waitForURL("**/portal/**");
    await partner.context().close();
    await admin.context().close();

    const ops = await demo(browser, "ops@media10.test", baseURL!);
    await ops.goto(`${baseURL}/users/${userId}`);
    await expect(ops.getByRole("heading", { name })).toBeVisible();
    await expect(ops.getByRole("button", { name: "Copy a sign-in link" })).toHaveCount(0);
    await ops.goto(`${baseURL}/users?tab=external&event=all`);
    await expect(ops.getByRole("button", { name: /^Copy a sign-in link for / })).toHaveCount(0);
    await ops.context().close();
  });

  test("suspending signs them out; a correct password is told who to ask", async ({
    browser,
    baseURL,
  }) => {
    test.skip(!userId, "needs the account made above");
    const pat = await fresh(browser);
    await signInWithPassword(pat, baseURL!, email, password);
    await pat.waitForURL("**/my-work");

    const admin = await demo(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/users/${userId}`);
    await admin.getByRole("button", { name: "Suspend Pat…" }).click();
    await admin.getByRole("dialog").getByRole("button", { name: "Suspend Pat" }).click();
    await expect(admin.getByText(`${name} suspended`)).toBeVisible();

    await pat.reload();
    await pat.waitForURL(/\/login/);
    await signInWithPassword(pat, baseURL!, email, password);
    await expect(
      pat.getByText("Your access is paused — ask Alex Admin (admin@media10.test)."),
    ).toBeVisible();

    // Clean-up: they can sign in again.
    await admin.getByRole("button", { name: "Reactivate Pat" }).click();
    await expect(admin.getByText(`${name} can sign in again`)).toBeVisible();
    await signInWithPassword(pat, baseURL!, email, password);
    await pat.waitForURL("**/my-work");
    await pat.context().close();
    await admin.context().close();
  });
});
