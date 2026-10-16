/**
 * Sending a sign for sign-off and back again, against a real database
 * (TEST_DATABASE_URL): the shared helpers the item page, the upload ("upload
 * and send") and the bulk actions use. Each change writes its audit row in
 * the same transaction.
 */
import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "@/lib/db/schema";

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let signage: typeof import("@/lib/domain/signage");
let orgId: string;
let editionId: string;
let workflowId: string;
let hallId: string;
let locationId: string;
let typeId: string;
let opsId: string;
let seq = 0;
const n = Date.now() % 1_000_000;

async function item(over: Partial<typeof schema.signageItems.$inferInsert> = {}) {
  seq += 1;
  const [row] = await db
    .insert(schema.signageItems)
    .values({
      editionId,
      ref: `SIG-SUB${n}-${String(seq).padStart(3, "0")}`,
      seq,
      name: `Submit test ${seq}`,
      workflowId,
      hallId,
      locationId,
      itemTypeId: typeId,
      widthMm: 1000,
      heightMm: 500,
      quantity: 1,
      fixingMethod: "wall_mounted",
      createdBy: opsId,
      ...over,
    })
    .returning();
  return row;
}

async function withArtwork(itemId: string) {
  const [v] = await db
    .insert(schema.artworkVersions)
    .values({
      signageItemId: itemId,
      versionNumber: 1,
      filePath: `seed/${itemId}.pdf`,
      fileName: "art.pdf",
      mimeType: "application/pdf",
      fileSize: 10,
      sha256: "0".repeat(64),
      uploadedBy: opsId,
    })
    .returning();
  await db
    .update(schema.signageItems)
    .set({ currentArtworkVersionId: v.id })
    .where(eq(schema.signageItems.id, itemId));
  return v.id;
}

const bundleOf = async (id: string) => (await signage.loadItemBundle(db, id))!;
const instancesOf = (id: string) =>
  db
    .select()
    .from(schema.approvalInstances)
    .where(eq(schema.approvalInstances.entityId, id))
    .orderBy(schema.approvalInstances.runNumber, schema.approvalInstances.sortOrderSnapshot);
const auditOf = (id: string) =>
  db
    .select()
    .from(schema.auditLog)
    .where(and(eq(schema.auditLog.entityId, id), eq(schema.auditLog.action, "submit")));

