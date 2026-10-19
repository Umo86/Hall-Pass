import "server-only";
import { cache } from "react";
import { and, count, desc, eq, gt, inArray, isNull, ne, or, sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  editionDeadlines,
  editions,
  events,
  externalGrants,
  halls,
  itemTypes,
  locations,
  memberships,
  signageItems,
  sponsors,
  sponsorshipPackages,
  staffInvites,
  suppliers,
  users,
  venues,
  workflows,
} from "@/lib/db/schema";
import { listDepartments } from "@/lib/domain/departments";
import { londonDateOfAccessEnd } from "@/lib/access";
import type { CopyableGrant } from "@/lib/copy-access";
import {
  DEADLINE_KEYS,
  DEADLINE_LABELS,
  DEFAULT_DEADLINE_OFFSETS,
  deadlineDate,
  diffDaysIso,
  type DeadlineKey,
} from "@/lib/deadlines";
import { formatDate, plural } from "@/lib/format";
import {
  abilityOn,
  can,
  canExtendToCopy,
  EVENT_SETUP_ABILITIES,
  seesEdition,
  type Action,
  type Actor,
  type EditionScope,
  type PermissionOverrides,
} from "@/lib/authz";
import { activeMembership } from "@/lib/users/active";
import { editionScopeSql } from "./edition-scope";

/*
 * Event setup: the checklist on /CODE/setup, the "Setup 3/6" pill in the nav
 * and the cards on the dashboard and the Events list all come from here.
 * The facts are loaded with a fixed number of grouped count queries (however
 * many events are asked about); turning them into steps is pure.
 */

export const SETUP_STEP_KEYS = [
  "details",
  "halls",
  "deadlines",
  "signoff",
  "people",
  "types",
  "suppliers",
  "signs",
  "sponsorship",
] as const;
export type SetupStepKey = (typeof SETUP_STEP_KEYS)[number];

/** Steps confirmed by hand (kept in editions.setup_checked), plus "dismissed" for the dashboard card. */
export const CONFIRMABLE_STEPS = ["details", "deadlines", "dismissed"] as const;
export type ConfirmableStep = (typeof CONFIRMABLE_STEPS)[number];

export type SetupState = "done" | "todo" | "waiting" | "optional";
export type SetupLevel = "essential" | "recommended" | "optional";

export type SetupStep = {
  key: SetupStepKey;
  title: string;
  /** One line: why it matters. */
  reason: string;
  level: SetupLevel;
  required: boolean;
  state: SetupState;
  /** One line built from the data ("2 halls · 12 locations"). */
  detail: string;
  /** Where the step is done, when it isn't done on the setup page itself. */
  href: string | null;
  /** Can the person looking do this step? */
  canAct: boolean;
  /** Shared by every event of the organisation (departments, people, types). */
  shared: boolean;
};

export type SignoffDepartmentFact = {
  name: string;
  /** Signs organiser signage by default, so it must have someone who can sign. */
  forOrganiser: boolean;
  approvers: {
    name: string;
    email: string;
    isMain: boolean;
    /** Invited: takes over as main approver when they accept (doesn't route anything yet). */
    mainOnAccept?: boolean;
    active: boolean;
    /**
     * Events they work on (Users → Events; invited: what their invitation
     * gives); null/missing = every event. Someone who won't see an event
     * doesn't count for it.
     */
    editionIds?: readonly string[] | null;
  }[];
};

export type OrgSetupFacts = {
  signageWorkflow: boolean;
  /** Live departments that sign off (not archived, signs-off on). */
  signoffDepartments: SignoffDepartmentFact[];
  memberCount: number;
  openInviteCount: number;
  signTypeCount: number;
  supplierCount: number;
};

export type EditionSetupFacts = {
  setupChecked: string[];
  dates: { buildStart: string; openStart: string; openEnd: string; breakdownEnd: string };
  copied: boolean;
  halls: { name: string; locations: number }[];
  signCount: number;
  draftSignCount: number;
  sponsorCount: number;
  /** Live sponsorship packages (optional for older callers: none). */
  packageCount?: number;
  sponsorshipItemCount: number;
  deadlines: { key: DeadlineKey; label: string; date: string | null }[];
};

/** Whether this person can act on each step (each by its own ability). */
export type SetupPermissions = Record<SetupStepKey, boolean>;

/** The ability behind each setup step. */
export const SETUP_STEP_ACTION = {
  details: "events.edit",
  halls: "halls.manage",
  deadlines: "events.edit",
  signoff: "departments.manage",
  people: "people.manage",
  types: "lists.manage",
  suppliers: "suppliers.manage",
  signs: "signage.create",
  sponsorship: "sponsorship.create",
} as const satisfies Record<SetupStepKey, Action["type"]>;

