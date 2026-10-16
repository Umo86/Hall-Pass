/**
 * Staff invitations against a real database (TEST_DATABASE_URL): the newest
 * open invite wins, claiming creates the membership once with the invited
 * role and permissions, and a used or revoked invite can't be claimed.
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
});
