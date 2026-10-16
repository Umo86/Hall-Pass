import { expect, test, type Browser, type Locator, type Page } from "@playwright/test";
import postgres from "postgres";
import { signInAs } from "./helpers";

/**
 * Partners (Users v2, P4.x): a partner invited to a second event gets it at
 * their next sign-in and sees each event separately; a sponsor uploads
 * their own artwork in the portal and the team sees the item in sign-off.
 */
const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";
const stamp = () => String(Date.now()).slice(-6);

// A 1×1 PNG stands in for the sponsor's logo.
const PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  "base64",
);

async function as(browser: Browser, email: string, baseURL: string): Promise<Page> {
  const ctx = await browser.newContext();
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

async function pick(select: Locator, text: string | RegExp) {
  const value = await select.locator("option", { hasText: text }).first().getAttribute("value");
  await select.selectOption(value!);
}

/** Users → External: invite a supplier from Big Print Co to one event; returns the link. */
async function inviteSupplier(admin: Page, baseURL: string, email: string, event: RegExp) {
  await admin.goto(`${baseURL}/users?tab=external&event=all`);
  await admin.getByRole("button", { name: "Invite someone from outside" }).click();
  const dialog = admin.getByRole("dialog", { name: "Invite someone from outside" });
  await pick(dialog.getByLabel("Event"), event);
  await dialog.getByLabel("They are a").selectOption("supplier");
  await pick(dialog.getByLabel("Which company"), "Big Print Co");
  // The contact on Big Print Co's record is filled in; this time it's someone else.
  await expect(dialog.getByLabel("Email")).toHaveValue("print@bigprint.test");
  await expect(dialog.getByText(/The contact on Big Print Co’s record/)).toBeVisible();
  await dialog.getByLabel("Email").fill(email);
  await dialog.getByRole("button", { name: "Send invitation" }).click();
  // Email isn't set up here: the link is shown to pass on.
  const ready = admin.getByRole("dialog", { name: "Invitation ready" });
  await expect(ready).toBeVisible();
  const link = await ready.getByLabel("Invitation link").inputValue();
  await ready.getByRole("button", { name: "Done" }).click();
  return link;
}

test.describe("partners", () => {
  test("a partner invited to two events sees both, each on its own", async ({
    browser,
    baseURL,
  }) => {
    test.setTimeout(120_000);
    const n = stamp();
    const email = `e2e-twice-${n}@bigprint.test`;
    const second = `E2E Second ${n}`;
    const signName = `E2E second-event sign ${n}`;
    const sql = postgres(DB, { max: 1, onnotice: () => {} });
    // A second event in the same organisation with one Big Print Co item.
    const [src] = await sql`select * from editions where code = 'BIRM27'`;
    const [edition] = await sql`
      insert into editions (event_id, venue_id, name, code, build_start, build_end, open_start,
        open_end, breakdown_end)
      values (${src.event_id}, ${src.venue_id}, ${second}, ${`PT${n}`}, '2028-03-01', '2028-03-02',
        '2028-03-03', '2028-03-05', '2028-03-06')
      returning id`;
    const [bigPrint] = await sql`
      select s.id from suppliers s join events e on e.organisation_id = s.organisation_id
      where e.id = ${src.event_id} and s.name = 'Big Print Co'`;
    const [ops] = await sql`select id from users where email = 'ops@media10.test'`;
    await sql`insert into signage_items (edition_id, ref, seq, name, created_by, supplier_id)
      values (${edition.id}, ${`SIG-PT${n}-001`}, 1, ${signName}, ${ops.id}, ${bigPrint.id})`;

    const admin = await as(browser, "admin@media10.test", baseURL!);
    const partnerCtx = await browser.newContext();
    try {
      const link = await inviteSupplier(admin, baseURL!, email, /^UKCW Birmingham 2027/);

      // They accept and see this event's items only.
      const partner = await partnerCtx.newPage();
      await partner.goto(link);
      await expect(
        partner.getByRole("heading", { name: /You're invited to .+ as a supplier/ }),
      ).toBeVisible();
      await expect(partner.getByText("UKCW Birmingham 2027 · Big Print Co")).toBeVisible();
      await partner.getByLabel("Your name").fill(`Pat Printer ${n}`);
      await partner.getByLabel("Choose a password").fill("s3cure-pass");
      await partner.getByLabel("Type it again").fill("s3cure-pass");
      await partner.getByRole("button", { name: "Create my account" }).click();
      await partner.waitForURL("**/portal/approvals");
      await partner.goto(`${baseURL}/portal/items`);
      await expect(partner.getByRole("heading", { name: "My items" })).toBeVisible();
      await expect(partner.getByRole("columnheader", { name: "PO" })).toBeVisible();
      await expect(partner.getByText(signName)).toHaveCount(0);
      await expect(partner.getByRole("group", { name: "Event" })).toHaveCount(0);

      // Invited again, to the second event. They never open that link.
      await inviteSupplier(admin, baseURL!, email, new RegExp(`^${second}`));

      // Their next page load claims it: both events, one at a time, the sooner first.
      await partner.reload();
      const events = partner.getByRole("group", { name: "Event" });
      await expect(events.getByRole("link", { name: /UKCW Birmingham 2027/ })).toHaveAttribute(
        "aria-current",
        "page",
      );
      await expect(partner.getByText(signName)).toHaveCount(0);
      await events.getByRole("link", { name: new RegExp(second) }).click();
      await partner.waitForURL(/event=PT/);
      await expect(partner.getByText(signName).first()).toBeVisible();
      await events.getByRole("link", { name: /All events/ }).click();
      await expect(
        partner.getByRole("heading", { level: 2, name: /UKCW Birmingham 2027/ }),
      ).toBeVisible();
      await expect(
        partner.getByRole("heading", { level: 2, name: new RegExp(second) }),
      ).toBeVisible();

      // Users → External shows both as active (the second one claimed at sign-in).
      await admin.goto(`${baseURL}/users?tab=external&event=all`);
      const rows = admin.getByRole("row").filter({ hasText: email });
      await expect(rows).toHaveCount(2);
      await expect(rows.filter({ hasText: second }).getByText("Active")).toBeVisible();
      const [audit] = await sql`
        select a.summary from audit_log a join external_grants g on g.id = a.entity_id
        where g.invited_email = ${email} and g.edition_id = ${edition.id}
          and a.summary like '%signed in%'`;
      expect(audit?.summary).toContain("accepted their invitation");

      // Inviting the same access again offers to resend instead of a second row.
      await admin.getByRole("button", { name: "Invite someone from outside" }).click();
      const dialog = admin.getByRole("dialog", { name: "Invite someone from outside" });
      await pick(dialog.getByLabel("Event"), new RegExp(`^${second}`));
      await dialog.getByLabel("They are a").selectOption("supplier");
      await pick(dialog.getByLabel("Which company"), "Big Print Co");
      await dialog.getByLabel("Email").fill(email);
      await dialog.getByRole("button", { name: "Send invitation" }).click();
      await expect(dialog.getByText(`${email} already has this access`)).toBeVisible();
      await dialog.getByRole("button", { name: "Cancel" }).click();
    } finally {
      await sql`delete from signage_items where edition_id = ${edition.id}`;
      await sql`update external_grants set revoked_at = now() where invited_email = ${email}`;
      await sql`update editions set status = 'archived' where id = ${edition.id}`;
      await sql.end();
      await partnerCtx.close();
      await admin.context().close();
    }
  });

  test("a sponsor uploads artwork in the portal and the team sees it in sign-off", async ({
    browser,
    baseURL,
  }) => {
    test.setTimeout(120_000);
    const n = stamp();
    const ref = `SIG-BIRM27-S${n}`;
    const name = `E2E sponsor upload ${n}`;
    const sql = postgres(DB, { max: 1, onnotice: () => {} });
    const [marketing] = await sql`select id from users where email = 'marketing@media10.test'`;
    // A complete BuildCo sign, as a draft waiting for the sponsor's artwork.
    await sql`
      insert into signage_items (edition_id, ref, seq, name, kind, category, item_type_id, hall_id,
        location_id, width_mm, height_mm, quantity, fixing_method, sponsor_id, workflow_id,
        owner_role, owner_user_id, created_by, signoffs)
      select edition_id, ${ref}, ${700000 + Number(n.slice(-5))}, ${name}, kind, category,
        item_type_id, hall_id, location_id, width_mm, height_mm, quantity, fixing_method,
        sponsor_id, workflow_id, 'marketing', ${marketing.id}, created_by, signoffs
      from signage_items where ref = 'SIG-BIRM27-019'`;
    const sponsor = await as(browser, "sponsor@buildco.test", baseURL!);
    const ops = await as(browser, "ops@media10.test", baseURL!);
    try {
      await sponsor.goto(`${baseURL}/portal/items/${ref}`);
      await expect(sponsor.getByRole("heading", { name })).toBeVisible();
      const box = sponsor.getByRole("region", { name: "Upload your artwork" });
      await expect(box).toBeVisible();
      await box
        .locator('input[type="file"]')
        .setInputFiles({ name: "buildco-logo.png", mimeType: "image/png", buffer: PNG });
      await box.getByLabel(/A note for the team/).fill("Our new logo");
      await box.getByRole("button", { name: "Upload artwork" }).click();
      await expect(sponsor.getByText("v1 uploaded and sent for sign-off").first()).toBeVisible();
      // Now in sign-off: the box is gone, the artwork is shown.
      await expect(sponsor.getByRole("region", { name: "Upload your artwork" })).toHaveCount(0);
      await expect(sponsor.getByText(/v1 · buildco-logo\.png/)).toBeVisible();

      // The team sees it in sign-off, uploaded by the sponsor; its owner was told.
      await ops.goto(`${baseURL}/BIRM27/signage/${ref}?tab=artwork`);
      await expect(ops.getByText("In sign-off").first()).toBeVisible();
      await expect(ops.getByText(/uploaded by Ben at BuildCo/).first()).toBeVisible();
      const told = await sql`
        select n.title from notifications n join signage_items i on i.id = n.entity_id
        where i.ref = ${ref} and n.user_id = ${marketing.id} and n.kind = 'artwork_uploaded'`;
      expect(told.map((t) => t.title)).toContain(`BuildCo uploaded artwork for ${name} (${ref})`);

      // Another sponsor's item stays out of reach.
      const res = await sponsor.request.get(`${baseURL}/portal/items/SIG-BIRM27-002`);
      expect(res.status()).toBe(404);
    } finally {
      await sql`update signage_items set deleted_at = now() where ref = ${ref}`;
      await sql.end();
      await sponsor.context().close();
      await ops.context().close();
    }
  });

  test("on a phone a sponsor sees their items as cards, with no sideways scrolling", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
    await signInAs(ctx, "sponsor@buildco.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/portal/items`);
    const list = page.getByRole("list", { name: "Items" });
    await expect(list.getByRole("link").first()).toBeVisible();
    const width = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(width).toBeLessThanOrEqual(390);
    await ctx.close();
  });
});