/**
 * What this person can do on each step. On an archived (read-only) event
 * only the shared people and sign-off steps stay open.
 */
export function setupPermissionsFor(
  actor: Actor,
  opts: { readOnly?: boolean } = {},
): SetupPermissions {
  return Object.fromEntries(
    SETUP_STEP_KEYS.map((key) => [
      key,
      (!opts.readOnly || key === "signoff" || key === "people") &&
        can(actor, { type: SETUP_STEP_ACTION[key] } as Action),
    ]),
  ) as SetupPermissions;
}

function hasChecked(facts: EditionSetupFacts, key: ConfirmableStep) {
  return facts.setupChecked.includes(key);
}

/** "Operations, Marketing and Sales". */
function listNames(names: string[]): string {
  if (names.length <= 1) return names.join("");
  return `${names.slice(0, -1).join(", ")} and ${names.at(-1)}`;
}

/**
 * Sign-off is ready when the workflow exists, at least one department signs
 * off, and every department that signs organiser signage by default has
 * someone with an account who can sign (its main approver, or anyone in it
 * when none is starred — that is how sign-offs are routed). Someone added by
 * email who hasn't accepted yet makes it "waiting".
 */
export function signoffState(
  org: OrgSetupFacts,
  /** The event the checklist is for: only approvers who can open it count. */
  editionId?: string | null,
): { state: SetupState; detail: string } {
  if (!org.signageWorkflow) return { state: "todo", detail: "Sign-off hasn't been set up yet" };
  if (org.signoffDepartments.length === 0) {
    return { state: "todo", detail: "No department signs off artwork yet" };
  }
  const needed = org.signoffDepartments.filter((d) => d.forOrganiser);
  if (needed.length === 0) {
    return { state: "todo", detail: "Choose which departments sign off organiser signage" };
  }
  const empty = needed.filter((d) => d.approvers.length === 0);
  if (empty.length > 0) {
    return {
      state: "todo",
      detail: `${listNames(empty.map((d) => d.name))}: nobody to sign off yet`,
    };
  }
  // Users → Events: someone who won't see this event can't sign for it.
  const sees = (a: SignoffDepartmentFact["approvers"][number]) =>
    !editionId || a.editionIds == null || a.editionIds.includes(editionId);
  const blind = needed.filter((d) => !d.approvers.some(sees));
  if (blind.length > 0) {
    return {
      state: "todo",
      detail: `${listNames(blind.map((d) => d.name))}: nobody who signs off can open this event — give one of them this event under Users`,
    };
  }
  const notReady = needed.filter((d) => {
    const here = d.approvers.filter(sees);
    const main = here.find((a) => a.isMain);
    return main ? !main.active && !here.some((a) => a.active) : !here.some((a) => a.active);
  });
  if (notReady.length > 0) {
    const waitingFor = notReady.map((d) => {
      const here = d.approvers.filter(sees);
      return (here.find((a) => a.isMain) ?? here[0]).email;
    });
    return {
      state: "waiting",
      detail: `Waiting for ${listNames(waitingFor)} to accept ${waitingFor.length === 1 ? "their invitation" : "their invitations"}`,
    };
  }
  return {
    state: "done",
    detail: `${listNames(org.signoffDepartments.map((d) => d.name))} sign${org.signoffDepartments.length === 1 ? "s" : ""} off`,
  };
}

function hallsState(facts: EditionSetupFacts): { done: boolean; detail: string } {
  if (facts.halls.length === 0) return { done: false, detail: "No halls yet" };
  const bare = facts.halls.filter((h) => h.locations === 0);
  const locationCount = facts.halls.reduce((n, h) => n + h.locations, 0);
  if (bare.length > 0) {
    return {
      done: false,
      detail:
        bare.length === 1
          ? `${bare[0].name} has no locations yet`
          : `${listNames(bare.map((h) => h.name))} have no locations yet`,
    };
  }
  return {
    done: true,
    detail: `${plural(facts.halls.length, "hall")} · ${plural(locationCount, "location")}`,
  };
}

