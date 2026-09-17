"use server";

import { revalidatePath } from "next/cache";
import { and, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { notifications } from "@/lib/db/schema";
import { requireSession } from "@/lib/auth/actor";
import { success, type ActionResult } from "@/lib/actions/result";

export async function markAllNotificationsRead(): Promise<ActionResult> {
  const session = await requireSession();
  await db
    .update(notifications)
    .set({ readAt: new Date() })
    .where(and(eq(notifications.userId, session.user.id), isNull(notifications.readAt)));
  revalidatePath("/", "layout");
  return success();
}
