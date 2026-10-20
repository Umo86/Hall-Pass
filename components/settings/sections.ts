/**
 * Settings sections: what each one is for, who can open it, and where the
 * old ?tab= links now go. Pure — unit tested in tests/unit/settings-sections.test.ts.
 */

export type SettingsSectionId = "organisation" | "item-types" | "venues" | "recycle-bin" | "system";

/** The ability (lib/authz.ts action) that opens each section. */
export type SettingsNeed =
  "organisation.manage" | "lists.manage" | "signage.delete" | "system.manage";

export type SettingsSection = {
  id: SettingsSectionId;
  label: string;
  /** One sentence saying what it is for (the Settings list). */
  hint: string;
  /** A few words for the rail beside each section. */
  short: string;
  href: string;
  /** Opened with this ability (Recycle bin: whoever may delete and restore items). */
  needs: SettingsNeed;
};

export const SETTINGS_SECTIONS: readonly SettingsSection[] = [
  {
    id: "organisation",
    label: "Organisation",
    short: "Name, currency, chasing rules",
    hint: "Your name, currency and company-wide rules such as chasing overdue sign-offs.",
    href: "/settings/organisation",
    needs: "organisation.manage",
  },
  {
    id: "item-types",
    label: "Item types",
    short: "Sign and sponsorship types",
    hint: "What people pick from when they add a sign or a sponsorship item.",
    href: "/settings/item-types",
    needs: "lists.manage",
  },
  {
    id: "venues",
    label: "Venues",
    short: "Places you run events",
    hint: "Places you run events. You choose one when you create an event.",
    href: "/settings/venues",
    needs: "lists.manage",
  },
  {
    id: "recycle-bin",
    label: "Recycle bin",
    short: "Put deleted items back",
    hint: "Deleted signs, sponsorship items and stands from every event. Restore puts them back.",
    href: "/settings/recycle-bin",
    needs: "signage.delete",
  },
  {
    id: "system",
    label: "System",
    short: "File storage, email and sign-in",
    hint: "Where files are kept, whether email works and how people sign in.",
    href: "/settings/system",
    needs: "system.manage",
  },
];

/** What this person may do, as can() answers it (passed in so this stays pure). */
export type SettingsAllows = (need: SettingsNeed) => boolean;

/** The sections this person can open, in order. */
export function settingsSectionsFor(allows: SettingsAllows): SettingsSection[] {
  return SETTINGS_SECTIONS.filter((s) => allows(s.needs));
}

/** Can this person open the section? */
export function canOpenSection(id: SettingsSectionId, allows: SettingsAllows): boolean {
  return settingsSectionsFor(allows).some((s) => s.id === id);
}

/**
 * Old /settings?tab=… links (emails, bookmarks, other pages) and where they
 * live now; null when the tab is unknown.
 */
export function legacySettingsRedirect(tab: string | null | undefined): string | null {
  switch (tab) {
    case "general":
      return "/account";
    case "team":
      return "/users";
    case "external":
      return "/users?tab=external";
    case "signoff":
      return "/users?tab=departments";
    case "types":
      return "/settings/item-types";
    case "services":
      return "/suppliers?manage=services";
    case "venues":
      return "/settings/venues";
    case "deleted":
      return "/settings/recycle-bin";
    case "storage":
      return "/settings/system";
    case "organisation":
      return "/settings/organisation";
    default:
      return null;
  }
}
