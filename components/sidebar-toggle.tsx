"use client";

import { useState } from "react";
import { PanelLeftClose, PanelLeftOpen } from "lucide-react";
import { SIDEBAR_COOKIE } from "@/lib/sidebar";

/**
 * Hide or show the side menu on larger screens, for more room on wide
 * pages. Remembered in a cookie so the page opens the same way next time.
 */
export function SidebarToggle({ initiallyHidden }: { initiallyHidden: boolean }) {
  const [hidden, setHidden] = useState(initiallyHidden);
  return (
    <button
      type="button"
      className="text-muted-foreground hover:text-foreground hover:bg-muted hidden size-8 items-center justify-center rounded-md md:inline-flex"
      aria-label={hidden ? "Show menu" : "Hide menu"}
      title={hidden ? "Show menu" : "Hide menu"}
      aria-pressed={hidden}
      onClick={(e) => {
        const next = !hidden;
        setHidden(next);
        e.currentTarget
          .closest("[data-sidebar]")
          ?.setAttribute("data-sidebar", next ? "hidden" : "shown");
        document.cookie = `${SIDEBAR_COOKIE}=${next ? "hidden" : "shown"}; path=/; max-age=31536000; samesite=lax`;
      }}
    >
      {hidden ? <PanelLeftOpen className="size-4" /> : <PanelLeftClose className="size-4" />}
    </button>
  );
}
