"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  CalendarCheck,
  CalendarDays,
  ClipboardCheck,
  FileBarChart,
  HardHat,
  LayoutDashboard,
  Map,
  Settings,
  Signpost,
} from "lucide-react";
import { cn } from "@/lib/utils";

// Placeholder until editions come from the database in Phase 1.
const DEFAULT_EDITION_CODE = "BIRM27";

function editionCodeFromPath(pathname: string): string {
  const first = pathname.split("/").filter(Boolean)[0];
  const reserved = ["editions", "approvals", "settings", "portal", "login", "invite", "q"];
  if (first && !reserved.includes(first)) return first;
  return DEFAULT_EDITION_CODE;
}

export function AppNav() {
  const pathname = usePathname();
  const edition = editionCodeFromPath(pathname);

  const items = [
    { label: "Dashboard", href: `/${edition}/dashboard`, icon: LayoutDashboard },
    { label: "Signage", href: `/${edition}/signage`, icon: Signpost },
    { label: "Stands", href: `/${edition}/stands`, icon: HardHat },
    { label: "My Sign-offs", href: "/approvals", icon: ClipboardCheck },
    { label: "Calendar", href: `/${edition}/calendar`, icon: CalendarDays },
    { label: "Floorplan", href: `/${edition}/floorplan`, icon: Map },
    { label: "Onsite", href: `/${edition}/onsite`, icon: CalendarCheck },
    { label: "Reports", href: `/${edition}/reports`, icon: FileBarChart },
    { label: "Settings", href: "/settings", icon: Settings },
  ];

  return (
    <nav className="flex flex-col gap-1 p-2" aria-label="Main navigation">
      {items.map((item) => {
        const active = pathname.startsWith(item.href);
        return (
          <Link
            key={item.href}
            href={item.href}
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
      })}
    </nav>
  );
}
