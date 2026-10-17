import Link from "next/link";
import { Lock } from "lucide-react";
import { FEATURE_LABELS, type Feature } from "@/lib/authz";
import { EmptyState } from "@/components/empty-state";
import { Page } from "@/components/page-header";
import { Button } from "@/components/ui/button";

/**
 * Shown instead of a section the person hasn't been given (Users →
 * Sections). Not a 404: it says what the section is and who to ask.
 */
export function SectionUnavailable({ feature, backHref }: { feature: Feature; backHref?: string }) {
  const label = FEATURE_LABELS[feature];
  return (
    <Page width="narrow">
      <EmptyState
        icon={Lock}
        title={`${label} isn't switched on for you`}
        description={`Ask a super admin or your manager to add ${label} to your sections in Users if you need it.`}
        action={
          <Button asChild variant="outline">
            <Link href={backHref ?? "/my-work"}>Back to My Work</Link>
          </Button>
        }
      />
    </Page>
  );
}
