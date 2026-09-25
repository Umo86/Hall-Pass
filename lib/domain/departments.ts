// No "server-only" marker: the seed script uses syncDepartmentSteps too.
import { and, asc, eq, inArray, isNotNull, isNull, sql } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import { approvers, departments, memberships, workflowSteps, workflows } from "@/lib/db/schema";

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
  steps: Pick<StepRow, "id" | "kind" | "departmentId" | "sortOrder" | "parallelGroup" | "isArchived">[],
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
 * Run after any change to departments or approvers. Sign-offs already under
 * way keep what they were started with.
 */
export async function syncDepartmentSteps(tx: Db | Tx, organisationId: string): Promise<void> {
  const depts = await tx
    .select()
    .from(departments)
    .where(eq(departments.organisationId, organisationId));
  const mains = await tx
    .select({ departmentId: approvers.departmentId, userId: approvers.userId })
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
      ),
    );
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
      const values = {
        name: signoffStepName(d.name),
        kind: "approval" as const,
        approverType: main ? ("user" as const) : ("role" as const),
        approverRole: null,
        approverUserId: main,
        defaultFor: d.defaultFor,
        isArchived: d.isArchived,
      };
      const existing = steps.find((s) => s.departmentId === d.id);
      if (existing) {
        await tx.update(workflowSteps).set(values).where(eq(workflowSteps.id, existing.id));
        Object.assign(existing, values);
      } else if (!d.isArchived) {
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
    for (const o of orderSignageSteps(steps, depts)) {
      const s = steps.find((x) => x.id === o.id)!;
      if (s.sortOrder === o.sortOrder && s.parallelGroup === o.parallelGroup) continue;
      await tx
        .update(workflowSteps)
        .set({ sortOrder: o.sortOrder, parallelGroup: o.parallelGroup })
        .where(eq(workflowSteps.id, o.id));
    }
  }
}

/**
 * Connect approver entries to a person's account by email — when they join,
 * or when an admin adds someone who is already on the team. Returns the
 * organisations whose steps may need a new main approver.
 */
export async function linkApproversToUser(
  tx: Tx,
  user: { id: string; email: string },
): Promise<string[]> {
  const linked = await tx
    .update(approvers)
    .set({ userId: user.id })
    .where(and(isNull(approvers.userId), eq(approvers.email, user.email.toLowerCase())))
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

/** People who can sign off for a department right now (account set up). */
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
      and(eq(approvers.organisationId, organisationId), eq(approvers.departmentId, departmentId)),
    );
  return rows
    .filter((r) => (r.overrides as Record<string, unknown> | null)?.["approval.decide"] !== false)
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
        /** Account set up and able to sign off. */
        active:
          Boolean(p.approver.userId && p.hasMembership) &&
          (p.overrides as Record<string, unknown> | null)?.["approval.decide"] !== false,
      })),
  }));
}
