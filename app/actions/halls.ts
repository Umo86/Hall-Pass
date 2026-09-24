"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, count, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { editions, events, halls, locations, signageItems } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession, type Session } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";

/** The edition, if it belongs to the caller's organisation. */
async function ownEdition(session: Session, editionId: string) {
  const [row] = await db
    .select({ edition: editions })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(editions.id, editionId), eq(events.organisationId, session.organisation.id)))
    .limit(1);
  return row?.edition ?? null;
}

type Guarded =
  | { error: string }
  | { session: Session; edition: NonNullable<Awaited<ReturnType<typeof ownEdition>>> };

async function guard(editionId: string): Promise<Guarded> {
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return { error: "Only admin and ops can change halls and locations" };
  }
  const edition = await ownEdition(session, editionId);
  if (!edition) return { error: "Edition not found" };
  if (editionIsReadOnly(edition.status)) return { error: EDITION_LOCKED_MESSAGE };
  return { session, edition };
}

const name = z.string().trim().min(1, "Give it a name").max(120);

export async function createHall(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ editionId: z.string().uuid(), name }).safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const g = await guard(parsed.data.editionId);
  if ("error" in g) return fail(g.error);
  const [{ n }] = await db
    .select({ n: count() })
    .from(halls)
    .where(eq(halls.editionId, g.edition.id));
  await db.transaction(async (tx) => {
    const [hall] = await tx
      .insert(halls)
      .values({ editionId: g.edition.id, name: parsed.data.name, sortOrder: Number(n) })
      .returning();
    await writeAudit(tx, {
      organisationId: g.session.organisation.id,
      editionId: g.edition.id,
      actorUserId: g.session.user.id,
      entityType: "hall",
      entityId: hall.id,
      action: "create",
      after: { name: hall.name },
      summary: `Added hall ${hall.name} to ${g.edition.code}`,
    });
  });
  revalidatePath(`/${g.edition.code}`, "layout");
  return success(undefined, "Hall added");
}

export async function renameHall(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid(), name }).safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const hall = await db.query.halls.findFirst({ where: eq(halls.id, parsed.data.id) });
  if (!hall) return fail("Hall not found");
  const g = await guard(hall.editionId);
  if ("error" in g) return fail(g.error);
  await db.transaction(async (tx) => {
    await tx.update(halls).set({ name: parsed.data.name }).where(eq(halls.id, hall.id));
    await writeAudit(tx, {
      organisationId: g.session.organisation.id,
      editionId: g.edition.id,
      actorUserId: g.session.user.id,
      entityType: "hall",
      entityId: hall.id,
      action: "update",
      before: { name: hall.name },
      after: { name: parsed.data.name },
      summary: `Renamed hall ${hall.name} → ${parsed.data.name}`,
    });
  });
  revalidatePath(`/${g.edition.code}`, "layout");
  return success(undefined, "Hall renamed");
}

export async function deleteHall(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const hall = await db.query.halls.findFirst({ where: eq(halls.id, parsed.data.id) });
  if (!hall) return fail("Hall not found");
  const g = await guard(hall.editionId);
  if ("error" in g) return fail(g.error);
  const [[items], [locs]] = await Promise.all([
    db.select({ n: count() }).from(signageItems).where(eq(signageItems.hallId, hall.id)),
    db.select({ n: count() }).from(locations).where(eq(locations.hallId, hall.id)),
  ]);
  if (Number(items.n) > 0) return fail(`${items.n} item(s) are in this hall — move them first`);
  if (Number(locs.n) > 0) return fail("Remove this hall's locations first");
  await db.transaction(async (tx) => {
    await tx.delete(halls).where(eq(halls.id, hall.id));
    await writeAudit(tx, {
      organisationId: g.session.organisation.id,
      editionId: g.edition.id,
      actorUserId: g.session.user.id,
      entityType: "hall",
      entityId: hall.id,
      action: "soft_delete",
      summary: `Removed hall ${hall.name}`,
    });
  });
  revalidatePath(`/${g.edition.code}`, "layout");
  return success(undefined, "Hall removed");
}

export async function createLocation(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({ hallId: z.string().uuid(), name, zone: z.string().trim().max(120).optional() })
    .safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const hall = await db.query.halls.findFirst({ where: eq(halls.id, parsed.data.hallId) });
  if (!hall) return fail("Hall not found");
  const g = await guard(hall.editionId);
  if ("error" in g) return fail(g.error);
  await db.transaction(async (tx) => {
    const [loc] = await tx
      .insert(locations)
      .values({ hallId: hall.id, name: parsed.data.name, zone: parsed.data.zone || null })
      .returning();
    await writeAudit(tx, {
      organisationId: g.session.organisation.id,
      editionId: g.edition.id,
      actorUserId: g.session.user.id,
      entityType: "location",
      entityId: loc.id,
      action: "create",
      after: { hall: hall.name, name: loc.name },
      summary: `Added location ${loc.name} in ${hall.name}`,
    });
  });
  revalidatePath(`/${g.edition.code}`, "layout");
  return success(undefined, "Location added");
}

export async function renameLocation(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid(), name }).safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const [row] = await db
    .select({ loc: locations, hall: halls })
    .from(locations)
    .innerJoin(halls, eq(locations.hallId, halls.id))
    .where(eq(locations.id, parsed.data.id));
  if (!row) return fail("Location not found");
  const g = await guard(row.hall.editionId);
  if ("error" in g) return fail(g.error);
  await db.transaction(async (tx) => {
    await tx.update(locations).set({ name: parsed.data.name }).where(eq(locations.id, row.loc.id));
    await writeAudit(tx, {
      organisationId: g.session.organisation.id,
      editionId: g.edition.id,
      actorUserId: g.session.user.id,
      entityType: "location",
      entityId: row.loc.id,
      action: "update",
      before: { name: row.loc.name },
      after: { name: parsed.data.name },
      summary: `Renamed location ${row.loc.name} → ${parsed.data.name}`,
    });
  });
  revalidatePath(`/${g.edition.code}`, "layout");
  return success(undefined, "Location renamed");
}

export async function deleteLocation(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const [row] = await db
    .select({ loc: locations, hall: halls })
    .from(locations)
    .innerJoin(halls, eq(locations.hallId, halls.id))
    .where(eq(locations.id, parsed.data.id));
  if (!row) return fail("Location not found");
  const g = await guard(row.hall.editionId);
  if ("error" in g) return fail(g.error);
  const [items] = await db
    .select({ n: count() })
    .from(signageItems)
    .where(eq(signageItems.locationId, row.loc.id));
  if (Number(items.n) > 0) {
    return fail(`${items.n} item(s) use this location — move them first`);
  }
  await db.transaction(async (tx) => {
    await tx.delete(locations).where(eq(locations.id, row.loc.id));
    await writeAudit(tx, {
      organisationId: g.session.organisation.id,
      editionId: g.edition.id,
      actorUserId: g.session.user.id,
      entityType: "location",
      entityId: row.loc.id,
      action: "soft_delete",
      summary: `Removed location ${row.loc.name} from ${row.hall.name}`,
    });
  });
  revalidatePath(`/${g.edition.code}`, "layout");
  return success(undefined, "Location removed");
}
