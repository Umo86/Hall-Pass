"use client";

import { Toaster as Sonner, type ToasterProps } from "sonner";

/**
 * Where success and error messages appear after an action ("Supplier
 * saved", "Invitation sent"). Mounted once in the root layout; call
 * `toast.success(…)` / `toast.error(…)` from "sonner" anywhere on the client.
 */
export function Toaster(props: ToasterProps) {
  return (
    <Sonner
      position="bottom-center"
      closeButton
      duration={5000}
      toastOptions={{
        classNames: {
          toast: "bg-background text-foreground border-border shadow-lg",
          description: "text-muted-foreground",
          actionButton: "bg-primary text-primary-foreground",
        },
      }}
      {...props}
    />
  );
}