d("sending signs for sign-off", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    signage = await import("@/lib/domain/signage");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Submit Org", slug: `submit-${n}` })
      .returning();
    orgId = org.id;
    opsId = randomUUID();
    await db.insert(schema.users).values({ id: opsId, email: `ops-${n}@submit.test` });
    await db
      .insert(schema.memberships)
      .values({ userId: opsId, organisationId: orgId, role: "ops" });
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Submit Event", code: `SE${n}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Submit Venue", code: `SV${n}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Submit Event 2027",
        code: `SUB${n}`,
        buildStart: "2027-10-01",
        buildEnd: "2027-10-04",
        openStart: "2027-10-05",
        openEnd: "2027-10-07",
        breakdownEnd: "2027-10-08",
      })
      .returning();
    editionId = edition.id;
    const [hall] = await db.insert(schema.halls).values({ editionId, name: "Hall 1" }).returning();
    hallId = hall.id;
    const [loc] = await db
      .insert(schema.locations)
      .values({ hallId, name: "Entrance" })
      .returning();
    locationId = loc.id;
    const [type] = await db
      .insert(schema.itemTypes)
      .values({ organisationId: orgId, name: "Foamex board", code: `FB${n}`, kind: "signage" })
      .returning();
    typeId = type.id;
    const [wf] = await db
      .insert(schema.workflows)
      .values({ organisationId: orgId, name: "Signage", appliesTo: "signage", isDefault: true })
      .returning();
    workflowId = wf.id;
    const step = (sortOrder: number, name: string, role: "ops" | "marketing" | "supplier") => ({
      workflowId,
      sortOrder,
      parallelGroup: role === "supplier" ? null : 1,
      name,
      kind: role === "supplier" ? ("confirmation" as const) : ("approval" as const),
      approverType: "role" as const,
      approverRole: role,
      conditions: ["always"],
      slaDays: 3,
      invalidateOnNewVersion: true,
      restartFromHereOnChanges: true,
    });
    await db
      .insert(schema.workflowSteps)
      .values([
        step(1, "Operations sign-off", "ops"),
        step(2, "Marketing sign-off", "marketing"),
        step(3, "Sent to print", "supplier"),
      ]);
  });

  afterAll(async () => {
    await client?.end();
  });

  it("a complete sign with artwork goes straight into sign-off, audited", async () => {
    const row = await item();
    await withArtwork(row.id);
    const res = await db.transaction(async (tx) =>
      signage.submitItemInTx(tx, await bundleOf(row.id), { actorUserId: opsId, now: new Date() }),
    );
    expect(res.next).toBe("in_review");
    expect(res.pending.map((p) => p.stepName)).toEqual([
      "Operations sign-off",
      "Marketing sign-off",
    ]);
    expect(signage.askedSummary(res.pending)).toBe("Operations sign-off and Marketing sign-off");
    const after = await bundleOf(row.id);
    expect(after.item.status).toBe("in_review");
    expect(after.item.currentRunNumber).toBe(1);
    expect((await instancesOf(row.id)).filter((i) => i.status === "pending")).toHaveLength(2);
    const audit = await auditOf(row.id);
    expect(audit.map((a) => a.summary)).toEqual([`${row.ref} sent for sign-off`]);
  });

  it("without artwork it waits for it, and nothing starts yet", async () => {
    const row = await item();
    const res = await db.transaction(async (tx) =>
      signage.submitItemInTx(tx, await bundleOf(row.id), { actorUserId: opsId, now: new Date() }),
    );
    expect(res.next).toBe("awaiting_artwork");
    expect(res.pending).toEqual([]);
    expect(await instancesOf(row.id)).toHaveLength(0);
  });

  it("refuses a sign that is missing what sign-off needs, and changes nothing", async () => {
    const row = await item({ widthMm: null, fixingMethod: null });
    await expect(
      db.transaction(async (tx) =>
        signage.submitItemInTx(tx, await bundleOf(row.id), { actorUserId: opsId, now: new Date() }),
      ),
    ).rejects.toThrow("missing: width, fixing method");
    expect((await bundleOf(row.id)).item.status).toBe("draft");
    expect(await auditOf(row.id)).toHaveLength(0);
  });

  it("only a draft can be sent", async () => {
    const row = await item({ status: "in_review" });
    await expect(
      db.transaction(async (tx) =>
        signage.submitItemInTx(tx, await bundleOf(row.id), { actorUserId: opsId, now: new Date() }),
      ),
    ).rejects.toThrow("already been sent");
  });

  it("after changes are asked for, it goes back to the step that asked", async () => {
    const row = await item();
    await withArtwork(row.id);
    await db.transaction(async (tx) =>
      signage.submitItemInTx(tx, await bundleOf(row.id), { actorUserId: opsId, now: new Date() }),
    );
    // Operations approve; Marketing asks for changes.
    const [ops, mkt] = await instancesOf(row.id);
    await db
      .update(schema.approvalInstances)
      .set({ status: "approved", decidedAt: new Date() })
      .where(eq(schema.approvalInstances.id, ops.id));
    await db
      .update(schema.approvalInstances)
      .set({ status: "changes_requested", decidedAt: new Date(), decisionComment: "Bigger logo" })
      .where(eq(schema.approvalInstances.id, mkt.id));
    await db
      .update(schema.signageItems)
      .set({ status: "changes_requested" })
      .where(eq(schema.signageItems.id, row.id));

    const res = await db.transaction(async (tx) =>
      signage.resubmitItemInTx(tx, await bundleOf(row.id), { actorUserId: opsId, now: new Date() }),
    );
    expect(res.next).toBe("in_review");
    expect(res.pending.map((p) => p.stepName)).toEqual(["Marketing sign-off"]);
    const after = await instancesOf(row.id);
    expect(after.find((i) => i.id === ops.id)?.status).toBe("approved");
    expect(after.find((i) => i.id === mkt.id)?.status).toBe("pending");
    expect((await bundleOf(row.id)).item.status).toBe("in_review");
    expect((await auditOf(row.id)).map((a) => a.summary)).toContain(`${row.ref} resubmitted`);

    // Sending back again is refused: it is no longer waiting on changes.
    await expect(
      db.transaction(async (tx) =>
        signage.resubmitItemInTx(tx, await bundleOf(row.id), {
          actorUserId: opsId,
          now: new Date(),
        }),
      ),
    ).rejects.toThrow("Only items with changes requested");
  });
});
