"use client";

import Link from "next/link";
import { ChevronDown, UserPlus, Users } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { cn } from "@/lib/utils";

/**
 * Users → "Add people": one person (the full form) or several at once
 * (paste a list). `query` carries a department to start in, e.g. from a
 * department card.
 */
export function AddPeopleMenu({
  className,
  query = "",
  label = "Add people",
}: {
  className?: string;
  /** Extra search params for both choices, e.g. "department=…". */
  query?: string;
  label?: string;
}) {
  const one = `/users/new${query ? `?${query}` : ""}`;
  const several = `/users/new?mode=several${query ? `&${query}` : ""}`;
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button className={cn("h-11 sm:h-9", className)}>
          <UserPlus aria-hidden />
          {label}
          <ChevronDown aria-hidden />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-56">
        <DropdownMenuItem asChild>
          <Link href={one} className="min-h-11 sm:min-h-8">
            <UserPlus aria-hidden />
            Add one person
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link href={several} className="min-h-11 sm:min-h-8">
            <Users aria-hidden />
            Add several people
          </Link>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
