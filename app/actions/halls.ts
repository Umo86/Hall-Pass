"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, count, eq, inArray, or, sql, type SQL } from "drizzle-orm";
import { db, type Tx } from "@/lib/db/client";
import { editions, events, halls, locations, signageItems } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession, type Session } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { BULK_MAX_HALLS, BULK_MAX_LOCATIONS, parseBulkHalls } from "@/components/halls/bulk";

/** The event, if it belongs to the caller's organisation. */
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
    return { error: "Only admins and Operations can change halls and locations" };
  }
  const edition = await ownEdition(session, editionId);
  if (!edition) return { error: "Event not found" };
  if (editionIsReadOnly(edition.status)) return { error: EDITION_LOCKED_MESSAGE };
  return { session, edition };
}

/** Halls feed the setup checklist in the nav, so every page is refreshed. */
function refresh() {
  revalidatePath("/", "layout");
}

const name = z.string().trim().min(1, "Give it a name").max(120, "Keep names to 120 characters");
const zone = z
  .string()
  .trim()
  .max(120, "Keep zones to 120 characters")
  .optional()
  .nullable()
  .transform((v) => (v ? v : null));

function signs(n: number) {
  return `${n} sign${n === 1 ? "" : "s"}`;
}

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
  refresh();
  return success(undefined, `${parsed.data.name} added`);
}

/**
 * "Add several at once": one hall per line, with its locations after a
 * colon. Halls that already exist (same name) get the new locations; one
 * audit row for the lot.
 */
export async function createHallsBulk(
  input: unknown,
): Promise<ActionResult<{ halls: number; locations: number }>> {
  const parsed = z
    .object({ editionId: z.string().uuid(), text: z.string().max(20_000) })
    .safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const wanted = parseBulkHalls(parsed.data.text);
  if (wanted.length === 0) return fail("Type at least one hall, one per line");
  if (wanted.length > BULK_MAX_HALLS) return fail(`Add up to ${BULK_MAX_HALLS} halls at a time`);
  if (wanted.reduce((n, h) => n + h.locations.length, 0) > BULK_MAX_LOCATIONS) {
    return fail(`Add up to ${BULK_MAX_LOCATIONS} locations at a time`);
  }
  const g = await guard(parsed.data.editionId);
  if ("error" in g) return fail(g.error);
  let hallsAdded = 0;
  let locationsAdded = 0;
  await db.transaction(async (tx) => {
    const existing = await tx.select().from(halls).where(eq(halls.editionId, g.edition.id));
    let sortOrder = existing.length;
    for (const w of wanted) {
      let hall = existing.find((h) => h.name.toLowerCase() === w.name.toLowerCase());
      if (!hall) {
        [hall] = await tx
          .insert(halls)
          .values({ editionId: g.edition.id, name: w.name, sortOrder: sortOrder++ })
          .returning();
        existing.push(hall);
        hallsAdded += 1;
      }
      if (w.locations.length === 0) continue;
      const have = await tx
        .select({ name: locations.name })
        .from(locations)
        .where(eq(locations.hallId, hall.id));
      const fresh = w.locations.filter(
        (l) => !have.some((h) => h.name.toLowerCase() === l.toLowerCase()),
      );
      if (fresh.length > 0) {
        await tx.insert(locations).values(fresh.map((l) => ({ hallId: hall.id, name: l })));
        locationsAdded += fresh.length;
      }
    }
    await writeAudit(tx, {
      organisationId: g.session.organisation.id,
      editionId: g.edition.id,
      actorUserId: g.session.user.id,
      entityType: "hall",
      entityId: null,
      action: "create",
      after: { halls: wanted },
      summary: `Added ${hallsAdded} hall(s) and ${locationsAdded} location(s) to ${g.edition.code}`,
    });
  });
  refresh();
  if (hallsAdded === 0 && locationsAdded === 0) {
    return success({ halls: 0, locations: 0 }, "Those halls and locations were already here");
  }
  return success(
    { halls: hallsAdded, locations: locationsAdded },
    `Added ${hallsAdded} hall${hallsAdded === 1 ? "" : "s"} and ${locationsAdded} location${locationsAdded === 1 ? "" : "s"}`,
  );
}

