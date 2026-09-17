import { Badge } from "@/components/ui/badge";

/**
 * Temporary stand-in for screens that arrive in a later phase. Every route
 * from the brief exists from day one so navigation, layout and deployment
 * can be exercised; the real screen replaces this component in its phase.
 */
export function PlaceholderPage({
  title,
  description,
  phase,
}: {
  title: string;
  description: string;
  phase: string;
}) {
  return (
    <div className="flex flex-col gap-4 p-6">
      <div className="flex items-center gap-3">
        <h1 className="text-xl font-semibold tracking-tight">{title}</h1>
        <Badge variant="outline">Arriving in {phase}</Badge>
      </div>
      <p className="text-muted-foreground max-w-prose text-sm">{description}</p>
      <div className="border-border text-muted-foreground mt-4 flex h-48 max-w-3xl items-center justify-center rounded-lg border border-dashed text-sm">
        This screen has not been built yet.
      </div>
    </div>
  );
}
