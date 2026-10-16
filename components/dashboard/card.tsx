import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { cn } from "@/lib/utils";

/**
 * One dashboard card: a heading (a link when there is a page behind it),
 * an optional muted count beside it, the content, and a footer link.
 */
export function DashCard({
  title,
  titleHref,
  count,
  footer,
  className,
  children,
}: {
  title: string;
  titleHref?: string | null;
  count?: React.ReactNode;
  footer?: React.ReactNode;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <section
      aria-label={title}
      className={cn("flex min-w-0 flex-col gap-3 rounded-lg border p-4", className)}
    >
      <div className="flex min-w-0 flex-col gap-3">
        <h2 className="text-sm font-semibold">
          {titleHref ? (
            <Link href={titleHref} className="hover:underline">
              {title}
            </Link>
          ) : (
            title
          )}
          {count != null && <span className="ml-1.5">{count}</span>}
        </h2>
        {children}
      </div>
      {footer && <div className="mt-auto">{footer}</div>}
    </section>
  );
}

/** "See all 69 overdue →" at the foot of a card. */
export function CardFooterLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="text-muted-foreground hover:text-foreground inline-flex w-fit items-center gap-1 text-sm"
    >
      {children}
      <ArrowRight className="size-3.5" aria-hidden />
    </Link>
  );
}