/**
 * Start an event's halls from an earlier event (usually the same venue last
 * year): every hall and location comes across. Only into an event that has
 * no halls yet, so nothing is doubled up.
 */
export async function copyHallsFrom(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({ sourceEditionId: z.string().uuid(), targetEditionId: z.string().uuid() })
    .safeParse(input);
  if (!parsed.success) return fail("Choose an event to copy from");
  if (parsed.data.sourceEditionId === parsed.data.targetEditionId) {
    return fail("Choose a different event to copy from");
  }
  const g = await guard(parsed.data.targetEditionId);
  if ("error" in g) return fail(g.error);
  const source = await ownEdition(g.session, parsed.data.sourceEditionId);
  if (!source) return fail("Event not found");
  const [[target], [from]] = await Promise.all([
    db.select({ n: count() }).from(halls).where(eq(halls.editionId, g.edition.id)),
    db.select({ n: count() }).from(halls).where(eq(halls.editionId, source.id)),
  ]);
  if (Number(target.n) > 0) {
    return fail("This event already has halls — add to them here instead of copying");
  }
  if (Number(from.n) === 0) return fail(`${source.name} has no halls to copy`);
  let copied = { halls: 0, locations: 0 };
  await db.transaction(async (tx) => {
    copied = await copyHalls(tx, source.id, g.edition.id);
    await writeAudit(tx, {
      organisationId: g.session.organisation.id,
      editionId: g.edition.id,
      actorUserId: g.session.user.id,
      entityType: "hall",
      entityId: null,
      action: "create",
      after: { copiedFrom: source.code, ...copied },
      summary: `Copied ${copied.halls} hall(s) and ${copied.locations} location(s) from ${source.code} to ${g.edition.code}`,
    });
  });
  refresh();
  return success(
    undefined,
    `Copied ${copied.halls} hall${copied.halls === 1 ? "" : "s"} and ${copied.locations} location${copied.locations === 1 ? "" : "s"} from ${source.name}`,
  );
}

async function copyHalls(tx: Tx, sourceId: string, targetId: string) {
  const hallRows = await tx
    .select()
    .from(halls)
    .where(eq(halls.editionId, sourceId))
    .orderBy(halls.sortOrder, halls.name);
  let locationCount = 0;
  for (const h of hallRows) {
    const [nh] = await tx
      .insert(halls)
      .values({ editionId: targetId, name: h.name, sortOrder: h.sortOrder })
      .returning({ id: halls.id });
    const locs = await tx.select().from(locations).where(eq(locations.hallId, h.id));
    if (locs.length > 0) {
      await tx.insert(locations).values(
        locs.map((l) => ({
          hallId: nh.id,
          name: l.name,
          zone: l.zone,
          xPct: l.xPct,
          yPct: l.yPct,
          nearStandNumber: l.nearStandNumber,
        })),
      );
      locationCount += locs.length;
    }
  }
  return { halls: hallRows.length, locations: locationCount };
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
  refresh();
  return success(undefined, "Hall renamed");
}

/** Live and deleted items that point at a hall or any of its locations. */
async function itemsUsing(where: SQL | undefined) {
  const rows = await db
    .select({ deleted: sql<boolean>`${signageItems.deletedAt} is not null`, n: count() })
    .from(signageItems)
    .where(where)
    .groupBy(sql`${signageItems.deletedAt} is not null`);
  return {
    live: Number(rows.find((r) => !r.deleted)?.n ?? 0),
    deleted: Number(rows.find((r) => r.deleted)?.n ?? 0),
  };
}

const RESTORE_HINT =
  "Restore them from Settings → Deleted items and move them first, or keep it — it does no harm.";

/**
 * Remove a hall with its locations. Refused while signs use it — including
 * deleted signs, which still point at it and can be restored.
 */