/** Turn the facts into the checklist, in order. Pure. */
export function buildSetupSteps(
  edition: { code: string; id?: string },
  facts: EditionSetupFacts,
  org: OrgSetupFacts,
  perms: SetupPermissions,
): SetupStep[] {
  const code = edition.code;
  const state = (done: boolean, level: SetupLevel): SetupState =>
    done ? "done" : level === "optional" ? "optional" : "todo";
  const halls = hallsState(facts);
  const signoff = signoffState(org, edition.id);
  const artwork = facts.deadlines.find((d) => d.key === "artwork_due");
  const print = facts.deadlines.find((d) => d.key === "print_deadline");
  const deadlineDetail = [
    artwork?.date ? `Artwork due ${formatDate(artwork.date)}` : null,
    print?.date ? `Print ${formatDate(print.date)}` : null,
  ]
    .filter(Boolean)
    .join(" · ");
  const sponsorParts = [
    (facts.packageCount ?? 0) > 0 ? plural(facts.packageCount ?? 0, "package") : null,
    facts.sponsorCount > 0 ? plural(facts.sponsorCount, "sponsor") : null,
    facts.sponsorshipItemCount > 0 ? plural(facts.sponsorshipItemCount, "sponsorship item") : null,
  ].filter(Boolean);

  const steps: SetupStep[] = [
    {
      key: "details",
      title: "Dates, venue and budget",
      reason: "Everything else is timed from these.",
      level: "essential",
      required: true,
      state: state(hasChecked(facts, "details"), "essential"),
      detail: hasChecked(facts, "details")
        ? `Build-up from ${formatDate(facts.dates.buildStart)} · open ${formatDate(facts.dates.openStart)} – ${formatDate(facts.dates.openEnd)}`
        : "Build-up and breakdown dates were assumed — check them",
      href: `/${code}/setup#details`,
      canAct: perms.details,
      shared: false,
    },
    {
      key: "halls",
      title: "Halls and locations",
      reason: "Every sign needs a hall and location before it can go for sign-off.",
      level: "essential",
      required: true,
      state: state(halls.done, "essential"),
      detail: halls.detail,
      href: `/${code}/halls`,
      canAct: perms.halls,
      shared: false,
    },
    {
      key: "deadlines",
      title: "Deadlines",
      reason: "Artwork, print and delivery reminders go out against these.",
      level: "essential",
      required: true,
      state: state(hasChecked(facts, "deadlines"), "essential"),
      detail: deadlineDetail || "No deadlines set",
      href: `/${code}/setup#deadlines`,
      canAct: perms.deadlines,
      shared: false,
    },
    {
      key: "signoff",
      title: "Who signs off",
      reason: "The departments that approve artwork. Shared by every event.",
      level: "essential",
      required: true,
      state: signoff.state,
      detail: signoff.detail,
      href: "/users?tab=departments",
      canAct: perms.signoff,
      shared: true,
    },
    {
      key: "people",
      title: "People",
      reason: "Invite the colleagues who'll add signs and approve them.",
      level: "recommended",
      required: false,
      state: state(org.memberCount >= 2 || org.openInviteCount >= 1, "recommended"),
      detail: [
        plural(org.memberCount, "person", "people"),
        org.openInviteCount > 0 ? `${plural(org.openInviteCount, "invitation")} open` : null,
      ]
        .filter(Boolean)
        .join(" · "),
      href: "/users/new",
      canAct: perms.people,
      shared: true,
    },
    {
      key: "types",
      title: "Sign types",
      reason: "The list people pick from when adding a sign.",
      level: "essential",
      required: true,
      state: state(org.signTypeCount >= 1, "essential"),
      detail: org.signTypeCount > 0 ? plural(org.signTypeCount, "sign type") : "No sign types yet",
      href: "/settings/item-types",
      canAct: perms.types,
      shared: true,
    },
    {
      key: "suppliers",
      title: "Suppliers",
      reason: "Printers and installers you send work to.",
      level: "optional",
      required: false,
      state: state(org.supplierCount >= 1, "optional"),
      detail: org.supplierCount > 0 ? plural(org.supplierCount, "supplier") : "None yet",
      href: "/suppliers",
      canAct: perms.suppliers,
      shared: true,
    },
    {
      key: "signs",
      title: "First signs",
      reason: "Add them one by one or import your spreadsheet.",
      level: "essential",
      required: true,
      state: state(facts.signCount >= 1, "essential"),
      detail:
        facts.signCount === 0
          ? "No signs yet"
          : facts.copied && facts.draftSignCount === facts.signCount
            ? `${plural(facts.signCount, "sign")} copied as drafts — review them`
            : plural(facts.signCount, "sign"),
      href: `/${code}/signage/new`,
      canAct: perms.signs,
      shared: false,
    },
    {
      key: "sponsorship",
      title: "Sponsorship",
      reason: "Sponsors and the items they've bought.",
      level: "optional",
      required: false,
      state: state(sponsorParts.length > 0, "optional"),
      detail: sponsorParts.length > 0 ? sponsorParts.join(" · ") : "None yet",
      href: `/${code}/sponsorship`,
      canAct: perms.sponsorship,
      shared: false,
    },
  ];
  return steps;
}

export type SetupSummary = {
  done: number;
  total: number;
  complete: boolean;
  /** The first essential step still to do (or waiting). */
  next: SetupStep | null;
};

