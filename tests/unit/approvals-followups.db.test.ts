/**
 * Approvals follow-ups against a real database (TEST_DATABASE_URL), with the
 * session stubbed:
 * - Remind uses approval.remind: Marketing can chase a sign they could send,
 *   Senior management can't (even with a sign-off of their own), and the
 *   Everyone's view's canRemind agrees;
 * - resubmitSignageItem sends a sign back for sign-off through the shared
 *   resubmitItemInTx, audited;
 * - ?who= narrows Everyone's to one person, department or role;
 * - All artwork with ?overdue=1 lists only artwork whose sign-off is late.
 * The ?who= parsing and group keys are pure and tested without a database.
 */
import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import * as schema from "@/lib/db/schema";
import type { Session } from "@/lib/auth/actor";
import type { StaffRole } from "@/lib/authz";

const state = vi.hoisted(() => ({ session: null as unknown }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn(), revalidateTag: vi.fn() }));
vi.mock("@/lib/auth/actor", () => ({
  requireSession: async () => state.session,
  requireStaffSession: async () => state.session,
}));

const DEPT = "8f6d2b1e-3c4a-4d5e-9f00-112233445566";
const USER = "0b1c2d3e-4f50-4617-8283-949596979899";

describe("?who= on Approvals → Everyone's (pure)", () => {
  it("groups a step by person, else department, else role", async () => {
    const { signoffGroupKey } = await import("@/lib/queries/approvals");
    const step = { assignedUserId: null, assignedDepartmentId: null, assignedRole: null };
    expect(signoffGroupKey({ ...step, assignedUserId: USER, assignedDepartmentId: DEPT })).toBe(
      `user:${USER}`,
    );
    expect(signoffGroupKey({ ...step, assignedDepartmentId: DEPT, assignedRole: "ops" })).toBe(
      `dept:${DEPT}`,
    );
    expect(signoffGroupKey({ ...step, assignedRole: "supplier" })).toBe("role:supplier");
    expect(signoffGroupKey(step)).toBe("role:none");
  });

  it("keeps well-formed keys, comma-separated, and drops the rest", async () => {
    const { parseWhoParam } = await import("@/lib/queries/approvals");
    expect(parseWhoParam(`dept:${DEPT},role:ops`)).toEqual([`dept:${DEPT}`, "role:ops"]);
    expect(parseWhoParam([`user:${USER}`, "role:ops"])).toEqual([`user:${USER}`, "role:ops"]);
    expect(parseWhoParam(`role:ops, role:ops ,dept:not-a-uuid,user:,team:x,role:Ops;drop`)).toEqual(
      ["role:ops"],
    );
    expect(parseWhoParam(undefined)).toEqual([]);
    expect(parseWhoParam("")).toEqual([]);
  });
});

const url = process.env.TEST_DATABASE_URL;
const d = describe.skipIf(!url);
if (url) process.env.DATABASE_URL = url;

let client: ReturnType<typeof postgres>;
let db: ReturnType<typeof drizzle<typeof schema>>;
let actions: typeof import("@/app/actions/approvals");
let queries: typeof import("@/lib/queries/approvals");
const n = Date.now() % 1_000_000;
let orgId: string;
let editionId: string;
let deptId: string;
let workflowId: string;
const stepIds: Record<"ops" | "mkt" | "print", string> = { ops: "", mkt: "", print: "" };
const people: Record<string, { id: string; role: StaffRole; depts: string[] }> = {};

async function addUser(key: string, role: StaffRole, depts: string[] = []) {
  const id = randomUUID();
  await db.insert(schema.users).values({ id, email: `${key}-${n}@follow.test`, fullName: key });
  await db.insert(schema.memberships).values({ userId: id, organisationId: orgId, role });
  people[key] = { id, role, depts };
}

