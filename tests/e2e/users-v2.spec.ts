import { randomUUID } from "node:crypto";
import { expect, test, type Browser, type Page } from "@playwright/test";
import postgres from "postgres";
import { signInAs } from "./helpers";

/*
 * Users v2: managers, account access and adding several people. People
 * made here are fixtures in the Media10 organisation (their memberships are
 * removed afterwards): a Marketing department manager, an Operations
 * manager for everyone, another manager, and two people to change.
 */
const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";
const n = String(Date.now()).slice(-6);
const mail = (who: string) => `${who}-${n}@v2e2e.test`;

async function as(browser: Browser, email: string, baseURL: string, width = 1280): Promise<Page> {
  const ctx = await browser.newContext({ viewport: { width, height: 900 } });
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

test.describe.configure({ mode: "serial" });

test.describe("Users v2", () => {
  const sql = postgres(DB, { max: 1, onnotice: () => {} });
  const people: Record<string, string> = {};
  let adminId = "";

  test.beforeAll(async () => {
    const [admin] = await sql`
      select u.id, m.organisation_id from users u join memberships m on m.user_id = u.id
      where u.email = 'admin@media10.test'`;
    adminId = admin.id;
    const org = admin.organisation_id;
    const dept = async (name: string) =>
      (await sql`select id from departments where organisation_id = ${org} and name = ${name}`)[0]
        .id as string;
    const [mkt, sales, ops] = [
      await dept("Marketing"),
      await dept("Sales"),
      await dept("Operations"),
    ];
    const add = async (
      key: string,
      name: string,
      role: string,
      departmentId: string,
      scope: string | null,
    ) => {
      const id = randomUUID();
      await sql`insert into users (id, email, full_name) values (${id}, ${mail(key)}, ${name})`;
      await sql`insert into memberships (user_id, organisation_id, role, department_id, manager_scope)
        values (${id}, ${org}, ${role}, ${departmentId}, ${scope})`;
      people[key] = id;
    };
    await add("mona", `Mona Manager ${n}`, "marketing", mkt, "department");
    await add("evan", `Evan Everyone ${n}`, "ops", ops, "everyone");
    await add("max", `Max Manager ${n}`, "marketing", mkt, "department");
    await add("sid", `Sid Seller ${n}`, "sales", sales, null);
    await add("fred", `Fred Freelance ${n}`, "marketing", mkt, null);
  });

  test.afterAll(async () => {
    const ids = Object.values(people);
    if (ids.length) {
      await sql`delete from approvers where user_id in ${sql(ids)}`;
      await sql`delete from memberships where user_id in ${sql(ids)}`;
    }
    await sql.end();
  });

  test("a department manager adds someone: their department only, no roles or abilities above theirs", async ({
    browser,
    baseURL,
  }) => {
    const mona = await as(browser, mail("mona"), baseURL!);
    await mona.goto(`${baseURL}/users`);
    // The list starts on her department.
    await expect(mona.getByText(/in Marketing · Show everyone/)).toBeVisible();
    await expect(mona.getByRole("row").filter({ hasText: mail("sid") })).toHaveCount(0);
    await expect(mona.getByRole("row").filter({ hasText: mail("fred") })).toBeVisible();

    await mona.getByRole("button", { name: "Add people" }).first().click();
    await mona.getByRole("menuitem", { name: "Add one person" }).click();
    await mona.waitForURL("**/users/new");
    const dept = mona.getByLabel("Department", { exact: true });
    await expect(dept).toBeDisabled();
    await expect(mona.locator("#add-department option:checked")).toHaveText("Marketing");
    await expect(mona.getByText("You add people to Marketing")).toBeVisible();
    await expect(mona.getByRole("option", { name: "+ New department…" })).toHaveCount(0);
    // Only roles she fully has; no manager card (super admins make managers).
    await expect(mona.getByRole("radio", { name: /^Marketing Adds/ })).toBeVisible();
    await expect(mona.getByRole("radio", { name: /^Viewer/ })).toBeVisible();
    for (const above of [/^Super admin/, /^Operations Runs/, /^Sales Sponsorship/]) {
      await expect(mona.getByRole("radio", { name: above })).toHaveCount(0);
    }
    await expect(mona.getByRole("heading", { name: "Manager" })).toHaveCount(0);
    // Templates she can't give aren't offered.
    await expect(mona.getByText("Operations coordinator")).toHaveCount(0);
    await expect(mona.getByText("Freelance installer")).toHaveCount(0);
    await mona.getByText("Marketing executive", { exact: true }).click();
    await expect(mona.getByRole("radio", { name: /^Marketing Adds/ })).toBeChecked();
    await expect(mona.getByLabel("Job title")).toHaveValue("Marketing executive");
    // Abilities she doesn't have are locked, with the reason.
    await mona.getByText("Fine-tune what they can do").click();
    await expect(mona.getByRole("checkbox", { name: "Edit costs and PO numbers" })).toBeDisabled();
    await expect(
      mona.getByText(/You don't have this yourself, so you can't give it/).first(),
    ).toBeVisible();
    await expect(mona.getByRole("checkbox", { name: "Invite partners" })).toBeDisabled();

    await mona.getByLabel("Full name").fill(`Nina New ${n}`);
    await mona.getByLabel("Email").fill(mail("nina"));
    await mona.getByRole("button", { name: "Send invitation" }).click();
    await expect(mona.getByText(`Nina New ${n} is invited`)).toBeVisible();
    const [invite] = await sql`
      select i.role, i.manager_scope, d.name as dept, i.features
      from staff_invites i join departments d on d.id = i.department_id
      where i.invited_email = ${mail("nina")}`;
    expect(invite).toMatchObject({ role: "marketing", manager_scope: null, dept: "Marketing" });
    expect(invite.features).toEqual(["signage", "sponsorship", "calendar", "reports", "approvals"]);
    await mona.context().close();
  });

  test("a manager for everyone edits someone in another department, never a super admin or another manager", async ({
    browser,
    baseURL,
  }) => {
    const evan = await as(browser, mail("evan"), baseURL!);
    await evan.goto(`${baseURL}/users?q=${n}`);
    // Checkboxes only on the people he may change.
    await expect(
      evan
        .getByRole("row")
        .filter({ hasText: mail("sid") })
        .getByRole("checkbox"),
    ).toHaveCount(1);
    await expect(
      evan
        .getByRole("row")
        .filter({ hasText: mail("max") })
        .getByRole("checkbox"),
    ).toHaveCount(0);
    await expect(
      evan
        .getByRole("row")
        .filter({ hasText: mail("max") })
        .getByText("Manager · Marketing"),
    ).toBeVisible();

    await evan.goto(`${baseURL}/users/${people.sid}`);
    await evan.getByLabel("Job title").fill(`Account lead ${n}`);
    await evan.getByRole("button", { name: "Save changes" }).click();
    await expect(evan.getByText(/Saved — Sid sees the change/)).toBeVisible();
    await evan.reload();
    await expect(evan.getByLabel("Job title")).toHaveValue(`Account lead ${n}`);
    // He can't make anyone a manager.
    await expect(evan.getByText("Only a super admin makes someone a manager.")).toBeVisible();

    await evan.goto(`${baseURL}/users/${adminId}`);
    await expect(evan.getByRole("note")).toHaveText(
      "Only super admins change a super admin's access.",
    );
    await expect(evan.locator("#p-name")).toHaveCount(0);
    await evan.goto(`${baseURL}/users/${people.max}`);
    await expect(evan.getByRole("note")).toHaveText("Only super admins change a manager's access.");
    await expect(evan.getByRole("button", { name: /Suspend/ })).toHaveCount(0);
    await evan.context().close();
  });

  test("suspending stops sign-in with a notice naming who to ask; reactivating lets them back", async ({
    browser,
    baseURL,
  }) => {
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/users/${people.fred}`);
    await admin.getByRole("button", { name: "Suspend Fred…" }).click();
    const dialog = admin.getByRole("dialog");
    await expect(dialog.getByText("No sign-offs are waiting on Fred.")).toBeVisible();
    await dialog.getByRole("button", { name: "Suspend Fred" }).click();
    await expect(admin.getByText(`Fred Freelance ${n} suspended`)).toBeVisible();
    await expect(admin.getByText(/^Suspended since \d+ \w+ \d{4} by Alex Admin$/)).toBeVisible();

    const fred = await as(browser, mail("fred"), baseURL!);
    await fred.goto(`${baseURL}/my-work`);
    await fred.waitForURL(/\/login/);
    await expect(
      fred.getByText(
        "Your access is paused for now. To get it back, ask Alex Admin (admin@media10.test).",
      ),
    ).toBeVisible();
    await expect(fred.getByRole("link", { name: "admin@media10.test" })).toHaveAttribute(
      "href",
      "mailto:admin@media10.test",
    );

    await admin.getByRole("button", { name: "Reactivate Fred" }).click();
    await expect(admin.getByText(`Fred Freelance ${n} can sign in again`)).toBeVisible();
    await fred.goto(`${baseURL}/my-work`);
    await expect(fred).toHaveURL(/\/my-work/);
    await fred.context().close();
    await admin.context().close();
  });

  test("end dates set from the list show there, and the history lists every change", async ({
    browser,
    baseURL,
  }) => {
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/users?q=${n}`);
    await admin.getByRole("checkbox", { name: `Select Fred Freelance ${n}` }).check();
    await admin.getByRole("checkbox", { name: `Select Sid Seller ${n}` }).check();
    const bar = admin.getByRole("region", { name: "Selected people" });
    await expect(bar.getByText("2 selected")).toBeVisible();
    await bar.getByRole("button", { name: "Set end date" }).click();
    const dialog = admin.getByRole("dialog");
    await dialog.getByLabel("Access ends on").fill("2099-01-31");
    await dialog.getByRole("button", { name: "Set end date" }).click();
    await expect(admin.getByRole("status").getByText("2 people given the end date")).toBeVisible();
    for (const who of ["fred", "sid"]) {
      await expect(
        admin
          .getByRole("row")
          .filter({ hasText: mail(who) })
          .getByText("Access ends 31 Jan"),
      ).toBeVisible();
    }
    // The list filters on it too.
    await admin.goto(`${baseURL}/users?q=${n}&status=ending`);
    await expect(admin.getByText("2 people", { exact: true })).toBeVisible();

    await admin.goto(`${baseURL}/users/${people.fred}`);
    const history = admin.getByRole("list", { name: "Access history" });
    await expect(history.getByText(`Access for ${mail("fred")} ends 31 Jan 2099`)).toBeVisible();
    await expect(history.getByText(`Reactivated ${mail("fred")}`)).toBeVisible();
    await expect(history.getByText(`Suspended ${mail("fred")}`)).toBeVisible();
    await expect(history.getByText("— Alex Admin").first()).toBeVisible();
    // Clear it again from the page.
    await admin.getByRole("button", { name: "Clear", exact: true }).click();
    await expect(admin.getByText("End date cleared")).toBeVisible();
    await admin.context().close();
  });

  test("adding several people: the check says why a row can't be invited, the rest are invited", async ({
    browser,
    baseURL,
  }) => {
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/users/new?mode=several`);
    await expect(admin.getByRole("heading", { name: "Add several people" })).toBeVisible();
    await admin
      .getByLabel(/One person per line/)
      .fill(
        `Pat Paste ${n}, ${mail("pat")}, Runner\nBad Row ${n}, not-an-email\nQuin Paste ${n}\t${mail("quin")}`,
      );
    await expect(admin.getByText("3 people found.")).toBeVisible();
    await admin.getByRole("radio", { name: /^Viewer/ }).check();
    await admin.getByRole("button", { name: "Check", exact: true }).click();
    await expect(admin.getByRole("heading", { name: "2 of 3 ready to invite" })).toBeVisible();
    await expect(
      admin
        .getByRole("row")
        .filter({ hasText: `Bad Row ${n}` })
        .getByText("Not an email address"),
    ).toBeVisible();
    await admin.getByRole("button", { name: "Invite 2 people" }).click();
    await expect(admin.getByRole("heading", { name: "2 people invited" })).toBeVisible();
    await expect(
      admin
        .getByRole("row")
        .filter({ hasText: mail("pat") })
        .getByText(/^Invited/),
    ).toBeVisible();
    await expect(
      admin
        .getByRole("row")
        .filter({ hasText: `Bad Row ${n}` })
        .getByText("Not an email address"),
    ).toBeVisible();
    // Email isn't set up locally: every link can be copied at once.
    await expect(admin.getByRole("button", { name: "Copy all links" })).toBeVisible();
    const invited = await sql`
      select invited_email, role, job_title from staff_invites
      where invited_email in ${sql([mail("pat"), mail("quin")])} order by invited_email`;
    expect(invited).toEqual([
      { invited_email: mail("pat"), role: "viewer", job_title: "Runner" },
      { invited_email: mail("quin"), role: "viewer", job_title: null },
    ]);
    await admin.context().close();
  });
});
