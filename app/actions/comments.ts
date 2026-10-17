"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { comments } from "@/lib/db/schema";
import { can, type ExternalActor } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { notify } from "@/lib/notify";
import { commentRecipients, itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { loadStandBundle, standAuthzCtx, stepActiveFlags } from "@/lib/domain/stand";
import { loadRun } from "@/lib/workflow/persist";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { itemPath } from "@/lib/edition-path";
import { recipientsWhoCanSee, staffMemberIds } from "@/lib/users/external";

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
  // Can a partner (from their live grants here) still see this record?
  let partnerSees: (actor: ExternalActor) => boolean = () => false;
  if (data.entityType === "signage_item") {
    const bundle = await loadItemBundle(db, data.entityId, {
      organisationId: session.organisation.id,
    });
    if (!bundle) return fail("Record not found");
    if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
    editionId = bundle.edition.id;
    ref = bundle.item.ref;
    ownerId = bundle.item.ownerUserId;
    createdBy = bundle.item.createdBy;
    link = `${itemPath(bundle.edition.code, bundle.item)}?tab=comments`;
    const itemCtx = itemAuthzCtx(bundle);
    partnerSees = (a) => can(a, { type: "signage.view", item: itemCtx });
    if (!data.isInternal) {
      if (!can(session.actor, { type: "comment.external.write", entity: itemAuthzCtx(bundle) })) {
        return fail("You cannot comment on this item");
      }
    } else if (session.actor.kind === "external") {
      return fail("You cannot write internal comments");
    }
  } else {
    const bundle = await loadStandBundle(db, data.entityId, {
      organisationId: session.organisation.id,
    });
    if (!bundle) return fail("Record not found");
    if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
    editionId = bundle.edition.id;
    ref = bundle.sub.ref;
    link = `/${bundle.edition.code}/stands/${bundle.sub.ref}`;
    const run =
      bundle.sub.currentRunNumber > 0
        ? await loadRun(db, "stand_submission", bundle.sub.id, bundle.sub.currentRunNumber)
        : [];
    const ctx = standAuthzCtx(bundle, stepActiveFlags(run));
    partnerSees = (a) => can(a, { type: "stand.view", sub: ctx });
    if (!data.isInternal) {
      if (!can(session.actor, { type: "comment.external.write", entity: ctx })) {
        return fail("You cannot comment on this submission");
      }
    } else if (session.actor.kind === "external") {
      return fail("You cannot write internal comments");
    }
  }

  // A reply must answer a comment on the same record.
  if (data.parentId) {
    const [parent] = await db
      .select({ id: comments.id })
      .from(comments)
      .where(
        and(
          eq(comments.id, data.parentId),
          eq(comments.entityType, data.entityType),
          eq(comments.entityId, data.entityId),
        ),
      );
    if (!parent) return fail("That comment no longer exists");
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
      // Staff means an active membership here, never the users.is_external flag.
      const authorIds = (
        await tx
          .selectDistinct({ id: comments.authorId })
          .from(comments)
          .where(
            and(eq(comments.entityType, data.entityType), eq(comments.entityId, data.entityId)),
          )
      ).map((r) => r.id);
      const staff = await staffMemberIds(tx, session.organisation.id, authorIds);
      const wanted = commentRecipients({
        authorId: session.user.id,
        ownerId,
        createdBy,
        priorAuthors: authorIds.map((id) => ({ id, isExternal: !staff.has(id) })),
        isInternal: data.isInternal,
      });
      // Partners only while their live grants here still show them this
      // record (an earlier commenter may have lost access since); never for
      // a staff-only comment.
      const recipients = await recipientsWhoCanSee(tx, session.organisation.id, wanted, {
        staffOnly: data.isInternal,
        sees: partnerSees,
      });
      if (recipients.length > 0) {
        await notify(tx, {
          userIds: recipients,
          scope: { organisationId: session.organisation.id, editionId },
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
