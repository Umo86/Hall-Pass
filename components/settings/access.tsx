import "server-only";
import Link from "next/link";
import { Lock } from "lucide-react";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { EmptyState } from "@/components/empty-state";
import { Button } from "@/components/ui/button";
import { canOpenSection, SETTINGS_SECTIONS, type SettingsSectionId } from "./sections";

/** The session plus what this person can do in Settings. */
export async function settingsAccess() {
  const session = await requireStaffSession();
  const canManage = can(session.actor, { type: "settings.manage" });
  const canUsers = can(session.actor, { type: "users.manage" });
  return {
    session,
    canManage,
    canUsers,
    canOpen: (id: SettingsSectionId) => canOpenSection(id, { canManage, canUsers }),
  };
}

/** Shown on a section this person can't open (a link, not a 404). */
export function SectionLocked({ id }: { id: SettingsSectionId }) {
  const section = SETTINGS_SECTIONS.find((s) => s.id === id)!;
  return (
    <EmptyState
      icon={Lock}
      title={
        section.needs === "users"
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
