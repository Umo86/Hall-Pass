import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/lib/db/client";
import { taskAttachments, tasks } from "@/lib/db/schema";
import { getSession } from "@/lib/auth/actor";
import { canWorkOnTask } from "@/lib/domain/tasks";
import { getDownloadUrl } from "@/lib/storage";

/** Download a task attachment — only for people who can work on the task. */
export async function GET(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await getSession();
  if (!session || session.actor.kind !== "staff") {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }
  const { id } = await params;
  if (!z.string().uuid().safeParse(id).success) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }
  const [row] = await db
    .select({ attachment: taskAttachments, task: tasks })
    .from(taskAttachments)
    .innerJoin(tasks, eq(tasks.id, taskAttachments.taskId))
    .where(and(eq(taskAttachments.id, id), eq(tasks.organisationId, session.organisation.id)))
    .limit(1);
  if (!row || !(await canWorkOnTask(session.actor, session.organisation.id, row.task))) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }
  const url = await getDownloadUrl("documents", row.attachment.filePath);
  return NextResponse.redirect(new URL(url, req.url));
}
