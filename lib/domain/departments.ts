// No "server-only" marker: the seed script uses syncDepartmentSteps too.
import { and, asc, eq, inArray, isNotNull, isNull, sql } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import { defaultSignageSteps } from "@/lib/workflow/defaults";
import { approvers, departments, memberships, workflowSteps, workflows } from "@/lib/db/schema";
import { signoffPaused, type PermissionOverrides } from "@/lib/authz";
import { accessLive } from "@/lib/access";
import { activeMembership } from "@/lib/users/active";
// lib/people imports nothing from lib/domain, so there is no cycle.
import { rerouteDepartmentSignoffs } from "@/lib/people";

export type Department = typeof departments.$inferSelect;
export type Approver = typeof approvers.$inferSelect;

/** "Marketing" → "Marketing sign-off": the name shown on each item's sign-off list. */
export function signoffStepName(departmentName: string): string {
  return `${departmentName} sign-off`;
}

type StepRow = typeof workflowSteps.$inferSelect;

/**
 * Where every step of a signage workflow goes, given its departments:
 * departments that sign off together (one parallel group), the other
 * approval steps (venue), departments that sign last, then confirmations.
 * Pure so the ordering can be unit tested.
 */
export function orderSignageSteps(
  steps: Pick<
    StepRow,
    "id" | "kind" | "departmentId" | "sortOrder" | "parallelGroup" | "isArchived"
  >[],
  depts: Pick<Department, "id" | "sortOrder" | "name" | "signsLast" | "isArchived">[],
): { id: string; sortOrder: number; parallelGroup: number | null }[] {
  const deptOrder = [...depts].sort(
    (a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name),
  );
  const deptById = new Map(deptOrder.map((d) => [d.id, d]));
  const live = steps.filter((s) => !s.isArchived);
  const deptSteps = (last: boolean) =>
    deptOrder
      .filter((d) => d.signsLast === last && !d.isArchived)
      .flatMap((d) => live.filter((s) => s.departmentId === d.id).slice(0, 1));
  const others = live
    .filter((s) => !s.departmentId || !deptById.has(s.departmentId))
    .sort((a, b) => a.sortOrder - b.sortOrder);
  const first = deptSteps(false);
  const last = deptSteps(true);
  const ordered = [
    ...first.map((s) => ({ id: s.id, group: first.length > 1 ? 1 : null })),
    ...others.filter((s) => s.kind === "approval").map((s) => ({ id: s.id, group: null })),
    ...last.map((s) => ({ id: s.id, group: last.length > 1 ? 2 : null })),
    ...others.filter((s) => s.kind !== "approval").map((s) => ({ id: s.id, group: null })),
  ];
  return ordered.map((o, i) => ({ id: o.id, sortOrder: i + 1, parallelGroup: o.group }));
}

/**
 * Make every signage workflow match the departments: one sign-off step per
 * department (named after it, going to its main approver when they have an
 * account, otherwise anyone in it), archived with it, in the right order.
 * Run after any change to departments or approvers. Open department
 * sign-offs then follow (rerouteDepartmentSignoffs): items on their
 * defaults go to the current main approver, and a step naming someone who
 * no longer signs for the department goes back to it.
 */
