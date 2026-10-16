"use server";

/**
 * Users: add people (one or several), change what they can do, suspend
 * them, end their access on a date, remove them, manage invitation links,
 * and do any of that to several people at once. The database work lives in
 * lib/users/manage.ts; each action here parses, checks the people action
 * (people.manage for super admins and managers, users.manage to remove),
 * runs it in one transaction — where the per-person rules are checked
 * against the person as loaded — and revalidates. Bulk actions run each
 * person in their own transaction with the same checks and audit rows.
 */
import { revalidatePath } from "next/cache";
import { unstable_rethrow } from "next/navigation";
import { z } from "zod";
import { db } from "@/lib/db/client";
import { can, FEATURES, MANAGER_SCOPES, missingAbilityMessage } from "@/lib/authz";
import { requireSession, type Session } from "@/lib/auth/actor";
import { deliverInvite } from "@/lib/auth/staff-invite";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { roleLabel } from "@/lib/format";
import { EDITABLE_ABILITY_KEYS, firstName, STAFF_ROLES } from "@/lib/users/rules";
import {
  bulkPeople,
  cancelInviteTx,
  inviteRowsTx,
  inviteUserTx,
  previewInviteRows,
  reactivateMemberTx,
  removeMemberTx,
  renewGrantLinkTx,
  renewInviteLinkTx,
  setAccessEndTx,
  suspendMemberTx,
  updateInviteTx,
  updateMemberTx,
  UserError,
  type InviteRowResult,
  type PreviewRow,
} from "@/lib/users/manage";
import { BACK_TO_DEPARTMENT, OTHER_GROUP } from "@/lib/users/handover";
import type { AbilityKey } from "@/lib/authz";

const NOT_ALLOWED = "Only super admins and managers add and change people";

const abilitiesSchema = z
  .object(
    Object.fromEntries(EDITABLE_ABILITY_KEYS.map((k) => [k, z.boolean().optional()])) as Record<
      AbilityKey,
      z.ZodOptional<z.ZodBoolean>
    >,
  )
  .partial()
  .strict();

/** A London date (YYYY-MM-DD) access ends on; null clears it. */
const accessEndsOn = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Enter the end date as a date")
  .nullable()
  .optional();

const personSchema = z
  .object({
    fullName: z.string().trim().min(1, "Enter their name").max(200),
    jobTitle: z
      .string()
      .trim()
      .max(200)
      .nullish()
      .transform((v) => v || null),
    departmentId: z.string().uuid().nullable(),
    newDepartmentName: z
      .string()
      .trim()
      .max(60, "Keep the department name under 60 characters")
      .nullish()
      .transform((v) => v || null),
    role: z.enum(STAFF_ROLES as [string, ...string[]], { message: "Choose a role" }),
    features: z.array(z.enum(FEATURES)).max(FEATURES.length).nullable(),
    abilities: abilitiesSchema,
    signoffs: z
      .array(z.object({ departmentId: z.string().uuid(), isMain: z.boolean() }).strict())
      .max(50),
    /** Super admins only (checked in the transaction); undefined = unchanged. */
    managerScope: z
      .enum(MANAGER_SCOPES as [string, ...string[]])
      .nullable()
      .optional(),
    accessEndsOn,
  })
  .strict();

const inviteSchema = personSchema
  .extend({ email: z.string().trim().toLowerCase().email("Enter a valid email address") })
  .strict();

const updateMemberSchema = personSchema
  .extend({ userId: z.string().uuid(), signoffPaused: z.boolean() })
  .strict();

const updateInviteSchema = personSchema.extend({ inviteId: z.string().uuid() }).strict();

/** Who takes over each department's sign-offs: a person, or back to the department. */
const handToSchema = z
  .record(
    z.union([z.string().uuid(), z.literal(OTHER_GROUP)]),
    z.union([z.string().uuid(), z.literal(BACK_TO_DEPARTMENT)]),
  )
  .nullish();

type Role = (typeof STAFF_ROLES)[number];
type Scope = (typeof MANAGER_SCOPES)[number];

