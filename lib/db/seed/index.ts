/**
 * Idempotent seed (brief section 12) — safe to run twice. Reference data is
 * upserted by natural key; items/exhibitors are created only when their ref
 * or stand number is absent.
 *
 *   pnpm db:seed
 */
import { createHash } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import "dotenv/config";
import * as s from "../schema";
import {
  applyDecision,
  createRun,
  defaultSignageSteps,
  defaultStandSteps,
  invalidateOnNewVersion,
  type EngineSettings,
  type EntityCtx,
  type StepDef,
} from "@/lib/workflow";
import { persistRun } from "@/lib/workflow/persist";
import { formatSignageRef, formatStandRef } from "@/lib/refs";

const url = process.env.DIRECT_DATABASE_URL ?? process.env.DATABASE_URL;
if (!url) throw new Error("DATABASE_URL is not set");
const client = postgres(url, { max: 1, prepare: false, onnotice: () => {} });
const db = drizzle(client, { schema: s });

const NOW = new Date();
const sha = (text: string) => createHash("sha256").update(text).digest("hex");

// Deterministic ids for users so re-runs are stable.
const uid = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;

const engineSettings: EngineSettings = { costThresholdForDirector: 5000 };

async function main() {
  // ---------------------------------------------------------------- tenancy
  const [org] = await db
    .insert(s.organisations)
    .values({
      name: "Media10",
      slug: "media10",
      brandName: "Hall Pass",
      settings: {
        escalate_after_days: 2,
        install_photo_required: true,
        cost_threshold_for_director: 5000,
        currency: "GBP",
      },
    })
    .onConflictDoUpdate({ target: s.organisations.slug, set: { name: "Media10" } })
    .returning();

  const staffUsers = [
    { id: uid(1), email: "admin@media10.test", fullName: "Alex Admin", role: "admin" as const },
    { id: uid(2), email: "ops@media10.test", fullName: "Olivia Ops", role: "ops" as const },
    {
      id: uid(3),
      email: "marketing@media10.test",
      fullName: "Marcus Marketing",
      role: "marketing" as const,
    },
    { id: uid(4), email: "sales@media10.test", fullName: "Sara Sales", role: "sales" as const },
    {
      id: uid(5),
      email: "director@media10.test",
      fullName: "Dana Director",
      role: "event_director" as const,
    },
    { id: uid(6), email: "viewer@media10.test", fullName: "Vic Viewer", role: "viewer" as const },
  ];
  for (const u of staffUsers) {
    await db
      .insert(s.users)
      .values({ id: u.id, email: u.email, fullName: u.fullName })
      .onConflictDoUpdate({ target: s.users.email, set: { fullName: u.fullName } });
    await db
      .insert(s.memberships)
      .values({ userId: u.id, organisationId: org.id, role: u.role })
      .onConflictDoNothing();
  }
  const byRole = Object.fromEntries(staffUsers.map((u) => [u.role, u.id]));

  // ---------------------------------------------------------- event & venues
  const [event] = await db
    .insert(s.events)
    .values({ organisationId: org.id, name: "UK Construction Week", code: "UKCW" })
    .onConflictDoUpdate({
      target: [s.events.organisationId, s.events.code],
      set: { name: "UK Construction Week" },
    })
    .returning();

  const venueRows = [
    { name: "NEC Birmingham", code: "NEC", requiresStandApproval: true },
    { name: "ExCeL London", code: "EXCEL", requiresStandApproval: true },
  ];
  const venues: Record<string, typeof s.venues.$inferSelect> = {};
  for (const v of venueRows) {
    const [row] = await db
      .insert(s.venues)
      .values({ organisationId: org.id, ...v })
      .onConflictDoUpdate({
        target: [s.venues.organisationId, s.venues.code],
        set: { name: v.name },
      })
      .returning();
    venues[v.code] = row;
  }

  // Venue rules — prefixed EXAMPLE: real rules must come from venue docs.
  const rules: Array<{
    category: (typeof s.venueRuleCategory)[number];
    title: string;
    ruleText: string;
    appliesTo: "signage" | "stand" | "both";
    isChecklistItem: boolean;
  }> = [
    {
      category: "height",
      title: "EXAMPLE: Maximum stand height 4000 mm",
      ruleText: "Stands above 4000 mm require complex-structure approval.",
      appliesTo: "stand",
      isChecklistItem: true,
    },
    {
      category: "rigging",
      title: "EXAMPLE: Rigged items via venue rigging team",
      ruleText: "Any rigged or suspended item goes through the venue's rigging team.",
      appliesTo: "both",
      isChecklistItem: true,
    },
    {
      category: "walls",
      title: "EXAMPLE: Walls over 2500 mm finished on reverse",
      ruleText:
        "Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.",
      appliesTo: "stand",
      isChecklistItem: true,
    },
    {
      category: "gangways",
      title: "EXAMPLE: No encroachment into gangways",
      ruleText: "No part of a stand or sign may encroach into gangways.",
      appliesTo: "both",
      isChecklistItem: true,
    },
    {
      category: "fire",
      title: "EXAMPLE: Fire-retardancy certification",
      ruleText: "All materials need fire-retardancy certification.",
      appliesTo: "both",
      isChecklistItem: true,
    },
    {
      category: "structure",
      title: "EXAMPLE: Double-deck stands need engineer sign-off",
      ruleText: "Double-deck stands need structural calculations and engineer sign-off.",
      appliesTo: "stand",
      isChecklistItem: true,
    },
    {
      category: "structure",
      title: "EXAMPLE: Platforms over 600 mm need handrails",
      ruleText: "Platforms over 600 mm need handrails and structural calculations.",
      appliesTo: "stand",
      isChecklistItem: true,
    },
  ];
  for (const [i, r] of rules.entries()) {
    const exists = await db.query.venueRules.findFirst({
      where: and(eq(s.venueRules.venueId, venues.NEC.id), eq(s.venueRules.title, r.title)),
    });
    if (!exists) {
      await db.insert(s.venueRules).values({ venueId: venues.NEC.id, sortOrder: i, ...r });
    }
  }

  // ------------------------------------------------------------------ edition
  const complexTriggers = [
    { key: "double_deck", label: "Double deck" },
    { key: "over_4000mm", label: "Over 4000 mm high" },
    { key: "platform_over_600mm", label: "Platform or stage over 600 mm" },
    { key: "ramped_raised_floor", label: "Ramped raised floor" },
    { key: "rigging", label: "Rigging or suspended items" },
    { key: "ceiling_or_roof", label: "Ceiling or roof" },
    { key: "tiered_seating", label: "Tiered seating" },
  ];

  let edition = await db.query.editions.findFirst({ where: eq(s.editions.code, "BIRM27") });
  if (!edition) {
    [edition] = await db
      .insert(s.editions)
      .values({
        eventId: event.id,
        venueId: venues.NEC.id,
        name: "UKCW Birmingham 2027",
        code: "BIRM27",
        buildStart: "2027-10-01",
        buildEnd: "2027-10-04",
        openStart: "2027-10-05",
        openEnd: "2027-10-07",
        breakdownEnd: "2027-10-08",
        status: "planning",
        signageBudget: "85000",
        complexStructureTriggers: complexTriggers,
      })
      .returning();
  }

  const deadlineDefs = [
    { key: "stand_design_due" as const, label: "Stand designs due", daysBeforeBuildStart: 42 },
    { key: "insurance_due" as const, label: "Insurance documents due", daysBeforeBuildStart: 28 },
    {
      key: "venue_rigging_submission" as const,
      label: "Venue rigging submission",
      daysBeforeBuildStart: 28,
    },
    { key: "artwork_due" as const, label: "Artwork due", daysBeforeBuildStart: 21 },
    { key: "print_deadline" as const, label: "Print deadline", daysBeforeBuildStart: 14 },
    { key: "delivery" as const, label: "Delivery to venue", daysBeforeBuildStart: 3 },
  ];
  for (const dl of deadlineDefs) {
    await db
      .insert(s.editionDeadlines)
      .values({ editionId: edition.id, ...dl })
      .onConflictDoUpdate({
        target: [s.editionDeadlines.editionId, s.editionDeadlines.key],
        set: { daysBeforeBuildStart: dl.daysBeforeBuildStart, label: dl.label },
      });
  }

  // --------------------------------------------------------------- floorplans
  const hallRows: Record<string, typeof s.halls.$inferSelect> = {};
  for (const [i, name] of ["Hall 1", "Hall 2"].entries()) {
    let hall = await db.query.halls.findFirst({
      where: and(eq(s.halls.editionId, edition.id), eq(s.halls.name, name)),
    });
    if (!hall) {
      [hall] = await db
        .insert(s.halls)
        .values({ editionId: edition.id, name, sortOrder: i })
        .returning();
    }
    hallRows[name] = hall;
  }
  const locationDefs = [
    ["Hall 1", "Main entrance", "North", 0.1, 0.05],
    ["Hall 1", "Registration", "North", 0.2, 0.1],
    ["Hall 1", "Central aisle A", "Centre", 0.5, 0.5],
    ["Hall 1", "Seminar theatre 1", "East", 0.8, 0.3],
    ["Hall 1", "Catering court", "South", 0.4, 0.85],
    ["Hall 1", "Feature area", "Centre", 0.55, 0.4],
    ["Hall 2", "Hall 2 entrance", "West", 0.05, 0.5],
    ["Hall 2", "Central aisle B", "Centre", 0.5, 0.45],
    ["Hall 2", "Seminar theatre 2", "East", 0.85, 0.6],
    ["Hall 2", "Networking lounge", "South", 0.3, 0.8],
    ["Hall 2", "External approach", "Outside", 0.5, 0.02],
    ["Hall 2", "Link corridor", "North", 0.5, 0.95],
  ] as const;
  const locationRows: (typeof s.locations.$inferSelect)[] = [];
  for (const [hallName, name, zone, x, y] of locationDefs) {
    let loc = await db.query.locations.findFirst({
      where: and(eq(s.locations.hallId, hallRows[hallName].id), eq(s.locations.name, name)),
    });
    if (!loc) {
      [loc] = await db
        .insert(s.locations)
        .values({ hallId: hallRows[hallName].id, name, zone, xPct: String(x), yPct: String(y) })
        .returning();
    }
    locationRows.push(loc);
  }

  // ------------------------------------------------------------- third parties
  const supplierDefs = [
    { name: "Big Print Co", kind: "print" as const, email: "print@bigprint.test" },
    { name: "Rig Right", kind: "rigging" as const, email: "hello@rigright.test" },
    { name: "Screen Hire Ltd", kind: "av" as const, email: "hire@screenhire.test" },
  ];
  const supplierRows: Record<string, typeof s.suppliers.$inferSelect> = {};
  for (const sup of supplierDefs) {
    let row = await db.query.suppliers.findFirst({
      where: and(eq(s.suppliers.organisationId, org.id), eq(s.suppliers.name, sup.name)),
    });
    if (!row) {
      [row] = await db
        .insert(s.suppliers)
        .values({ organisationId: org.id, ...sup })
        .returning();
    }
    supplierRows[sup.name] = row;
  }

  const contractorDefs = [
    { name: "Stand Builders Ltd", email: "team@standbuilders.test", insuranceExpiry: "2028-06-30" },
    // Insurance expiring before the build so the expiry flag shows.
    { name: "Custom Stands Co", email: "info@customstands.test", insuranceExpiry: "2027-09-15" },
  ];
  const contractorRows: Record<string, typeof s.contractors.$inferSelect> = {};
  for (const c of contractorDefs) {
    let row = await db.query.contractors.findFirst({
      where: and(eq(s.contractors.organisationId, org.id), eq(s.contractors.name, c.name)),
    });
    if (!row) {
      [row] = await db
        .insert(s.contractors)
        .values({ organisationId: org.id, ...c })
        .returning();
    }
    contractorRows[c.name] = row;
  }

  const sponsorDefs = [
    {
      companyName: "BuildCo",
      contactEmail: "sponsor@buildco.test",
      packageName: "Headline sponsor",
      entitlements: [
        { description: "Logo on 6 hanging banners", quantity: 6 },
        { description: "Entrance feature branding", quantity: 1 },
      ],
    },
    {
      companyName: "ToolMart",
      contactEmail: "brand@toolmart.test",
      packageName: "Seminar theatre sponsor",
      entitlements: [{ description: "Seminar theatre branding", quantity: 1 }],
    },
  ];
  const sponsorRows: Record<string, typeof s.sponsors.$inferSelect> = {};
  const entitlementRows: Record<string, typeof s.sponsorEntitlements.$inferSelect> = {};
  for (const sp of sponsorDefs) {
    let row = await db.query.sponsors.findFirst({
      where: and(eq(s.sponsors.editionId, edition.id), eq(s.sponsors.companyName, sp.companyName)),
    });
    if (!row) {
      [row] = await db
        .insert(s.sponsors)
        .values({
          editionId: edition.id,
          companyName: sp.companyName,
          contactEmail: sp.contactEmail,
          packageName: sp.packageName,
        })
        .returning();
    }
    sponsorRows[sp.companyName] = row;
    for (const ent of sp.entitlements) {
      let e = await db.query.sponsorEntitlements.findFirst({
        where: and(
          eq(s.sponsorEntitlements.sponsorId, row.id),
          eq(s.sponsorEntitlements.description, ent.description),
        ),
      });
      if (!e) {
        [e] = await db
          .insert(s.sponsorEntitlements)
          .values({ sponsorId: row.id, ...ent })
          .returning();
      }
      entitlementRows[ent.description] = e;
    }
  }

  // ------------------------------------------------------------------ workflows
  async function ensureWorkflow(name: string, appliesTo: "signage" | "stand", steps: StepDef[]) {
    let wf = await db.query.workflows.findFirst({
      where: and(eq(s.workflows.organisationId, org.id), eq(s.workflows.name, name)),
    });
    if (!wf) {
      [wf] = await db
        .insert(s.workflows)
        .values({ organisationId: org.id, name, appliesTo, isDefault: true })
        .returning();
      for (const step of steps) {
        await db.insert(s.workflowSteps).values({
          workflowId: wf.id,
          sortOrder: step.sortOrder,
          parallelGroup: step.parallelGroup,
          name: step.name,
          kind: step.kind,
          approverType: step.approverType,
          approverRole: step.approverRole,
          approverUserId: null,
          conditions: step.conditions,
          slaDays: step.slaDays,
          invalidateOnNewVersion: step.invalidateOnNewVersion,
          restartFromHereOnChanges: step.restartFromHereOnChanges,
        });
      }
    }
    const stepRows = await db
      .select()
      .from(s.workflowSteps)
      .where(eq(s.workflowSteps.workflowId, wf.id))
      .orderBy(s.workflowSteps.sortOrder);
    const defs: StepDef[] = stepRows.map((r) => ({
      id: r.id,
      sortOrder: r.sortOrder,
      parallelGroup: r.parallelGroup,
      name: r.name,
      kind: r.kind,
      approverType: r.approverType,
      approverRole: r.approverRole,
      approverUserId: r.approverUserId,
      conditions: r.conditions as StepDef["conditions"],
      slaDays: r.slaDays,
      invalidateOnNewVersion: r.invalidateOnNewVersion,
      restartFromHereOnChanges: r.restartFromHereOnChanges,
    }));
    return { workflow: wf, steps: defs };
  }

  const signageWf = await ensureWorkflow("Signage default", "signage", defaultSignageSteps);
  const standWf = await ensureWorkflow("Stand default", "stand", defaultStandSteps);

  // ------------------------------------------------------------------ item types
  const itemTypeDefs: Array<{
    name: string;
    code: string;
    defaultFixingMethod: typeof s.signageItems.$inferSelect.fixingMethod;
    requiresVenueApprovalDefault: boolean;
  }> = [
    {
      name: "Hanging banner",
      code: "hanging_banner",
      defaultFixingMethod: "rigged",
      requiresVenueApprovalDefault: true,
    },
    {
      name: "Foamex board",
      code: "foamex_board",
      defaultFixingMethod: "wall_mounted",
      requiresVenueApprovalDefault: false,
    },
    {
      name: "Fabric graphic",
      code: "fabric_graphic",
      defaultFixingMethod: "shell_mounted",
      requiresVenueApprovalDefault: false,
    },
    {
      name: "Floor vinyl",
      code: "floor_vinyl",
      defaultFixingMethod: "floor",
      requiresVenueApprovalDefault: false,
    },
    {
      name: "Aisle sign",
      code: "aisle_sign",
      defaultFixingMethod: "rigged",
      requiresVenueApprovalDefault: true,
    },
    {
      name: "Entrance feature",
      code: "entrance_feature",
      defaultFixingMethod: "freestanding",
      requiresVenueApprovalDefault: true,
    },
    {
      name: "Registration",
      code: "registration",
      defaultFixingMethod: "freestanding",
      requiresVenueApprovalDefault: false,
    },
    {
      name: "Seminar theatre",
      code: "seminar_theatre",
      defaultFixingMethod: "freestanding",
      requiresVenueApprovalDefault: false,
    },
    {
      name: "Feature area",
      code: "feature_area",
      defaultFixingMethod: "freestanding",
      requiresVenueApprovalDefault: false,
    },
    {
      name: "External",
      code: "external",
      defaultFixingMethod: "freestanding",
      requiresVenueApprovalDefault: true,
    },
    {
      name: "Digital screen",
      code: "digital_screen",
      defaultFixingMethod: "digital",
      requiresVenueApprovalDefault: false,
    },
  ];
  const itemTypeRows: Record<string, typeof s.itemTypes.$inferSelect> = {};
  for (const [i, it] of itemTypeDefs.entries()) {
    const [row] = await db
      .insert(s.itemTypes)
      .values({
        organisationId: org.id,
        sortOrder: i,
        defaultWorkflowId: signageWf.workflow.id,
        ...it,
      })
      .onConflictDoUpdate({
        target: [s.itemTypes.organisationId, s.itemTypes.code],
        set: { name: it.name },
      })
      .returning();
    itemTypeRows[it.code] = row;
  }

  // -------------------------------------------------------------- external users
  const externalDefs = [
    {
      id: uid(11),
      email: "venue@nec.test",
      fullName: "Nina at NEC",
      role: "venue" as const,
      scopeType: "venue" as const,
      scopeId: venues.NEC.id,
    },
    {
      id: uid(12),
      email: "engineer@calcs.test",
      fullName: "Ed Engineer",
      role: "structural_engineer" as const,
      scopeType: null,
      scopeId: null,
    },
    {
      id: uid(13),
      email: "hs@safety.test",
      fullName: "Harri Safety",
      role: "hs" as const,
      scopeType: null,
      scopeId: null,
    },
    {
      id: uid(14),
      email: "print@bigprint.test",
      fullName: "Petra at Big Print",
      role: "supplier" as const,
      scopeType: "supplier" as const,
      scopeId: supplierRows["Big Print Co"].id,
    },
    {
      id: uid(16),
      email: "sponsor@buildco.test",
      fullName: "Ben at BuildCo",
      role: "sponsor" as const,
      scopeType: "sponsor" as const,
      scopeId: sponsorRows.BuildCo.id,
    },
  ];
  for (const e of externalDefs) {
    await db
      .insert(s.users)
      .values({ id: e.id, email: e.email, fullName: e.fullName, isExternal: true })
      .onConflictDoUpdate({ target: s.users.email, set: { fullName: e.fullName } });
    const existing = await db.query.externalGrants.findFirst({
      where: and(
        eq(s.externalGrants.invitedEmail, e.email),
        eq(s.externalGrants.editionId, edition.id),
      ),
    });
    if (!existing) {
      await db.insert(s.externalGrants).values({
        userId: e.id,
        invitedEmail: e.email,
        organisationId: org.id,
        editionId: edition.id,
        role: e.role,
        scopeType: e.scopeType,
        scopeId: e.scopeId,
        invitedBy: byRole.admin,
        inviteTokenHash: sha(`seed-${e.email}`),
        acceptedAt: NOW,
      });
    }
  }

  // ------------------------------------------------------------------ exhibitors
  const exhibitorDefs = [
    {
      companyName: "Exhibitor Co",
      standNumber: "A10",
      standType: "space_only",
      contractor: "Stand Builders Ltd",
      email: "stand@exhibitorco.test",
    },
    {
      companyName: "SteelFrame Systems",
      standNumber: "A20",
      standType: "space_only",
      contractor: "Custom Stands Co",
      email: "expo@steelframe.test",
    },
    {
      companyName: "BrickWorks UK",
      standNumber: "A30",
      standType: "space_only",
      contractor: "Stand Builders Ltd",
      email: "events@brickworks.test",
    },
    {
      companyName: "Timber Trade Ltd",
      standNumber: "B10",
      standType: "space_only",
      contractor: "Custom Stands Co",
      email: "shows@timbertrade.test",
    },
    {
      companyName: "GlassTech",
      standNumber: "B20",
      standType: "space_only",
      contractor: "Stand Builders Ltd",
      email: "marketing@glasstech.test",
    },
    {
      companyName: "Insulate Pro",
      standNumber: "B30",
      standType: "space_only",
      contractor: "Custom Stands Co",
      email: "expo@insulatepro.test",
    },
    {
      companyName: "RoofRight",
      standNumber: "C10",
      standType: "space_only",
      contractor: "Stand Builders Ltd",
      email: "events@roofright.test",
    },
    {
      companyName: "PlantHire Direct",
      standNumber: "C20",
      standType: "space_only",
      contractor: "Custom Stands Co",
      email: "shows@planthire.test",
    },
    {
      companyName: "SafetyFirst PPE",
      standNumber: "D10",
      standType: "shell",
      contractor: null,
      email: "expo@safetyfirst.test",
    },
    {
      companyName: "ToolMart Retail",
      standNumber: "D20",
      standType: "shell",
      contractor: null,
      email: "events@toolmart.test",
    },
    {
      companyName: "EcoBuild Materials",
      standNumber: "D30",
      standType: "shell",
      contractor: null,
      email: "expo@ecobuild.test",
    },
    {
      companyName: "SiteWise Software",
      standNumber: "D40",
      standType: "shell",
      contractor: null,
      email: "hello@sitewise.test",
    },
  ] as const;
  const exhibitorRows: (typeof s.exhibitors.$inferSelect)[] = [];
  for (const [i, ex] of exhibitorDefs.entries()) {
    let row = await db.query.exhibitors.findFirst({
      where: and(
        eq(s.exhibitors.editionId, edition.id),
        eq(s.exhibitors.standNumber, ex.standNumber),
      ),
    });
    if (!row) {
      [row] = await db
        .insert(s.exhibitors)
        .values({
          editionId: edition.id,
          companyName: ex.companyName,
          standNumber: ex.standNumber,
          hallId: i < 6 ? hallRows["Hall 1"].id : hallRows["Hall 2"].id,
          standSizeSqm: String(24 + i * 6),
          standType: ex.standType,
          contactName: ex.companyName + " events team",
          contactEmail: ex.email,
          contractorId: ex.contractor ? contractorRows[ex.contractor].id : null,
        })
        .returning();
    }
    exhibitorRows.push(row);
  }
  // Exhibitor grant for the seeded external exhibitor user.
  await db
    .insert(s.users)
    .values({
      id: uid(15),
      email: "stand@exhibitorco.test",
      fullName: "Erin at Exhibitor Co",
      isExternal: true,
    })
    .onConflictDoNothing();
  const exhibitorGrant = await db.query.externalGrants.findFirst({
    where: and(
      eq(s.externalGrants.invitedEmail, "stand@exhibitorco.test"),
      eq(s.externalGrants.editionId, edition.id),
    ),
  });
  if (!exhibitorGrant) {
    await db.insert(s.externalGrants).values({
      userId: uid(15),
      invitedEmail: "stand@exhibitorco.test",
      organisationId: org.id,
      editionId: edition.id,
      role: "exhibitor",
      scopeType: "exhibitor",
      scopeId: exhibitorRows[0].id,
      invitedBy: byRole.admin,
      inviteTokenHash: sha("seed-stand@exhibitorco.test"),
      acceptedAt: NOW,
    });
  }

  // ------------------------------------------------------------- signage items
  const daysAgo = (n: number) => new Date(NOW.getTime() - n * 86_400_000);

  type ItemPlan = {
    seq: number;
    name: string;
    type: keyof typeof itemTypeRows;
    hall: "Hall 1" | "Hall 2";
    locIdx: number;
    status: typeof s.signageItems.$inferSelect.status;
    owner: "ops" | "marketing";
    sponsor?: "BuildCo" | "ToolMart";
    entitlement?: string;
    supplier?: string;
    cost?: number;
    requiresDirector?: boolean;
    /** How far to advance the run: list of [stepName, decision] */
    advance?: Array<
      [string, "approve" | "approve_with_conditions" | "confirm" | "request_changes" | "reject"]
    >;
    versions?: number;
    overdue?: boolean;
    superseded?: boolean;
    onHoldFrom?: typeof s.signageItems.$inferSelect.status;
  };

  const P = (p: ItemPlan) => p;
  const plans: ItemPlan[] = [
    P({
      seq: 1,
      name: "Main entrance arch banner",
      type: "entrance_feature",
      hall: "Hall 1",
      locIdx: 0,
      status: "in_review",
      owner: "marketing",
      sponsor: "BuildCo",
      entitlement: "Entrance feature branding",
      supplier: "Big Print Co",
      cost: 12000,
      versions: 1,
      advance: [],
    }),
    P({
      seq: 2,
      name: "Registration desk fascia",
      type: "registration",
      hall: "Hall 1",
      locIdx: 1,
      status: "in_review",
      owner: "marketing",
      supplier: "Big Print Co",
      cost: 1800,
      versions: 1,
      advance: [["Marketing brand check", "approve"]],
    }),
    P({
      seq: 3,
      name: "Aisle A hanging banner",
      type: "hanging_banner",
      hall: "Hall 1",
      locIdx: 2,
      status: "in_review",
      owner: "ops",
      sponsor: "BuildCo",
      entitlement: "Logo on 6 hanging banners",
      supplier: "Big Print Co",
      cost: 2400,
      versions: 2,
      advance: [
        ["Marketing brand check", "approve"],
        ["Sponsor approval", "approve"],
      ],
      overdue: true,
    }),
    P({
      seq: 4,
      name: "Seminar theatre 1 backdrop",
      type: "seminar_theatre",
      hall: "Hall 1",
      locIdx: 3,
      status: "in_review",
      owner: "marketing",
      sponsor: "ToolMart",
      supplier: "Big Print Co",
      cost: 3200,
      versions: 1,
      advance: [],
    }),
    P({
      seq: 5,
      name: "Catering court floor vinyl",
      type: "floor_vinyl",
      hall: "Hall 1",
      locIdx: 4,
      status: "changes_requested",
      owner: "ops",
      supplier: "Big Print Co",
      cost: 900,
      versions: 1,
      advance: [["Marketing brand check", "request_changes"]],
    }),
    P({
      seq: 6,
      name: "Feature area totem",
      type: "feature_area",
      hall: "Hall 1",
      locIdx: 5,
      status: "in_review",
      owner: "ops",
      supplier: "Big Print Co",
      cost: 8000,
      requiresDirector: true,
      versions: 1,
      advance: [
        ["Marketing brand check", "approve"],
        ["Ops technical check", "approve"],
      ],
      overdue: true,
    }),
    P({
      seq: 7,
      name: "Hall 2 entrance banner",
      type: "hanging_banner",
      hall: "Hall 2",
      locIdx: 6,
      status: "in_review",
      owner: "marketing",
      supplier: "Big Print Co",
      cost: 2100,
      versions: 1,
      advance: [
        ["Marketing brand check", "approve"],
        ["Ops technical check", "approve"],
      ],
    }),
    P({
      seq: 8,
      name: "Aisle B hanging banner",
      type: "aisle_sign",
      hall: "Hall 2",
      locIdx: 7,
      status: "approved",
      owner: "ops",
      supplier: "Big Print Co",
      cost: 1500,
      versions: 1,
      advance: [
        ["Marketing brand check", "approve"],
        ["Ops technical check", "approve"],
        ["Venue approval", "approve"],
      ],
    }),
    P({
      seq: 9,
      name: "Seminar theatre 2 entrance sign",
      type: "seminar_theatre",
      hall: "Hall 2",
      locIdx: 8,
      status: "approved_with_conditions",
      owner: "marketing",
      sponsor: "ToolMart",
      supplier: "Big Print Co",
      cost: 2800,
      versions: 1,
      advance: [
        ["Marketing brand check", "approve"],
        ["Sponsor approval", "approve_with_conditions"],
        ["Ops technical check", "approve"],
      ],
    }),
    P({
      seq: 10,
      name: "Networking lounge fabric wall",
      type: "fabric_graphic",
      hall: "Hall 2",
      locIdx: 9,
      status: "in_production",
      owner: "marketing",
      supplier: "Big Print Co",
      cost: 3600,
      versions: 1,
      advance: [
        ["Marketing brand check", "approve"],
        ["Ops technical check", "approve"],
        ["Sent to print", "confirm"],
      ],
    }),
    P({
      seq: 11,
      name: "External approach flags",
      type: "external",
      hall: "Hall 2",
      locIdx: 10,
      status: "in_production",
      owner: "ops",
      supplier: "Big Print Co",
      cost: 4200,
      versions: 1,
      advance: [
        ["Marketing brand check", "approve"],
        ["Ops technical check", "approve"],
        ["Venue approval", "approve"],
        ["Sent to print", "confirm"],
      ],
    }),
    P({
      seq: 12,
      name: "Link corridor wayfinding",
      type: "foamex_board",
      hall: "Hall 2",
      locIdx: 11,
      status: "delivered",
      owner: "ops",
      supplier: "Big Print Co",
      cost: 700,
      versions: 1,
      advance: [
        ["Marketing brand check", "approve"],
        ["Ops technical check", "approve"],
        ["Sent to print", "confirm"],
        ["Delivered", "confirm"],
      ],
    }),
    P({
      seq: 13,
      name: "Registration totem screens",
      type: "digital_screen",
      hall: "Hall 1",
      locIdx: 1,
      status: "delivered",
      owner: "marketing",
      supplier: "Screen Hire Ltd",
      cost: 5200,
      requiresDirector: true,
      versions: 1,
      advance: [
        ["Marketing brand check", "approve"],
        ["Ops technical check", "approve"],
        ["Event Director sign-off", "approve"],
        ["Sent to print", "confirm"],
        ["Delivered", "confirm"],
      ],
    }),
    P({
      seq: 14,
      name: "Hall 1 aisle signs set",
      type: "aisle_sign",
      hall: "Hall 1",
      locIdx: 2,
      status: "installed",
      owner: "ops",
      supplier: "Big Print Co",
      cost: 3900,
      versions: 1,
      advance: [
        ["Marketing brand check", "approve"],
        ["Ops technical check", "approve"],
        ["Venue approval", "approve"],
        ["Sent to print", "confirm"],
        ["Delivered", "confirm"],
        ["Installed", "confirm"],
      ],
    }),
    P({
      seq: 15,
      name: "Catering signage pack",
      type: "foamex_board",
      hall: "Hall 1",
      locIdx: 4,
      status: "snagged",
      owner: "ops",
      supplier: "Big Print Co",
      cost: 1100,
      versions: 1,
      advance: [
        ["Marketing brand check", "approve"],
        ["Ops technical check", "approve"],
        ["Sent to print", "confirm"],
        ["Delivered", "confirm"],
        ["Installed", "confirm"],
      ],
    }),
    P({
      seq: 16,
      name: "Sponsor wall Hall 1",
      type: "feature_area",
      hall: "Hall 1",
      locIdx: 5,
      status: "closed",
      owner: "marketing",
      sponsor: "BuildCo",
      supplier: "Big Print Co",
      cost: 2600,
      versions: 1,
      advance: [
        ["Marketing brand check", "approve"],
        ["Sponsor approval", "approve"],
        ["Ops technical check", "approve"],
        ["Sent to print", "confirm"],
        ["Delivered", "confirm"],
        ["Installed", "confirm"],
      ],
    }),
    P({
      seq: 17,
      name: "Gantry banner over aisle C",
      type: "hanging_banner",
      hall: "Hall 2",
      locIdx: 7,
      status: "rejected",
      owner: "ops",
      supplier: "Big Print Co",
      cost: 2000,
      versions: 1,
      advance: [["Marketing brand check", "reject"]],
    }),
    P({
      seq: 18,
      name: "VIP lounge entrance sign",
      type: "fabric_graphic",
      hall: "Hall 2",
      locIdx: 9,
      status: "on_hold",
      owner: "marketing",
      supplier: "Big Print Co",
      cost: 1400,
      versions: 1,
      advance: [["Marketing brand check", "approve"]],
      onHoldFrom: "in_review",
    }),
    P({
      seq: 19,
      name: "BuildCo banner — north hall",
      type: "hanging_banner",
      hall: "Hall 1",
      locIdx: 2,
      status: "in_review",
      owner: "marketing",
      sponsor: "BuildCo",
      entitlement: "Logo on 6 hanging banners",
      supplier: "Big Print Co",
      cost: 2400,
      versions: 3,
      advance: [
        ["Marketing brand check", "approve"],
        ["Sponsor approval", "approve"],
        ["Ops technical check", "approve"],
      ],
      superseded: true,
    }),
    P({
      seq: 20,
      name: "Organiser office door signs",
      type: "foamex_board",
      hall: "Hall 2",
      locIdx: 11,
      status: "awaiting_artwork",
      owner: "ops",
      supplier: "Big Print Co",
      cost: 300,
    }),
    P({
      seq: 21,
      name: "Cloakroom signage",
      type: "foamex_board",
      hall: "Hall 1",
      locIdx: 1,
      status: "awaiting_artwork",
      owner: "ops",
      supplier: "Big Print Co",
      cost: 250,
    }),
    P({
      seq: 22,
      name: "Press office fascia",
      type: "registration",
      hall: "Hall 2",
      locIdx: 6,
      status: "awaiting_artwork",
      owner: "marketing",
      cost: 800,
    }),
    P({
      seq: 23,
      name: "Hall 1 big screen content loop",
      type: "digital_screen",
      hall: "Hall 1",
      locIdx: 5,
      status: "draft",
      owner: "marketing",
      supplier: "Screen Hire Ltd",
      cost: 6000,
      requiresDirector: true,
    }),
    P({
      seq: 24,
      name: "Wayfinding floor arrows",
      type: "floor_vinyl",
      hall: "Hall 2",
      locIdx: 8,
      status: "draft",
      owner: "ops",
      cost: 450,
    }),
    P({
      seq: 25,
      name: "ToolMart seminar bunting",
      type: "seminar_theatre",
      hall: "Hall 2",
      locIdx: 8,
      status: "draft",
      owner: "marketing",
      sponsor: "ToolMart",
      cost: 600,
    }),
    P({
      seq: 26,
      name: "External car park totems",
      type: "external",
      hall: "Hall 2",
      locIdx: 10,
      status: "draft",
      owner: "ops",
      cost: 5400,
      requiresDirector: true,
    }),
    P({
      seq: 27,
      name: "Smoking area signage",
      type: "foamex_board",
      hall: "Hall 2",
      locIdx: 10,
      status: "draft",
      owner: "ops",
      cost: 150,
    }),
    P({
      seq: 28,
      name: "First aid point signs",
      type: "foamex_board",
      hall: "Hall 1",
      locIdx: 4,
      status: "changes_requested",
      owner: "ops",
      supplier: "Big Print Co",
      cost: 320,
      versions: 1,
      advance: [["Marketing brand check", "request_changes"]],
    }),
    P({
      seq: 29,
      name: "BuildCo entrance feature cladding",
      type: "entrance_feature",
      hall: "Hall 1",
      locIdx: 0,
      status: "in_review",
      owner: "marketing",
      sponsor: "BuildCo",
      entitlement: "Entrance feature branding",
      supplier: "Big Print Co",
      cost: 15000,
      versions: 1,
      advance: [
        ["Marketing brand check", "approve"],
        ["Sponsor approval", "approve"],
        ["Ops technical check", "approve"],
        ["Venue approval", "approve"],
      ],
    }),
    P({
      seq: 30,
      name: "Recycling point signage",
      type: "foamex_board",
      hall: "Hall 2",
      locIdx: 11,
      status: "draft",
      owner: "ops",
      cost: 200,
    }),
  ];

  const signageStepDefs = signageWf.steps;

  for (const plan of plans) {
    const ref = formatSignageRef("BIRM27", plan.seq);
    const exists = await db.query.signageItems.findFirst({ where: eq(s.signageItems.ref, ref) });
    if (exists) continue;

    const itemType = itemTypeRows[plan.type];
    const fixing = itemType.defaultFixingMethod ?? "freestanding";
    const requiresVenue = itemType.requiresVenueApprovalDefault || fixing === "rigged";
    const sponsorId = plan.sponsor ? sponsorRows[plan.sponsor].id : null;
    const status = plan.onHoldFrom ? "on_hold" : plan.status;

    const [item] = await db
      .insert(s.signageItems)
      .values({
        editionId: edition.id,
        ref,
        seq: plan.seq,
        name: plan.name,
        description: `${plan.name} for UKCW Birmingham 2027.`,
        itemTypeId: itemType.id,
        hallId: hallRows[plan.hall].id,
        locationId: locationRows[plan.locIdx]?.id ?? null,
        ownerRole: plan.owner,
        ownerUserId: plan.owner === "ops" ? byRole.ops : byRole.marketing,
        sponsorId,
        sponsorEntitlementId: plan.entitlement ? entitlementRows[plan.entitlement].id : null,
        isSponsorDeliverable: Boolean(plan.sponsor),
        widthMm: 3000,
        heightMm: 1000,
        quantity: 1,
        sided: "single",
        material: "Tension fabric",
        finish: "Matt",
        fixingMethod: fixing,
        requiresVenueApproval: requiresVenue,
        requiresEventDirector: plan.requiresDirector ?? false,
        costEstimate: plan.cost != null ? String(plan.cost) : null,
        supplierId: plan.supplier ? supplierRows[plan.supplier].id : null,
        installDate: "2027-10-02",
        installSlot: plan.seq % 2 === 0 ? "am" : "pm",
        status,
        previousStatus: plan.onHoldFrom ?? null,
        onHoldReason: plan.onHoldFrom ? "Awaiting sponsor confirmation" : null,
        workflowId: signageWf.workflow.id,
        currentRunNumber: plan.advance ? 1 : 0,
        createdBy: byRole.ops,
      })
      .returning();

    // Artwork versions.
    let currentVersionId: string | null = null;
    const versionCount = plan.versions ?? 0;
    for (let v = 1; v <= versionCount; v++) {
      const content = `${plan.name} — artwork v${v}`;
      const [ver] = await db
        .insert(s.artworkVersions)
        .values({
          signageItemId: item.id,
          versionNumber: v,
          filePath: `seed/${ref}-v${v}.pdf`,
          fileName: `${ref}-v${v}.pdf`,
          mimeType: "application/pdf",
          fileSize: content.length,
          sha256: sha(content),
          pageCount: 1,
          uploadedBy: plan.owner === "ops" ? byRole.ops : byRole.marketing,
          proofStatus: v === versionCount ? "proof" : "draft",
        })
        .returning();
      currentVersionId = ver.id;
    }
    if (currentVersionId) {
      await db
        .update(s.signageItems)
        .set({ currentArtworkVersionId: currentVersionId })
        .where(eq(s.signageItems.id, item.id));
    }

    // Approval run.
    if (plan.advance) {
      const entity: EntityCtx = {
        kind: "signage",
        sponsorId,
        requiresVenueApproval: requiresVenue,
        requiresEventDirector: plan.requiresDirector ?? false,
        costEstimate: plan.cost ?? null,
        fixingMethod: fixing,
        supplierId: plan.supplier ? supplierRows[plan.supplier].id : null,
      };
      let run = createRun({
        steps: signageStepDefs,
        entity,
        settings: engineSettings,
        runNumber: 1,
        now: daysAgo(plan.overdue ? 12 : 5),
      });
      const decider: Record<string, string> = {
        "Marketing brand check": byRole.marketing,
        "Sponsor approval": byRole.sales,
        "Ops technical check": byRole.ops,
        "Venue approval": uid(11),
        "Event Director sign-off": byRole.event_director,
        "Sent to print": uid(14),
        Delivered: uid(14),
        Installed: byRole.ops,
      };
      for (const [stepName, decisionType] of plan.advance) {
        const inst = run.find((i) => i.stepName === stepName && i.status === "pending");
        if (!inst) continue;
        const res = applyDecision(run, {
          instanceId: inst.id,
          decision:
            decisionType === "approve"
              ? { type: "approve" }
              : decisionType === "approve_with_conditions"
                ? {
                    type: "approve_with_conditions",
                    conditionsText: "Amend per attached notes before install.",
                  }
                : decisionType === "confirm"
                  ? { type: "confirm" }
                  : decisionType === "request_changes"
                    ? { type: "request_changes", comment: "Please revise — see comments." }
                    : { type: "reject", comment: "Does not meet the brand guidelines." },
          decidedBy: decider[stepName] ?? byRole.ops,
          now: daysAgo(plan.overdue ? 10 : 3),
          entity,
          expectedStatus: "pending",
          expectedLockedVersionId: null,
          lockedVersionType: currentVersionId ? "artwork_version" : null,
          lockedVersionId: null,
          lockedSha256: null,
        });
        run = res.instances;
        if (res.entityEvent.type !== "none") break;
      }
      if (plan.superseded) {
        const inv = invalidateOnNewVersion(run, { entity, now: daysAgo(1) });
        run = inv.instances;
      }
      if (plan.overdue) {
        run = run.map((i) => (i.status === "pending" ? { ...i, dueAt: daysAgo(4) } : i));
      }
      await db.transaction(async (tx) => {
        await persistRun(tx, "signage_item", item.id, run);
      });
    }

    // A snag on the snagged item.
    if (plan.status === "snagged") {
      await db.insert(s.snags).values({
        editionId: edition.id,
        signageItemId: item.id,
        description: "Corner delaminating on the catering court panel.",
        severity: "medium",
        assignedSupplierId: supplierRows["Big Print Co"].id,
        status: "open",
      });
    }
  }
  // Counter reflects the highest seeded seq so new items continue from 31.
  await db
    .insert(s.editionCounters)
    .values({ editionId: edition.id, key: "signage", value: 30 })
    .onConflictDoUpdate({
      target: [s.editionCounters.editionId, s.editionCounters.key],
      set: { value: 30 },
    });

  // -------------------------------------------------------- stand submissions
  type StandPlan = {
    exhibitorIdx: number;
    status: typeof s.standSubmissions.$inferSelect.status;
    complex?: boolean;
    height?: number;
    advance?: Array<[string, "approve" | "approve_with_conditions" | "request_changes"]>;
    outcome?: "approved" | "approved_with_conditions" | null;
    conditions?: string;
  };
  const standPlans: StandPlan[] = [
    {
      exhibitorIdx: 0,
      status: "in_review",
      complex: true,
      height: 5200,
      advance: [["Ops completeness and rules check", "approve"]],
    }, // engineer pending
    { exhibitorIdx: 1, status: "in_review", height: 3400, advance: [] }, // ops completeness pending
    {
      exhibitorIdx: 2,
      status: "changes_requested",
      height: 3800,
      advance: [["Ops completeness and rules check", "request_changes"]],
    },
    {
      exhibitorIdx: 3,
      status: "approved_with_conditions",
      height: 3000,
      advance: [
        ["Ops completeness and rules check", "approve"],
        ["H&S review (RAMS, insurance)", "approve"],
        ["Venue approval", "approve"],
        ["Ops final outcome", "approve_with_conditions"],
      ],
      outcome: "approved_with_conditions",
      conditions: "Handrail detail to be verified onsite before opening.",
    },
    {
      exhibitorIdx: 4,
      status: "approved",
      height: 2900,
      advance: [
        ["Ops completeness and rules check", "approve"],
        ["H&S review (RAMS, insurance)", "approve"],
        ["Venue approval", "approve"],
        ["Ops final outcome", "approve"],
      ],
      outcome: "approved",
    },
    { exhibitorIdx: 5, status: "not_submitted" },
    { exhibitorIdx: 6, status: "not_submitted" },
    { exhibitorIdx: 7, status: "not_submitted" },
  ];

  const standDeciders: Record<string, string> = {
    "Ops completeness and rules check": byRole.ops,
    "Structural engineer review": uid(12),
    "H&S review (RAMS, insurance)": uid(13),
    "Venue approval": uid(11),
    "Ops final outcome": byRole.ops,
    "Onsite build check": byRole.ops,
  };

  for (const sp of standPlans) {
    const exhibitor = exhibitorRows[sp.exhibitorIdx];
    const ref = formatStandRef("BIRM27", exhibitor.standNumber);
    const exists = await db.query.standSubmissions.findFirst({
      where: eq(s.standSubmissions.ref, ref),
    });
    if (exists) continue;

    const submitted = sp.status !== "not_submitted";
    const isComplex = sp.complex ?? false;
    await db.transaction(async (tx) => {
      const [sub] = await tx
        .insert(s.standSubmissions)
        .values({
          editionId: edition.id,
          exhibitorId: exhibitor.id,
          ref,
          contractorId: exhibitor.contractorId,
          submissionVersion: 1,
          maxHeightMm: sp.height ?? null,
          hasRigging: isComplex,
          isComplex,
          status: sp.status,
          outcome: sp.outcome ?? null,
          conditionsText: sp.conditions ?? null,
          submittedAt: submitted ? daysAgo(6) : null,
          submittedBy: submitted ? uid(15) : null,
          workflowId: standWf.workflow.id,
          currentRunNumber: submitted ? 1 : 0,
          createdBy: byRole.ops,
        })
        .returning();

      if (submitted) {
        // Required documents for the submission.
        for (const docType of ["plan", "elevation", "rams", "insurance_pl"] as const) {
          const content = `${ref} ${docType}`;
          await tx.insert(s.documents).values({
            organisationId: org.id,
            editionId: edition.id,
            entityType: "stand_submission",
            entityId: sub.id,
            docType,
            filePath: `seed/${ref}-${docType}.pdf`,
            fileName: `${ref}-${docType}.pdf`,
            mimeType: "application/pdf",
            fileSize: content.length,
            sha256: sha(content),
            submissionVersion: 1,
            expiresAt: docType === "insurance_pl" ? "2027-09-20" : null,
            uploadedBy: uid(15),
            isExternalUpload: true,
          });
        }

        const entity: EntityCtx = {
          kind: "stand",
          isComplex,
          venueRequiresStandApproval: true,
        };
        let run = createRun({
          steps: standWf.steps,
          entity,
          settings: engineSettings,
          runNumber: 1,
          now: daysAgo(6),
        });
        for (const [stepName, decisionType] of sp.advance ?? []) {
          const inst = run.find((i) => i.stepName === stepName && i.status === "pending");
          if (!inst) continue;
          const res = applyDecision(run, {
            instanceId: inst.id,
            decision:
              decisionType === "approve"
                ? { type: "approve" }
                : decisionType === "approve_with_conditions"
                  ? {
                      type: "approve_with_conditions",
                      conditionsText: sp.conditions ?? "See conditions.",
                    }
                  : {
                      type: "request_changes",
                      comment: "Structural calculations are missing for the raised floor.",
                    },
            decidedBy: standDeciders[stepName] ?? byRole.ops,
            now: daysAgo(4),
            entity,
            expectedStatus: "pending",
            expectedLockedVersionId: "1",
            lockedVersionType: "submission_version",
            lockedVersionId: "1",
            lockedSha256: null,
          });
          run = res.instances;
          if (res.entityEvent.type !== "none") break;
        }
        await persistRun(tx, "stand_submission", sub.id, run);
      }
    });
  }

  console.log("Seed complete.");
  await client.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