export async function syncDepartmentSteps(tx: Db | Tx, organisationId: string): Promise<void> {
  const depts = await tx
    .select()
    .from(departments)
    .where(eq(departments.organisationId, organisationId));
  // A main approver who can't sign now (suspended, access ended or sign-off
  // paused) isn't named: the step goes to everyone in the department.
  const mainRows = await tx
    .select({
      departmentId: approvers.departmentId,
      userId: approvers.userId,
      overrides: memberships.permissionOverrides,
    })
    .from(approvers)
    .innerJoin(
      memberships,
      and(
        eq(memberships.userId, approvers.userId),
        eq(memberships.organisationId, approvers.organisationId),
      ),
    )
    .where(
      and(
        eq(approvers.organisationId, organisationId),
        eq(approvers.isMain, true),
        isNotNull(approvers.userId),
        activeMembership(),
      ),
    );
  const mains = mainRows.filter((m) => !signoffPaused(m.overrides as PermissionOverrides));
  const mainByDept = new Map(mains.map((m) => [m.departmentId, m.userId!]));
  const flows = await tx
    .select({ id: workflows.id })
    .from(workflows)
    .where(
      and(
        eq(workflows.organisationId, organisationId),
        eq(workflows.appliesTo, "signage"),
        eq(workflows.isArchived, false),
      ),
    );

  for (const flow of flows) {
    const steps = await tx
      .select()
      .from(workflowSteps)
      .where(eq(workflowSteps.workflowId, flow.id));
    const slaDays =
      steps.find((s) => s.departmentId && !s.isArchived)?.slaDays ??
      steps.find((s) => s.kind === "approval")?.slaDays ??
      3;
    for (const d of depts) {
      const main = mainByDept.get(d.id) ?? null;
      // A department that doesn't sign off has no live step (like an archived one).
      const off = d.isArchived || !d.signsOff;
      const values = {
        name: signoffStepName(d.name),
        kind: "approval" as const,
        approverType: main ? ("user" as const) : ("role" as const),
        approverRole: null,
        approverUserId: main,
        defaultFor: d.defaultFor,
        isArchived: off,
      };
      const existing = steps.find((s) => s.departmentId === d.id);
      if (existing) {
        await tx.update(workflowSteps).set(values).where(eq(workflowSteps.id, existing.id));
        Object.assign(existing, values);
      } else if (!off) {
        const [row] = await tx
          .insert(workflowSteps)
          .values({
            ...values,
            workflowId: flow.id,
            departmentId: d.id,
            sortOrder: 1000,
            conditions: ["always"],
            slaDays,
          })
          .returning();
        steps.push(row);
      }
    }
    const ordering = depts.map((d) => ({ ...d, isArchived: d.isArchived || !d.signsOff }));
    for (const o of orderSignageSteps(steps, ordering)) {
      const s = steps.find((x) => x.id === o.id)!;
      if (s.sortOrder === o.sortOrder && s.parallelGroup === o.parallelGroup) continue;
      await tx
        .update(workflowSteps)
        .set({ sortOrder: o.sortOrder, parallelGroup: o.parallelGroup })
        .where(eq(workflowSteps.id, o.id));
    }
  }
  await rerouteDepartmentSignoffs(tx, organisationId);
}

/**
 * Connect approver entries to a person's account by email — when they join,
 * or when an admin adds someone who is already on the team. Only the
 * organisation they joined counts when one is given. Returns the
 * organisations whose steps may need a new main approver.
 */
export async function linkApproversToUser(
  tx: Tx,
  user: { id: string; email: string },
  organisationId?: string,
): Promise<string[]> {
  const linked = await tx
    .update(approvers)
    .set({ userId: user.id })
    .where(
      and(
        isNull(approvers.userId),
        eq(approvers.email, user.email.toLowerCase()),
        organisationId ? eq(approvers.organisationId, organisationId) : undefined,
      ),
    )
    .returning({ organisationId: approvers.organisationId });
  return [...new Set(linked.map((l) => l.organisationId))];
}

/**
 * Departments this person signs off for (for "can I decide this?").
 * Removed departments still count so sign-offs already waiting on them can
 * be finished.
 */
export async function departmentIdsForUser(
  db: Db | Tx,
  organisationId: string,
  userId: string,
): Promise<string[]> {
  const rows = await db
    .select({ id: approvers.departmentId })
    .from(approvers)
    .where(and(eq(approvers.organisationId, organisationId), eq(approvers.userId, userId)));
  return rows.map((r) => r.id);
}

/**
 * People who can sign off for a department right now: account set up,
 * access active and sign-off not paused.
 */
