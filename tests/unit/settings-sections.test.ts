import { describe, expect, it } from "vitest";
import {
  canOpenSection,
  legacySettingsRedirect,
  SETTINGS_SECTIONS,
  settingsSectionsFor,
  type SettingsAllows,
  type SettingsNeed,
} from "@/components/settings/sections";
import {
  databaseStatus,
  emailStatus,
  signInStatus,
  storageStatus,
} from "@/components/settings/system-status";
import { NOTIFICATION_GROUPS } from "@/components/account/notification-groups";
import { MUTABLE_KINDS } from "@/lib/notification-kinds";

const ALL: SettingsNeed[] = [
  "organisation.manage",
  "lists.manage",
  "signage.delete",
  "system.manage",
];
const allows =
  (...needs: SettingsNeed[]): SettingsAllows =>
  (need) =>
    needs.includes(need);

describe("settings sections", () => {
  it("admins see everything, in order", () => {
    expect(settingsSectionsFor(allows(...ALL)).map((s) => s.id)).toEqual([
      "organisation",
      "item-types",
      "venues",
      "recycle-bin",
      "system",
    ]);
  });

  it("Operations (everything but System by default) see everything but System", () => {
    const ops = allows("organisation.manage", "lists.manage", "signage.delete");
    const ids = settingsSectionsFor(ops).map((s) => s.id);
    expect(ids).toEqual(["organisation", "item-types", "venues", "recycle-bin"]);
    expect(canOpenSection("system", ops)).toBe(false);
  });

  it("each section is opened by its own ability", () => {
    expect(settingsSectionsFor(allows("lists.manage")).map((s) => s.id)).toEqual([
      "item-types",
      "venues",
    ]);
    expect(settingsSectionsFor(allows("signage.delete")).map((s) => s.id)).toEqual(["recycle-bin"]);
    expect(settingsSectionsFor(allows("organisation.manage")).map((s) => s.id)).toEqual([
      "organisation",
    ]);
    const needs = Object.fromEntries(SETTINGS_SECTIONS.map((s) => [s.id, s.needs]));
    expect(needs).toEqual({
      organisation: "organisation.manage",
      "item-types": "lists.manage",
      venues: "lists.manage",
      "recycle-bin": "signage.delete",
      system: "system.manage",
    });
  });

  it("everyone else sees nothing", () => {
    expect(settingsSectionsFor(allows())).toEqual([]);
    for (const s of SETTINGS_SECTIONS) {
      expect(canOpenSection(s.id, allows())).toBe(false);
    }
  });

  it("every section has a route under /settings and a one-line hint", () => {
    for (const s of SETTINGS_SECTIONS) {
      expect(s.href).toBe(`/settings/${s.id}`);
      expect(s.hint.length).toBeGreaterThan(10);
      expect(s.hint).not.toMatch(/\n/);
    }
  });

  it.each([
    ["team", "/users"],
    ["general", "/account"],
    ["signoff", "/users?tab=departments"],
    ["external", "/users?tab=external"],
    ["types", "/settings/item-types"],
    ["services", "/suppliers?manage=services"],
    ["venues", "/settings/venues"],
    ["deleted", "/settings/recycle-bin"],
    ["storage", "/settings/system"],
  ])("old ?tab=%s goes to %s", (tab, href) => {
    expect(legacySettingsRedirect(tab)).toBe(href);
  });

  it("unknown or missing tabs stay put", () => {
    expect(legacySettingsRedirect(undefined)).toBeNull();
    expect(legacySettingsRedirect("nonsense")).toBeNull();
  });
});

describe("system status in plain words", () => {
  it("says files are safe in a working bucket", () => {
    expect(storageStatus({ backend: "s3", check: { ok: true }, hosted: true })).toMatchObject({
      tone: "ok",
      title: "Files are stored safely",
    });
  });
  it("says so when the bucket is broken", () => {
    expect(storageStatus({ backend: "s3", check: { ok: false }, hosted: true })).toMatchObject({
      tone: "error",
      title: "File storage isn't working",
    });
  });
  it("warns that disk storage is lost on hosting", () => {
    expect(storageStatus({ backend: "local", check: null, hosted: true })).toMatchObject({
      tone: "error",
      title: "Uploaded files will be lost",
    });
    expect(storageStatus({ backend: "local", check: null, hosted: false }).tone).toBe("warn");
  });
  it("names Blob as safe", () => {
    expect(storageStatus({ backend: "blob", check: null, hosted: true }).tone).toBe("ok");
  });
  it("says whether email works", () => {
    expect(emailStatus(true)).toMatchObject({ tone: "ok", title: "Email is working" });
    expect(emailStatus(false)).toMatchObject({ tone: "warn", title: "Email is off" });
  });
  it("says sign-in works, and how people get links without email", () => {
    const on = signInStatus({ configured: true, demo: false, emailOn: true });
    expect(on).toMatchObject({ tone: "ok", title: "Sign-in is working" });
    expect(on.detail).toContain("emailed");
    const noEmail = signInStatus({ configured: true, demo: false, emailOn: false });
    expect(noEmail.tone).toBe("ok");
    expect(noEmail.detail).toContain("super admin");
  });
  it("warns while demo sign-in is on, with or without real sign-in", () => {
    expect(signInStatus({ configured: true, demo: true, emailOn: false })).toMatchObject({
      tone: "warn",
      title: "Demo sign-in is on",
    });
    expect(signInStatus({ configured: false, demo: true, emailOn: false })).toMatchObject({
      tone: "warn",
      title: "Only demo sign-in is on",
    });
  });
  it("says nobody can sign in when neither is set up", () => {
    expect(signInStatus({ configured: false, demo: false, emailOn: true })).toMatchObject({
      tone: "error",
      title: "Nobody can sign in",
    });
  });
  it("says where the data is: Neon in London, with no backup claim", () => {
    expect(
      databaseStatus({
        provider: "neon",
        region: "aws-eu-west-2",
        schema: "current",
        reachable: true,
      }),
    ).toEqual({
      tone: "ok",
      title: "Your data is stored safely",
      detail: "In Neon's London data centre.",
    });
    expect(
      databaseStatus({
        provider: "supabase",
        region: "aws-eu-central-1",
        schema: "current",
        reachable: true,
      }).detail,
    ).toBe("In Supabase's Frankfurt data centre.");
    expect(
      databaseStatus({ provider: "neon", region: null, schema: "unknown", reachable: true }).detail,
    ).toBe("With Neon.");
    expect(
      databaseStatus({ provider: "local", region: null, schema: "current", reachable: true }),
    ).toMatchObject({ tone: "ok", detail: "In a database on this computer." });
  });
  it("says so when the database is unreachable or not set", () => {
    for (const p of [
      { provider: "neon", region: "aws-eu-west-2", schema: "unknown" as const, reachable: false },
      { provider: null, region: null, schema: "unknown" as const, reachable: false },
    ]) {
      expect(databaseStatus(p)).toMatchObject({
        tone: "error",
        title: "The database isn't connected",
      });
    }
  });
  it("warns when the database is behind this release", () => {
    expect(
      databaseStatus({
        provider: "neon",
        region: "aws-eu-west-2",
        schema: "behind",
        reachable: true,
      }),
    ).toMatchObject({ tone: "warn", title: "The database needs updating" });
  });
});

describe("notification groups on My account", () => {
  it("cover every notification someone can switch off, once each", () => {
    const listed = NOTIFICATION_GROUPS.flatMap((g) => g.kinds);
    expect([...listed].sort()).toEqual([...MUTABLE_KINDS].sort());
    expect(new Set(listed).size).toBe(listed.length);
  });
});