/** Progress over the essential steps. Pure. */
export function summariseSetup(steps: SetupStep[]): SetupSummary {
  const essential = steps.filter((s) => s.required);
  const done = essential.filter((s) => s.state === "done").length;
  return {
    done,
    total: essential.length,
    complete: done === essential.length,
    next: essential.find((s) => s.state !== "done") ?? null,
  };
}

// ---------------------------------------------------------------- database

/** How many events the organisation has (of the viewer's, Users → Events): not archived, and in all. */
export async function countEvents(
  organisationId: string,
  scope: EditionScope,
): Promise<{ active: number; total: number }> {
  const [row] = await db
    .select({
      total: count(),
      active: sql<number>`(count(*) filter (where ${editions.status} <> 'archived'))::int`,
    })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(events.organisationId, organisationId), editionScopeSql(scope, editions.id)));
  return { active: Number(row?.active ?? 0), total: Number(row?.total ?? 0) };
}

/** Events that aren't archived (of the viewer's) — none means the organisation hasn't started. */
export async function countActiveEvents(
  organisationId: string,
  scope: EditionScope,
): Promise<number> {
  const [row] = await db
    .select({ n: count() })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(
      and(
        eq(events.organisationId, organisationId),
        ne(editions.status, "archived"),
        editionScopeSql(scope, editions.id),
      ),
    );
  return Number(row?.n ?? 0);
}

/** The organisation-wide facts (one query each, run together). */
export async function loadOrgSetupFacts(organisationId: string): Promise<OrgSetupFacts> {
  const [flow, depts, [members], [invites], [types], [supplierRows], inviteEvents] =
    await Promise.all([
      db
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
        .limit(1),
      listDepartments(db, organisationId),
      db
        .select({ n: count() })
        .from(memberships)
        .where(eq(memberships.organisationId, organisationId)),
      db
        .select({ n: count() })
        .from(staffInvites)
        .where(
          and(
            eq(staffInvites.organisationId, organisationId),
            isNull(staffInvites.acceptedAt),
            isNull(staffInvites.revokedAt),
            or(isNull(staffInvites.expiresAt), gt(staffInvites.expiresAt, new Date())),
          ),
        ),
      db
        .select({ n: count() })
        .from(itemTypes)
        .where(
          and(
            eq(itemTypes.organisationId, organisationId),
            eq(itemTypes.kind, "signage"),
            eq(itemTypes.isArchived, false),
          ),
        ),
      db
        .select({ n: count() })
        .from(suppliers)
        .where(and(eq(suppliers.organisationId, organisationId), eq(suppliers.isArchived, false))),
      // C11: an approver added by email gets the events their open invitation gives.
      db
        .select({
          email: staffInvites.invitedEmail,
          role: staffInvites.role,
          editionIds: staffInvites.editionIds,
        })
        .from(staffInvites)
        .where(
          and(
            eq(staffInvites.organisationId, organisationId),
            isNull(staffInvites.acceptedAt),
            isNull(staffInvites.revokedAt),
          ),
        ),
    ]);
  const invitedEvents = new Map(
    inviteEvents.map((i) => [
      i.email.toLowerCase(),
      i.role === "admin" ? null : (i.editionIds ?? null),
    ]),
  );
  return {
    signageWorkflow: flow.length > 0,
    signoffDepartments: depts
      .filter((d) => !d.isArchived && d.signsOff)
      .map((d) => ({
        name: d.name,
        forOrganiser: d.defaultFor.includes("organiser"),
        approvers: d.approvers.map((a) => ({
          name: a.fullName,
          email: a.email,
          isMain: a.isMain,
          mainOnAccept: a.mainOnAccept,
          active: a.active,
          editionIds: a.userId ? a.editionIds : (invitedEvents.get(a.email.toLowerCase()) ?? null),
        })),
      })),
    memberCount: Number(members?.n ?? 0),
    openInviteCount: Number(invites?.n ?? 0),
    signTypeCount: Number(types?.n ?? 0),
    supplierCount: Number(supplierRows?.n ?? 0),
  };
}

type EditionRowForSetup = Pick<
  typeof editions.$inferSelect,
  | "id"
  | "setupChecked"
  | "buildStart"
  | "openStart"
  | "openEnd"
  | "breakdownEnd"
  | "clonedFromEditionId"
>;

