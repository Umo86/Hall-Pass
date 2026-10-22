"use server";

import { unstable_rethrow } from "next/navigation";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { users } from "@/lib/db/schema";
import { requireSession } from "@/lib/auth/actor";
import { authConfigured } from "@/lib/auth/config";
import { getAuthSession } from "@/lib/auth/session";
import { changeOwnPassword } from "@/lib/auth/accounts";
import { allow } from "@/lib/auth/rate-limit";
import { NOT_SET_UP, TOO_MANY, UNAVAILABLE } from "@/lib/auth/messages";
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

const passwordSchema = z
  .object({
    currentPassword: z.string().max(200).optional(),
    password: z.string().min(8, "Use at least 8 characters").max(200, "Use at most 200 characters"),
    confirm: z.string(),
  })
  .refine((d) => d.password === d.confirm, { message: "The two passwords don't match" });

/**
 * Change (or first set) your own password (My account). The current one is
 * checked when there is one; every other session is signed out, this one
 * stays. Own account only, like updateMyName (no can() row).
 */
export async function changeMyPassword(input: unknown): Promise<ActionResult> {
  try {
    const parsed = passwordSchema.safeParse(input);
    if (!parsed.success) return fail(parsed.error.issues[0].message);
    const session = await requireSession();
    if (!authConfigured()) return fail(NOT_SET_UP);
    // Demo logins share one password: nobody may change it for the others.
    if (session.actor.demo) return fail("Demo accounts keep the shared demo password");
    const gate = await allow("changePassword", session.user.id);
    if (gate !== "ok") return fail(gate === "limited" ? TOO_MANY : UNAVAILABLE);
    const auth = await getAuthSession();
    if (!auth?.session || auth.user.id !== session.user.id) {
      return fail("Sign in with your password first");
    }
    const result = await changeOwnPassword({
      userId: session.user.id,
      organisationId: session.organisation.id,
      currentPassword: parsed.data.currentPassword?.length ? parsed.data.currentPassword : null,
      newPassword: parsed.data.password,
      keepToken: auth.session.token,
    });
    if (result === "wrong_current") return fail("Your current password isn't right");
    revalidatePath("/account");
    return success(undefined, "Password changed");
  } catch (err) {
    unstable_rethrow(err);
    console.error("changeMyPassword", err);
    return fail("Could not change your password — please try again");
  }
}