/** The form's data as lib/users/manage.ts takes it. */
function personData<T extends { role: string; managerScope?: string | null }>(data: T) {
  return {
    ...data,
    role: data.role as Role,
    managerScope: data.managerScope as Scope | null | undefined,
  };
}

function invalid(error: z.ZodError): ActionResult<never> {
  const fieldErrors: Record<string, string> = {};
  for (const issue of error.issues) {
    const key = String(issue.path[0] ?? "form");
    fieldErrors[key] ??= issue.message;
  }
  return fail(error.issues[0]?.message ?? "Check the form", fieldErrors);
}

function failure(err: unknown, label: string): ActionResult<never> {
  unstable_rethrow(err);
  if (err instanceof UserError) return fail(err.message, err.detail);
  console.error(label, err);
  return fail("Could not save — please try again");
}

function refresh() {
  revalidatePath("/users", "layout");
  revalidatePath("/approvals");
}

/**
 * A session allowed to open the people actions at all (super admins and
 * managers); who they may change is checked per person in the transaction.
 */
async function peopleSession(): Promise<Session | null> {
  const session = await requireSession();
  return can(session.actor, { type: "people.manage" }) ? session : null;
}

function ctx(session: Session) {
  return { organisationId: session.organisation.id, actorUserId: session.user.id };
}

function inviterName(session: Session) {
  return session.user.fullName || session.user.email;
}

export type InviteUserResult = {
  inviteId: string;
  email: string;
  name: string;
  emailed: boolean;
  /** Only when nothing could be emailed: the link to pass on by hand. */
  inviteUrl?: string;
};

/**
 * Add someone to the team. They get an invitation (by email, or a link to
 * pass on when email isn't set up) carrying everything chosen here.
 */
export async function inviteUser(input: unknown): Promise<ActionResult<InviteUserResult>> {
  const parsed = inviteSchema.safeParse(input);
  if (!parsed.success) return invalid(parsed.error);
  const session = await peopleSession();
  if (!session) return fail(NOT_ALLOWED);
  const data = personData(parsed.data);
  try {
    const invite = await db.transaction((tx) => inviteUserTx(tx, ctx(session), data));
    const delivery = await deliverInvite({
      email: data.email,
      name: data.fullName,
      inviterName: inviterName(session),
      reason: `You've been added to the ${session.organisation.brandName} team${
        invite.departmentName ? ` (${invite.departmentName})` : ""
      } as ${roleLabel(data.role)}.`,
      inviteUrl: invite.inviteUrl,
      inviteId: invite.inviteId,
    });
    refresh();
    return success(
      {
        inviteId: invite.inviteId,
        email: data.email,
        name: data.fullName,
        emailed: delivery.emailed,
        inviteUrl: delivery.emailed ? undefined : delivery.fallbackUrl,
      },
      [
        delivery.emailed
          ? `Invitation sent to ${data.email}`
          : `${firstName(data.fullName)} added — send them the link`,
        ...invite.mainKept.map(
          (m) => `${m.name} stays main approver until ${firstName(data.fullName)} has accepted`,
        ),
      ].join(". "),
    );
  } catch (err) {
    return failure(err, "inviteUser");
  }
}

/** Save a team member's details, department, role, sections, sign-off and abilities. */
export async function updateUser(input: unknown): Promise<ActionResult> {
  const parsed = updateMemberSchema.safeParse(input);
  if (!parsed.success) return invalid(parsed.error);
  const session = await peopleSession();
  if (!session) return fail(NOT_ALLOWED);
  try {
    const out = await db.transaction((tx) =>
      updateMemberTx(tx, ctx(session), personData(parsed.data)),
    );
    refresh();
    if (out.changed.length === 0) return success(undefined, "Nothing to save");
    const notes = [
      out.signoffsMoved > 0
        ? `${out.signoffsMoved} sign-off${out.signoffsMoved === 1 ? "" : "s"} went back to the department`
        : null,
      out.signoffsKept > 0
        ? `${out.signoffsKept} sign-off${out.signoffsKept === 1 ? " still names" : "s still name"} ${firstName(out.name)} — nobody else signs off there, so hand ${out.signoffsKept === 1 ? "it" : "them"} on from the item`
        : null,
    ].filter(Boolean);
    return success(
      undefined,
      [
        parsed.data.userId === session.user.id
          ? "Saved"
          : `Saved — ${firstName(out.name)} sees the change on their next page load`,
        ...notes,
      ].join(". "),
    );
  } catch (err) {
    return failure(err, "updateUser");
  }
}

