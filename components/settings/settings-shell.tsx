"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { cn } from "@/lib/utils";
import type { SettingsSection } from "./sections";
import { SECTION_ICONS } from "./section-icons";

/**
 * Settings around each section: on md+ a rail of the sections with a
 * one-line hint each; on phones a "Settings" back link (the list itself is
 * the /settings page).
 */
export function SettingsShell({
  sections,
  children,
}: {
  sections: SettingsSection[];
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const isIndex = pathname === "/settings";
  if (isIndex || sections.length === 0) {
    return <div className="flex flex-col gap-6">{children}</div>;
  }
  return (
    <div className="flex flex-col gap-4 md:grid md:grid-cols-[15rem_minmax(0,1fr)] md:items-start md:gap-8">
      <nav aria-label="Settings sections" className="hidden md:sticky md:top-4 md:block">
        <Link
          href="/settings"
          className="text-muted-foreground hover:text-foreground mb-2 block px-2 text-xs font-semibold tracking-wide uppercase"
        >
          Settings
        </Link>
        <ul className="space-y-0.5">
          {sections.map((s) => {
            const Icon = SECTION_ICONS[s.id];
            const active = pathname === s.href || pathname.startsWith(`${s.href}/`);
            return (
              <li key={s.id}>
                <Link
                  href={s.href}
                  aria-current={active ? "page" : undefined}
                  className={cn(
                    "flex gap-2.5 rounded-md px-2 py-2 text-sm transition-colors",
                    active ? "bg-accent text-foreground" : "hover:bg-accent/60 text-foreground/90",
                  )}
                >
                  <Icon className="text-muted-foreground mt-0.5 size-4 shrink-0" aria-hidden />
                  <span className="min-w-0">
                    <span className={cn("block", active && "font-medium")}>{s.label}</span>
                    <span className="text-muted-foreground block truncate text-xs" title={s.hint}>
                      {s.short}
                    </span>
                  </span>
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>
      <Link
        href="/settings"
        className="text-muted-foreground hover:text-foreground inline-flex min-h-11 w-fit items-center gap-1 text-sm md:hidden"
      >
        <ArrowLeft className="size-3.5" aria-hidden />
        Settings
      </Link>
      <div className="flex min-w-0 flex-col gap-6">{children}</div>
    </div>
  );
}