/** Per-event facts for several events at once (four grouped queries). */
export async function loadEditionSetupFacts(
  rows: readonly EditionRowForSetup[],
): Promise<Map<string, EditionSetupFacts>> {
  const ids = rows.map((r) => r.id);
  const out = new Map<string, EditionSetupFacts>();
  if (ids.length === 0) return out;
  const [hallRows, itemRows, sponsorRows, deadlineRows, packageRows] = await Promise.all([
    db
      .select({
        editionId: halls.editionId,
        name: halls.name,
        sortOrder: halls.sortOrder,
        n: count(locations.id),
      })
      .from(halls)
      .leftJoin(locations, eq(locations.hallId, halls.id))
      .where(inArray(halls.editionId, ids))
      .groupBy(halls.id)
      .orderBy(halls.sortOrder, halls.name),
    db
      .select({
        editionId: signageItems.editionId,
        kind: signageItems.kind,
        draft: sql<boolean>`${signageItems.status} = 'draft'`,
        n: count(),
      })
      .from(signageItems)
      .where(and(inArray(signageItems.editionId, ids), isNull(signageItems.deletedAt)))
      .groupBy(signageItems.editionId, signageItems.kind, sql`${signageItems.status} = 'draft'`),
    db
      .select({ editionId: sponsors.editionId, n: count() })
      .from(sponsors)
      .where(inArray(sponsors.editionId, ids))
      .groupBy(sponsors.editionId),
    db.select().from(editionDeadlines).where(inArray(editionDeadlines.editionId, ids)),
    db
      .select({ editionId: sponsorshipPackages.editionId, n: count() })
      .from(sponsorshipPackages)
      .where(
        and(inArray(sponsorshipPackages.editionId, ids), eq(sponsorshipPackages.isArchived, false)),
      )
      .groupBy(sponsorshipPackages.editionId),
  ]);
  for (const r of rows) {
    const items = itemRows.filter((i) => i.editionId === r.id);
    const signs = items.filter((i) => i.kind === "signage");
    out.set(r.id, {
      setupChecked: r.setupChecked ?? [],
      dates: {
        buildStart: r.buildStart,
        openStart: r.openStart,
        openEnd: r.openEnd,
        breakdownEnd: r.breakdownEnd,
      },
      copied: Boolean(r.clonedFromEditionId),
      halls: hallRows
        .filter((h) => h.editionId === r.id)
        .map((h) => ({ name: h.name, locations: Number(h.n) })),
      signCount: signs.reduce((n, i) => n + Number(i.n), 0),
      draftSignCount: signs.filter((i) => i.draft).reduce((n, i) => n + Number(i.n), 0),
      sponsorCount: Number(sponsorRows.find((s) => s.editionId === r.id)?.n ?? 0),
      packageCount: Number(packageRows.find((p) => p.editionId === r.id)?.n ?? 0),
      sponsorshipItemCount: items
        .filter((i) => i.kind === "sponsorship_item")
        .reduce((n, i) => n + Number(i.n), 0),
      deadlines: deadlineRows
        .filter((d) => d.editionId === r.id)
        .map((d) => ({
          key: d.key,
          label: d.label,
          date: deadlineDate(r.buildStart, d.daysBeforeBuildStart, d.overrideDate),
        }))
        .sort((a, b) => DEADLINE_KEYS.indexOf(a.key) - DEADLINE_KEYS.indexOf(b.key)),
    });
  }
  return out;
}

/**
 * The facts behind the checklist, loaded once per request (React cache):
 * the layout's "Setup 3/6" and the Dashboard or Setup page under it share
 * them instead of running the same queries twice. Keyed by value, so the
 * same event row from two loaders hits the same entry.
 */
const orgSetupFactsForRequest = cache((organisationId: string) =>
  loadOrgSetupFacts(organisationId),
);
const editionSetupFactsForRequest = cache(async (key: string) => {
  const row = JSON.parse(key) as EditionRowForSetup;
  return (await loadEditionSetupFacts([row])).get(row.id)!;
});

/** The checklist for one event (one round of queries per request). */
export async function getSetupStatus(
  edition: EditionRowForSetup & { code: string },
  organisationId: string,
  perms: SetupPermissions,
): Promise<{
  steps: SetupStep[];
  summary: SetupSummary;
  org: OrgSetupFacts;
  facts: EditionSetupFacts;
}> {
  const key: EditionRowForSetup = {
    id: edition.id,
    setupChecked: edition.setupChecked ?? [],
    buildStart: edition.buildStart,
    openStart: edition.openStart,
    openEnd: edition.openEnd,
    breakdownEnd: edition.breakdownEnd,
    clonedFromEditionId: edition.clonedFromEditionId,
  };
  const [org, facts] = await Promise.all([
    orgSetupFactsForRequest(organisationId),
    editionSetupFactsForRequest(JSON.stringify(key)),
  ]);
  const steps = buildSetupSteps(edition, facts, org, perms);
  return { steps, summary: summariseSetup(steps), org, facts };
}