/** Change what an open invitation will give someone. */
export async function updateInvitation(input: unknown): Promise<ActionResult> {
  const parsed = updateInviteSchema.safeParse(input);
  if (!parsed.success) return invalid(parsed.error);
  const session = await peopleSession();
  if (!session) return fail(NOT_ALLOWED);
  try {
    const out = await db.transaction((tx) =>
      updateInviteTx(tx, ctx(session), personData(parsed.data)),
    );
    refresh();
    return success(
      undefined,
      [
        `Saved — ${firstName(out.name)} gets this when they accept`,
        ...out.mainKept.map(
          (m) => `${m.name} stays main approver until ${firstName(out.name)} has accepted`,
        ),
      ].join(". "),
    );
  } catch (err) {
    return failure(err, "updateInvitation");
  }
}

/**
 * Remove someone who has left. Sign-offs waiting on them go to the person
 * picked; their tasks and items move to you; departments fall back.
 */
export async function removeUser(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({
      userId: z.string().uuid(),
      handTo: handToSchema,
      handToUserId: z.string().uuid().nullish(),
      workToUserId: z.string().uuid().nullish(),
    })
    .strict()
    .safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) {
    return fail("Only a super admin can remove people");
  }
  try {
    const out = await db.transaction((tx) =>
      removeMemberTx(tx, { ...ctx(session), actorName: inviterName(session) }, parsed.data),
    );
    refresh();
    revalidatePath("/", "layout");
    const toWorker = out.items - out.itemsToYou;
    const moved = [
      out.tasks ? `${out.tasks} task${out.tasks === 1 ? "" : "s"}` : null,
      toWorker ? `${toWorker} item${toWorker === 1 ? "" : "s"}` : null,
    ].filter(Boolean);
    const workTo = parsed.data.workToUserId && parsed.data.workToUserId !== session.user.id;
    return success(
      undefined,
      `${out.name} removed${
        moved.length ? ` — ${moved.join(" and ")} moved to ${workTo ? out.workToName : "you"}` : ""
      }${
        out.itemsToYou
          ? `; ${out.itemsToYou} item${out.itemsToYou === 1 ? "" : "s"} ${out.workToName} can't work on moved to you`
          : ""
      }${
        out.handedOver
          ? `; ${out.handedOver} sign-off${out.handedOver === 1 ? "" : "s"} handed over`
          : ""
      }`,
    );
  } catch (err) {
    return failure(err, "removeUser");
  }
}

/** Cancel an invitation: the link stops working and its sign-offs go back to the department. */
export async function cancelInvitation(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ inviteId: z.string().uuid() }).strict().safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await peopleSession();
  if (!session) return fail(NOT_ALLOWED);
  try {
    const name = await db.transaction((tx) =>
      cancelInviteTx(tx, ctx(session), parsed.data.inviteId),
    );
    refresh();
    return success(undefined, `Invitation for ${name} cancelled`);
  } catch (err) {
    return failure(err, "cancelInvitation");
  }
}

/**
 * Send the invitation again with a fresh link (valid for another 14 days).
 * When email isn't set up, the new link comes back to pass on.
 */
export async function resendInvitation(
  input: unknown,
): Promise<ActionResult<{ emailed: boolean; inviteUrl?: string }>> {
  const parsed = z.object({ inviteId: z.string().uuid() }).strict().safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await peopleSession();
  if (!session) return fail(NOT_ALLOWED);
  try {
    const { invite, inviteUrl } = await db.transaction((tx) =>
      renewInviteLinkTx(tx, ctx(session), parsed.data.inviteId),
    );
    const delivery = await deliverInvite({
      email: invite.invitedEmail,
      name: invite.fullName,
      inviterName: inviterName(session),
      reason: `You've been added to the ${session.organisation.brandName} team as ${roleLabel(invite.role)}.`,
      inviteUrl,
      inviteId: invite.id,
    });
    refresh();
    return delivery.emailed
      ? success({ emailed: true }, `Invitation sent again to ${invite.invitedEmail}`)
      : success(
          { emailed: false, inviteUrl: delivery.fallbackUrl },
          "Email isn't set up here — send them this new link",
        );
  } catch (err) {
    return failure(err, "resendInvitation");
  }
}

