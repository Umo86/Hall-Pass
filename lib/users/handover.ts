/**
 * Who takes over sign-offs that name someone when they are suspended,
 * removed or stop signing for a department. Pure — unit tested in
 * tests/unit/users-handover.test.ts; lib/users/manage.ts loads the steps
 * and signers and applies the result in the transaction.
 *
 * Sign-offs are grouped by the department they belong to. Each group goes
 * to someone who can sign for that department: by default its main
 * approver, else another of its approvers who can sign now; the person
 * making the change may pick someone else, or send the group back to the
 * whole department ("department"). Steps outside a department, and
 * departments with nobody else able to sign, need a person picked.
 */
import {
  can,
  signoffPaused,
  type Feature,
  type PermissionOverrides,
  type StaffActor,
  type StaffRole,
} from "@/lib/authz";

export type HandoverStep = {
  id: string;
  entityType: "signage_item" | "stand_submission";
  entityId: string;
  runNumber: number;
  /** pending = waiting on them now; waiting / changes_requested / decided = not started again yet. */
  status: string;
  stepName: string;
  ref: string;
  departmentId: string | null;
  /** The item's page, when it has one. */
  href: string | null;
};

export type HandoverSigner = { userId: string; name: string; isMain: boolean };

/** The choice for a group that sends it back to the whole department. */
export const BACK_TO_DEPARTMENT = "department";

export type HandoverGroup = {
  /** The department id, or "other". */
  key: string;
  departmentId: string | null;
  departmentName: string | null;
  steps: HandoverStep[];
  /** How many are waiting on them right now (the rest start later). */
  waitingNow: number;
  /** Others who can sign for this department now (main approver first). */
  signers: HandoverSigner[];
  /** A user id, BACK_TO_DEPARTMENT, or null when someone must be picked. */
  defaultTo: string | null;
};

/** Group key → a user id or BACK_TO_DEPARTMENT. */
export type HandoverChoice = Record<string, string>;

export const OTHER_GROUP = "other";

/** One group per department (in name order), then the steps outside any department. */
export function handoverGroups(
  steps: readonly HandoverStep[],
  opts: {
    departmentNames: ReadonlyMap<string, string>;
    /** Active signers per department, the person themselves left out. */
    signers: ReadonlyMap<string, readonly HandoverSigner[]>;
  },
): HandoverGroup[] {
  const byKey = new Map<string, HandoverStep[]>();
  for (const s of steps) {
    const key =
      s.departmentId && opts.departmentNames.has(s.departmentId) ? s.departmentId : OTHER_GROUP;
    byKey.set(key, [...(byKey.get(key) ?? []), s]);
  }
  const groups = [...byKey.entries()].map(([key, list]): HandoverGroup => {
    const departmentId = key === OTHER_GROUP ? null : key;
    const signers = departmentId
      ? [...(opts.signers.get(departmentId) ?? [])].sort(
          (a, b) => Number(b.isMain) - Number(a.isMain) || a.name.localeCompare(b.name, "en-GB"),
        )
      : [];
    return {
      key,
      departmentId,
      departmentName: departmentId ? (opts.departmentNames.get(departmentId) ?? null) : null,
      steps: [...list].sort((a, b) => a.ref.localeCompare(b.ref)),
      waitingNow: list.filter((s) => s.status === "pending").length,
      signers,
      defaultTo: signers[0]?.userId ?? null,
    };
  });
  return groups.sort((a, b) =>
    a.key === OTHER_GROUP
      ? 1
      : b.key === OTHER_GROUP
        ? -1
        : (a.departmentName ?? "").localeCompare(b.departmentName ?? "", "en-GB"),
  );
}

function sentence(n: number, who: string, dept: string | null): string {
  const what = n === 1 ? "A sign-off is" : `${n} sign-offs are`;
  return `${what} waiting on ${who}${dept ? ` (${dept})` : ""} — choose who takes ${n === 1 ? "it" : "them"} over`;
}

/**
 * Where each group goes: a user id, or null for "back to the department".
 * `fallback` is a single person picked for everything (older callers).
 * Refused with the words to show when a group has no one to go to, or the
 * person picked can't sign.
 */
