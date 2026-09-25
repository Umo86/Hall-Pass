"use client";

import { usePathname, useRouter } from "next/navigation";
import { ChevronsUpDown } from "lucide-react";
import { editionCodeFromPath } from "@/lib/edition-path";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

export type EditionOption = { code: string; name: string; status: string };

export function EditionSwitcher({ editions }: { editions: EditionOption[] }) {
  const pathname = usePathname();
  const router = useRouter();
  const first = editionCodeFromPath(pathname);
  const current =
    editions.find((e) => e.code === first) ?? editions.find((e) => e.status !== "archived");

  function go(code: string) {
    if (first) {
      router.push(pathname.replace(`/${first}`, `/${code}`));
    } else {
      router.push(`/${code}/dashboard`);
    }
  }

  if (editions.length === 0) return null;

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" size="sm" className="gap-2">
          <span className="font-medium">{current?.code ?? "Select edition"}</span>
          <span className="text-muted-foreground hidden max-w-48 truncate sm:inline">
            {current?.name}
          </span>
          <ChevronsUpDown className="size-3.5 opacity-50" aria-hidden />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="w-72">
        <DropdownMenuLabel>Shows</DropdownMenuLabel>
        <DropdownMenuSeparator />
        {editions.map((edition) => (
          <DropdownMenuItem key={edition.code} onSelect={() => go(edition.code)}>
            <span className="font-medium">{edition.code}</span>
            <span className="text-muted-foreground truncate">{edition.name}</span>
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
