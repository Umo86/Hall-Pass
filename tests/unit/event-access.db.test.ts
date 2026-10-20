/**
 * Events per person (Users → Events) against a real database
 * (TEST_DATABASE_URL), with the session stubbed for the actions. Each test
 * builds its own organisation with two events, A and B, so counts are its
 * own: people limited to A never see, are told about or are handed anything
 * in B; people without a list (and super admins) behave exactly as before.
 */
import { randomUUID } from "node:crypto";
import { and, eq, gte, inArray, isNull } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";
import type { Session } from "@/lib/auth/actor";
import type { Actor, StaffRole } from "@/lib/authz";
import { startingChoices } from "@/lib/users/rules";

const state = vi.hoisted(() => ({
  session: null as unknown,
  sent: [] as Array<{ to: string; subject: string }>,
}));
vi.mock("@/lib/email/send", () => ({
  sendEmail: async (m: { to: string; subject: string }) => {
    state.sent.push({ to: m.to, subject: m.subject });
    return true;
  },
}));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn(), revalidateTag: vi.fn() }));
vi.mock("next/headers", () => ({
  cookies: async () => ({ get: () => undefined, set: () => {}, delete: () => {} }),
  headers: async () => new Headers(),
}));
vi.mock("@/lib/auth/actor", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/auth/actor")>();
  return {
    ...actual,
    requireSession: async () => state.session,
    requireStaffSession: async () => state.session,
  };
});

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let manage: typeof import("@/lib/users/manage");
let claim: typeof import("@/lib/auth/claim-staff-invite");
let departments: typeof import("@/lib/domain/departments");
let actorMod: typeof import("@/lib/auth/actor");
const n = Date.now() % 1_000_000;
let worldSeq = 0;
let refSeq = 0;
const editionsMade: string[] = [];

type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];
const run = <T>(fn: (tx: Tx) => Promise<T>) => db.transaction(fn);
const mail = (k: string) => `${k.toLowerCase().replace(/\s+/g, ".")}-${n}@event-access.test`;

type World = {
  tag: string;
  orgId: string;
  adminId: string;
  venueId: string;
  workflowId: string;
  A: string;
  B: string;
  codeA: string;
  codeB: string;
};

/** A fresh organisation with a super admin, a venue and two events, A and B. */
async function makeWorld(): Promise<World> {
  worldSeq++;
  const tag = `EA${worldSeq}X${n}`;
  const [org] = await db
    .insert(schema.organisations)
    .values({ name: `Event Access ${tag}`, slug: `ea-${worldSeq}-${n}` })
    .returning();
  const [wf] = await db
    .insert(schema.workflows)
    .values({ organisationId: org.id, name: "Signage", appliesTo: "signage", isDefault: true })
    .returning();
  const adminId = randomUUID();
  await db
    .insert(schema.users)
    .values({ id: adminId, email: mail(`alex-${tag}`), fullName: "Alex" });
  await db
    .insert(schema.memberships)
    .values({ userId: adminId, organisationId: org.id, role: "admin" });
  const [venue] = await db
    .insert(schema.venues)
    .values({ organisationId: org.id, name: `Hall ${tag}`, code: `V${tag}` })
    .returning();
  const [series] = await db
    .insert(schema.events)
    .values({ organisationId: org.id, name: `Show ${tag}`, code: `S${tag}` })
    .returning();
  const mk = async (letter: "A" | "B", month: string) => {
    const [ed] = await db
      .insert(schema.editions)
      .values({
        eventId: series.id,
        venueId: venue.id,
        name: `Show ${letter} ${tag}`,
        code: `${letter}${tag}`,
        buildStart: `2027-${month}-01`,
        buildEnd: `2027-${month}-02`,
        openStart: `2027-${month}-03`,
        openEnd: `2027-${month}-04`,
        breakdownEnd: `2027-${month}-05`,
        status: "planning",
      })
      .returning();
    editionsMade.push(ed.id);
    return ed;
  };
  const a = await mk("A", "03");
  const b = await mk("B", "09");
  return {
    tag,
    orgId: org.id,
    adminId,
    venueId: venue.id,
    workflowId: wf.id,
    A: a.id,
    B: b.id,
    codeA: a.code,
    codeB: b.code,
  };
}

async function member(
  w: World,
  name: string,
  role: StaffRole,
  extra: Partial<typeof schema.memberships.$inferInsert> = {},
) {
  const id = randomUUID();
  await db.insert(schema.users).values({ id, email: mail(`${name}-${w.tag}`), fullName: name });
  await db
    .insert(schema.memberships)
    .values({ userId: id, organisationId: w.orgId, role, ...extra });
  return id;
}

/** A department that signs off; `defaultFor` decides whether new rounds include it. */
async function dept(w: World, name: string, defaultFor: ("organiser" | "sponsor")[] = []) {
  const [row] = await db
    .insert(schema.departments)
    .values({ organisationId: w.orgId, name: `${name} ${w.tag}`, sortOrder: 1, defaultFor })
    .returning();
  await run((tx) => departments.syncDepartmentSteps(tx, w.orgId));
  return row;
}

async function approve(
  w: World,
  userId: string,
  name: string,
  departmentId: string,
  isMain = false,
) {
  await db.insert(schema.approvers).values({
    organisationId: w.orgId,
    departmentId,
    fullName: name,
    email: mail(`${name}-${w.tag}`),
    userId,
    isMain,
  });
  await run((tx) => departments.syncDepartmentSteps(tx, w.orgId));
}

async function stepOf(w: World, departmentId: string) {
  const [step] = await db
    .select()
    .from(schema.workflowSteps)
    .where(
      and(
        eq(schema.workflowSteps.workflowId, w.workflowId),
        eq(schema.workflowSteps.departmentId, departmentId),
      ),
    );
  return step;
}

async function item(
  w: World,
  editionId: string,
  over: Partial<typeof schema.signageItems.$inferInsert> = {},
) {
  refSeq++;
  const [row] = await db
    .insert(schema.signageItems)
    .values({
      editionId,
      ref: `SIG-${w.tag}-${String(refSeq).padStart(3, "0")}`,
      seq: refSeq,
      name: `Sign ${refSeq}`,
      category: "organiser",
      createdBy: w.adminId,
      ownerUserId: w.adminId,
      workflowId: w.workflowId,
      ...over,
    })
    .returning();
  return row;
}

/** A sign in sign-off, its department step waiting on `who` (or the department). */
async function inSignoff(
  w: World,
  editionId: string,
  departmentId: string,
  who: string | null,
  opts: {
    planned?: boolean;
    dueAt?: Date;
    over?: Partial<typeof schema.signageItems.$inferInsert>;
  } = {},
) {
  const step = await stepOf(w, departmentId);
  const it = await item(w, editionId, {
    status: "in_review",
    currentRunNumber: 1,
    signoffs: (opts.planned && who ? [{ stepId: step.id, userId: who }] : null) as never,
    ...opts.over,
  });
  const [inst] = await db
    .insert(schema.approvalInstances)
    .values({
      entityType: "signage_item",
      entityId: it.id,
      runNumber: 1,
      workflowStepId: step.id,
      stepNameSnapshot: step.name,
      stepKindSnapshot: "approval",
      sortOrderSnapshot: 1,
      status: "pending",
      assignedDepartmentId: departmentId,
      assignedUserId: who,
      pendingSince: new Date(),
      dueAt: opts.dueAt ?? null,
    })
    .returning();
  return { item: it, inst };
}

