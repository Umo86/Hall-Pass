/**
 * Demo logins (testing only, DEMO_LOGIN_PASSWORD): when they are on, what a
 * demo account may never do, and the order the sign-in page lists them in.
 * The database side (password set at sign-in, the lock when off) is in
 * auth-demo-logins.db.test.ts.
 */
import { describe, expect, it, vi } from "vitest";
import { demoAccountLocked, demoLoginPassword, isDemoAccount } from "@/lib/auth/config";
import {
  can,
  canExtendToCopy,
  canGrantManager,
  canManagePerson,
  canRemovePerson,
  canRenewInvite,
  canSuspendPerson,
  DEMO_DENIED,
  personChangeRefusal,
  type Action,
  type ExternalActor,
  type PersonAccess,
  type PersonCtx,
  type StaffActor,
} from "@/lib/authz";

vi.mock("@/lib/db/client", () => ({ db: {} }));

const SECRET = { BETTER_AUTH_SECRET: "x".repeat(40) };
const ON = { ...SECRET, DEMO_LOGIN_PASSWORD: "demo-pass-2026" };
const PROD = { VERCEL_ENV: "production", CRON_SECRET: "cron-secret-0123456789" };

describe("demo logins: when they are on", () => {
  it("demo accounts are the seeded …@….test addresses", () => {
    expect(isDemoAccount("admin@media10.test")).toBe(true);
    expect(isDemoAccount(" Venue@NEC.TEST ")).toBe(true);
    expect(isDemoAccount("demo@hall-pass.com")).toBe(false);
    expect(isDemoAccount("someone@test.com")).toBe(false);
  });

  it("DEMO_LOGIN_PASSWORD turns them on, with real sign-in and 8+ characters", () => {
    expect(demoLoginPassword(ON)).toBe("demo-pass-2026");
    expect(demoLoginPassword({ ...ON, DEMO_LOGIN_PASSWORD: "  demo-pass-2026 " })).toBe(
      "demo-pass-2026",
    );
    expect(demoLoginPassword({ ...PROD, DEMO_LOGIN_PASSWORD: "demo-pass-2026" })).toBe(
      "demo-pass-2026",
    );
    expect(demoLoginPassword(SECRET)).toBeNull();
    expect(demoLoginPassword({ ...SECRET, DEMO_LOGIN_PASSWORD: "   " })).toBeNull();
    expect(demoLoginPassword({ ...SECRET, DEMO_LOGIN_PASSWORD: "short" })).toBeNull();
    // Without real sign-in there is nothing to sign in to.
    expect(demoLoginPassword({ DEMO_LOGIN_PASSWORD: "demo-pass-2026" })).toBeNull();
  });

  it("off on any Vercel deployment with real sign-in, demo accounts are locked out", () => {
    expect(demoAccountLocked("admin@media10.test", PROD)).toBe(true);
    expect(
      demoAccountLocked("admin@media10.test", { ...SECRET, VERCEL_TARGET_ENV: "production" }),
    ).toBe(true);
    // Another deployment on the same database without the variable: locked too.
    expect(demoAccountLocked("admin@media10.test", { ...SECRET, VERCEL_ENV: "preview" })).toBe(
      true,
    );
    expect(
      demoAccountLocked("admin@media10.test", { ...PROD, DEMO_LOGIN_PASSWORD: "demo-pass-2026" }),
    ).toBe(false);
    expect(demoAccountLocked("demo@hall-pass.com", PROD)).toBe(false);
    // Demo sign-in previews (no real sign-in), CI and local use the seeded accounts as before.
    expect(demoAccountLocked("admin@media10.test", { VERCEL_ENV: "preview", DEV_AUTH: "1" })).toBe(
      false,
    );
    expect(demoAccountLocked("admin@media10.test", SECRET)).toBe(false);
  });
});

const ORG = "org-1";
const demoAdmin: StaffActor = {
  kind: "staff",
  userId: "demo-admin",
  organisationId: ORG,
  role: "admin",
  demo: true,
};
const realAdmin: StaffActor = { ...demoAdmin, userId: "boss", demo: undefined };
const demoPartner: ExternalActor = {
  kind: "external",
  userId: "demo-venue",
  organisationId: ORG,
  grants: [
    {
      role: "venue",
      editionId: "ed-1",
      scopeType: "venue",
      scopeId: "venue-1",
      expiresAt: null,
      revokedAt: null,
    },
  ],
  demo: true,
};
const owner: PersonCtx = {
  organisationId: ORG,
  userId: "owner",
  role: "admin",
  departmentId: null,
  managerScope: null,
};
const access: PersonAccess = {
  role: "viewer",
  departmentId: null,
  features: null,
  overrides: {},
  managerScope: null,
  signoffs: [],
};

