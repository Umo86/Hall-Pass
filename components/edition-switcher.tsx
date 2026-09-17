"use client";

import { ChevronsUpDown } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

// Static placeholder until editions are read from the database in Phase 1.
const editions = [{ code: "BIRM27", name: "UKCW Birmingham 2027" }];

export function EditionSwitcher() {
  const current = editions[0];

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" size="sm" className="gap-2">
          <span className="font-medium">{current.code}</span>
          <span className="text-muted-foreground hidden sm:inline">{current.name}</span>
          <ChevronsUpDown className="size-3.5 opacity-50" aria-hidden />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="w-64">
        <DropdownMenuLabel>Editions</DropdownMenuLabel>
        <DropdownMenuSeparator />
        {editions.map((edition) => (
          <DropdownMenuItem key={edition.code}>
            <span className="font-medium">{edition.code}</span>
            <span className="text-muted-foreground">{edition.name}</span>
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