/** Progress for several events (the Events list), same number of queries. */
export async function getSetupSummaries(
  rows: readonly (EditionRowForSetup & { code: string })[],
  organisationId: string,
  perms: SetupPermissions,
): Promise<Map<string, SetupSummary>> {
  const out = new Map<string, SetupSummary>();
  if (rows.length === 0) return out;
  const [org, facts] = await Promise.all([
    loadOrgSetupFacts(organisationId),
    loadEditionSetupFacts(rows),
  ]);
  for (const r of rows) {
    out.set(r.id, summariseSetup(buildSetupSteps(r, facts.get(r.id)!, org, perms)));
  }
  return out;
}

/**
 * Who to ask about setting things up: people with access (not suspended,
 * access not ended) who hold the ability the page needs — creating events
 * by default, or any of the event setup abilities — super admins first;
 * the organisation's super admins with access when nobody else holds it.
 */
export async function setupContacts(
  organisationId: string,
  need: "events.create" | "event.setup" = "events.create",
  /** For one event: only people who can open it (Users → Events). */
  opts: { editionId?: string | null } = {},
): Promise<{ name: string; email: string; role: string }[]> {
  const rows = await db
    .select({
      name: users.fullName,
      email: users.email,
      role: memberships.role,
      overrides: memberships.permissionOverrides,
      editionIds: memberships.editionIds,
    })
    .from(memberships)
    .innerJoin(users, eq(memberships.userId, users.id))
    .where(and(eq(memberships.organisationId, organisationId), activeMembership()))
    .orderBy(users.fullName);
  const holds = (r: (typeof rows)[number]) => {
    const holder = {
      role: r.role,
      overrides: r.overrides as PermissionOverrides,
      editionIds: r.editionIds,
    };
    if (opts.editionId && !seesEdition(holder, opts.editionId)) return false;
    return need === "events.create"
      ? abilityOn(holder, "events.create")
      : EVENT_SETUP_ABILITIES.some((k) => abilityOn(holder, k));
  };
  const picked = rows.filter(holds);
  const contacts = picked.length > 0 ? picked : rows.filter((r) => r.role === "admin");
  return contacts
    .sort((a, b) => Number(b.role === "admin") - Number(a.role === "admin"))
    .map((r) => ({ name: r.name || r.email, email: r.email, role: r.role }));
}

/** Every deadline for the setup form; missing rows take the standard offsets. */
export async function deadlinesForSetup(editionId: string) {
  const rows = await db
    .select()
    .from(editionDeadlines)
    .where(eq(editionDeadlines.editionId, editionId));
  return DEADLINE_KEYS.map((key) => {
    const row = rows.find((r) => r.key === key);
    return {
      key,
      label: DEADLINE_LABELS[key],
      daysBeforeBuildStart: row?.daysBeforeBuildStart ?? DEFAULT_DEADLINE_OFFSETS[key],
      overrideDate: row?.overrideDate ?? null,
    };
  });
}

/** Hall and location rows for the halls editor, with sign counts. */
export async function hallsEditorData(editionId: string) {
  const live = and(eq(signageItems.editionId, editionId), isNull(signageItems.deletedAt));
  const [hallRows, locationRows, byHall, byLocation, unplaced] = await Promise.all([
    db
      .select()
      .from(halls)
      .where(eq(halls.editionId, editionId))
      .orderBy(halls.sortOrder, halls.name),
    db
      .select({ loc: locations })
      .from(locations)
      .innerJoin(halls, eq(locations.hallId, halls.id))
      .where(eq(halls.editionId, editionId))
      .orderBy(locations.name),
    db
      .select({ id: signageItems.hallId, n: count() })
      .from(signageItems)
      .where(live)
      .groupBy(signageItems.hallId),
    db
      .select({ id: signageItems.locationId, n: count() })
      .from(signageItems)
      .where(live)
      .groupBy(signageItems.locationId),
    db
      .select({ id: signageItems.hallId, n: count() })
      .from(signageItems)
      .where(and(live, isNull(signageItems.locationId)))
      .groupBy(signageItems.hallId),
  ]);
  const hallCounts = new Map(byHall.map((r) => [r.id, Number(r.n)]));
  const locCounts = new Map(byLocation.map((r) => [r.id, Number(r.n)]));
  const unplacedCounts = new Map(unplaced.map((r) => [r.id, Number(r.n)]));
  const zones = [
    ...new Set(locationRows.map(({ loc }) => loc.zone?.trim()).filter((z): z is string => !!z)),
  ].sort((a, b) => a.localeCompare(b));
  return {
    zones,
    halls: hallRows.map((h) => ({
      id: h.id,
      name: h.name,
      itemCount: hallCounts.get(h.id) ?? 0,
      unplacedCount: unplacedCounts.get(h.id) ?? 0,
      locations: locationRows
        .filter(({ loc }) => loc.hallId === h.id)
        .map(({ loc }) => ({
          id: loc.id,
          name: loc.name,
          zone: loc.zone,
          itemCount: locCounts.get(loc.id) ?? 0,
        })),
    })),
  };
}

