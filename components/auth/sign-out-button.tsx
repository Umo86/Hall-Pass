"use client";

import { LogOut } from "lucide-react";
import { Button } from "@/components/ui/button";
import { signOut } from "@/app/actions/auth";

export function SignOutButton() {
  return (
    <Button variant="ghost" size="icon" aria-label="Sign out" onClick={() => signOut()}>
      <LogOut className="size-4" aria-hidden />
    </Button>
  );
}
