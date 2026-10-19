/**
 * Migration 0013 against a real database (TEST_DATABASE_URL): the file is
 * run twice inside one transaction that is rolled back, over data shaped
 * like live — sponsors with messy package names in two events,
 * notifications about a record, a link and nothing in particular. Checks the
 * backfills, that the second run changes nothing, that a later run picks up
 * a sponsor written "in the gap" and leaves a removed package alone, and
 * that every new CHECK, unique index and FK refuses what it should.
 */
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);

const FILE = readFileSync("lib/db/migrations/0013_users_events_packages.sql", "utf8");
/** The file as psql would run it: drizzle's breakpoint markers stripped. */
const SQL_TEXT = FILE.replaceAll("--> statement-breakpoint", "");

let client: ReturnType<typeof postgres>;
const n = Date.now() % 1_000_000;

type Conn = postgres.ReservedSql;

/** One statement that must fail; the savepoint keeps the transaction usable. */
async function refused(c: Conn, statement: string): Promise<string> {
  await c.unsafe("SAVEPOINT refusal");
  try {
    await c.unsafe(statement);
  } catch (err) {
    await c.unsafe("ROLLBACK TO SAVEPOINT refusal");
    const e = err as { constraint_name?: string; message: string };
    return e.constraint_name ?? e.message;
  }
  await c.unsafe("ROLLBACK TO SAVEPOINT refusal");
  throw new Error(`Expected this to be refused: ${statement}`);
}