export async function deleteHall(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const hall = await db.query.halls.findFirst({ where: eq(halls.id, parsed.data.id) });
  if (!hall) return fail("Hall not found");
  const g = await guard(hall.editionId);
  if ("error" in g) return fail(g.error);
  const locs = await db.select().from(locations).where(eq(locations.hallId, hall.id));
  const used = await itemsUsing(
    locs.length > 0
      ? or(
          eq(signageItems.hallId, hall.id),
          inArray(
            signageItems.locationId,
            locs.map((l) => l.id),
          ),
        )
      : eq(signageItems.hallId, hall.id),
  );
  if (used.live > 0) {
    return fail(
      `${signs(used.live)} ${used.live === 1 ? "is" : "are"} in ${hall.name} — move them to another hall first.`,
    );
  }
  if (used.deleted > 0) {
    return fail(
      `${used.deleted} deleted item${used.deleted === 1 ? " still points" : "s still point"} at ${hall.name}, so it can't be removed. ${RESTORE_HINT}`,
    );
  }
  await db.transaction(async (tx) => {
    if (locs.length > 0) await tx.delete(locations).where(eq(locations.hallId, hall.id));
    await tx.delete(halls).where(eq(halls.id, hall.id));
    await writeAudit(tx, {
      organisationId: g.session.organisation.id,
      editionId: g.edition.id,
      actorUserId: g.session.user.id,
      entityType: "hall",
      entityId: hall.id,
      action: "soft_delete",
      before: { name: hall.name, locations: locs.map((l) => l.name) },
      summary: `Removed hall ${hall.name}${locs.length ? ` and its ${locs.length} location(s)` : ""}`,
    });
  });
  refresh();
  return success(undefined, `${hall.name} removed`);
}

export async function createLocation(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ hallId: z.string().uuid(), name, zone }).safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const hall = await db.query.halls.findFirst({ where: eq(halls.id, parsed.data.hallId) });
  if (!hall) return fail("Hall not found");
  const g = await guard(hall.editionId);
  if ("error" in g) return fail(g.error);
  await db.transaction(async (tx) => {
    const [loc] = await tx
      .insert(locations)
      .values({ hallId: hall.id, name: parsed.data.name, zone: parsed.data.zone })
      .returning();
    await writeAudit(tx, {
      organisationId: g.session.organisation.id,
      editionId: g.edition.id,
      actorUserId: g.session.user.id,
      entityType: "location",
      entityId: loc.id,
      action: "create",
      after: { hall: hall.name, name: loc.name, zone: loc.zone },
      summary: `Added location ${loc.name} in ${hall.name}`,
    });
  });
  refresh();
  return success(undefined, `${parsed.data.name} added to ${hall.name}`);
}

/** Rename a location and set (or clear) its zone. */
export async function renameLocation(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid(), name, zone: zone.optional() }).safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const [row] = await db
    .select({ loc: locations, hall: halls })
    .from(locations)
    .innerJoin(halls, eq(locations.hallId, halls.id))
    .where(eq(locations.id, parsed.data.id));
  if (!row) return fail("Location not found");
  const g = await guard(row.hall.editionId);
  if ("error" in g) return fail(g.error);
  const set = {
    name: parsed.data.name,
    ...(parsed.data.zone !== undefined ? { zone: parsed.data.zone } : {}),
  };
  await db.transaction(async (tx) => {
    await tx.update(locations).set(set).where(eq(locations.id, row.loc.id));
    await writeAudit(tx, {
      organisationId: g.session.organisation.id,
      editionId: g.edition.id,
      actorUserId: g.session.user.id,
      entityType: "location",
      entityId: row.loc.id,
      action: "update",
      before: { name: row.loc.name, zone: row.loc.zone },
      after: set,
      summary:
        row.loc.name === parsed.data.name
          ? `Changed location ${row.loc.name} in ${row.hall.name}`
          : `Renamed location ${row.loc.name} → ${parsed.data.name}`,
    });
  });
  refresh();
  return success(undefined, "Location saved");
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
  const used = await itemsUsing(eq(signageItems.locationId, row.loc.id));
  if (used.live > 0) {
    return fail(
      `${signs(used.live)} ${used.live === 1 ? "is" : "are"} at ${row.loc.name} — move them to another location first.`,
    );
  }
  if (used.deleted > 0) {
    return fail(
      `${used.deleted} deleted item${used.deleted === 1 ? " still points" : "s still point"} at ${row.loc.name}, so it can't be removed. ${RESTORE_HINT}`,
    );
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
      before: { name: row.loc.name, zone: row.loc.zone },
      summary: `Removed location ${row.loc.name} from ${row.hall.name}`,
    });
  });
  refresh();
  return success(undefined, `${row.loc.name} removed`);
}