describe("demo logins: what a demo account never does", () => {
  const denied: Action[] = [
    { type: "people.manage" },
    { type: "users.manage" },
    { type: "people.access_link" },
    { type: "partners.invite" },
    { type: "departments.manage" },
    { type: "system.manage" },
    { type: "person.edit", person: owner },
    { type: "person.suspend", person: owner },
    { type: "person.remove", person: owner },
  ];

  it("lists exactly the people, partner and system actions", () => {
    expect([...DEMO_DENIED].sort()).toEqual(denied.map((a) => a.type).sort());
  });

  it.each(denied.map((a) => [a.type, a] as const))(
    "a demo super admin can't %s; the real one still can",
    (_type, action) => {
      expect(can(demoAdmin, action)).toBe(false);
      expect(can(realAdmin, action)).toBe(true);
    },
  );

  it("keeps the rest of its role: a demo super admin still works on the schedule", () => {
    for (const action of [
      { type: "signage.create" },
      { type: "organisation.manage" },
      { type: "events.archive" },
    ] satisfies Action[]) {
      expect(can(demoAdmin, action)).toBe(true);
    }
  });

  it("can't touch anyone through the per-person checks either", () => {
    expect(canManagePerson(demoAdmin, owner)).toBe(false);
    expect(canSuspendPerson(demoAdmin, owner, { lastActiveAdmin: false })).toBe(false);
    expect(canRemovePerson(demoAdmin, owner)).toBe(false);
    expect(personChangeRefusal(demoAdmin, owner, access, access)).toBe(
      "Demo accounts can't change people's access",
    );
    expect(personChangeRefusal(demoAdmin, null, null, access)).toBe(
      "Demo accounts can't change people's access",
    );
    expect(canManagePerson(realAdmin, owner)).toBe(true);
    expect(canRemovePerson(realAdmin, owner)).toBe(true);
  });

  it("can't make managers, renew invitations or carry people into a copied event", () => {
    expect(canGrantManager(demoAdmin)).toBe(false);
    expect(canRenewInvite(demoAdmin, access)).toBe(false);
    expect(canExtendToCopy(demoAdmin, owner, "ed-1")).toBe(false);
    expect(canGrantManager(realAdmin)).toBe(true);
    expect(canRenewInvite(realAdmin, access)).toBe(true);
    expect(canExtendToCopy(realAdmin, owner, "ed-1")).toBe(true);
  });

  it("a demo partner can't invite partners", () => {
    expect(can(demoPartner, { type: "partners.invite" })).toBe(false);
  });
});

describe("demo logins: the list on the sign-in page", () => {
  it("staff from super admin down, then partners; demo addresses only, one row each", async () => {
    const { orderDemoLogins } = await import("@/lib/auth/demo-logins");
    const rows = orderDemoLogins([
      { email: "print@bigprint.test", name: "Petra", staffRole: null, externalRole: "supplier" },
      { email: "viewer@media10.test", name: "Vic", staffRole: "viewer", externalRole: null },
      { email: "venue@nec.test", name: "Nina", staffRole: null, externalRole: "venue" },
      { email: "ops@media10.test", name: "Olivia", staffRole: "ops", externalRole: null },
      { email: "admin@media10.test", name: "Alex", staffRole: "admin", externalRole: null },
      // A second row for the same account (another grant) is listed once.
      { email: "venue@nec.test", name: "Nina", staffRole: null, externalRole: "venue" },
      // No access now: not offered.
      { email: "gone@media10.test", name: "Gone", staffRole: null, externalRole: null },
      // A real person's address is never listed.
      { email: "demo@hall-pass.com", name: "Owner", staffRole: "admin", externalRole: null },
      { email: "nameless@media10.test", name: "", staffRole: "sales", externalRole: null },
    ]);
    expect(rows).toEqual([
      { email: "admin@media10.test", name: "Alex", role: "Super admin", isExternal: false },
      { email: "ops@media10.test", name: "Olivia", role: "Operations", isExternal: false },
      { email: "nameless@media10.test", name: "nameless", role: "Sales", isExternal: false },
      { email: "viewer@media10.test", name: "Vic", role: "Viewer (read-only)", isExternal: false },
      { email: "venue@nec.test", name: "Nina", role: "Venue", isExternal: true },
      { email: "print@bigprint.test", name: "Petra", role: "Supplier", isExternal: true },
    ]);
  });
});