d("migration 0013: users, events per person, sponsorship packages", () => {
  beforeAll(() => {
    client = postgres(url!, { max: 2, prepare: false, onnotice: () => {} });
  });

  afterAll(async () => {
    await client?.end();
  });

  it("runs twice cleanly, backfills packages and notification events, and refuses what it should", async () => {
    const c = await client.reserve();
    try {
      await c.unsafe("BEGIN");
      const org = randomUUID();
      const user = randomUUID();
      const other = randomUUID();
      const event = randomUUID();
      const venue = randomUUID();
      const [edA, edB, edC] = [randomUUID(), randomUUID(), randomUUID()];
      const [codeA, codeB, codeC] = [`MA${n}`, `MB${n}`, `MC${n}`];
      await c`INSERT INTO organisations (id, name, slug) VALUES (${org}, 'Mig Org', ${`mig-${n}`})`;
      await c`INSERT INTO users (id, email, full_name) VALUES
        (${user}, ${`mig-${n}@m13.test`}, 'Mig'), (${other}, ${`mig2-${n}@m13.test`}, 'Mig Two')`;
      await c`INSERT INTO events (id, organisation_id, name, code) VALUES (${event}, ${org}, 'Mig Show', ${`ME${n}`})`;
      await c`INSERT INTO venues (id, organisation_id, name, code) VALUES (${venue}, ${org}, 'Mig Hall', ${`MV${n}`})`;
      for (const [id, code] of [
        [edA, codeA],
        [edB, codeB],
        [edC, codeC],
      ]) {
        await c`INSERT INTO editions (id, event_id, venue_id, name, code, build_start, build_end, open_start, open_end, breakdown_end)
          VALUES (${id}, ${event}, ${venue}, ${code}, ${code}, '2027-02-01', '2027-02-02', '2027-02-03', '2027-02-04', '2027-02-05')`;
      }
      // Sponsors as the old code left them: free-text package names.
      const sponsor = async (
        editionId: string,
        name: string,
        packageName: string | null,
        at: string,
      ) => {
        const [row] = await c<{ id: string }[]>`
          INSERT INTO sponsors (edition_id, company_name, package_name, created_at)
          VALUES (${editionId}, ${name}, ${packageName}, ${at}::timestamptz) RETURNING id`;
        return row.id;
      };
      const gold1 = await sponsor(edA, "Gold One", "Gold", "2026-01-01T09:00:00Z");
      const gold2 = await sponsor(edA, "Gold Two", " gold ", "2026-01-02T09:00:00Z");
      const silver = await sponsor(edA, "Silver Co", "Silver", "2026-01-03T09:00:00Z");
      const blank = await sponsor(edA, "Blank Co", "", "2026-01-04T09:00:00Z");
      const none = await sponsor(edA, "None Co", null, "2026-01-05T09:00:00Z");
      const goldB = await sponsor(edB, "Gold B", "Gold", "2026-01-06T09:00:00Z");
      await c`INSERT INTO sponsor_entitlements (sponsor_id, description, quantity) VALUES (${gold1}, 'Logo on banners', 6)`;
      // Notifications about a record, a link, and nothing in particular.
      const [exhibitor] = await c<{ id: string }[]>`
        INSERT INTO exhibitors (edition_id, company_name, stand_number) VALUES (${edA}, 'Stand Co', ${`S${n}`}) RETURNING id`;
      const [item] = await c<{ id: string }[]>`
        INSERT INTO signage_items (edition_id, ref, seq, name) VALUES (${edB}, ${`SIG-${codeB}-001`}, 1, 'A sign') RETURNING id`;
      const notice = async (fields: { entityType?: string; entityId?: string; link?: string }) => {
        const [row] = await c<{ id: string }[]>`
          INSERT INTO notifications (user_id, kind, title, entity_type, entity_id, link)
          VALUES (${user}, 'mention', 'Hi', ${fields.entityType ?? null}::entity_type, ${fields.entityId ?? null}, ${fields.link ?? null})
          RETURNING id`;
        return row.id;
      };
      const nExhibitor = await notice({ entityType: "exhibitor", entityId: exhibitor.id });
      const nItem = await notice({
        entityType: "signage_item",
        entityId: item.id,
        link: "/approvals",
      });
      const nEdition = await notice({ entityType: "edition", entityId: edB });
      const nLink = await notice({ link: `/${codeA}/signage?show=mine` });
      const nQuery = await notice({ link: `/${codeB}?tab=x` });
      const nApprovals = await notice({ link: "/approvals" });
      const nPrefix = await notice({ link: `/${codeA}X/signage` });
      const nC = await notice({ link: `/${codeC}` });

      await c.unsafe(SQL_TEXT).simple();
      const snapshot = async () => ({
        packages: await c`SELECT edition_id, name, sort_order, price, places, is_archived
          FROM sponsorship_packages WHERE edition_id IN (${edA}, ${edB}, ${edC}) ORDER BY edition_id, sort_order`,
        sponsors:
          await c`SELECT id, package_id, package_price, package_price_note, package_sold_at, created_at, package_name
          FROM sponsors WHERE edition_id IN (${edA}, ${edB}) ORDER BY created_at`,
        notifications:
          await c`SELECT id, edition_id FROM notifications WHERE user_id = ${user} ORDER BY id`,
      });
      const first = await snapshot();
      // Second run: a no-op.
      await c.unsafe(SQL_TEXT).simple();
      expect(await snapshot()).toEqual(first);

      // 2 packages in A ("Gold" named by its earliest spelling, A-Z), 1 in B.
      const packages = first.packages.map((p) => ({
        edition: p.edition_id === edA ? "A" : "B",
        name: p.name,
        sort: p.sort_order,
        price: p.price,
        places: p.places,
        archived: p.is_archived,
      }));
      expect(packages).toEqual(
        expect.arrayContaining([
          { edition: "A", name: "Gold", sort: 1, price: null, places: null, archived: false },
          { edition: "A", name: "Silver", sort: 2, price: null, places: null, archived: false },
          { edition: "B", name: "Gold", sort: 1, price: null, places: null, archived: false },
        ]),
      );
      expect(packages).toHaveLength(3);
      const pkgId = async (editionId: string, name: string) => {
        const [row] = await c<{ id: string }[]>`
          SELECT id FROM sponsorship_packages WHERE edition_id = ${editionId} AND name = ${name}`;
        return row.id;
      };
      const goldA = await pkgId(edA, "Gold");
      const silverA = await pkgId(edA, "Silver");
      const goldBPkg = await pkgId(edB, "Gold");
      const byId = new Map(first.sponsors.map((s) => [s.id as string, s]));
      expect(byId.get(gold1)!.package_id).toBe(goldA);
      expect(byId.get(gold2)!.package_id).toBe(goldA);
      expect(byId.get(silver)!.package_id).toBe(silverA);
      expect(byId.get(goldB)!.package_id).toBe(goldBPkg);
      expect(byId.get(blank)!.package_id).toBeNull();
      expect(byId.get(none)!.package_id).toBeNull();
      for (const id of [gold1, gold2, silver, goldB]) {
        const s = byId.get(id)!;
        // Sold when they were added; no agreed price yet; the name is kept as it was.
        expect((s.package_sold_at as Date).toISOString()).toBe(
          (s.created_at as Date).toISOString(),
        );
        expect(s.package_price).toBeNull();
        expect(s.package_price_note).toBeNull();
      }
      expect(byId.get(gold2)!.package_name).toBe(" gold ");
      expect(byId.get(blank)!.package_sold_at).toBeNull();
      const ents =
        await c`SELECT from_package_id FROM sponsor_entitlements WHERE sponsor_id = ${gold1}`;
      expect(ents.map((e) => e.from_package_id)).toEqual([null]);

      // Notification events: from the record first, then the link's event code.
      const ev = new Map(first.notifications.map((r) => [r.id as string, r.edition_id]));
      expect(ev.get(nExhibitor)).toBe(edA);
      expect(ev.get(nItem)).toBe(edB);
      expect(ev.get(nEdition)).toBe(edB);
      expect(ev.get(nLink)).toBe(edA);
      expect(ev.get(nQuery)).toBe(edB);
      expect(ev.get(nApprovals)).toBeNull();
      expect(ev.get(nPrefix)).toBeNull();
      expect(ev.get(nC)).toBe(edC);

      // A later run (after deploy) picks up a sponsor the old code wrote in
      // the gap, numbered after the event's packages, and leaves a sponsor
      // whose package was removed (name cleared) alone.
      await c`UPDATE sponsors SET package_id = NULL, package_sold_at = NULL, package_name = NULL WHERE id = ${silver}`;
      const gap = await sponsor(edA, "Gap Co", "  Bronze ", "2026-02-01T09:00:00Z");
      const late = await notice({ link: `/${codeB}/stands` });
      await c.unsafe(SQL_TEXT).simple();
      const [gapRow] = await c`SELECT s.package_id, p.name, p.sort_order FROM sponsors s
        JOIN sponsorship_packages p ON p.id = s.package_id WHERE s.id = ${gap}`;
      expect(gapRow).toMatchObject({ name: "Bronze", sort_order: 3 });
      const [silverRow] = await c`SELECT package_id FROM sponsors WHERE id = ${silver}`;
      expect(silverRow.package_id).toBeNull();
      const [lateRow] = await c`SELECT edition_id FROM notifications WHERE id = ${late}`;
      expect(lateRow.edition_id).toBe(edB);

      // Refused as intended.
      const deptId = randomUUID();
      await c`INSERT INTO departments (id, organisation_id, name) VALUES (${deptId}, ${org}, 'Mig Dept')`;
      const memberRow = (role: string, ids: string) =>
        `INSERT INTO memberships (user_id, organisation_id, role, edition_ids) VALUES ('${other}', '${org}', '${role}', ${ids})`;
      expect(await refused(c, memberRow("admin", `ARRAY['${edA}']::uuid[]`))).toBe(
        "memberships_edition_ids_not_admin",
      );
      expect(await refused(c, memberRow("ops", `'{}'::uuid[]`))).toBe(
        "memberships_edition_ids_not_empty",
      );
      const inviteRow = (role: string, ids: string) =>
        `INSERT INTO staff_invites (organisation_id, invited_email, role, invite_token_hash, edition_ids) VALUES ('${org}', 'inv-${n}@m13.test', '${role}', 'h', ${ids})`;
      expect(await refused(c, inviteRow("admin", `ARRAY['${edA}']::uuid[]`))).toBe(
        "staff_invites_edition_ids_not_admin",
      );
      expect(await refused(c, inviteRow("ops", `'{}'::uuid[]`))).toBe(
        "staff_invites_edition_ids_not_empty",
      );
      // A limited member and a limited invitation are fine.
      await c.unsafe(memberRow("ops", `ARRAY['${edA}']::uuid[]`));
      await c.unsafe(inviteRow("ops", `ARRAY['${edA}', '${edB}']::uuid[]`));
      const approver = (email: string, extra: string) =>
        `INSERT INTO approvers (organisation_id, department_id, full_name, email, ${extra})`;
      expect(
        await refused(
          c,
          approver(
            "linked@m13.test",
            `user_id, main_on_accept) VALUES ('${org}', '${deptId}', 'L', 'linked@m13.test', '${user}', true`,
          ),
        ),
      ).toBe("approvers_main_on_accept_invite_only");
      expect(
        await refused(
          c,
          approver(
            "main@m13.test",
            `is_main, main_on_accept) VALUES ('${org}', '${deptId}', 'M', 'main@m13.test', true, true`,
          ),
        ),
      ).toBe("approvers_main_on_accept_invite_only");
      await c.unsafe(
        approver(
          "ask1@m13.test",
          `main_on_accept, main_on_accept_by) VALUES ('${org}', '${deptId}', 'A1', 'ask1@m13.test', true, '${user}'`,
        ),
      );
      expect(
        await refused(
          c,
          approver(
            "ask2@m13.test",
            `main_on_accept) VALUES ('${org}', '${deptId}', 'A2', 'ask2@m13.test', true`,
          ),
        ),
      ).toBe("approvers_one_main_on_accept");
      expect(await refused(c, `UPDATE sponsors SET package_price = 100 WHERE id = '${none}'`)).toBe(
        "sponsors_package_sale_fields",
      );
      expect(
        await refused(c, `UPDATE sponsors SET package_id = '${goldBPkg}' WHERE id = '${none}'`),
      ).toBe("sponsors_package_same_event_fk");
      expect(
        await refused(
          c,
          `INSERT INTO sponsorship_packages (edition_id, name) VALUES ('${edA}', 'GOLD')`,
        ),
      ).toBe("sponsorship_packages_edition_name_unique");
      expect(
        await refused(
          c,
          `INSERT INTO sponsorship_packages (edition_id, name, price) VALUES ('${edA}', 'Neg', -1)`,
        ),
      ).toBe("sponsorship_packages_price_not_negative");
      expect(
        await refused(
          c,
          `INSERT INTO sponsorship_packages (edition_id, name, places) VALUES ('${edA}', 'None left', 0)`,
        ),
      ).toBe("sponsorship_packages_places_positive");
      expect(
        await refused(
          c,
          `INSERT INTO sponsorship_package_lines (package_id, description, quantity) VALUES ('${goldA}', 'x', 0)`,
        ),
      ).toBe("sponsorship_package_lines_quantity_positive");
      expect(await refused(c, `UPDATE sponsors SET package_price = -5 WHERE id = '${gold1}'`)).toBe(
        "sponsors_package_price_not_negative",
      );

      // Deleting an event clears notifications.edition_id instead of blocking.
      await c`DELETE FROM editions WHERE id = ${edC}`;
      const [cleared] = await c`SELECT edition_id FROM notifications WHERE id = ${nC}`;
      expect(cleared.edition_id).toBeNull();
    } finally {
      await c.unsafe("ROLLBACK").catch(() => {});
      c.release();
    }
  });
});
