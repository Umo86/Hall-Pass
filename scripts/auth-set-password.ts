/**
 * Break-glass: give someone a new password from the command line, for when
 * the last super admin is locked out and email isn't set up.
 *   DATABASE_URL='<the live database URL>' pnpm auth:set-password you@company.com
 * In one transaction: the password is set (or replaced), the email marked
 * verified, every session of theirs ended, and an audit row written. The new
 * password is printed once.
 */
import { randomBytes } from "node:crypto";
import { eq, sql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import "dotenv/config";
import * as schema from "../lib/db/schema";
import { writeAudit } from "../lib/audit";
import { hashPassword } from "../lib/auth/password";

async function main() {
  const email = process.argv[2]?.trim().toLowerCase();
  if (!email) {
    console.error("Usage: pnpm auth:set-password <email>");
    process.exit(1);
  }
  const url = process.env.DATABASE_URL ?? process.env.DIRECT_DATABASE_URL;
  if (!url) {
    console.error("Set DATABASE_URL to the database to change.");
    process.exit(1);
  }
  const client = postgres(url, { max: 1, prepare: false, onnotice: () => {} });
  const db = drizzle(client, { schema });
  try {
    const [user] = await db
      .select({ id: schema.users.id, email: schema.users.email })
      .from(schema.users)
      .where(sql`lower(${schema.users.email}) = ${email}`)
      .limit(1);
    if (!user) {
      console.error("No account with that email — invite them and use the invitation link");
      process.exitCode = 1;
      return;
    }
    const password = randomBytes(15).toString("base64url"); // 20 characters
    const hash = await hashPassword(password);
    const [member] = await db
      .select({ organisationId: schema.memberships.organisationId })
      .from(schema.memberships)
      .where(eq(schema.memberships.userId, user.id))
      .limit(1);
    await db.transaction(async (tx) => {
      await tx
        .insert(schema.authAccount)
        .values({ userId: user.id, accountId: user.id, providerId: "credential", password: hash })
        .onConflictDoUpdate({
          target: [schema.authAccount.providerId, schema.authAccount.accountId],
          set: { password: hash, updatedAt: new Date() },
        });
      await tx
        .update(schema.users)
        .set({ emailVerified: true, updatedAt: new Date() })
        .where(eq(schema.users.id, user.id));
      const ended = await tx
        .delete(schema.authSession)
        .where(eq(schema.authSession.userId, user.id))
        .returning({ id: schema.authSession.id });
      await writeAudit(tx, {
        organisationId: member?.organisationId ?? null,
        actorType: "system",
        entityType: "user",
        entityId: user.id,
        action: "settings_change",
        summary: "Password reset from the command line",
        after: { sessionsEnded: ended.length },
        subjectUserId: user.id,
        subjectEmail: user.email,
      });
    });
    console.log(`New password for ${user.email}: ${password}`);
    console.log("Sign in with this, then change it on My account.");
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