/**
 * A new invitation link to pass on by hand (when email isn't set up). The
 * earlier link stops working: links are only stored as hashes.
 */
export async function newInvitationLink(
  input: unknown,
): Promise<ActionResult<{ inviteUrl: string }>> {
  const parsed = z.object({ inviteId: z.string().uuid() }).strict().safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await peopleSession();
  if (!session) return fail(NOT_ALLOWED);
  try {
    const { inviteUrl } = await db.transaction((tx) =>
      renewInviteLinkTx(tx, ctx(session), parsed.data.inviteId),
    );
    refresh();
    return success({ inviteUrl }, "New link ready — the earlier one no longer works");
  } catch (err) {
    return failure(err, "newInvitationLink");
  }
}

/** A new link for an external invitation nobody has accepted yet. */
export async function newExternalLink(
  input: unknown,
): Promise<ActionResult<{ inviteUrl: string }>> {
  const parsed = z.object({ grantId: z.string().uuid() }).strict().safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "partners.invite" })) {
    return fail(missingAbilityMessage("partners.invite"));
  }
  try {
    const inviteUrl = await db.transaction((tx) =>
      renewGrantLinkTx(tx, ctx(session), parsed.data.grantId),
    );
    refresh();
    return success({ inviteUrl }, "New link ready — the earlier one no longer works");
  } catch (err) {
    return failure(err, "newExternalLink");
  }
}

/**
 * Suspend someone: they can't sign in or be told about anything until
 * reactivated. Sign-offs waiting on them by name go to the person picked;
 * everything else stays as it is.
 */
export async function suspendUser(input: unknown): Promise<ActionResult<{ handedOver: number }>> {
  const parsed = z
    .object({
      userId: z.string().uuid(),
      handTo: handToSchema,
      handToUserId: z.string().uuid().nullish(),
    })
    .strict()
    .safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await peopleSession();
  if (!session) return fail(NOT_ALLOWED);
  try {
    const out = await db.transaction((tx) =>
      suspendMemberTx(tx, { ...ctx(session), actorName: inviterName(session) }, parsed.data),
    );
    refresh();
    revalidatePath("/", "layout");
    return success(
      { handedOver: out.handedOver },
      `${out.name} suspended${
        out.handedOver
          ? ` — ${out.handedOver} sign-off${out.handedOver === 1 ? "" : "s"} handed over`
          : ""
      }`,
    );
  } catch (err) {
    return failure(err, "suspendUser");
  }
}

/** Give a suspended person their access back, as it was. */
export async function reactivateUser(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ userId: z.string().uuid() }).strict().safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await peopleSession();
  if (!session) return fail(NOT_ALLOWED);
  try {
    const out = await db.transaction((tx) => reactivateMemberTx(tx, ctx(session), parsed.data));
    refresh();
    revalidatePath("/", "layout");
    return success(
      undefined,
      out.accessEnded
        ? `${out.name} reactivated — their access end date has passed, so set a new one to let them in`
        : `${out.name} can sign in again`,
    );
  } catch (err) {
    return failure(err, "reactivateUser");
  }
}

/**
 * Set or clear the London date someone's access ends (a team member or an
 * open invitation). Access lasts to the end of that day.
 */
