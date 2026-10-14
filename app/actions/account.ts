"use server";

import { unstable_rethrow } from "next/navigation";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { users } from "@/lib/db/schema";
import { requireSession } from "@/lib/auth/actor";
import { writeAudit } from "@/lib/audit";
import { fail, success, type ActionResult } from "@/lib/actions/result";

/** Change your own display name (My account). */
export async function updateMyName(input: unknown): Promise<ActionResult> {
  try {
    const parsed = z.object({ fullName: z.string().trim().min(1).max(120) }).safeParse(input);
    if (!parsed.success) return fail("Enter your name");
    const session = await requireSession();
    await db.transaction(async (tx) => {
      await tx
        .update(users)
        .set({ fullName: parsed.data.fullName, updatedAt: new Date() })
        .where(eq(users.id, session.user.id));
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        actorUserId: session.user.id,
        entityType: "user",
        entityId: session.user.id,
        action: "update",
        before: { fullName: session.user.fullName },
        after: { fullName: parsed.data.fullName },
        summary: `Changed their name to ${parsed.data.fullName}`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, "Name saved");
  } catch (err) {
    unstable_rethrow(err);
    console.error("updateMyName", err);
    return fail("Could not save — please try again");
  }
}
