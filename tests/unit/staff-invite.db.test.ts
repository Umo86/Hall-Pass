/**
 * Staff invitations against a real database (TEST_DATABASE_URL): the newest
 * open invite wins, claiming creates the membership once with the invited
 * role and permissions, and a used or revoked invite can't be claimed; a
 * "main approver when they accept" is carried out once.
 */
import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "@/lib/db/schema";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let invites: typeof import("@/lib/auth/claim-staff-invite");
let orgId: string;
const suffix = Date.now() % 1_000_000;
const email = `invitee-${suffix}@invite.test`;

d("staff invitations", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    await migrate(db, { migrationsFolder: "lib/db/migrations" });
    invites = await import("@/lib/auth/claim-staff-invite");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Invite Org", slug: `invite-${suffix}` })
      .returning();
    orgId = org.id;
  });

  afterAll(async () => {
    await client?.end();
  });

  it("claims the newest open invitation once, with its role and permissions", async () => {
    await db.insert(schema.staffInvites).values({
      organisationId: orgId,
      invitedEmail: email,
      role: "viewer",
      inviteTokenHash: `old-${suffix}`,
      createdAt: new Date(Date.now() - 60_000),
    });
    await db.insert(schema.staffInvites).values({
      organisationId: orgId,
      invitedEmail: email,
      role: "sales",
      permissionOverrides: { "costs.edit": true },
      inviteTokenHash: `new-${suffix}`,
    });

    const invite = await invites.openStaffInviteFor(email.toUpperCase());
    expect(invite?.role).toBe("sales");

    const userId = randomUUID();
    await db.insert(schema.users).values({ id: userId, email });
    await invites.claimStaffInvite(invite!, userId, "  Ivy Invitee ");
    // A second claim of the same invite does nothing.
    await invites.claimStaffInvite(invite!, userId);

    const rows = await db
      .select()
      .from(schema.memberships)
      .where(
        and(eq(schema.memberships.userId, userId), eq(schema.memberships.organisationId, orgId)),
      );
    expect(rows).toHaveLength(1);
    expect(rows[0].role).toBe("sales");
    expect(rows[0].permissionOverrides).toEqual({ "costs.edit": true });

    const [user] = await db.select().from(schema.users).where(eq(schema.users.id, userId));
    expect(user.fullName).toBe("Ivy Invitee");

    const audit = await db
      .select()
      .from(schema.auditLog)
      .where(
        and(
          eq(schema.auditLog.entityType, "staff_invite"),
          eq(schema.auditLog.entityId, invite!.id),
        ),
      );
    expect(audit.length).toBe(1);
  });

  it("does not claim an expired invitation, and copies department and sections when valid", async () => {
    const [dept] = await db
      .insert(schema.departments)
      .values({ organisationId: orgId, name: `Events ${suffix}`, signsOff: false })
      .returning();
    const expiredEmail = `expired-${suffix}@invite.test`;
    const [expired] = await db
      .insert(schema.staffInvites)
      .values({
        organisationId: orgId,
        invitedEmail: expiredEmail,
        role: "ops",
        inviteTokenHash: `exp-${suffix}`,
        expiresAt: new Date(Date.now() - 60_000),
      })
      .returning();
    expect(await invites.openStaffInviteFor(expiredEmail)).toBeNull();
    const expiredUser = randomUUID();
    await db.insert(schema.users).values({ id: expiredUser, email: expiredEmail });
    await invites.claimStaffInvite(expired, expiredUser);
    expect(
      await db.select().from(schema.memberships).where(eq(schema.memberships.userId, expiredUser)),
    ).toHaveLength(0);

    const okEmail = `fresh-${suffix}@invite.test`;
    const [fresh] = await db
      .insert(schema.staffInvites)
      .values({
        organisationId: orgId,
        invitedEmail: okEmail,
        role: "marketing",
        fullName: "Fran Fresh",
        jobTitle: "Designer",
        departmentId: dept.id,
        features: ["signage", "calendar"],
        inviteTokenHash: `fresh-${suffix}`,
        expiresAt: new Date(Date.now() + 60_000),
      })
      .returning();
    const freshUser = randomUUID();
    await db.insert(schema.users).values({ id: freshUser, email: okEmail });
    await invites.claimStaffInvite(fresh, freshUser);
    const [m] = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, freshUser));
    expect(m).toMatchObject({
      role: "marketing",
      departmentId: dept.id,
      features: ["signage", "calendar"],
      jobTitle: "Designer",
    });
    // The name from the invitation is used when none is typed.
    const [u] = await db.select().from(schema.users).where(eq(schema.users.id, freshUser));
    expect(u.fullName).toBe("Fran Fresh");
  });

  it("accepting twice promotes once (main approver when they accept)", async () => {
    const [dept] = await db
      .insert(schema.departments)
      .values({ organisationId: orgId, name: `Press ${suffix}` })
      .returning();
    const joId = randomUUID();
    const joEmail = `jo-${suffix}@invite.test`;
    await db.insert(schema.users).values({ id: joId, email: joEmail, fullName: "Jo Main" });
    await db
      .insert(schema.memberships)
      .values({ userId: joId, organisationId: orgId, role: "marketing" });
    const samEmail = `sam-${suffix}@invite.test`;
    await db.insert(schema.approvers).values([
      {
        organisationId: orgId,
        departmentId: dept.id,
        fullName: "Jo Main",
        email: joEmail,
        userId: joId,
        isMain: true,
      },
      {
        organisationId: orgId,
        departmentId: dept.id,
        fullName: "Sam Asked",
        email: samEmail,
        mainOnAccept: true,
      },
    ]);
    const [invite] = await db
      .insert(schema.staffInvites)
      .values({
        organisationId: orgId,
        invitedEmail: samEmail,
        role: "marketing",
        inviteTokenHash: `ask-${suffix}`,
      })
      .returning();
    const samId = randomUUID();
    await db.insert(schema.users).values({ id: samId, email: samEmail });
    await invites.claimStaffInvite(invite, samId, "Sam Asked");
    await invites.claimStaffInvite(invite, samId, "Sam Asked");
    const rows = await db
      .select()
      .from(schema.approvers)
      .where(eq(schema.approvers.departmentId, dept.id));
    expect(rows.find((r) => r.email === samEmail)).toMatchObject({
      userId: samId,
      isMain: true,
      mainOnAccept: false,
    });
    expect(rows.find((r) => r.email === joEmail)?.isMain).toBe(false);
    const promoted = await db
      .select()
      .from(schema.auditLog)
      .where(
        and(
          eq(schema.auditLog.subjectUserId, samId),
          eq(schema.auditLog.entityType, "approver"),
          eq(schema.auditLog.actorType, "system"),
        ),
      );
    expect(promoted.map((a) => a.summary)).toEqual([
      `Sam Asked is now the main approver for Press ${suffix} — they accepted their invitation`,
    ]);
    const told = await db
      .select()
      .from(schema.notifications)
      .where(
        and(eq(schema.notifications.userId, joId), eq(schema.notifications.kind, "main_approver")),
      );
    expect(told).toHaveLength(1);
  });

  it("does not claim a revoked invitation", async () => {
    const otherEmail = `revoked-${suffix}@invite.test`;
    const [invite] = await db
      .insert(schema.staffInvites)
      .values({
        organisationId: orgId,
        invitedEmail: otherEmail,
        role: "ops",
        inviteTokenHash: `rev-${suffix}`,
        revokedAt: new Date(),
      })
      .returning();
    expect(await invites.openStaffInviteFor(otherEmail)).toBeNull();
    const userId = randomUUID();
    await db.insert(schema.users).values({ id: userId, email: otherEmail });
    await invites.claimStaffInvite(invite, userId);
    const rows = await db
      .select()
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, userId));
    expect(rows).toHaveLength(0);
  });

  it("limited invitation renew rules (Users → Events): a manager limited to some events renews only invitations within them", async () => {
    const manage = await import("@/lib/users/manage");
    const { startingChoices } = await import("@/lib/users/rules");
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Invite Show", code: `IS${suffix}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Invite Hall", code: `IH${suffix}` })
      .returning();
    const [a, b] = await db
      .insert(schema.editions)
      .values(
        ["A", "B"].map((x, i) => ({
          eventId: event.id,
          venueId: venue.id,
          name: `Invite ${x}`,
          code: `INV${x}${suffix}`,
          buildStart: `2027-0${i + 3}-01`,
          buildEnd: `2027-0${i + 3}-02`,
          openStart: `2027-0${i + 3}-03`,
          openEnd: `2027-0${i + 3}-04`,
          breakdownEnd: `2027-0${i + 3}-05`,
        })),
      )
      .returning();
    const person = async (key: string, role: "admin" | "ops", extra = {}) => {
      const id = randomUUID();
      await db.insert(schema.users).values({ id, email: `${key}-${suffix}@invite.test` });
      await db
        .insert(schema.memberships)
        .values({ userId: id, organisationId: orgId, role, ...extra });
      return id;
    };
    const boss = await person("renew-boss", "admin");
    const mona = await person("renew-mona", "ops", {
      managerScope: "everyone",
      editionIds: [a.id],
    });
    const asBoss = { organisationId: orgId, actorUserId: boss, actorName: "Boss" };
    const asMona = { organisationId: orgId, actorUserId: mona, actorName: "Mona" };
    const input = (key: string, editionIds: string[] | null) => ({
      email: `${key}-${suffix}@invite.test`,
      fullName: key,
      jobTitle: null,
      departmentId: null,
      role: "ops" as const,
      features: null,
      abilities: startingChoices("ops", {}, { superAdmin: false }),
      signoffs: [],
      editionIds,
    });
    const tx = <T>(fn: (t: Parameters<Parameters<typeof db.transaction>[0]>[0]) => Promise<T>) =>
      db.transaction(fn);
    const mine = await tx((t) => manage.inviteUserTx(t, asMona, input("renew-a", [a.id])));
    await tx((t) => manage.renewInviteLinkTx(t, asMona, mine.inviteId));
    // A super admin adds B: no longer one Mona could have made.
    await tx((t) =>
      manage.updateInviteTx(t, asBoss, {
        ...input("renew-a", [a.id, b.id]),
        inviteId: mine.inviteId,
      }),
    );
    await expect(tx((t) => manage.renewInviteLinkTx(t, asMona, mine.inviteId))).rejects.toThrow(
      manage.RENEW_NOT_YOURS,
    );
    await tx((t) => manage.renewInviteLinkTx(t, asBoss, mine.inviteId));
    const all = await tx((t) => manage.inviteUserTx(t, asBoss, input("renew-all", null)));
    await expect(tx((t) => manage.renewInviteLinkTx(t, asMona, all.inviteId))).rejects.toThrow(
      manage.RENEW_NOT_YOURS,
    );
  });
});
