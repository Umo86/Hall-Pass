import Link from "next/link";
import { cn } from "@/lib/utils";

/** Classes for one option of a segmented control (links or buttons). */
export function segmentClass(active: boolean) {
  return cn(
    "inline-flex h-9 items-center gap-1.5 whitespace-nowrap px-3 text-sm font-medium transition-colors first:rounded-l-md last:rounded-r-md",
    "focus-visible:ring-ring focus-visible:relative focus-visible:ring-2 focus-visible:outline-none",
    active
      ? "bg-primary text-primary-foreground"
      : "bg-background text-muted-foreground hover:bg-accent hover:text-foreground",
  );
}

/** The bordered group that holds segment options. */
export function SegmentGroup({
  label,
  className,
  children,
}: {
  label: string;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <div
      role="group"
      aria-label={label}
      className={cn("inline-flex max-w-full divide-x overflow-x-auto rounded-md border", className)}
    >
      {children}
    </div>
  );
}

export type SegmentLink = { label: string; href: string; active: boolean; count?: number };

/**
 * A segmented control made of links, for scope toggles that live in the
 * URL ("My tasks | Given to others | Everyone's"). Works without JavaScript.
 */
export function SegmentedLinks({
  label,
  items,
  className,
}: {
  label: string;
  items: SegmentLink[];
  className?: string;
}) {
  return (
    <SegmentGroup label={label} className={className}>
      {items.map((item) => (
        <Link
          key={item.href}
          href={item.href}
          aria-current={item.active ? "page" : undefined}
          className={segmentClass(item.active)}
        >
          {item.label}
          {item.count !== undefined && (
            <span
              className={cn(
                "rounded-full px-1.5 text-xs tabular-nums",
                item.active ? "bg-primary-foreground/20" : "bg-muted",
              )}
            >
              {item.count}
            </span>
          )}
        </Link>
      ))}
    </SegmentGroup>
  );
}
