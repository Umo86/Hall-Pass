import { Page } from "@/components/page-header";
import { SettingsShell } from "@/components/settings/settings-shell";
import { settingsAccess } from "@/components/settings/access";

/** Settings: organisation setup, one route per section (see components/settings/sections.ts). */
export default async function SettingsLayout({ children }: { children: React.ReactNode }) {
  const { sections } = await settingsAccess();
  return (
    <Page>
      <SettingsShell sections={sections}>{children}</SettingsShell>
    </Page>
  );
}