const instance = async (id: string) =>
  (await db.select().from(schema.approvalInstances).where(eq(schema.approvalInstances.id, id)))[0];
const membershipOf = async (userId: string) =>
  (await db.select().from(schema.memberships).where(eq(schema.memberships.userId, userId)))[0];
const itemRow = async (id: string) =>
  (await db.select().from(schema.signageItems).where(eq(schema.signageItems.id, id)))[0];
const ctxOf = (w: World, userId = w.adminId, actorName = "Alex") => ({
  organisationId: w.orgId,
  actorUserId: userId,
  actorName,
});
const notesFor = (userId: string, kind?: string) =>
  db
    .select()
    .from(schema.notifications)
    .where(
      and(
        eq(schema.notifications.userId, userId),
        kind ? eq(schema.notifications.kind, kind) : undefined,
      ),
    );

async function sessionOf(userId: string): Promise<Session> {
  const s = await actorMod.sessionForUserId(userId);
  if (!s) throw new Error(`no session for ${userId}`);
  return s;
}

/** The same person as if they had no list (to compare a scoped answer with today's). */
function unlimited(s: Session): Session {
  return { ...s, actor: { ...s.actor, editionIds: null } as Actor };
}

const base = {
  jobTitle: null,
  newDepartmentName: null,
  features: null,
  abilities: {},
  departmentId: null as string | null,
  signoffs: [] as { departmentId: string; isMain: boolean }[],
};

/** Change someone's events and nothing else (as the person page's Save). */
function setEvents(
  w: World,
  userId: string,
  fullName: string,
  role: StaffRole,
  editionIds: string[] | null,
  extra: Partial<Parameters<typeof manage.updateMemberTx>[2]> = {},
  ctx = ctxOf(w),
) {
  return run((tx) =>
    manage.updateMemberTx(tx, ctx, {
      ...base,
      userId,
      fullName,
      role,
      signoffPaused: false,
      editionIds,
      ...extra,
    }),
  );
}

