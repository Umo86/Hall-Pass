"use server";

/**
 * Users: add people, change what they can do, suspend them, end their
 * access on a date, remove them, and manage invitation links. The database
 * work lives in lib/users/manage.ts; each action here parses, checks the
 * people action (people.manage for super admins and managers, users.manage
 * to remove), runs it in one transaction — where the per-person rules are
 * checked against the person as loaded — and revalidates.
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
  cancelInviteTx,
  inviteUserTx,
  reactivateMemberTx,
  removeMemberTx,
  renewGrantLinkTx,
  renewInviteLinkTx,
  setAccessEndTx,
  suspendMemberTx,
  updateInviteTx,
  updateMemberTx,
  UserError,
} from "@/lib/users/manage";
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
      delivery.emailed
        ? `Invitation sent to ${data.email}`
        : `${firstName(data.fullName)} added — send them the link`,
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
    return success(
      undefined,
      parsed.data.userId === session.user.id
        ? "Saved"
        : `Saved — ${firstName(out.name)} sees the change on their next page load`,
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
    return success(undefined, `Saved — ${firstName(out.name)} gets this when they accept`);
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
    .object({ userId: z.string().uuid(), handToUserId: z.string().uuid().nullish() })
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
    const moved = [
      out.tasks ? `${out.tasks} task${out.tasks === 1 ? "" : "s"}` : null,
      out.items ? `${out.items} item${out.items === 1 ? "" : "s"}` : null,
    ].filter(Boolean);
    return success(
      undefined,
      `${out.name} removed${moved.length ? ` — ${moved.join(" and ")} moved to you` : ""}${
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
    .object({ userId: z.string().uuid(), handToUserId: z.string().uuid().nullish() })
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