export async function setAccessEnd(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({
      userId: z.string().uuid().optional(),
      inviteId: z.string().uuid().optional(),
      date: z
        .string()
        .regex(/^\d{4}-\d{2}-\d{2}$/, "Enter the end date as a date")
        .nullable(),
    })
    .strict()
    .refine((d) => Boolean(d.userId) !== Boolean(d.inviteId), "Choose a person")
    .safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0]?.message ?? "Invalid request");
  const session = await peopleSession();
  if (!session) return fail(NOT_ALLOWED);
  try {
    const out = await db.transaction((tx) => setAccessEndTx(tx, ctx(session), parsed.data));
    refresh();
    return success(
      undefined,
      out.endsAt ? `Saved — ${firstName(out.name)}'s access ends then` : "End date cleared",
    );
  } catch (err) {
    return failure(err, "setAccessEnd");
  }
}

// ---------------------------------------------------------------------------
// Add several people at once.
// ---------------------------------------------------------------------------

const pastedRowSchema = z
  .object({
    line: z.number().int().min(1).max(10_000),
    name: z.string().trim().max(200),
    email: z.string().trim().max(320),
    jobTitle: z
      .string()
      .trim()
      .max(200)
      .nullish()
      .transform((v) => v || null),
  })
  .strict();

/** What everyone pasted gets: department, role, sections, abilities and an end date. */
const sharedSchema = personSchema
  .pick({
    departmentId: true,
    newDepartmentName: true,
    role: true,
    features: true,
    abilities: true,
    accessEndsOn: true,
  })
  .strict();

export type PreviewInviteResult = { rows: PreviewRow[]; ready: number };

/** Check pasted people before inviting them (reads only): ready, or why not. */
export async function previewInviteUsers(
  input: unknown,
): Promise<ActionResult<PreviewInviteResult>> {
  const parsed = z
    .object({ rows: z.array(pastedRowSchema).min(1, "Paste at least one person").max(200) })
    .strict()
    .safeParse(input);
  if (!parsed.success) return invalid(parsed.error);
  const session = await peopleSession();
  if (!session) return fail(NOT_ALLOWED);
  try {
    const rows = await previewInviteRows(db, session.organisation.id, parsed.data.rows);
    return success({ rows, ready: rows.filter((r) => r.reason === "ready").length });
  } catch (err) {
    return failure(err, "previewInviteUsers");
  }
}

export type InviteUsersResult = {
  results: (InviteRowResult & { emailed?: boolean })[];
  invited: number;
};

/**
 * Invite up to 50 people with the same settings. Each person is checked and
 * saved on their own (one savepoint each) inside one transaction; emails go
 * out after it commits. When email isn't set up, each link comes back to
 * pass on.
 */
export async function inviteUsers(input: unknown): Promise<ActionResult<InviteUsersResult>> {
  const parsed = z
    .object({
      rows: z.array(pastedRowSchema).min(1, "Paste at least one person").max(200),
      shared: sharedSchema,
    })
    .strict()
    .safeParse(input);
  if (!parsed.success) return invalid(parsed.error);
  const session = await peopleSession();
  if (!session) return fail(NOT_ALLOWED);
  const shared = personData(parsed.data.shared);
  try {
    const out = await db.transaction((tx) =>
      inviteRowsTx(
        tx,
        { ...ctx(session), actorName: inviterName(session) },
        parsed.data.rows,
        shared,
      ),
    );
    const results: InviteUsersResult["results"] = [];
    for (const r of out.results) {
      if (!r.ok || !r.inviteId || !r.inviteUrl) {
        results.push(r);
        continue;
      }
      const delivery = await deliverInvite({
        email: r.email,
        name: r.name,
        inviterName: inviterName(session),
        reason: `You've been added to the ${session.organisation.brandName} team${
          out.departmentName ? ` (${out.departmentName})` : ""
        } as ${roleLabel(shared.role)}.`,
        inviteUrl: r.inviteUrl,
        inviteId: r.inviteId,
      });
      results.push({
        ...r,
        emailed: delivery.emailed,
        inviteUrl: delivery.emailed ? undefined : delivery.fallbackUrl,
      });
    }
    refresh();
    const invited = results.filter((r) => r.ok).length;
    return success(
      { results, invited },
      invited === 0
        ? "Nobody was invited — see why below"
        : `${invited} ${invited === 1 ? "person" : "people"} invited${
            invited < results.length ? ` · ${results.length - invited} left out` : ""
          }`,
    );
  } catch (err) {
    return failure(err, "inviteUsers");
  }
}

