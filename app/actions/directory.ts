"use server";

import { revalidatePath } from "next/cache";
import { unstable_rethrow } from "next/navigation";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { contractors, events, suppliers, venues } from "@/lib/db/schema";
import type { Tx } from "@/lib/db/client";
import { can, missingAbilityMessage } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";

/** A refusal worded for the person; anything else is logged and replaced with a generic message. */
class Refusal extends Error {}

const opt = (max = 200) =>
  z
    .string()
    .trim()
    .max(max)
    .optional()
    .nullable()
    .transform((v) => (v ? v : null));
const email = z
  .string()
  .trim()
  .optional()
  .nullable()
  .transform((v) => (v ? v : null))
  .refine((v) => v === null || z.string().email().safeParse(v).success, "Enter a valid email");
/**
 * Venue and series codes are internal (nobody types or reads them), so the
 * forms no longer ask: a code is made from the name when one isn't given.
 */
const code = z
  .string()
  .trim()
  .max(20)
  .optional()
  .nullable()
  .transform((v) => (v ? v.toUpperCase() : null))
  .refine((v) => v === null || /^[A-Z0-9-]{2,20}$/.test(v), "Use letters and numbers only");
const name = z.string().trim().min(1, "Give it a name").max(200);

const schema = z.discriminatedUnion("type", [
  z.object({
    type: z.literal("event"),
    id: z.string().uuid().optional(),
    values: z.object({ name, code }),
  }),
  z.object({
    type: z.literal("venue"),
    id: z.string().uuid().optional(),
    values: z.object({
      name,
      code,
      address: opt(500),
      riggingContactName: opt(),
      riggingContactEmail: email,
    }),
  }),
  z.object({
    type: z.literal("supplier"),
    id: z.string().uuid().optional(),
    values: z.object({
      name,
      kind: z.enum(["print", "rigging", "av", "contractor", "structural_engineer", "other"]),
      contactName: opt(),
      email,
      phone: opt(50),
    }),
  }),
  z.object({
    type: z.literal("contractor"),
    id: z.string().uuid().optional(),
    values: z.object({
      name,
      contactName: opt(),
      email,
      phone: opt(50),
      insuranceExpiry: z
        .string()
        .optional()
        .nullable()
        .transform((v) => (v ? v : null))
        .refine((v) => v === null || /^\d{4}-\d{2}-\d{2}$/.test(v), "Use a valid date"),
    }),
  }),
]);

const TABLES = { event: events, venue: venues, supplier: suppliers, contractor: contractors };
/** Who may change each kind of entry. */
const DIRECTORY_ABILITY = {
  event: "events.create",
  venue: "lists.manage",
  supplier: "suppliers.manage",
  contractor: "suppliers.manage",
} as const;
const LABELS = {
  event: "Event series",
  venue: "Venue",
  supplier: "Supplier",
  contractor: "Install contractor",
};

/** A short unique code from a name ("NEC Birmingham" → "NECBIRMINGHAM", then -2…). */
async function uniqueCode(
  tx: Tx,
  table: typeof events | typeof venues,
  organisationId: string,
  name: string,
) {
  const base =
    name
      .toUpperCase()
      .replace(/[^A-Z0-9]+/g, "")
      .slice(0, 16) || "VENUE";
  let candidate = base;
  for (let n = 2; ; n++) {
    const clash = await tx
      .select({ id: table.id })
      .from(table)
      .where(and(eq(table.organisationId, organisationId), eq(table.code, candidate)))
      .limit(1);
    if (clash.length === 0) return candidate;
    candidate = `${base.slice(0, 16)}-${n}`;
  }
}

/** Add or edit an event series, venue, supplier or install contractor (each by its own ability). */
export async function saveDirectoryEntry(input: unknown): Promise<ActionResult> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  const { type, id } = parsed.data;
  const needs = DIRECTORY_ABILITY[type];
  if (!can(session.actor, { type: needs })) return fail(missingAbilityMessage(needs));
  const table = TABLES[type];
  const orgId = session.organisation.id;
  // A code left out keeps the one it has (edit) or is made from the name (add).
  const values: Record<string, unknown> & { name: string } = { ...parsed.data.values };
  if ("code" in values && !values.code) delete values.code;
  try {
    await db.transaction(async (tx) => {
      let entityId = id;
      if (id) {
        const updated = await tx
          .update(table)
          .set({ ...values, updatedAt: new Date() } as never)
          .where(and(eq(table.id, id), eq(table.organisationId, orgId)))
          .returning({ id: table.id });
        if (updated.length === 0) throw new Refusal(`${LABELS[type]} not found — reload the page`);
      } else {
        if ((type === "venue" || type === "event") && !values.code) {
          values.code = await uniqueCode(
            tx,
            type === "venue" ? venues : events,
            orgId,
            values.name,
          );
        }
        const [row] = await tx
          .insert(table)
          .values({ ...values, organisationId: orgId } as never)
          .returning({ id: table.id });
        entityId = row.id;
      }
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: type,
        entityId: entityId!,
        action: id ? "update" : "create",
        after: values,
        summary: `${id ? "Updated" : "Added"} ${LABELS[type].toLowerCase()} ${values.name}`,
      });
    });
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof Refusal) return fail(err.message);
    const message = err instanceof Error ? err.message : "";
    if (/unique|duplicate/i.test(message)) {
      return fail("Something with that code already exists — reload the page and try again");
    }
    console.error("saveDirectoryEntry", err);
    return fail("Could not save — please try again");
  }
  revalidatePath("/", "layout");
  return success(undefined, `${parsed.data.values.name} saved`);
}

/**
 * Archive a venue (no longer offered when creating an event; its events keep
 * it) or put it back.
 */
export async function setVenueArchived(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid(), archived: z.boolean() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "lists.manage" })) {
    return fail(missingAbilityMessage("lists.manage"));
  }
  const { id, archived } = parsed.data;
  const orgId = session.organisation.id;
  try {
    const name = await db.transaction(async (tx) => {
      const [row] = await tx
        .update(venues)
        .set({ isArchived: archived, updatedAt: new Date() })
        .where(and(eq(venues.id, id), eq(venues.organisationId, orgId)))
        .returning({ id: venues.id, name: venues.name });
      if (!row) throw new Refusal("Venue not found — reload the page");
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: "venue",
        entityId: row.id,
        action: "update",
        before: { archived: !archived },
        after: { archived },
        summary: `${archived ? "Archived" : "Restored"} venue ${row.name}`,
      });
      return row.name;
    });
    revalidatePath("/", "layout");
    return success(
      undefined,
      archived ? `${name} archived — it won't be offered for new events` : `${name} restored`,
    );
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof Refusal) return fail(err.message);
    console.error("setVenueArchived", err);
    return fail("Could not update the venue — please try again");
  }
}
