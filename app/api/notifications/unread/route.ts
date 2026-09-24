import { NextResponse } from "next/server";
import { and, count, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { notifications } from "@/lib/db/schema";
import { getSession } from "@/lib/auth/actor";

export const dynamic = "force-dynamic";

/** Tiny unread counter polled by the bell (~every 30s). */
export async function GET() {
  const session = await getSession().catch(() => null);
  if (!session) return NextResponse.json({ unread: 0 }, { status: 401 });
  const [row] = await db
    .select({ n: count() })
    .from(notifications)
    .where(and(eq(notifications.userId, session.user.id), isNull(notifications.readAt)));
  return NextResponse.json(
    { unread: Number(row?.n ?? 0) },
    { headers: { "cache-control": "no-store" } },
  );
}