function sessionOf(key: string): Session {
  const p = people[key];
  return {
    actor: {
      kind: "staff",
      userId: p.id,
      organisationId: orgId,
      role: p.role,
      signoffDepartmentIds: p.depts,
    },
    user: { id: p.id, email: `${key}@follow.test`, fullName: key, isExternal: false },
    organisation: {
      id: orgId,
      brandName: "Hall Pass",
      settings: {} as Session["organisation"]["settings"],
    },
  };
}
function as(key: string) {
  state.session = sessionOf(key);
}

let seq = 0;
type StepSpec = {
  step: "ops" | "mkt" | "print";
  status?: "pending" | "waiting" | "changes_requested" | "approved";
  role?: string;
  userId?: string;
  departmentId?: string;
  /** Days from now; negative is overdue. */
  dueInDays?: number;
};
/** A sign with artwork and the given steps in its first round. */
async function sign(
  status: (typeof schema.signageItems.$inferSelect)["status"],
  steps: StepSpec[],
  name?: string,
) {
  seq++;
  const [item] = await db
    .insert(schema.signageItems)
    .values({
      editionId,
      ref: `SIG-FOL${n}-${String(seq).padStart(3, "0")}`,
      seq,
      name: name ?? `Follow-up sign ${seq}`,
      status,
      workflowId,
      currentRunNumber: 1,
      createdBy: people.ops.id,
      ownerUserId: people.mkt.id,
    })
    .returning();
  const [v] = await db
    .insert(schema.artworkVersions)
    .values({
      signageItemId: item.id,
      versionNumber: 1,
      filePath: `seed/${item.id}.pdf`,
      fileName: "art.pdf",
      mimeType: "application/pdf",
      fileSize: 10,
      sha256: "0".repeat(64),
      uploadedBy: people.ops.id,
    })
    .returning();
  await db
    .update(schema.signageItems)
    .set({ currentArtworkVersionId: v.id })
    .where(eq(schema.signageItems.id, item.id));
  const instances = await db
    .insert(schema.approvalInstances)
    .values(
      steps.map((st, i) => ({
        entityType: "signage_item" as const,
        entityId: item.id,
        runNumber: 1,
        workflowStepId: stepIds[st.step],
        stepNameSnapshot:
          st.step === "ops"
            ? "Operations sign-off"
            : st.step === "mkt"
              ? "Marketing sign-off"
              : "Sent to print",
        stepKindSnapshot: st.step === "print" ? ("confirmation" as const) : ("approval" as const),
        sortOrderSnapshot: i + 1,
        parallelGroupSnapshot: st.step === "print" ? null : 1,
        status: st.status ?? "pending",
        assignedRole: st.role ?? null,
        assignedUserId: st.userId ?? null,
        assignedDepartmentId: st.departmentId ?? null,
        restartFromHereSnapshot: true,
        pendingSince: new Date(),
        dueAt: st.dueInDays === undefined ? null : new Date(Date.now() + st.dueInDays * 86_400_000),
      })),
    )
    .returning();
  return { item, instances };
}

