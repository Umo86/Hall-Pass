import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { organisations } from "@/lib/db/schema";
import { PageHeader } from "@/components/page-header";
import { SectionLocked, settingsAccess } from "@/components/settings/access";
import { OrganisationForm } from "@/components/settings/organisation-form";

export const metadata = { title: "Organisation · Settings" };
export const dynamic = "force-dynamic";

export default async function OrganisationSettingsPage() {
  const { session, canOpen } = await settingsAccess();
  const header = (
    <PageHeader
      title="Organisation"
      description="Company-wide settings. They apply to every event and everyone on the team."
    />
  );
  if (!canOpen("organisation")) {
    return (
      <>
        {header}
        <SectionLocked id="organisation" />
      </>
    );
  }
  const org = await db.query.organisations.findFirst({
    where: eq(organisations.id, session.organisation.id),
  });
  const settings = org?.settings ?? session.organisation.settings;
  return (
    <>
      {header}
      <OrganisationForm
        initial={{
          brandName: org?.brandName ?? session.organisation.brandName,
          currency: ["GBP", "EUR", "USD"].includes(settings.currency) ? settings.currency : "GBP",
          escalateAfterDays: Math.min(14, Math.max(1, settings.escalate_after_days ?? 2)),
          installPhotoRequired: settings.install_photo_required ?? true,
        }}
      />
    </>
  );
}