export async function departmentSignerIds(
  db: Db | Tx,
  organisationId: string,
  departmentId: string,
): Promise<string[]> {
  const rows = await db
    .select({ userId: approvers.userId, overrides: memberships.permissionOverrides })
    .from(approvers)
    .innerJoin(
      memberships,
      and(
        eq(memberships.userId, approvers.userId),
        eq(memberships.organisationId, approvers.organisationId),
      ),
    )
    .where(
      and(
        eq(approvers.organisationId, organisationId),
        eq(approvers.departmentId, departmentId),
        activeMembership(),
      ),
    );
  return rows
    .filter((r) => !signoffPaused(r.overrides as PermissionOverrides))
    .map((r) => r.userId!);
}

/** Department names by id, for labelling sign-offs. */
export async function departmentNames(
  db: Db | Tx,
  ids: (string | null | undefined)[],
): Promise<Map<string, string>> {
  const wanted = [...new Set(ids.filter((i): i is string => Boolean(i)))];
  if (wanted.length === 0) return new Map();
  const rows = await db
    .select({ id: departments.id, name: departments.name })
    .from(departments)
    .where(inArray(departments.id, wanted));
  return new Map(rows.map((r) => [r.id, r.name]));
}

/** Departments with their approvers, for the Approvers tab and the item form. */
export async function listDepartments(db: Db | Tx, organisationId: string) {
  const [depts, people] = await Promise.all([
    db
      .select()
      .from(departments)
      .where(eq(departments.organisationId, organisationId))
      .orderBy(asc(departments.sortOrder), asc(departments.name)),
    db
      .select({
        approver: approvers,
        hasMembership: sql<boolean>`${memberships.id} IS NOT NULL`,
        overrides: memberships.permissionOverrides,
        suspendedAt: memberships.suspendedAt,
        accessEndsAt: memberships.accessEndsAt,
      })
      .from(approvers)
      .leftJoin(
        memberships,
        and(
          eq(memberships.userId, approvers.userId),
          eq(memberships.organisationId, approvers.organisationId),
        ),
      )
      .where(eq(approvers.organisationId, organisationId))
      .orderBy(asc(approvers.fullName)),
  ]);
  return depts.map((d) => ({
    ...d,
    approvers: people
      .filter((p) => p.approver.departmentId === d.id)
      .map((p) => ({
        ...p.approver,
        /** Account set up, access active and able to sign off. */
        active:
          Boolean(p.approver.userId && p.hasMembership) &&
          accessLive(p) &&
          !signoffPaused(p.overrides as PermissionOverrides),
      })),
  }));
}

export const SIGNAGE_WORKFLOW_NAME = "Signage default";

/**
 * Make sure the organisation has a signage sign-off workflow. A brand-new
 * organisation has none until this runs, and without it no sign can go for
 * sign-off. It holds the venue approval and the print, delivery and install
 * confirmations; the department sign-offs come from the departments.
 */
export async function ensureSignageWorkflow(tx: Db | Tx, organisationId: string): Promise<string> {
  const [existing] = await tx
    .select({ id: workflows.id })
    .from(workflows)
    .where(
      and(
        eq(workflows.organisationId, organisationId),
        eq(workflows.appliesTo, "signage"),
        isNull(workflows.forKind),
        eq(workflows.isArchived, false),
      ),
    )
    .limit(1);
  if (existing) return existing.id;
  const [flow] = await tx
    .insert(workflows)
    .values({ organisationId, name: SIGNAGE_WORKFLOW_NAME, appliesTo: "signage", isDefault: true })
    .returning({ id: workflows.id });
  const fixed = defaultSignageSteps.filter(
    (st) => st.kind === "confirmation" || st.approverRole === "venue",
  );
  for (const st of fixed) {
    await tx.insert(workflowSteps).values({
      workflowId: flow.id,
      sortOrder: st.sortOrder,
      parallelGroup: st.parallelGroup,
      name: st.name,
      kind: st.kind,
      approverType: st.approverType,
      approverRole: st.approverRole,
      approverUserId: null,
      conditions: st.conditions,
      slaDays: st.slaDays,
      invalidateOnNewVersion: st.invalidateOnNewVersion,
      restartFromHereOnChanges: st.restartFromHereOnChanges,
      defaultFor: st.defaultFor ?? [],
    });
  }
  await syncDepartmentSteps(tx, organisationId);
  return flow.id;
}