d("approvals follow-ups", () => {
  beforeAll(async () => {
    client = postgres(url!, { max: 3, prepare: false, onnotice: () => {} });
    db = drizzle(client, { schema });
    actions = await import("@/app/actions/approvals");
    queries = await import("@/lib/queries/approvals");
    const [org] = await db
      .insert(schema.organisations)
      .values({ name: "Follow-up Org", slug: `follow-${n}` })
      .returning();
    orgId = org.id;
    const [dept] = await db
      .insert(schema.departments)
      .values({ organisationId: orgId, name: `Design ${n}` })
      .returning();
    deptId = dept.id;
    await addUser("admin", "admin");
    await addUser("ops", "ops");
    await addUser("mkt", "marketing");
    await addUser("director", "event_director", [deptId]);
    await db.insert(schema.approvers).values({
      organisationId: orgId,
      departmentId: deptId,
      userId: people.director.id,
      fullName: "director",
      email: `director-${n}@follow.test`,
    });
    const [event] = await db
      .insert(schema.events)
      .values({ organisationId: orgId, name: "Follow-up Event", code: `FE${n}` })
      .returning();
    const [venue] = await db
      .insert(schema.venues)
      .values({ organisationId: orgId, name: "Follow-up Venue", code: `FV${n}` })
      .returning();
    const [edition] = await db
      .insert(schema.editions)
      .values({
        eventId: event.id,
        venueId: venue.id,
        name: "Follow-up Edition",
        code: `FOL${n}`,
        buildStart: "2027-10-01",
        buildEnd: "2027-10-04",
        openStart: "2027-10-05",
        openEnd: "2027-10-07",
        breakdownEnd: "2027-10-08",
      })
      .returning();
    editionId = edition.id;
    const [wf] = await db
      .insert(schema.workflows)
      .values({ organisationId: orgId, name: `Follow-up WF ${n}`, appliesTo: "signage" })
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
      restartFromHereOnChanges: true,
    });
    const rows = await db
      .insert(schema.workflowSteps)
      .values([
        step(1, "Operations sign-off", "ops"),
        step(2, "Marketing sign-off", "marketing"),
        step(3, "Sent to print", "supplier"),
      ])
      .returning();
    stepIds.ops = rows[0].id;
    stepIds.mkt = rows[1].id;
    stepIds.print = rows[2].id;
  });

  afterAll(async () => {
    if (editionId) {
      await db
        .update(schema.signageItems)
        .set({ deletedAt: new Date() })
        .where(eq(schema.signageItems.editionId, editionId));
    }
    await client?.end();
  });

  it("Remind: Marketing can chase a sign they could send; Senior management can't", async () => {
    const { item, instances } = await sign("in_review", [
      { step: "ops", role: "ops", dueInDays: -2 },
    ]);
    const [step] = instances;

    as("director");
    const refused = await actions.remindApproval({ instanceId: step.id });
    expect(refused).toMatchObject({ ok: false, error: "You cannot chase this sign-off" });

    as("mkt");
    const sent = await actions.remindApproval({ instanceId: step.id });
    expect(sent).toMatchObject({ ok: true, data: { reminded: 1, alreadyToday: 0, nobody: 0 } });
    const [audit] = await db
      .select()
      .from(schema.auditLog)
      .where(and(eq(schema.auditLog.entityId, item.id), eq(schema.auditLog.action, "escalate")));
    expect(audit?.summary).toBe("Reminder sent for Operations sign-off (1 person)");

    // The Everyone's view offers Remind to the same people.
    const forMkt = await queries.openSignoffsForTeam(sessionOf("mkt"), { editionId });
    const forDirector = await queries.openSignoffsForTeam(sessionOf("director"), { editionId });
    expect(forMkt.find((r) => r.instanceId === step.id)?.canRemind).toBe(true);
    expect(forDirector.find((r) => r.instanceId === step.id)?.canRemind).toBe(false);
  });

  it("resubmitSignageItem sends a sign back to the step that asked, audited", async () => {
    const { item, instances } = await sign("changes_requested", [
      { step: "ops", role: "ops", status: "approved" },
      { step: "mkt", role: "marketing", status: "changes_requested" },
      { step: "print", role: "supplier", status: "waiting" },
    ]);
    as("mkt");
    const res = await actions.resubmitSignageItem({ id: item.id });
    expect(res).toMatchObject({ ok: true, message: "Resubmitted for review" });
    const [after] = await db
      .select({ status: schema.signageItems.status })
      .from(schema.signageItems)
      .where(eq(schema.signageItems.id, item.id));
    expect(after.status).toBe("in_review");
    const steps = await db
      .select()
      .from(schema.approvalInstances)
      .where(eq(schema.approvalInstances.entityId, item.id));
    expect(steps.find((s) => s.id === instances[0].id)?.status).toBe("approved");
    expect(steps.find((s) => s.id === instances[1].id)?.status).toBe("pending");
    const audits = await db
      .select()
      .from(schema.auditLog)
      .where(and(eq(schema.auditLog.entityId, item.id), eq(schema.auditLog.action, "submit")));
    expect(audits.map((a) => a.summary)).toEqual([`${item.ref} resubmitted`]);

    // Again: it is no longer waiting on changes.
    const again = await actions.resubmitSignageItem({ id: item.id });
    expect(again).toMatchObject({
      ok: false,
      error: "Only items with changes requested can be resubmitted",
    });
  });

  it("?who= narrows Everyone's to one person, department or role", async () => {
    const byDept = await sign("in_review", [{ step: "mkt", departmentId: deptId }]);
    const byUser = await sign("in_review", [{ step: "ops", userId: people.ops.id }]);
    const byRole = await sign("in_review", [{ step: "ops", role: "ops" }]);
    const ids = (rows: { instanceId: string }[]) => new Set(rows.map((r) => r.instanceId));
    const admin = sessionOf("admin");

    const all = ids(await queries.openSignoffsForTeam(admin, { editionId }));
    for (const x of [byDept, byUser, byRole]) expect(all.has(x.instances[0].id)).toBe(true);

    const dept = await queries.openSignoffsForTeam(admin, { editionId, who: [`dept:${deptId}`] });
    expect(dept.map((r) => r.instanceId)).toEqual([byDept.instances[0].id]);
    expect(dept[0].groupKey).toBe(`dept:${deptId}`);

    const user = await queries.openSignoffsForTeam(admin, {
      editionId,
      who: [`user:${people.ops.id}`],
    });
    expect(user.map((r) => r.instanceId)).toEqual([byUser.instances[0].id]);

    // A role group is only the role's own steps, not a named person's.
    const role = ids(await queries.openSignoffsForTeam(admin, { editionId, who: ["role:ops"] }));
    expect(role.has(byRole.instances[0].id)).toBe(true);
    expect(role.has(byUser.instances[0].id)).toBe(false);
    expect(role.has(byDept.instances[0].id)).toBe(false);

    const both = ids(
      await queries.openSignoffsForTeam(admin, {
        editionId,
        who: [`dept:${deptId}`, `user:${people.ops.id}`],
      }),
    );
    expect(both).toEqual(new Set([byDept.instances[0].id, byUser.instances[0].id]));
  });

  it("?overdue=1 on All artwork lists late sign-offs only, most overdue first", async () => {
    const later = await sign("in_review", [{ step: "mkt", role: "marketing", dueInDays: -1 }]);
    const latest = await sign("in_review", [{ step: "ops", role: "ops", dueInDays: -6 }]);
    const onTime = await sign("in_review", [{ step: "ops", role: "ops", dueInDays: 4 }]);
    const lateConfirmation = await sign("approved", [
      { step: "ops", role: "ops", status: "approved" },
      { step: "print", role: "supplier", dueInDays: -5 },
    ]);
    const held = await sign("on_hold", [{ step: "ops", role: "ops", dueInDays: -3 }]);

    const { rows, truncated } = await queries.listOverdueArtwork({
      organisationId: orgId,
      editionId,
    });
    const refs = rows.map((r) => r.ref);
    expect(truncated).toBe(false);
    expect(refs.indexOf(latest.item.ref)).toBeGreaterThanOrEqual(0);
    expect(refs.indexOf(later.item.ref)).toBeGreaterThan(refs.indexOf(latest.item.ref));
    for (const x of [onTime, lateConfirmation, held]) expect(refs).not.toContain(x.item.ref);

    const row = rows.find((r) => r.ref === latest.item.ref)!;
    expect(row).toMatchObject({
      name: latest.item.name,
      status: "in_review",
      version: 1,
      previewUrl: null,
      href: `/FOL${n}/signage/${latest.item.ref}?tab=artwork`,
    });
    expect(row.signoffs.map((s) => [s.stepName, s.status])).toEqual([
      ["Operations sign-off", "pending"],
    ]);

    // The status filter and the search still apply.
    const changes = await queries.listOverdueArtwork({
      organisationId: orgId,
      editionId,
      filter: "changes",
    });
    expect(changes.rows).toEqual([]);
    const searched = await queries.listOverdueArtwork({
      organisationId: orgId,
      editionId,
      search: later.item.ref,
    });
    expect(searched.rows.map((r) => r.ref)).toEqual([later.item.ref]);
  });
});