export function resolveHandover(
  groups: readonly HandoverGroup[],
  choice: HandoverChoice | null | undefined,
  opts: {
    personId: string;
    who: string;
    canReceive: (userId: string) => boolean;
    fallback?: string | null;
  },
): { ok: true; targets: Map<string, string | null> } | { ok: false; error: string } {
  const targets = new Map<string, string | null>();
  for (const g of groups) {
    const picked = choice?.[g.key] || opts.fallback || g.defaultTo;
    if (!picked) return { ok: false, error: sentence(g.steps.length, opts.who, g.departmentName) };
    if (picked === BACK_TO_DEPARTMENT) {
      if (!g.departmentId || g.signers.length === 0) {
        return {
          ok: false,
          error: g.departmentName
            ? `Nobody else can sign off for ${g.departmentName} — choose a person`
            : "These sign-offs aren't a department's — choose a person",
        };
      }
      targets.set(g.key, null);
      continue;
    }
    if (picked === opts.personId || !opts.canReceive(picked)) {
      return { ok: false, error: "Pick a team member who can sign off" };
    }
    targets.set(g.key, picked);
  }
  return { ok: true, targets };
}

/** "Back to Marketing" / "Olivia Ops" — for the success message and audit. */
export function handoverTargetLabel(
  group: Pick<HandoverGroup, "departmentName">,
  target: string | null,
  names: ReadonlyMap<string, string>,
): string {
  if (target === null)
    return `everyone who signs off for ${group.departmentName ?? "the department"}`;
  return names.get(target) ?? "someone else";
}

// ---------------------------------------------------------------------------
// Items and tasks: who can take them over (removal), and what someone could
// no longer work on after a change to their role or sections (person page).
// ---------------------------------------------------------------------------

export type ItemKind = "signage" | "sponsorship_item" | "stand_design" | "stand_panel";

/** The section each kind of item lives in. */
export const ITEM_KIND_FEATURE: Record<ItemKind, Feature> = {
  signage: "signage",
  sponsorship_item: "sponsorship",
  stand_design: "stand_designs",
  stand_panel: "stand_designs",
};

export const ITEM_KIND_LABEL: Record<ItemKind, { one: string; many: string }> = {
  signage: { one: "sign", many: "signs" },
  sponsorship_item: { one: "sponsorship item", many: "sponsorship items" },
  stand_design: { one: "feature stand", many: "feature stands" },
  stand_panel: { one: "stand panel", many: "stand panels" },
};

/** Someone's access as these rules see it. */
export type WorkAccess = {
  role: StaffRole;
  features: readonly Feature[] | null;
  overrides?: PermissionOverrides | null;
};

function probe(a: WorkAccess): StaffActor {
  return {
    kind: "staff",
    userId: "person",
    organisationId: "org",
    role: a.role,
    features: a.features ? [...a.features] : null,
    overrides: a.overrides ?? {},
  };
}

/**
 * Could they work on an item of this kind they own: edit it, or (for
 * signage and sponsorship) upload artwork and send it for sign-off? Uses
 * can() with the item as theirs, so it follows the role and section rules.
 */
export function canWorkOwnItem(a: WorkAccess, kind: ItemKind): boolean {
  const actor = probe(a);
  const item = { editionId: "e", venueId: "v", kind, ownerUserId: actor.userId };
  return can(actor, { type: "signage.edit", item }) || can(actor, { type: "artwork.upload", item });
}

/** Can they still decide sign-offs handed to them (not a viewer, sign-off not paused)? */
export function canStillSign(a: WorkAccess): boolean {
  return a.role !== "viewer" && !signoffPaused(a.overrides);
}

/** The owned items they could work on before the change but not after it. */
export function itemsLostByChange<T extends { kind: ItemKind }>(
  items: readonly T[],
  before: WorkAccess,
  after: WorkAccess,
): T[] {
  const lost = new Map<ItemKind, boolean>();
  const check = (k: ItemKind) => {
    if (!lost.has(k)) lost.set(k, canWorkOwnItem(before, k) && !canWorkOwnItem(after, k));
    return lost.get(k)!;
  };
  return items.filter((i) => check(i.kind));
}
