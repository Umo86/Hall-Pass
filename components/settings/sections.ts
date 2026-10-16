/**
 * Settings sections: what each one is for, who can open it, and where the
 * old ?tab= links now go. Pure — unit tested in tests/unit/settings-sections.test.ts.
 */

export type SettingsSectionId = "organisation" | "item-types" | "venues" | "recycle-bin" | "system";

export type SettingsSection = {
  id: SettingsSectionId;
  label: string;
  /** One sentence saying what it is for (the Settings list). */
  hint: string;
  /** A few words for the rail beside each section. */
  short: string;
  href: string;
  /** settings.manage (admins and Operations) or users.manage (admins). */
  needs: "settings" | "users";
};

export const SETTINGS_SECTIONS: readonly SettingsSection[] = [
  {
    id: "organisation",
    label: "Organisation",
    short: "Name, currency, chasing rules",
    hint: "Your name, currency and company-wide rules such as chasing overdue sign-offs.",
    href: "/settings/organisation",
    needs: "settings",
  },
  {
    id: "item-types",
    label: "Item types",
    short: "Sign and sponsorship types",
    hint: "What people pick from when they add a sign or a sponsorship item.",
    href: "/settings/item-types",
    needs: "settings",
  },
  {
    id: "venues",
    label: "Venues",
    short: "Places you run events",
    hint: "Places you run events. You choose one when you create an event.",
    href: "/settings/venues",
    needs: "settings",
  },
  {
    id: "recycle-bin",
    label: "Recycle bin",
    short: "Put deleted items back",
    hint: "Deleted signs, sponsorship items and stands from every event. Restore puts them back.",
    href: "/settings/recycle-bin",
    needs: "settings",
  },
  {
    id: "system",
    label: "System",
    short: "File storage and email",
    hint: "Where files are kept and whether email works.",
    href: "/settings/system",
    needs: "users",
  },
];

/** The sections this person can open, in order. */
export function settingsSectionsFor(p: {
  canManage: boolean;
  canUsers: boolean;
}): SettingsSection[] {
  return SETTINGS_SECTIONS.filter((s) => (s.needs === "users" ? p.canUsers : p.canManage));
}

/** Can this person open the section? */
export function canOpenSection(
  id: SettingsSectionId,
  p: { canManage: boolean; canUsers: boolean },
): boolean {
  return settingsSectionsFor(p).some((s) => s.id === id);
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
