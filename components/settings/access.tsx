import "server-only";
import Link from "next/link";
import { Lock } from "lucide-react";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { EmptyState } from "@/components/empty-state";
import { Button } from "@/components/ui/button";
import {
  canOpenSection,
  SETTINGS_SECTIONS,
  settingsSectionsFor,
  type SettingsAllows,
  type SettingsSectionId,
} from "./sections";

/** The session plus what this person can do in Settings (each section by its ability). */
export async function settingsAccess() {
  const session = await requireStaffSession();
  const allows: SettingsAllows = (need) => can(session.actor, { type: need });
  return {
    session,
    allows,
    sections: settingsSectionsFor(allows),
    /** Item types, services and venues (lists.manage). */
    canManage: allows("lists.manage"),
    /** Give partners portal access (venues). */
    canInvite: can(session.actor, { type: "partners.invite" }),
    canOpen: (id: SettingsSectionId) => canOpenSection(id, allows),
  };
}

/** Shown on a section this person can't open (a link, not a 404). */
export function SectionLocked({ id }: { id: SettingsSectionId }) {
  const section = SETTINGS_SECTIONS.find((s) => s.id === id)!;
  return (
    <EmptyState
      icon={Lock}
      title={
        section.needs === "system.manage"
          ? `Only admins can open ${section.label}`
          : `Only admins and Operations can change ${section.label.toLowerCase()}`
      }
      description="Your own details and notifications are in My account."
      action={
        <Button asChild variant="outline">
          <Link href="/account">Go to My account</Link>
        </Button>
      }
    />
  );
}