d("events per person", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    manage = await import("@/lib/users/manage");
    claim = await import("@/lib/auth/claim-staff-invite");
    departments = await import("@/lib/domain/departments");
    actorMod = await import("@/lib/auth/actor");
  });

  afterAll(async () => {
    for (const id of editionsMade) {
      await db
        .update(schema.signageItems)
        .set({ deletedAt: new Date() })
        .where(eq(schema.signageItems.editionId, id));
    }
    await client?.end();
  });

  it("claimStaffInvite copies edition_ids onto the membership (never for super admins)", async () => {
    const w = await makeWorld();
    const out = await run((tx) =>
      manage.inviteUserTx(tx, ctxOf(w), {
        ...base,
        email: mail(`cleo-${w.tag}`),
        fullName: "Cleo",
        role: "ops",
        editionIds: [w.A],
      }),
    );
    const [inv] = await db
      .select()
      .from(schema.staffInvites)
      .where(eq(schema.staffInvites.id, out.inviteId));
    expect(inv.editionIds).toEqual([w.A]);
    const uid = randomUUID();
    await db.insert(schema.users).values({ id: uid, email: inv.invitedEmail });
    await claim.claimStaffInvite(inv, uid, "Cleo");
    expect((await membershipOf(uid)).editionIds).toEqual([w.A]);

    const boss = await run((tx) =>
      manage.inviteUserTx(tx, ctxOf(w), {
        ...base,
        email: mail(`bo-${w.tag}`),
        fullName: "Bo",
        role: "admin",
        editionIds: [w.A],
      }),
    );
    const [bossInv] = await db
      .select()
      .from(schema.staffInvites)
      .where(eq(schema.staffInvites.id, boss.inviteId));
    expect(bossInv.editionIds).toBeNull();
  });

  it("claimStaffInvite gives what the invitation says when it is claimed, not when the caller read it", async () => {
    const w = await makeWorld();
    const out = await run((tx) =>
      manage.inviteUserTx(tx, ctxOf(w), {
        ...base,
        email: mail(`edie-${w.tag}`),
        fullName: "Edie",
        role: "ops",
        editionIds: null,
      }),
    );
    // The accept page reads the invitation by its link first (then creates
    // the account) …
    const { findValidStaffInvite } = await import("@/lib/users/invite-lookup");
    const found = await findValidStaffInvite(out.inviteUrl.split("/invite/")[1]);
    expect(found.invite?.editionIds).toBeNull();
    // … while a manager narrows it to A, makes it a viewer and sets an end date.
    await run((tx) =>
      manage.updateInviteTx(tx, ctxOf(w), {
        ...base,
        inviteId: out.inviteId,
        fullName: "Edie",
        role: "viewer",
        editionIds: [w.A],
        accessEndsOn: "2099-12-31",
      }),
    );
    const uid = randomUUID();
    await db.insert(schema.users).values({ id: uid, email: found.invite!.invitedEmail });
    await claim.claimStaffInvite(found.invite!, uid);
    const m = await membershipOf(uid);
    expect(m.role).toBe("viewer");
    expect(m.editionIds).toEqual([w.A]);
    expect(m.accessEndsAt).not.toBeNull();
    const accepted = await db
      .select()
      .from(schema.auditLog)
      .where(
        and(
          eq(schema.auditLog.entityId, out.inviteId),
          eq(schema.auditLog.summary, "Staff invitation accepted (viewer)"),
        ),
      );
    expect(accepted).toHaveLength(1);
  });

  it("inviteUserTx / updateInviteTx store events; a limited manager can't give B or All", async () => {
    const w = await makeWorld();
    const mona = await member(w, "Mona", "ops", { managerScope: "everyone", editionIds: [w.A] });
    const ctx = ctxOf(w, mona, "Mona");
    // What the Add form starts a manager from (no super-admin-only abilities).
    const abilities = startingChoices("ops", {}, { superAdmin: false });
    const invite = (editionIds: string[] | null, who = "Ned") =>
      run((tx) =>
        manage.inviteUserTx(tx, ctx, {
          ...base,
          abilities,
          email: mail(`${who}-${w.tag}`),
          fullName: who,
          role: "ops",
          editionIds,
        }),
      );
    await expect(invite([w.B])).rejects.toThrow(
      "You can only give the events you can open yourself",
    );
    await expect(invite(null)).rejects.toThrow(
      "You can only give the events you can open yourself — tick them one by one",
    );
    await expect(invite([])).rejects.toThrow("Tick at least one event, or choose All events");
    const ok = await invite([w.A]);
    const read = async () =>
      (
        await db.select().from(schema.staffInvites).where(eq(schema.staffInvites.id, ok.inviteId))
      )[0].editionIds;
    expect(await read()).toEqual([w.A]);
    const update = (editionIds: string[] | null, c = ctx) =>
      run((tx) =>
        manage.updateInviteTx(tx, c, {
          ...base,
          abilities,
          inviteId: ok.inviteId,
          fullName: "Ned",
          role: "ops",
          editionIds,
        }),
      );
    await expect(update([w.A, w.B])).rejects.toThrow(
      "You can only give the events you can open yourself",
    );
    await update([w.B], ctxOf(w));
    expect(await read()).toEqual([w.B]);
    await update(null, ctxOf(w));
    expect(await read()).toBeNull();
  });

  it("updateMemberTx keeps events the manager can't see and refuses taking them away", async () => {
    const w = await makeWorld();
    const mona = await member(w, "Mona", "ops", { managerScope: "everyone", editionIds: [w.A] });
    const pat = await member(w, "Pat", "ops", { editionIds: [w.A, w.B] });
    const quin = await member(w, "Quin", "ops");
    const asMona = ctxOf(w, mona, "Mona");
    // Mona's form lists only A: B stays.
    await setEvents(w, pat, "Pat", "ops", [w.A], {}, asMona);
    expect((await membershipOf(pat)).editionIds?.sort()).toEqual([w.A, w.B].sort());
    await expect(setEvents(w, quin, "Quin", "ops", [w.A], {}, asMona)).rejects.toThrow(
      "You can only take away events you can open yourself — ask a super admin",
    );
    expect((await membershipOf(quin)).editionIds).toBeNull();
    await expect(setEvents(w, mona, "Mona", "ops", [w.A, w.B], {}, asMona)).rejects.toThrow(
      /can't change your own events|only give the events you can open/,
    );
    // A super admin may; the audit row says events changed.
    await setEvents(w, quin, "Quin", "ops", [w.B]);
    expect((await membershipOf(quin)).editionIds).toEqual([w.B]);
    const audit = await db
      .select()
      .from(schema.auditLog)
      .where(
        and(eq(schema.auditLog.organisationId, w.orgId), eq(schema.auditLog.subjectUserId, quin)),
      );
    expect(audit.some((a) => /events/i.test(a.summary ?? ""))).toBe(true);
  });

  it("narrowing hands named sign-offs in B back to the department, with one audit row per item and the plan cleared only for B", async () => {
    const w = await makeWorld();
    const mkt = await dept(w, "Marketing");
    const pip = await member(w, "Pip", "marketing", {
      departmentId: mkt.id,
      editionIds: [w.A, w.B],
    });
    const quee = await member(w, "Quee", "marketing", { departmentId: mkt.id });
    await approve(w, pip, "Pip", mkt.id);
    await approve(w, quee, "Quee", mkt.id);
    const inA = await inSignoff(w, w.A, mkt.id, pip, { planned: true });
    const inB = await inSignoff(w, w.B, mkt.id, pip, { planned: true });
    const since = new Date();
    const out = await setEvents(w, pip, "Pip", "marketing", [w.A], {
      departmentId: mkt.id,
      signoffs: [{ departmentId: mkt.id, isMain: false }],
    });
    expect((await membershipOf(pip)).editionIds).toEqual([w.A]);
    expect(await instance(inA.inst.id)).toMatchObject({ assignedUserId: pip });
    expect(await instance(inB.inst.id)).toMatchObject({
      assignedUserId: null,
      assignedDepartmentId: mkt.id,
    });
    expect(out.eventSignoffsMoved).toBe(1);
    const planOf = async (id: string) =>
      ((await itemRow(id)).signoffs as { userId?: string | null }[] | null) ?? [];
    expect((await planOf(inA.item.id)).some((s) => s.userId === pip)).toBe(true);
    expect((await planOf(inB.item.id)).some((s) => s.userId === pip)).toBe(false);
    const rows = await db
      .select()
      .from(schema.auditLog)
      .where(and(eq(schema.auditLog.entityId, inB.item.id), gte(schema.auditLog.createdAt, since)));
    // One row for each change to the item: its plan, and who its sign-off is with.
    expect(rows.map((r) => r.summary)).toEqual([
      `${inB.item.ref}: the sign-off plan no longer names Pip, who no longer works on ${w.codeB} — that step goes to the department`,
      `${inB.item.ref}: ${mkt.name} sign-off handed to everyone who signs off for ${mkt.name} after Pip no longer works on ${w.codeB}`,
    ]);
    const aRows = await db
      .select()
      .from(schema.auditLog)
      .where(and(eq(schema.auditLog.entityId, inA.item.id), gte(schema.auditLog.createdAt, since)));
    expect(aRows).toEqual([]);
    // Quee (who can open B) is told it's back with the department, about B.
    const told = await notesFor(quee, "delegation");
    expect(told.map((r) => [r.title, r.editionId])).toEqual([
      [`A ${mkt.name} sign-off is back with your department: ${inB.item.ref}`, w.B],
    ]);
  });

  it("narrowing refuses without a pick when nobody else in the department can open B, then hands it to the person picked", async () => {
    const w = await makeWorld();
    const ops = await dept(w, "Ops");
    const ria = await member(w, "Ria", "marketing", {
      departmentId: ops.id,
      editionIds: [w.A, w.B],
    });
    const rex = await member(w, "Rex", "marketing", { departmentId: ops.id, editionIds: [w.A] });
    const fay = await member(w, "Fay", "ops");
    await approve(w, ria, "Ria", ops.id);
    await approve(w, rex, "Rex", ops.id);
    const inB = await inSignoff(w, w.B, ops.id, ria, { planned: true });
    const change = (eventHandover?: Record<string, string>) =>
      setEvents(w, ria, "Ria", "marketing", [w.A], {
        departmentId: ops.id,
        signoffs: [{ departmentId: ops.id, isMain: false }],
        eventHandover,
      });
    await expect(change()).rejects.toThrow(
      `Nobody else in ${ops.name} can open ${w.codeB} — choose who takes Ria's ${ops.name} sign-offs there`,
    );
    expect((await membershipOf(ria)).editionIds?.sort()).toEqual([w.A, w.B].sort());
    await expect(change({ [ops.id]: rex })).rejects.toThrow();
    await change({ [ops.id]: fay });
    expect(await instance(inB.inst.id)).toMatchObject({ assignedUserId: fay });
    expect((await membershipOf(ria)).editionIds).toEqual([w.A]);
  });

  it("tasks and items in B stay with the person and leave their My Work and reminders", async () => {
    const w = await makeWorld();
    const { boardTasks, dueTaskCounts } = await import("@/lib/queries/tasks");
    const tia = await member(w, "Tia", "ops", { editionIds: [w.A, w.B] });
    const owned = await item(w, w.B, { ownerUserId: tia });
    const { todayInLondon } = await import("@/lib/today");
    const { addDaysIso } = await import("@/lib/deadlines");
    const today = todayInLondon();
    const yesterday = addDaysIso(today, -1);
    const task = async (editionId: string | null, title: string) =>
      (
        await db
          .insert(schema.tasks)
          .values({
            organisationId: w.orgId,
            editionId,
            title,
            dueDate: yesterday,
            assignedToUserId: tia,
            createdByUserId: w.adminId,
          })
          .returning()
      )[0];
    const tA = await task(w.A, "In A");
    const tB = await task(w.B, "In B");
    const tNone = await task(null, "No event");
    const overdue = async () =>
      (await dueTaskCounts({ organisationId: w.orgId, userId: tia, today }))[0]?.overdue ?? 0;
    expect(await overdue()).toBe(3);
    await setEvents(w, tia, "Tia", "ops", [w.A]);
    expect((await itemRow(owned.id)).ownerUserId).toBe(tia);
    const [stillB] = await db.select().from(schema.tasks).where(eq(schema.tasks.id, tB.id));
    expect(stillB.assignedToUserId).toBe(tia);
    expect(await overdue()).toBe(2);
    const board = await boardTasks({
      organisationId: w.orgId,
      userId: tia,
      isAdmin: false,
      scope: "mine",
      editionScope: [w.A],
    });
    expect(board.map((t) => t.id).sort()).toEqual([tA.id, tNone.id].sort());
  });

  it("createEdition by a limited creator adds the event to their list, audited", async () => {
    const w = await makeWorld();
    const { createEdition } = await import("@/app/actions/editions");
    const lou = await member(w, "Lou", "ops", {
      editionIds: [w.A],
      permissionOverrides: { "events.create": true },
    });
    state.session = await sessionOf(lou);
    const code = `N${w.tag}`;
    const res = await createEdition({
      name: `New ${w.tag} 2028`,
      code,
      openStart: "2028-03-01",
      openEnd: "2028-03-02",
      venueId: w.venueId,
    });
    if (!res.ok) throw new Error(res.error);
    expect(res.message).toMatch(/created — it's been added to your events$/);
    const [ed] = await db.select().from(schema.editions).where(eq(schema.editions.code, code));
    editionsMade.push(ed.id);
    expect((await membershipOf(lou)).editionIds).toEqual([w.A, ed.id]);
    const audit = await db
      .select()
      .from(schema.auditLog)
      .where(and(eq(schema.auditLog.subjectUserId, lou), eq(schema.auditLog.editionId, ed.id)));
    expect(audit.map((a) => a.summary)).toEqual([
      `${mail(`Lou-${w.tag}`)}: events changed — added the event they created`,
    ]);
    // Someone without a list sees it anyway: nothing changes for them.
    state.session = await sessionOf(w.adminId);
    const other = await createEdition({
      name: `Other ${w.tag} 2028`,
      code: `O${w.tag}`,
      openStart: "2028-04-01",
      openEnd: "2028-04-02",
      venueId: w.venueId,
    });
    expect(other.ok && other.message).toBe(`Other ${w.tag} 2028 created`);
    const [ed2] = await db
      .select()
      .from(schema.editions)
      .where(eq(schema.editions.code, `O${w.tag}`));
    editionsMade.push(ed2.id);
  });

  it("createEdition and cloneEdition wait for the people lock before changing anyone's events", async () => {
    const w = await makeWorld();
    const { createEdition, cloneEdition } = await import("@/app/actions/editions");
    const lou = await member(w, "Lou", "ops", {
      editionIds: [w.A],
      permissionOverrides: { "events.create": true },
    });
    state.session = await sessionOf(lou);
    // Another transaction holds the people lock (as a person-page save does).
    const holder = postgres(url!, { max: 1, prepare: false, onnotice: () => {} });
    const whileLocked = async (start: () => Promise<{ ok: boolean }>) => {
      let finished = false;
      let pending!: Promise<{ ok: boolean }>;
      await holder.begin(async (sql) => {
        await sql`SELECT pg_advisory_xact_lock(hashtext(${`people:${w.orgId}`}))`;
        pending = start().then((r) => {
          finished = true;
          return r;
        });
        await new Promise((r) => setTimeout(r, 600));
        expect(finished).toBe(false);
      });
      return pending;
    };
    try {
      const made = await whileLocked(() =>
        createEdition({
          name: `Locked ${w.tag} 2028`,
          code: `L${w.tag}`,
          openStart: "2028-03-01",
          openEnd: "2028-03-02",
          venueId: w.venueId,
        }),
      );
      expect(made.ok).toBe(true);
      const copied = await whileLocked(() =>
        cloneEdition({
          sourceEditionId: w.A,
          name: `Locked copy ${w.tag}`,
          code: `K${w.tag}`,
          openStart: "2028-06-02",
          openEnd: "2028-06-04",
        }),
      );
      expect(copied.ok).toBe(true);
    } finally {
      await holder.end();
      const made = await db
        .select({ id: schema.editions.id })
        .from(schema.editions)
        .where(inArray(schema.editions.code, [`L${w.tag}`, `K${w.tag}`]));
      editionsMade.push(...made.map((e) => e.id));
    }
    expect((await membershipOf(lou)).editionIds).toHaveLength(3);
  });

  it("cloneEdition gives the copy to people limited to the source within the copier's scope, invitations included, and counts the rest", async () => {
    const w = await makeWorld();
    const { cloneEdition } = await import("@/app/actions/editions");
    const { copySourceCounts } = await import("@/lib/queries/setup");
    const d1 = await dept(w, "Team One");
    const d2 = await dept(w, "Team Two");
    const max = await member(w, "Max", "ops", {
      managerScope: "department",
      departmentId: d1.id,
      editionIds: [w.A],
      permissionOverrides: { "events.create": true },
    });
    const ina = await member(w, "Ina", "ops", { departmentId: d1.id, editionIds: [w.A] });
    const oto = await member(w, "Oto", "ops", { departmentId: d2.id, editionIds: [w.A] });
    const ally = await member(w, "Ally", "ops", { departmentId: d1.id });
    const inv = await run((tx) =>
      manage.inviteUserTx(tx, ctxOf(w), {
        ...base,
        email: mail(`ivy-${w.tag}`),
        fullName: "Ivy",
        role: "ops",
        departmentId: d1.id,
        editionIds: [w.A],
      }),
    );
    state.session = await sessionOf(max);
    const counts = (await copySourceCounts(w.orgId, (state.session as Session).actor))(w.A);
    expect({ people: counts.people, peopleLeftOut: counts.peopleLeftOut }).toEqual({
      people: 2,
      peopleLeftOut: 1,
    });
    const code = `C${w.tag}`;
    const res = await cloneEdition({
      sourceEditionId: w.A,
      name: `Copy ${w.tag}`,
      code,
      openStart: "2028-06-02",
      openEnd: "2028-06-04",
      include: {
        halls: false,
        deadlines: false,
        sponsors: false,
        items: false,
        access: false,
        people: true,
      },
    });
    if (!res.ok) throw new Error(res.error);
    const [copy] = await db.select().from(schema.editions).where(eq(schema.editions.code, code));
    editionsMade.push(copy.id);
    expect(res.message).toContain(`2 people who only saw ${w.codeA} can open ${code} too`);
    expect(res.message).toContain(`1 more who only see ${w.codeA}`);
    expect((await membershipOf(max)).editionIds).toEqual([w.A, copy.id]);
    expect((await membershipOf(ina)).editionIds).toEqual([w.A, copy.id]);
    expect((await membershipOf(oto)).editionIds).toEqual([w.A]);
    expect((await membershipOf(ally)).editionIds).toBeNull();
    const [invRow] = await db
      .select()
      .from(schema.staffInvites)
      .where(eq(schema.staffInvites.id, inv.inviteId));
    expect(invRow.editionIds).toEqual([w.A, copy.id]);
    // A source the copier can't open is "not found".
    const refused = await cloneEdition({
      sourceEditionId: w.B,
      name: `Copy B ${w.tag}`,
      code: `D${w.tag}`,
      openStart: "2028-07-02",
      openEnd: "2028-07-04",
    });
    expect(refused).toMatchObject({ ok: false, error: "Event not found" });
  });

  it("a limited main approver: new rounds in B go to the department; nobody can → the department and super admins are told; nobody at all → nothing new", async () => {
    const w = await makeWorld();
    const signage = await import("@/lib/domain/signage");
    const mkt = await dept(w, "Marketing", ["organiser"]);
    const solo = await dept(w, "Solo", ["organiser"]);
    const empty = await dept(w, "Empty", ["organiser"]);
    const mia = await member(w, "Mia", "marketing", { departmentId: mkt.id, editionIds: [w.A] });
    const moe = await member(w, "Moe", "marketing", { departmentId: mkt.id });
    const sal = await member(w, "Sal", "marketing", { departmentId: solo.id, editionIds: [w.A] });
    await approve(w, mia, "Mia", mkt.id, true);
    await approve(w, moe, "Moe", mkt.id);
    await approve(w, sal, "Sal", solo.id, true);
    const start = async (editionId: string) => {
      const it = await item(w, editionId, { status: "in_review" });
      const bundle = (await signage.loadItemBundle(db, it.id))!;
      const insts = await run(async (tx) => {
        const made = await signage.startItemRun(tx, bundle, new Date());
        await signage.notifyPendingAssignees(tx, bundle, made);
        return made;
      });
      const of = (deptId: string) => insts.find((i) => i.assignedDepartmentId === deptId)!;
      return { it, of };
    };
    const a = await start(w.A);
    expect(a.of(mkt.id).assignedUserId).toBe(mia);
    expect(a.of(solo.id).assignedUserId).toBe(sal);
    const b = await start(w.B);
    expect(b.of(mkt.id).assignedUserId).toBeNull();
    expect(b.of(solo.id).assignedUserId).toBeNull();
    expect(b.of(empty.id).assignedUserId).toBeNull();
    // Moe (who can open B) is asked for Marketing; Mia and Sal hear nothing about B.
    expect((await notesFor(moe, "approval_requested")).some((r) => r.entityId === b.it.id)).toBe(
      true,
    );
    expect((await notesFor(mia)).some((r) => r.entityId === b.it.id)).toBe(false);
    expect((await notesFor(sal)).some((r) => r.entityId === b.it.id)).toBe(false);
    const stuck = (await notesFor(w.adminId, "signoff_stuck")).filter(
      (r) => r.entityId === b.it.id,
    );
    expect(stuck.map((r) => r.title)).toEqual([
      `Nobody who signs off for ${solo.name} can open ${w.codeB} — ${b.it.name} (${b.it.ref})`,
    ]);
    expect(stuck[0].editionId).toBe(w.B);
    expect((await notesFor(w.adminId, "signoff_stuck")).some((r) => r.entityId === a.it.id)).toBe(
      false,
    );
  });

  it("delegateApproval refuses someone who can't open the event", async () => {
    const w = await makeWorld();
    const { delegateApproval } = await import("@/app/actions/approvals");
    const mkt = await dept(w, "Marketing");
    const lim = await member(w, "Lim", "marketing", { departmentId: mkt.id, editionIds: [w.A] });
    const free = await member(w, "Fred", "marketing", { departmentId: mkt.id });
    await approve(w, free, "Fred", mkt.id);
    const inB = await inSignoff(w, w.B, mkt.id, free, { planned: true });
    state.session = await sessionOf(w.adminId);
    const res = await delegateApproval({ instanceId: inB.inst.id, toUserId: lim });
    expect(res).toMatchObject({
      ok: false,
      error: "Lim can't open this event — pick someone who can",
    });
    expect((await instance(inB.inst.id)).assignedUserId).toBe(free);
  });

  it("notify drops people who can't open the event, derives it from the link, and stores edition_id; dispatch doesn't email a notification about an event since taken away", async () => {
    const w = await makeWorld();
    const { notify } = await import("@/lib/notify");
    const lim = await member(w, "Lim", "ops", { editionIds: [w.A] });
    const free = await member(w, "Fred", "ops");
    const it = await item(w, w.B);
    await run((tx) =>
      notify(tx, {
        userIds: [lim, free],
        kind: "comment",
        title: "About B by link",
        link: `/${w.codeB}/signage/${it.ref}`,
      }),
    );
    await run((tx) =>
      notify(tx, {
        userIds: [lim, free],
        kind: "comment",
        title: "About B by record",
        entityType: "signage_item",
        entityId: it.id,
      }),
    );
    await run((tx) =>
      notify(tx, {
        userIds: [lim, free],
        kind: "comment",
        title: "About nothing",
        link: "/approvals",
      }),
    );
    const limRows = await notesFor(lim);
    const freeRows = await notesFor(free);
    expect(limRows.map((r) => r.title)).toEqual(["About nothing"]);
    expect(limRows[0].editionId).toBeNull();
    expect(freeRows.map((r) => [r.title, r.editionId]).sort()).toEqual(
      [
        ["About B by link", w.B],
        ["About B by record", w.B],
        ["About nothing", null],
      ].sort(),
    );

    // Told while they had B; B taken away before the email went.
    const [old, kept] = await db
      .insert(schema.notifications)
      .values([
        { userId: lim, kind: "comment", title: "Old B news", editionId: w.B },
        { userId: lim, kind: "comment", title: "A news", editionId: w.A },
      ])
      .returning();
    const key = process.env.RESEND_API_KEY;
    const from = process.env.EMAIL_FROM;
    process.env.RESEND_API_KEY = "re_test";
    process.env.EMAIL_FROM = "Test <noreply@example.test>";
    try {
      const { dispatchNotificationEmails } = await import("@/lib/email/dispatch");
      state.sent.length = 0;
      await dispatchNotificationEmails({ ids: [old.id, kept.id] });
      const toLim = state.sent.filter((m) => m.to === mail(`Lim-${w.tag}`));
      expect(toLim.some((m) => m.subject.includes("Old B news"))).toBe(false);
      expect(toLim.some((m) => m.subject.includes("A news"))).toBe(true);
      const [after] = await db
        .select()
        .from(schema.notifications)
        .where(eq(schema.notifications.id, old.id));
      expect(after.emailedAt).not.toBeNull(); // settled, never retried
    } finally {
      if (key === undefined) delete process.env.RESEND_API_KEY;
      else process.env.RESEND_API_KEY = key;
      if (from === undefined) delete process.env.EMAIL_FROM;
      else process.env.EMAIL_FROM = from;
    }
  });

  it("scoped queries return nothing from B for the limited user and everything without the list or for the super admin", async () => {
    const w = await makeWorld();
    const { listEditions, getEditionByCode } = await import("@/lib/queries/editions");
    const approvals = await import("@/lib/queries/approvals");
    const artwork = await import("@/lib/queries/artwork-approvals");
    const { boardTasks, dueTaskCounts } = await import("@/lib/queries/tasks");
    const { listGrants } = await import("@/lib/users/external");
    const { portalGrantsByScope } = await import("@/components/portal/grants");
    const { accessHistory } = await import("@/lib/users/history");
    const { writeAudit } = await import("@/lib/audit");
    const { todayInLondon } = await import("@/lib/today");
    const { addDaysIso } = await import("@/lib/deadlines");
    const mkt = await dept(w, "Marketing");
    const lim = await member(w, "Lim", "ops", {
      departmentId: mkt.id,
      editionIds: [w.A],
      managerScope: "everyone",
    });
    await approve(w, lim, "Lim", mkt.id);
    const past = new Date(Date.now() - 3 * 86_400_000);
    const sA = await inSignoff(w, w.A, mkt.id, lim, { planned: true, dueAt: past });
    const sB = await inSignoff(w, w.B, mkt.id, lim, { planned: true, dueAt: past });
    for (const s of [sA, sB]) {
      const [v] = await db
        .insert(schema.artworkVersions)
        .values({
          signageItemId: s.item.id,
          versionNumber: 1,
          filePath: `seed/${s.item.id}.pdf`,
          fileName: "art.pdf",
          mimeType: "application/pdf",
          fileSize: 10,
          sha256: "0".repeat(64),
          uploadedBy: w.adminId,
        })
        .returning();
      await db
        .update(schema.signageItems)
        .set({ currentArtworkVersionId: v.id })
        .where(eq(schema.signageItems.id, s.item.id));
    }
    const today = todayInLondon();
    const yesterday = addDaysIso(today, -1);
    const task = async (editionId: string | null, who: string) =>
      (
        await db
          .insert(schema.tasks)
          .values({
            organisationId: w.orgId,
            editionId,
            title: `Task ${editionId ?? "none"}`,
            dueDate: yesterday,
            assignedToUserId: who,
            createdByUserId: w.adminId,
          })
          .returning()
      )[0];
    const tA = await task(w.A, lim);
    const tB = await task(w.B, lim);
    const tNone = await task(null, lim);
    await task(w.A, w.adminId);
    await task(w.B, w.adminId);
    const [sup] = await db
      .insert(schema.suppliers)
      .values({ organisationId: w.orgId, name: `Printer ${w.tag}` })
      .returning();
    const grant = async (editionId: string) =>
      (
        await db
          .insert(schema.externalGrants)
          .values({
            invitedEmail: mail(`printer-${editionId}`),
            organisationId: w.orgId,
            editionId,
            role: "supplier",
            scopeType: "supplier",
            scopeId: sup.id,
            invitedBy: w.adminId,
            inviteTokenHash: `t-${randomUUID()}`,
          })
          .returning()
      )[0];
    const gA = await grant(w.A);
    const gB = await grant(w.B);
    await run(async (tx) => {
      for (const [editionId, word] of [
        [w.A, "alpha"],
        [w.B, "bravo"],
      ] as const) {
        await writeAudit(tx, {
          organisationId: w.orgId,
          editionId,
          actorUserId: w.adminId,
          entityType: "signage_item",
          entityId: editionId === w.A ? sA.item.id : sB.item.id,
          action: "delegate",
          summary: `Hand-over ${word}`,
          subjectUserId: lim,
        });
      }
    });

    const limS = await sessionOf(lim);
    const openS = unlimited(limS);
    const adminS = await sessionOf(w.adminId);
    const has = (v: unknown, s: string) => JSON.stringify(v).includes(s);

    expect((await listEditions(w.orgId, [w.A])).map((r) => r.edition.id)).toEqual([w.A]);
    expect((await listEditions(w.orgId, null)).map((r) => r.edition.id)).toEqual([w.A, w.B]);
    expect(await getEditionByCode(w.codeB, limS)).toBeNull();
    expect((await getEditionByCode(w.codeA, limS))?.edition.id).toBe(w.A);
    expect((await getEditionByCode(w.codeB, adminS))?.edition.id).toBe(w.B);

    expect((await approvals.countPendingForUser(limS)).total).toBe(1);
    expect((await approvals.countPendingForUser(openS)).total).toBe(2);
    expect(has(await approvals.oldestPendingForUser(limS), sB.item.ref)).toBe(false);
    expect(has(await approvals.oldestPendingForUser(openS), sB.item.ref)).toBe(true);
    expect(await approvals.pendingEntityIdsForUser(limS, [sA.item.id, sB.item.id])).toEqual(
      new Set([sA.item.id]),
    );
    expect(await approvals.pendingEntityIdsForUser(openS, [sA.item.id, sB.item.id])).toEqual(
      new Set([sA.item.id, sB.item.id]),
    );
    expect((await approvals.teamPendingSummary(w.orgId, [w.A])).total).toBe(1);
    expect((await approvals.teamPendingSummary(w.orgId, null)).total).toBe(2);
    expect(has(await approvals.openSignoffsForTeam(limS), sB.item.ref)).toBe(false);
    expect(has(await approvals.openSignoffsForTeam(limS), sA.item.ref)).toBe(true);
    expect(has(await approvals.openSignoffsForTeam(adminS), sB.item.ref)).toBe(true);
    expect(
      has(
        await approvals.listOverdueArtwork({ organisationId: w.orgId, scope: [w.A] }),
        sB.item.ref,
      ),
    ).toBe(false);
    expect(
      has(
        await approvals.listOverdueArtwork({ organisationId: w.orgId, scope: null }),
        sB.item.ref,
      ),
    ).toBe(true);
    const art = (scope: string[] | null) =>
      artwork.listArtworkApprovals({ organisationId: w.orgId, scope, filter: "all" });
    expect(has(await art([w.A]), sB.item.ref)).toBe(false);
    expect(has(await art([w.A]), sA.item.ref)).toBe(true);
    expect(has(await art(null), sB.item.ref)).toBe(true);
    expect(await artwork.countItemsInSignoff(w.orgId, [w.A])).toBe(1);
    expect(await artwork.countItemsInSignoff(w.orgId, null)).toBe(2);

    const board = (editionScope: string[] | null) =>
      boardTasks({
        organisationId: w.orgId,
        userId: lim,
        isAdmin: false,
        scope: "mine",
        editionScope,
      });
    expect((await board([w.A])).map((t) => t.id).sort()).toEqual([tA.id, tNone.id].sort());
    expect((await board(null)).map((t) => t.id).sort()).toEqual([tA.id, tB.id, tNone.id].sort());
    const due = async (userId: string) =>
      (await dueTaskCounts({ organisationId: w.orgId, userId, today }))[0]?.overdue ?? 0;
    expect(await due(lim)).toBe(2);
    expect(await due(w.adminId)).toBe(2);

    expect(has(await listGrants(db, w.orgId, [w.A]), gB.id)).toBe(false);
    expect(has(await listGrants(db, w.orgId, [w.A]), gA.id)).toBe(true);
    expect(has(await listGrants(db, w.orgId, null), gB.id)).toBe(true);
    const portal = async (scope: string[] | null) =>
      ((await portalGrantsByScope(w.orgId, "supplier", scope)).get(sup.id) ?? []).length;
    expect(await portal([w.A])).toBe(1);
    expect(await portal(null)).toBe(2);

    const hist = async (viewerScope: string[] | null) =>
      (await accessHistory(db, w.orgId, { userId: lim }, { viewerScope })).map((h) =>
        JSON.stringify(h),
      );
    expect((await hist([w.A])).some((h) => h.includes("bravo"))).toBe(false);
    expect((await hist([w.A])).some((h) => h.includes("alpha"))).toBe(true);
    expect((await hist(null)).some((h) => h.includes("bravo"))).toBe(true);
  });

  it("loadItemBundle / loadStandBundle / ownEdition / exportEdition return null for B with a limited actor; partners and super admins are unchanged", async () => {
    const w = await makeWorld();
    const signage = await import("@/lib/domain/signage");
    const { loadStandBundle } = await import("@/lib/domain/stand");
    const { exportEdition } = await import("@/lib/exports/serve");
    const lim = await member(w, "Lim", "ops", { editionIds: [w.A] });
    const limS = await sessionOf(lim);
    const adminS = await sessionOf(w.adminId);
    const partner: Actor = {
      kind: "external",
      userId: randomUUID(),
      organisationId: w.orgId,
      grants: [],
    };
    const iA = await item(w, w.A);
    const iB = await item(w, w.B);
    const [x] = await db
      .insert(schema.exhibitors)
      .values({
        editionId: w.B,
        companyName: "Stand Co",
        standNumber: `B${w.tag}`,
        standType: "space_only",
        contactEmail: mail(`stand-${w.tag}`),
      })
      .returning();
    const [sub] = await db
      .insert(schema.standSubmissions)
      .values({ editionId: w.B, exhibitorId: x.id, ref: `STD-${w.tag}-001` })
      .returning();
    const scope = (actor: Actor) => ({ organisationId: w.orgId, actor });
    expect(await signage.loadItemBundle(db, iB.id, scope(limS.actor))).toBeNull();
    expect(await signage.loadItemBundle(db, iA.id, scope(limS.actor))).not.toBeNull();
    expect(await signage.loadItemBundle(db, iB.id, scope(adminS.actor))).not.toBeNull();
    expect(await signage.loadItemBundle(db, iB.id, scope(partner))).not.toBeNull();
    expect(await loadStandBundle(db, sub.id, scope(limS.actor))).toBeNull();
    expect(await loadStandBundle(db, sub.id, scope(adminS.actor))).not.toBeNull();
    expect(await loadStandBundle(db, sub.id, scope(partner))).not.toBeNull();
    expect(await signage.ownEdition(db, w.orgId, w.B, limS.actor)).toBeNull();
    expect((await signage.ownEdition(db, w.orgId, w.A, limS.actor))?.id).toBe(w.A);
    expect((await signage.ownEdition(db, w.orgId, w.B, adminS.actor))?.id).toBe(w.B);
    expect(await exportEdition(limS, w.codeB)).toBeNull();
    expect((await exportEdition(limS, w.codeA))?.id).toBe(w.A);
    expect((await exportEdition(adminS, w.codeB))?.id).toBe(w.B);
  });

  it("removeMemberTx gives tasks and items in events the picked person can't open to the remover", async () => {
    const w = await makeWorld();
    const gone = await member(w, "Gus", "ops");
    const pick = await member(w, "Pia", "ops", { editionIds: [w.A] });
    const iA = await item(w, w.A, { ownerUserId: gone });
    const iB = await item(w, w.B, { ownerUserId: gone });
    const [tA, tB] = await db
      .insert(schema.tasks)
      .values([
        {
          organisationId: w.orgId,
          editionId: w.A,
          title: "A job",
          assignedToUserId: gone,
          createdByUserId: w.adminId,
        },
        {
          organisationId: w.orgId,
          editionId: w.B,
          title: "B job",
          assignedToUserId: gone,
          createdByUserId: w.adminId,
        },
      ])
      .returning();
    const out = await run((tx) =>
      manage.removeMemberTx(tx, ctxOf(w), { userId: gone, workToUserId: pick }),
    );
    expect(out.tasksToYou).toBe(1);
    expect(out.itemsToYou).toBe(1);
    expect((await itemRow(iA.id)).ownerUserId).toBe(pick);
    expect((await itemRow(iB.id)).ownerUserId).toBe(w.adminId);
    const taskOwner = async (id: string) =>
      (await db.select().from(schema.tasks).where(eq(schema.tasks.id, id)))[0].assignedToUserId;
    expect(await taskOwner(tA.id)).toBe(pick);
    expect(await taskOwner(tB.id)).toBe(w.adminId);
  });

  it("hand-over notices naming one event's work keep that event, so they're hidden once the person is taken off it", async () => {
    const w = await makeWorld();
    const { editionScopeSql } = await import("@/lib/queries/edition-scope");
    const mkt = await dept(w, "Marketing");
    const sue = await member(w, "Sue", "marketing", { departmentId: mkt.id });
    const ola = await member(w, "Ola", "marketing", { departmentId: mkt.id });
    await approve(w, sue, "Sue", mkt.id);
    await approve(w, ola, "Ola", mkt.id);
    const inA = await inSignoff(w, w.A, mkt.id, sue, { planned: true });
    await run((tx) => manage.suspendMemberTx(tx, ctxOf(w), { userId: sue }));
    expect((await instance(inA.inst.id)).assignedUserId).toBe(ola);

    const gus = await member(w, "Gus", "ops");
    const pia = await member(w, "Pia", "ops");
    const owned = await item(w, w.A, { ownerUserId: gus });
    await db.insert(schema.tasks).values({
      organisationId: w.orgId,
      editionId: w.A,
      title: "A job",
      assignedToUserId: gus,
      createdByUserId: w.adminId,
    });
    // Gus's twin owns items in both events: that notice is about no one event.
    const ian = await member(w, "Ian", "ops");
    await item(w, w.A, { ownerUserId: ian });
    await item(w, w.B, { ownerUserId: ian });
    await run((tx) => manage.removeMemberTx(tx, ctxOf(w), { userId: gus, workToUserId: pia }));
    await run((tx) => manage.removeMemberTx(tx, ctxOf(w), { userId: ian, workToUserId: pia }));

    const titles = async (userId: string, scope: string[] | null) =>
      (
        await db
          .select({ title: schema.notifications.title, editionId: schema.notifications.editionId })
          .from(schema.notifications)
          .where(
            and(
              eq(schema.notifications.userId, userId),
              editionScopeSql(scope, schema.notifications.editionId, { allowNull: true }),
            ),
          )
      )
        .map((r) => `${r.title} @${r.editionId === w.A ? "A" : r.editionId ? "?" : "none"}`)
        .sort();
    expect(await titles(ola, null)).toContain(`A sign-off is now yours: ${inA.item.ref} @A`);
    expect(await titles(pia, null)).toEqual(
      [
        `A task is now yours: A job @A`,
        `You now own ${owned.ref} @A`,
        "You now own 2 items @none",
      ].sort(),
    );

    // Both are taken off A (only B left): A's notices leave their bell.
    for (const id of [ola, pia]) {
      await db
        .update(schema.memberships)
        .set({ editionIds: [w.B] })
        .where(eq(schema.memberships.userId, id));
    }
    expect(await titles(ola, [w.B])).toEqual([]);
    expect(await titles(pia, [w.B])).toEqual(["You now own 2 items @none"]);
  });

  it("suspend: hand-over defaults skip signers who can't open the group's events; a limited viewer sees B's refs hidden", async () => {
    const w = await makeWorld();
    const mkt = await dept(w, "Marketing");
    const sue = await member(w, "Sue", "marketing", { departmentId: mkt.id });
    const mia = await member(w, "Mia", "marketing", { departmentId: mkt.id, editionIds: [w.A] });
    const ola = await member(w, "Ola", "marketing", { departmentId: mkt.id });
    const mona = await member(w, "Mona", "ops", { managerScope: "everyone", editionIds: [w.A] });
    await approve(w, sue, "Sue", mkt.id);
    await approve(w, mia, "Mia", mkt.id, true);
    await approve(w, ola, "Ola", mkt.id);
    const inB = await inSignoff(w, w.B, mkt.id, sue, { planned: true });
    const owned = await item(w, w.B, { ownerUserId: sue });
    const plan = await manage.handoverPlan(db, w.orgId, sue);
    const group = plan.groups.find((g) => g.key === mkt.id)!;
    expect(group.signers.map((s) => s.userId)).toEqual([ola]);
    expect(group.defaultTo).toBe(ola);
    // The same plan for a manager limited to A: counted, never named.
    const monaS = await sessionOf(mona);
    const hidden = await manage.handoverPlan(db, w.orgId, sue, {
      viewer: monaS.actor as import("@/lib/authz").StaffActor,
    });
    const steps = hidden.groups.flatMap((g) => g.steps);
    expect(steps).toHaveLength(1);
    expect(steps[0]).toMatchObject({ hidden: true, ref: "", href: null });
    expect(JSON.stringify(hidden)).not.toContain(inB.item.ref);
    const work = await manage.workableOwnedItems(db, w.orgId, sue, { viewer: monaS.actor });
    expect(work.filter((x) => x.hidden)).toHaveLength(work.length);
    expect(JSON.stringify(work)).not.toContain(owned.ref);
    // Suspending with the defaults hands it to Ola.
    await run((tx) => manage.suspendMemberTx(tx, ctxOf(w), { userId: sue }));
    expect((await instance(inB.inst.id)).assignedUserId).toBe(ola);
  });

  it("iCal for a limited person lists only A", async () => {
    const w = await makeWorld();
    const { icalToken } = await import("@/lib/ical");
    const { GET } = await import("@/app/api/ical/[token]/route");
    const lim = await member(w, "Lim", "ops", { editionIds: [w.A] });
    const iA = await item(w, w.A, { installDate: "2027-03-01" });
    const iB = await item(w, w.B, { installDate: "2027-09-01" });
    const secret = process.env.ICAL_SECRET;
    process.env.ICAL_SECRET = "ical-test-secret";
    try {
      const feed = async (userId: string) =>
        (
          await GET(new Request("http://localhost/api/ical/x"), {
            params: Promise.resolve({ token: icalToken(userId) }),
          })
        ).text();
      const mine = await feed(lim);
      expect(mine).toContain(iA.ref);
      expect(mine).not.toContain(iB.ref);
      expect(mine).not.toContain(w.codeB);
      const all = await feed(w.adminId);
      expect(all).toContain(iB.ref);
    } finally {
      if (secret === undefined) delete process.env.ICAL_SECRET;
      else process.env.ICAL_SECRET = secret;
    }
  });

  it("main-on-accept: a limited invitee takes A's default sign-offs; B's go to the department with the new reason words", async () => {
    const w = await makeWorld();
    const mkt = await dept(w, "Marketing");
    const jo = await member(w, "Jo", "marketing", { departmentId: mkt.id });
    await approve(w, jo, "Jo", mkt.id, true);
    const inA = await inSignoff(w, w.A, mkt.id, jo);
    const inB = await inSignoff(w, w.B, mkt.id, jo);
    const out = await run((tx) =>
      manage.inviteUserTx(tx, ctxOf(w), {
        ...base,
        email: mail(`nia-${w.tag}`),
        fullName: "Nia",
        role: "marketing",
        departmentId: mkt.id,
        signoffs: [{ departmentId: mkt.id, isMain: true }],
        editionIds: [w.A],
      }),
    );
    expect(out.mainOnAccept).toHaveLength(1);
    expect((await instance(inA.inst.id)).assignedUserId).toBe(jo);
    const [inv] = await db
      .select()
      .from(schema.staffInvites)
      .where(and(eq(schema.staffInvites.id, out.inviteId), isNull(schema.staffInvites.acceptedAt)));
    const nia = randomUUID();
    await db.insert(schema.users).values({ id: nia, email: inv.invitedEmail });
    await claim.claimStaffInvite(inv, nia, "Nia");
    expect((await instance(inA.inst.id)).assignedUserId).toBe(nia);
    expect((await instance(inB.inst.id)).assignedUserId).toBeNull();
    const [why] = await db
      .select()
      .from(schema.auditLog)
      .where(
        and(eq(schema.auditLog.entityId, inB.item.id), eq(schema.auditLog.action, "delegate")),
      );
    expect(why.summary).toContain(`Nia, ${mkt.name}'s main approver, doesn't work on ${w.codeB}`);
  });
});
