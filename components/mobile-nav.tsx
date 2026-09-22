"use client";

import { useState } from "react";
import { Menu } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { AppNav, type NavEdition } from "@/components/app-nav";
import { Wordmark } from "@/components/wordmark";

/** Hamburger + slide-out navigation for screens below the md breakpoint. */
export function MobileNav({ editions, brandName }: { editions: NavEdition[]; brandName: string }) {
  const [open, setOpen] = useState(false);
  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button variant="ghost" size="sm" className="md:hidden" aria-label="Open menu">
          <Menu className="size-5" />
        </Button>
      </SheetTrigger>
      <SheetContent side="left" aria-describedby={undefined}>
        <SheetTitle className="px-5 pt-5">
          <Wordmark name={brandName} size="sm" />
        </SheetTitle>
        <div className="p-2">
          <AppNav editions={editions} onNavigate={() => setOpen(false)} />
        </div>
      </SheetContent>
    </Sheet>
  );
}
