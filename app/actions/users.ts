"use server";

/**
 * Users: add people, change what they can do, remove them, and manage
 * invitation links. The database work lives in lib/users/manage.ts; each
 * action here parses, checks users.manage, runs it in one transaction
 * (audit rows included) and revalidates.
 */
import { revalidatePath } from "next/cache";
import { unstable_rethrow } from "next/navigation";
import { z } from "zod";
import { db } from "@/lib/db/client";
import { can, FEATURES } from "@/lib/authz";
import { requireSession, type Session } from "@/lib/auth/actor";
import { deliverInvite } from "@/lib/auth/staff-invite";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { roleLabel } from "@/lib/format";
import { ABILITY_KEYS, firstName, STAFF_ROLES } from "@/lib/users/rules";
import {
  cancelInviteTx,
  inviteUserTx,
  removeMemberTx,
  renewGrantLinkTx,
  renewInviteLinkTx,
  updateInviteTx,
  updateMemberTx,
  UserError,
} from "@/lib/users/manage";

const NOT_ALLOWED = "Only admins manage users";

const abilitiesSchema = z
  .object(
    Object.fromEntries(ABILITY_KEYS.map((k) => [k, z.boolean().optional()])) as Record<
      (typeof ABILITY_KEYS)[number],
      z.ZodOptional<z.ZodBoolean>
    >,
  )
  .strict();

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

async function adminSession(): Promise<Session | null> {
  const session = await requireSession();
  return can(session.actor, { type: "users.manage" }) ? session : null;
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
  const session = await adminSession();
  if (!session) return fail(NOT_ALLOWED);
  const data = { ...parsed.data, role: parsed.data.role as Role };
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
  const session = await adminSession();
  if (!session) return fail(NOT_ALLOWED);
  try {
    const out = await db.transaction((tx) =>
      updateMemberTx(tx, ctx(session), { ...parsed.data, role: parsed.data.role as Role }),
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
  const session = await adminSession();
  if (!session) return fail(NOT_ALLOWED);
  try {
    const out = await db.transaction((tx) =>
      updateInviteTx(tx, ctx(session), { ...parsed.data, role: parsed.data.role as Role }),
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
  const session = await adminSession();
  if (!session) return fail(NOT_ALLOWED);
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
  const session = await adminSession();
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
  const session = await adminSession();
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
  const session = await adminSession();
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
  const session = await adminSession();
  if (!session) return fail("Only admins manage external access");
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
