"use server";

import { unstable_rethrow } from "next/navigation";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { notifications, users } from "@/lib/db/schema";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { MUTABLE_KINDS } from "@/lib/notification-kinds";

export async function markAllNotificationsRead(): Promise<ActionResult> {
  try {
    const session = await requireSession();
    await db
      .update(notifications)
      .set({ readAt: new Date() })
      .where(and(eq(notifications.userId, session.user.id), isNull(notifications.readAt)));
    revalidatePath("/", "layout");
    return success();
  } catch (err) {
    unstable_rethrow(err);
    console.error("markAllNotificationsRead", err);
    return fail("Could not save — please try again");
  }
}

/** Mark one of my notifications read (tapping it in the bell). */
export async function markNotificationRead(input: unknown): Promise<ActionResult> {
  try {
    const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
    if (!parsed.success) return fail("Invalid request");
    const session = await requireSession();
    await db
      .update(notifications)
      .set({ readAt: new Date() })
      .where(
        and(
          eq(notifications.id, parsed.data.id),
          eq(notifications.userId, session.user.id),
          isNull(notifications.readAt),
        ),
      );
    return success();
  } catch (err) {
    unstable_rethrow(err);
    console.error("markNotificationRead", err);
    return fail("Could not save — please try again");
  }
}

const prefsSchema = z.record(z.enum(MUTABLE_KINDS), z.boolean());

/** Per-kind email/notification mutes, merged over the user's existing prefs. */
export async function updateNotificationPrefs(input: unknown): Promise<ActionResult> {
  try {
    const parsed = prefsSchema.safeParse(input);
    if (!parsed.success) return fail("Invalid preferences");
    const session = await requireSession();
    const [user] = await db.select().from(users).where(eq(users.id, session.user.id));
    if (!user) return fail("User not found");
    await db
      .update(users)
      .set({ notificationPrefs: { ...user.notificationPrefs, ...parsed.data } })
      .where(eq(users.id, session.user.id));
    revalidatePath("/settings");
    return success(undefined, "Notification preferences saved");
  } catch (err) {
    unstable_rethrow(err);
    console.error("updateNotificationPrefs", err);
    return fail("Could not save — please try again");
  }
}