// ---------------------------------------------------------------------------
// The same change for several people (the list's bulk bar).
// ---------------------------------------------------------------------------

const BULK_USER_ACTIONS = ["resend", "suspend", "reactivate", "end_date", "cancel"] as const;
export type BulkUserAction = (typeof BULK_USER_ACTIONS)[number];

export type BulkUserRow = {
  id: string;
  name: string;
  ok: boolean;
  /** Why it was left alone, in a few words. */
  reason?: string;
  /** Resend with email off: the new link to pass on. */
  inviteUrl?: string;
};

export type BulkUsersResult = { done: number; failed: number; rows: BulkUserRow[] };

const VERB: Record<BulkUserAction, string> = {
  resend: "sent again",
  suspend: "suspended",
  reactivate: "reactivated",
  end_date: "given the end date",
  cancel: "cancelled",
};

/**
 * Resend, suspend, reactivate, set an end date or cancel for several
 * people. Each person runs on their own (own transaction, the same checks
 * and audit rows as doing it on their page); the result names everyone
 * left alone and why, so the list keeps them selected. Suspending here
 * hands sign-offs to each department's default (its main approver or
 * another approver); people with nobody to take them are left for their
 * own page.
 */
export async function bulkUsers(input: unknown): Promise<ActionResult<BulkUsersResult>> {
  const parsed = z
    .object({
      ids: z.array(z.string().uuid()).min(1, "Select someone first").max(200),
      action: z.enum(BULK_USER_ACTIONS),
      date: z
        .string()
        .regex(/^\d{4}-\d{2}-\d{2}$/, "Enter the end date as a date")
        .nullish(),
    })
    .strict()
    .safeParse(input);
  if (!parsed.success) return invalid(parsed.error);
  const session = await peopleSession();
  if (!session) return fail(NOT_ALLOWED);
  const { action, date } = parsed.data;
  if (action === "end_date" && date === undefined) return fail("Choose the date access ends");
  const c = { ...ctx(session), actorName: inviterName(session) };
  try {
    const out = await bulkPeople(db, c, { ids: parsed.data.ids, action, date });
    const rows: BulkUserRow[] = [];
    for (const r of out) {
      if (!r.ok || !r.invite || !r.inviteUrl) {
        rows.push({ id: r.id, name: r.name, ok: r.ok, reason: r.reason });
        continue;
      }
      // Resent: emails go out after each invitation's own transaction.
      const delivery = await deliverInvite({
        email: r.invite.email,
        name: r.invite.name,
        inviterName: c.actorName,
        reason: `You've been added to the ${session.organisation.brandName} team as ${roleLabel(r.invite.role)}.`,
        inviteUrl: r.inviteUrl,
        inviteId: r.id,
      });
      rows.push({
        id: r.id,
        name: r.name,
        ok: true,
        inviteUrl: delivery.emailed ? undefined : delivery.fallbackUrl,
      });
    }
    refresh();
    if (action === "suspend" || action === "reactivate") revalidatePath("/", "layout");
    const done = rows.filter((r) => r.ok).length;
    const failed = rows.length - done;
    const people = (n: number) => `${n} ${n === 1 ? "person" : "people"}`;
    return success(
      { done, failed, rows },
      done === 0
        ? `Nothing changed — ${people(failed)} left as they were`
        : `${people(done)} ${VERB[action]}${failed ? ` · ${people(failed)} left as they were` : ""}`,
    );
  } catch (err) {
    return failure(err, "bulkUsers");
  }
}
