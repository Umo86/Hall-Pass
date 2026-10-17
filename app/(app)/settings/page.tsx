import Link from "next/link";
import { redirect } from "next/navigation";
import { ChevronRight } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { settingsAccess } from "@/components/settings/access";
import { legacySettingsRedirect } from "@/components/settings/sections";
import { SECTION_ICONS } from "@/components/settings/section-icons";

export const metadata = { title: "Settings" };
export const dynamic = "force-dynamic";

/** Settings: the list of sections (also where old ?tab= links are sent on). */
export default async function SettingsPage({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string | string[] }>;
}) {
  const { tab } = await searchParams;
  const target = legacySettingsRedirect(Array.isArray(tab) ? tab[0] : tab);
  if (target) redirect(target);

  const { sections } = await settingsAccess();

  if (sections.length === 0) {
    return (
      <PageHeader
        title="Settings"
        description={
          <>
            Settings are looked after by super admins and the people they choose. Your own details
            and notifications are in{" "}
            <Link href="/account" className="link">
              My account
            </Link>
            ; the team is in{" "}
            <Link href="/users" className="link">
              Users
            </Link>
            .
          </>
        }
      />
    );
  }

  return (
    <>
      <PageHeader
        title="Settings"
        description={
          <>
            How your organisation is set up. Your own details and notifications are in{" "}
            <Link href="/account" className="link">
              My account
            </Link>
            .
          </>
        }
      />
      <ul className="divide-y rounded-lg border md:grid md:grid-cols-2 md:gap-3 md:divide-y-0 md:border-0">
        {sections.map((s) => {
          const Icon = SECTION_ICONS[s.id];
          return (
            <li key={s.id}>
              <Link
                href={s.href}
                className="hover:bg-accent/60 flex min-h-16 items-center gap-3 px-4 py-3 md:h-full md:rounded-lg md:border"
              >
                <span className="bg-muted text-muted-foreground flex size-9 shrink-0 items-center justify-center rounded-full">
                  <Icon className="size-4" aria-hidden />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block text-sm font-medium">{s.label}</span>
                  <span className="text-muted-foreground block text-sm">{s.hint}</span>
                </span>
                <ChevronRight className="text-muted-foreground size-4 shrink-0" aria-hidden />
              </Link>
            </li>
          );
        })}
      </ul>
      <p className="text-muted-foreground text-sm">
        People, departments and who signs off are in{" "}
        <Link href="/users" className="link">
          Users
        </Link>
        ; suppliers and what they do are in{" "}
        <Link href="/suppliers" className="link">
          Suppliers
        </Link>
        .
      </p>
    </>
  );
}
