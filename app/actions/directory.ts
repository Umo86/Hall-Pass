"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { contractors, events, suppliers, venues } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";

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
const code = z
  .string()
  .trim()
  .min(2, "Code needs at least 2 characters")
  .max(20)
  .regex(/^[A-Z0-9-]+$/i, "Use letters and numbers only")
  .transform((v) => v.toUpperCase());
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
const LABELS = { event: "Event", venue: "Venue", supplier: "Supplier", contractor: "Contractor" };

/** Add or edit an event, venue, supplier or contractor (admin & ops). */
export async function saveDirectoryEntry(input: unknown): Promise<ActionResult> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admin and ops can change this list");
  }
  const { type, id, values } = parsed.data;
  const table = TABLES[type];
  const orgId = session.organisation.id;
  try {
    await db.transaction(async (tx) => {
      let entityId = id;
      if (id) {
        const updated = await tx
          .update(table)
          .set(values)
          .where(and(eq(table.id, id), eq(table.organisationId, orgId)))
          .returning({ id: table.id });
        if (updated.length === 0) throw new Error(`${LABELS[type]} not found`);
      } else {
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
    const message = err instanceof Error ? err.message : "Something went wrong";
    if (/unique|duplicate/i.test(message)) return fail("That code is already in use");
    return fail(message);
  }
  revalidatePath("/", "layout");
  return success(undefined, `${LABELS[type]} saved`);
}
