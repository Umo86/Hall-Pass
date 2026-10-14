"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Box,
  CalendarDays,
  ClipboardCheck,
  FileBarChart,
  Gift,
  HardHat,
  Layers,
  LayoutDashboard,
  ListChecks,
  ListTodo,
  MapPin,
  Settings,
  Signpost,
  Sparkles,
  Truck,
  Users,
  Wrench,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { editionCodeFromPath } from "@/lib/edition-path";
import type { Feature } from "@/lib/authz";

export type NavEdition = { code: string; name: string; status: string };

type NavItem = {
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
  /** Small count pill on the right (e.g. sign-offs waiting). */
  badge?: { text: string; tone?: "default" | "alert" };
  /** Also active on these path prefixes. */
  alsoActive?: string[];
};

export type NavOptions = {
  /** Admin/ops: show the event-setup pages. */
  canSetup: boolean;
  /** Admin/ops or admin: show Settings. */
  canSettings: boolean;
  /** Exhibitor stand approvals are hidden unless switched on. */
  showStands: boolean;
  /** Sections this person can use; null = every section. */
  features: Feature[] | null;
  /** Waiting work, shown as pills. */
  counts?: { approvals: number; approvalsOverdue: boolean; myWork: number };
  /** Setup progress of the current event (admins/ops), while unfinished. */
  setup?: { code: string; done: number; total: number } | null;
};

function allowed(options: NavOptions, feature: Feature) {
  return options.features == null || options.features.includes(feature);
}

export function AppNav({
  editions,
  options,
  onNavigate,
}: {
  editions: NavEdition[];
  options: NavOptions;
  /** Closes the mobile sheet after a link is chosen. */
  onNavigate?: () => void;
}) {
  const pathname = usePathname();
  const pathCode = editionCodeFromPath(pathname);
  const edition =
    editions.find((e) => e.code === pathCode) ??
    editions.find((e) => e.status !== "archived") ??
    editions[0] ??
    null;
  const code = edition?.code ?? null;
  const setup = options.setup && options.setup.code === code ? options.setup : null;

  const editionItems: NavItem[] = code
    ? [
        ...(options.canSetup && setup && setup.done < setup.total
          ? [
              {
                label: "Setup",
                href: `/${code}/setup`,
                icon: ListChecks,
                badge: { text: `${setup.done}/${setup.total}` },
              },
            ]
          : []),
        { label: "Dashboard", href: `/${code}/dashboard`, icon: LayoutDashboard },
        ...(allowed(options, "signage")
          ? [{ label: "Signage", href: `/${code}/signage`, icon: Signpost }]
          : []),
        ...(allowed(options, "sponsorship")
          ? [{ label: "Sponsorship", href: `/${code}/sponsorship`, icon: Gift }]
          : []),
        ...(allowed(options, "stand_designs")
          ? [
              {
                label: "Feature stands",
                href: `/${code}/stand-designs`,
                icon: Box,
                alsoActive: [`/${code}/stand-panels/`],
              },
            ]
          : []),
        ...(options.showStands && allowed(options, "stands")
          ? [{ label: "Exhibitor stands", href: `/${code}/stands`, icon: HardHat }]
          : []),
        ...(allowed(options, "onsite")
          ? [{ label: "Onsite", href: `/${code}/onsite`, icon: Wrench }]
          : []),
        ...(allowed(options, "calendar")
          ? [{ label: "Calendar", href: `/${code}/calendar`, icon: CalendarDays }]
          : []),
        ...(allowed(options, "reports")
          ? [{ label: "Reports", href: `/${code}/reports`, icon: FileBarChart }]
          : []),
        ...(options.canSetup
          ? [{ label: "Halls & locations", href: `/${code}/halls`, icon: MapPin }]
          : []),
        ...(options.canSetup && !(setup && setup.done < setup.total)
          ? [{ label: "Event details", href: `/${code}/setup`, icon: ListChecks }]
          : []),
      ]
    : [];

  const counts = options.counts;
  const globalItems: NavItem[] = [
    ...(editions.length === 0 && options.canSetup
      ? [{ label: "Create your event", href: "/start", icon: Sparkles }]
      : []),
    {
      label: "My Work",
      href: "/my-work",
      icon: ListTodo,
      badge: counts && counts.myWork > 0 ? { text: String(counts.myWork) } : undefined,
    },
    ...(allowed(options, "approvals") || (counts?.approvals ?? 0) > 0
      ? [
          {
            label: "Approvals",
            href: "/approvals",
            icon: ClipboardCheck,
            badge:
              counts && counts.approvals > 0
                ? {
                    text: String(counts.approvals),
                    tone: counts.approvalsOverdue ? ("alert" as const) : ("default" as const),
                  }
                : undefined,
          },
        ]
      : []),
    { label: "Events", href: "/events", icon: Layers },
    ...(allowed(options, "suppliers")
      ? [{ label: "Suppliers", href: "/suppliers", icon: Truck }]
      : []),
    { label: "Users", href: "/users", icon: Users },
    ...(options.canSettings ? [{ label: "Settings", href: "/settings", icon: Settings }] : []),
  ];

  function renderItems(items: NavItem[]) {
    return items.map((item) => {
      const active =
        pathname === item.href ||
        pathname.startsWith(`${item.href}/`) ||
        (item.alsoActive ?? []).some((p) => pathname.startsWith(p));
      return (
        <Link
          key={item.href + item.label}
          href={item.href}
          onClick={onNavigate}
          className={cn(
            "flex min-h-9 items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
            active
              ? "bg-sidebar-accent text-sidebar-accent-foreground"
              : "text-muted-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
          )}
          aria-current={active ? "page" : undefined}
        >
          <item.icon className="size-4 shrink-0" aria-hidden />
          <span className="min-w-0 flex-1 truncate">{item.label}</span>
          {item.badge && (
            <span
              className={cn(
                "rounded-full px-1.5 py-0.5 text-[11px] leading-none font-semibold tabular-nums",
                item.badge.tone === "alert"
                  ? "bg-red-600 text-white"
                  : "bg-muted text-foreground border",
              )}
            >
              {item.badge.text}
            </span>
          )}
        </Link>
      );
    });
  }

  return (
    <nav className="flex flex-col gap-1 p-2" aria-label="Main navigation">
      {edition && editionItems.length > 0 && (
        <>
          <div className="px-3 pt-2 pb-1">
            <p className="text-muted-foreground text-[11px] font-semibold tracking-wide uppercase">
              {pathCode ? "Event" : "Current event"}
            </p>
            <p className="truncate text-sm font-semibold" title={edition.name}>
              {edition.name}
            </p>
            <p className="text-muted-foreground text-xs">{edition.code}</p>
          </div>
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
