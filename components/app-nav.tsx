"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  CalendarDays,
  ClipboardCheck,
  FileBarChart,
  Gift,
  HardHat,
  Layers,
  LayoutDashboard,
  Settings,
  Signpost,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { editionCodeFromPath } from "@/lib/edition-path";

export type NavEdition = { code: string; status: string };

type NavItem = { label: string; href: string; icon: React.ComponentType<{ className?: string }> };

export function AppNav({
  editions,
  onNavigate,
}: {
  editions: NavEdition[];
  /** Closes the mobile sheet after a link is chosen. */
  onNavigate?: () => void;
}) {
  const pathname = usePathname();
  const edition =
    editionCodeFromPath(pathname) ??
    editions.find((e) => e.status !== "archived")?.code ??
    editions[0]?.code ??
    null;

  const editionItems: NavItem[] = edition
    ? [
        { label: "Dashboard", href: `/${edition}/dashboard`, icon: LayoutDashboard },
        { label: "Signage", href: `/${edition}/signage`, icon: Signpost },
        { label: "Sponsorship", href: `/${edition}/sponsorship`, icon: Gift },
        { label: "Stands", href: `/${edition}/stands`, icon: HardHat },
        { label: "Calendar", href: `/${edition}/calendar`, icon: CalendarDays },
        { label: "Reports", href: `/${edition}/reports`, icon: FileBarChart },
      ]
    : [];
  const globalItems: NavItem[] = [
    { label: "My Sign-offs", href: "/approvals", icon: ClipboardCheck },
    { label: "Editions", href: "/editions", icon: Layers },
    { label: "Settings", href: "/settings", icon: Settings },
  ];

  function renderItems(items: NavItem[]) {
    return items.map((item) => {
      const active = pathname.startsWith(item.href);
      return (
        <Link
          key={item.href}
          href={item.href}
          onClick={onNavigate}
          className={cn(
            "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
            active
              ? "bg-sidebar-accent text-sidebar-accent-foreground"
              : "text-muted-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
          )}
          aria-current={active ? "page" : undefined}
        >
          <item.icon className="size-4" aria-hidden />
          {item.label}
        </Link>
      );
    });
  }

  return (
    <nav className="flex flex-col gap-1 p-2" aria-label="Main navigation">
      {editionItems.length > 0 && (
        <>
          <p className="text-muted-foreground px-3 pt-2 pb-1 text-[11px] font-semibold tracking-wide uppercase">
            {edition}
          </p>
          {renderItems(editionItems)}
        </>
      )}
      <p className="text-muted-foreground px-3 pt-3 pb-1 text-[11px] font-semibold tracking-wide uppercase">
        General
      </p>
      {renderItems(globalItems)}
    </nav>
  );
}