/**
 * Earlier events at the same venue that have halls, newest first, to copy
 * halls and locations from.
 */
export async function hallCopySources(
  organisationId: string,
  target: { id: string; venueId: string },
  /** The viewer's events (Users → Events): only events they can open are offered. */
  scope: EditionScope,
) {
  const rows = await db
    .select({
      id: editions.id,
      name: editions.name,
      code: editions.code,
      openStart: editions.openStart,
      halls: sql<number>`count(distinct ${halls.id})`,
      locations: sql<number>`count(${locations.id})`,
    })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .innerJoin(halls, eq(halls.editionId, editions.id))
    .leftJoin(locations, eq(locations.hallId, halls.id))
    .where(
      and(
        eq(events.organisationId, organisationId),
        eq(editions.venueId, target.venueId),
        ne(editions.id, target.id),
        editionScopeSql(scope, editions.id),
      ),
    )
    .groupBy(editions.id)
    .orderBy(desc(editions.openStart));
  return rows.map((r) => ({
    id: r.id,
    name: r.name,
    code: r.code,
    halls: Number(r.halls),
    locations: Number(r.locations),
  }));
}

/** Venues for pickers: most recently used first, archived ones left out. */
export async function venuesForPicker(organisationId: string) {
  const rows = await db
    .select({
      id: venues.id,
      name: venues.name,
      address: venues.address,
      lastUsed: sql<string | null>`max(${editions.openStart})`,
    })
    .from(venues)
    .leftJoin(editions, eq(editions.venueId, venues.id))
    .where(and(eq(venues.organisationId, organisationId), eq(venues.isArchived, false)))
    .groupBy(venues.id)
    .orderBy(sql`max(${editions.openStart}) desc nulls last`, venues.name);
  return rows.map((r) => ({ id: r.id, name: r.name, address: r.address }));
}

/**
 * What each earlier event would bring across when copied, for the "Copy a
 * previous event" form: one grouped query per kind of record. `viewer` is
 * who copies: people limited to a source (Users → Events) whom they may
 * change get the copy too ("people"); the rest are counted ("peopleLeftOut").
 */
