import { describe, expect, it } from "vitest";
import {
  canOpenSection,
  legacySettingsRedirect,
  SETTINGS_SECTIONS,
  settingsSectionsFor,
  type SettingsAllows,
  type SettingsNeed,
} from "@/components/settings/sections";
import { emailStatus, storageStatus } from "@/components/settings/system-status";
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
});

describe("notification groups on My account", () => {
  it("cover every notification someone can switch off, once each", () => {
    const listed = NOTIFICATION_GROUPS.flatMap((g) => g.kinds);
    expect([...listed].sort()).toEqual([...MUTABLE_KINDS].sort());
    expect(new Set(listed).size).toBe(listed.length);
  });
});
