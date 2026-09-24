"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { comments, users } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { notify } from "@/lib/notify";
import { commentRecipients, itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { loadStandBundle, standAuthzCtx, stepActiveFlags } from "@/lib/domain/stand";
import { loadRun } from "@/lib/workflow/persist";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";

const addSchema = z.object({
  entityType: z.enum(["signage_item", "stand_submission"]),
  entityId: z.string().uuid(),
  body: z.string().trim().min(1, "Write a comment first").max(10000),
  isInternal: z.coerce.boolean().default(true),
  parentId: z.string().uuid().optional().nullable(),
  mentionUserIds: z.array(z.string().uuid()).default([]),
});

export async function addComment(input: unknown): Promise<ActionResult> {
  const parsed = addSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  const data = parsed.data;

  // Authorisation: internal comments are staff-only; external comments need
  // write access to a record the actor can see.
  if (data.isInternal) {
    if (!can(session.actor, { type: "comment.internal.write" })) {
      return fail("You cannot write internal comments");
    }
  }

  let editionId: string | null = null;
  let ref = "";
  let link = "";
  let ownerId: string | null = null;
  let createdBy: string | null = null;
  if (data.entityType === "signage_item") {
    const bundle = await loadItemBundle(db, data.entityId);
    if (!bundle) return fail("Record not found");
    if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
    editionId = bundle.edition.id;
    ref = bundle.item.ref;
    ownerId = bundle.item.ownerUserId;
    createdBy = bundle.item.createdBy;
    link = `/${bundle.edition.code}/signage/${bundle.item.ref}?tab=comments`;
    if (!data.isInternal) {
      if (!can(session.actor, { type: "comment.external.write", entity: itemAuthzCtx(bundle) })) {
        return fail("You cannot comment on this item");
      }
    } else if (session.actor.kind === "external") {
      return fail("You cannot write internal comments");
    }
  } else {
    const bundle = await loadStandBundle(db, data.entityId);
    if (!bundle) return fail("Record not found");
    if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
    editionId = bundle.edition.id;
    ref = bundle.sub.ref;
    link = `/${bundle.edition.code}/stands/${bundle.sub.ref}`;
    if (!data.isInternal) {
      const run =
        bundle.sub.currentRunNumber > 0
          ? await loadRun(db, "stand_submission", bundle.sub.id, bundle.sub.currentRunNumber)
          : [];
      const ctx = standAuthzCtx(bundle, stepActiveFlags(run));
      if (!can(session.actor, { type: "comment.external.write", entity: ctx })) {
        return fail("You cannot comment on this submission");
      }
    } else if (session.actor.kind === "external") {
      return fail("You cannot write internal comments");
    }
  }

  try {
    await db.transaction(async (tx) => {
      const [comment] = await tx
        .insert(comments)
        .values({
          entityType: data.entityType,
          entityId: data.entityId,
          parentId: data.parentId ?? null,
          authorId: session.user.id,
          body: data.body,
          mentionUserIds: data.mentionUserIds,
          isInternal: data.isInternal,
        })
        .returning();

      // The owner and everyone already in the conversation hear about it.
      const priorAuthors = await tx
        .selectDistinct({ id: users.id, isExternal: users.isExternal })
        .from(comments)
        .innerJoin(users, eq(comments.authorId, users.id))
        .where(and(eq(comments.entityType, data.entityType), eq(comments.entityId, data.entityId)));
      const recipients = commentRecipients({
        authorId: session.user.id,
        ownerId,
        createdBy,
        priorAuthors,
        isInternal: data.isInternal,
      });
      if (recipients.length > 0) {
        await notify(tx, {
          userIds: recipients,
          kind: "comment",
          title: `Comment on ${ref}`,
          body: data.body.slice(0, 200),
          link,
          entityType: data.entityType,
          entityId: data.entityId,
        });
      }
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId,
        actorUserId: session.user.id,
        entityType: data.entityType,
        entityId: data.entityId,
        action: "update",
        after: { commentId: comment.id, isInternal: data.isInternal },
        summary: `Comment added on ${ref}`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, "Comment added");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}
