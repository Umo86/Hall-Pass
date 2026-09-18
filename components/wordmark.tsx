import { cn } from "@/lib/utils";

/**
 * Text-based logo. The brand name stays a config value: the first word is
 * set in the foreground colour, the rest in the accent, closed with an
 * amber full stop — distinctive at any size with no image asset.
 */
export function Wordmark({
  name,
  className,
  size = "md",
}: {
  name: string;
  className?: string;
  size?: "sm" | "md" | "lg";
}) {
  const [first, ...rest] = name.split(" ");
  const sizes = {
    sm: "text-sm",
    md: "text-lg",
    lg: "text-3xl sm:text-4xl",
  } as const;
  return (
    <span
      className={cn(
        "inline-flex items-baseline font-bold tracking-tight lowercase select-none",
        sizes[size],
        className,
      )}
    >
      <span>{first}</span>
      {rest.length > 0 && (
        <span className="text-indigo-600 dark:text-indigo-400">{rest.join(" ")}</span>
      )}
      <span className="text-amber-500" aria-hidden>
        .
      </span>
    </span>
  );
}

/** Thin multi-colour rule used under headers on public pages. */
export function AccentRule({ className }: { className?: string }) {
  return (
    <span className={cn("flex h-1 w-full overflow-hidden rounded-full", className)} aria-hidden>
      <span className="flex-1 bg-indigo-500" />
      <span className="flex-1 bg-sky-500" />
      <span className="flex-1 bg-emerald-500" />
      <span className="flex-1 bg-amber-500" />
      <span className="flex-1 bg-rose-500" />
    </span>
  );
}
