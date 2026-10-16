import Link from "next/link";
import { cn } from "@/lib/utils";

/** Suppliers (n) | Install contractors (n). */
export function SuppliersTabs({
  tab,
  suppliers,
  contractors,
}: {
  tab: "suppliers" | "contractors";
  suppliers: number;
  contractors: number;
}) {
  const tabs = [
    { id: "suppliers", label: "Suppliers", n: suppliers, href: "/suppliers" },
    {
      id: "contractors",
      label: "Install contractors",
      n: contractors,
      href: "/suppliers?tab=contractors",
    },
  ] as const;
  return (
    <nav className="-mt-2 flex gap-1 overflow-x-auto border-b" aria-label="Suppliers sections">
      {tabs.map((t) => (
        <Link
          key={t.id}
          href={t.href}
          className={cn(
            "inline-flex min-h-11 items-center gap-1.5 px-3 text-sm whitespace-nowrap sm:min-h-9",
            tab === t.id
              ? "border-primary text-foreground border-b-2 font-medium"
              : "text-muted-foreground hover:text-foreground",
          )}
          aria-current={tab === t.id ? "page" : undefined}
        >
          {t.label}
          <span className="bg-muted rounded-full px-1.5 text-xs tabular-nums">{t.n}</span>
        </Link>
      ))}
    </nav>
  );
}
