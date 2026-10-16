import { Page } from "@/components/page-header";
import { SettingsShell } from "@/components/settings/settings-shell";
import { settingsSectionsFor } from "@/components/settings/sections";
import { settingsAccess } from "@/components/settings/access";

/** Settings: organisation setup, one route per section (see components/settings/sections.ts). */
export default async function SettingsLayout({ children }: { children: React.ReactNode }) {
  const { canManage, canUsers } = await settingsAccess();
  return (
    <Page>
      <SettingsShell sections={settingsSectionsFor({ canManage, canUsers })}>
        {children}
      </SettingsShell>
    </Page>
  );
}