export async function copySourceCounts(organisationId: string, viewer: Actor) {
  const orgEditions = db
    .select({ id: editions.id })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(eq(events.organisationId, organisationId));
  const [hallRows, deadlineRows, sponsorRows, itemRows, grantRows, packageRows] = await Promise.all(
    [
      db
        .select({
          editionId: halls.editionId,
          halls: sql<number>`count(distinct ${halls.id})`,
          locations: sql<number>`count(${locations.id})`,
        })
        .from(halls)
        .leftJoin(locations, eq(locations.hallId, halls.id))
        .where(inArray(halls.editionId, orgEditions))
        .groupBy(halls.editionId),
      db
        .select({ editionId: editionDeadlines.editionId, n: count() })
        .from(editionDeadlines)
        .where(inArray(editionDeadlines.editionId, orgEditions))
        .groupBy(editionDeadlines.editionId),
      db
        .select({ editionId: sponsors.editionId, n: count() })
        .from(sponsors)
        .where(inArray(sponsors.editionId, orgEditions))
        .groupBy(sponsors.editionId),
      db
        .select({ editionId: signageItems.editionId, n: count() })
        .from(signageItems)
        .where(and(inArray(signageItems.editionId, orgEditions), isNull(signageItems.deletedAt)))
        .groupBy(signageItems.editionId),
      // Every grant that isn't revoked, ended ones included: cloneEdition
      // copies those too, with the end date moved to the new event.
      db
        .select({
          editionId: externalGrants.editionId,
          scopeType: externalGrants.scopeType,
          scopeId: externalGrants.scopeId,
          role: externalGrants.role,
          expiresAt: externalGrants.expiresAt,
          userId: externalGrants.userId,
          email: externalGrants.invitedEmail,
          venueId: editions.venueId,
          breakdownEnd: editions.breakdownEnd,
        })
        .from(externalGrants)
        .innerJoin(editions, eq(editions.id, externalGrants.editionId))
        .where(
          and(eq(externalGrants.organisationId, organisationId), isNull(externalGrants.revokedAt)),
        ),
      // Live sponsorship packages: what cloneEdition brings across.
      db
        .select({ editionId: sponsorshipPackages.editionId, n: count() })
        .from(sponsorshipPackages)
        .where(
          and(
            inArray(sponsorshipPackages.editionId, orgEditions),
            eq(sponsorshipPackages.isArchived, false),
          ),
        )
        .groupBy(sponsorshipPackages.editionId),
    ],
  );
  const [liveSupplierRows, teamRows, limitedInvites] = await Promise.all([
    db
      .select({ id: suppliers.id })
      .from(suppliers)
      .where(and(eq(suppliers.organisationId, organisationId), eq(suppliers.isArchived, false))),
    db
      .select({
        userId: memberships.userId,
        email: users.email,
        role: memberships.role,
        departmentId: memberships.departmentId,
        managerScope: memberships.managerScope,
        editionIds: memberships.editionIds,
      })
      .from(memberships)
      .innerJoin(users, eq(users.id, memberships.userId))
      .where(eq(memberships.organisationId, organisationId)),
    db
      .select({
        role: staffInvites.role,
        departmentId: staffInvites.departmentId,
        managerScope: staffInvites.managerScope,
        editionIds: staffInvites.editionIds,
      })
      .from(staffInvites)
      .where(
        and(
          eq(staffInvites.organisationId, organisationId),
          isNull(staffInvites.acceptedAt),
          isNull(staffInvites.revokedAt),
          sql`${staffInvites.editionIds} IS NOT NULL`,
        ),
      ),
  ]);
  // Everyone (and every open invitation) limited to some events — not the
  // viewer, who gets the copy anyway when limited (as cloneEdition counts).
  const limited = [
    ...teamRows
      .filter((r) => r.role !== "admin" && r.editionIds && r.userId !== viewer.userId)
      .map((r) => ({
        editionIds: r.editionIds!,
        ctx: {
          organisationId,
          userId: r.userId,
          role: r.role,
          departmentId: r.departmentId,
          managerScope: r.managerScope,
        },
      })),
    ...limitedInvites
      .filter((r) => r.role !== "admin")
      .map((r) => ({
        editionIds: r.editionIds!,
        ctx: {
          organisationId,
          userId: null,
          role: r.role,
          departmentId: r.departmentId,
          managerScope: r.managerScope,
        },
      })),
  ];
  const liveSuppliers = new Set(liveSupplierRows.map((r) => r.id));
  const teamIds = new Set(teamRows.map((r) => r.userId));
  const teamEmails = new Set(teamRows.map((r) => r.email.toLowerCase()));
  const num = (v: unknown) => Number(v ?? 0);
  return (editionId: string) => {
    const h = hallRows.find((r) => r.editionId === editionId);
    const grants = grantRows.filter((g) => g.editionId === editionId);
    // What cloneEdition brings across: the venue (to the same venue),
    // suppliers still in use, engineers and H&S — never someone now on the
    // team. Sponsor and exhibitor access belongs to the old event's records.
    const copyable: CopyableGrant[] = grants
      .filter((g) =>
        g.scopeType === null
          ? g.role === "structural_engineer" || g.role === "hs"
          : g.scopeType === "venue"
            ? g.scopeId === g.venueId
            : g.scopeType === "supplier" && g.scopeId != null && liveSuppliers.has(g.scopeId),
      )
      .filter((g) => !(g.userId && teamIds.has(g.userId)) && !teamEmails.has(g.email.toLowerCase()))
      .map((g) => ({
        venue: g.scopeType === "venue",
        endOffsetDays: g.expiresAt
          ? diffDaysIso(londonDateOfAccessEnd(g.expiresAt), g.breakdownEnd)
          : null,
      }));
    return {
      halls: num(h?.halls),
      locations: num(h?.locations),
      deadlines: num(deadlineRows.find((r) => r.editionId === editionId)?.n),
      packages: num(packageRows.find((r) => r.editionId === editionId)?.n),
      sponsors: num(sponsorRows.find((r) => r.editionId === editionId)?.n),
      items: num(itemRows.find((r) => r.editionId === editionId)?.n),
      /** Grants a copy to the same venue could bring across (ended ones included). */
      access: copyable.length,
      /** Each of them, for counting against the new event's dates and venue (copiedAccessCount). */
      accessGrants: copyable,
      accessLeftBehind: grants.filter(
        (g) => g.scopeType === "sponsor" || g.scopeType === "exhibitor",
      ).length,
      /** People who only see this event (limited, including it) the copier may give the copy. */
      people: limited.filter(
        (p) => p.editionIds.includes(editionId) && canExtendToCopy(viewer, p.ctx, editionId),
      ).length,
      /** The rest of them: they won't see the copy unless a super admin adds it. */
      peopleLeftOut: limited.filter(
        (p) => p.editionIds.includes(editionId) && !canExtendToCopy(viewer, p.ctx, editionId),
      ).length,
    };
  };
}
