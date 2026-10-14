"use client";

import { useState } from "react";
import Link from "next/link";
import { LogOut, Menu, UserRound } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { AppNav, type NavEdition, type NavOptions } from "@/components/app-nav";
import { Wordmark } from "@/components/wordmark";
import type { AccountInfo } from "@/components/account-menu";
import { signOut } from "@/app/actions/auth";

/** Hamburger + slide-out navigation for screens below the md breakpoint. */
export function MobileNav({
  editions,
  options,
  brandName,
  account,
}: {
  editions: NavEdition[];
  options: NavOptions;
  brandName: string;
  account: AccountInfo;
}) {
  const [open, setOpen] = useState(false);
  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button variant="ghost" size="touch" className="md:hidden" aria-label="Open menu">
          <Menu className="size-5" />
        </Button>
      </SheetTrigger>
      <SheetContent side="left" aria-describedby={undefined} className="flex flex-col">
        <SheetTitle className="px-5 pt-5">
          <Wordmark name={brandName} size="sm" />
        </SheetTitle>
        <div className="flex-1 overflow-y-auto p-2">
          <AppNav editions={editions} options={options} onNavigate={() => setOpen(false)} />
        </div>
        <div className="border-t p-4">
          <p className="truncate text-sm font-medium">{account.name || account.email}</p>
          <p className="text-muted-foreground truncate text-xs">
            {account.role}
            {account.department ? ` · ${account.department}` : ""}
          </p>
          <div className="mt-3 grid grid-cols-2 gap-2">
            <Button asChild variant="outline" size="sm" onClick={() => setOpen(false)}>
              <Link href="/account">
                <UserRound aria-hidden />
                My account
              </Link>
            </Button>
            <Button variant="outline" size="sm" onClick={() => void signOut()}>
              <LogOut aria-hidden />
              Sign out
            </Button>
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}
