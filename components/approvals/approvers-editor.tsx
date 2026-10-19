import Link from "next/link";
import { Star } from "lucide-react";
import { EmptyState } from "@/components/empty-state";
import { Button } from "@/components/ui/button";
import { EventsTag } from "@/components/users/person-fields";

export type WhoSignsOffDepartment = {
  id: string;
  name: string;
  defaultFor: string[];
  signsLast: boolean;
  approvers: {
    id: string;
    name: string;
    jobTitle: string | null;
    isMain: boolean;
    /** Invited: becomes the main approver when they accept. */
    mainOnAccept?: boolean;
    state: "active" | "paused" | "invited" | "none";
    /** Users → Events: "BIRM27 only" for someone limited; null/missing = All events. */
    events?: { text: string; title: string } | null;
  }[];
};

const STATE_TEXT = {
  active: null,
  paused: "sign-off paused",
  invited: "invited, not set up yet",
  none: "no account yet",
} as const;

/**
 * Approvals → Who signs off: each department that signs off artwork, its
 * approvers and its main approver. Read-only; admins change it in
 * Users → Departments.
 */
export function WhoSignsOff({
  departments,
  canManage,
}: {
  departments: WhoSignsOffDepartment[];
  canManage: boolean;
}) {
  return (
    <section className="space-y-4">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <p className="text-muted-foreground max-w-3xl text-sm">
          Each department signs off the artwork for the signage it&apos;s set up for. The{" "}
          <span className="text-foreground font-medium">main approver</span> gets every item unless
          someone else in the department is picked when the signage is added; otherwise anyone
          listed can sign. Departments that sign off last wait until the others have approved.
        </p>
        {canManage && (
          <Button asChild variant="outline" className="h-11 shrink-0 sm:h-9">
            <Link href="/users?tab=departments">Manage in Users</Link>
          </Button>
        )}
      </div>
      {departments.length === 0 ? (
        <EmptyState
          title="No department signs off artwork yet"
          description={
            canManage
              ? "Switch on sign-off for a department in Users → Departments and add who signs."
              : "People who manage departments set up who signs off, in Users → Departments."
          }
        />
      ) : (
        <div className="grid gap-3 md:grid-cols-2">
          {departments.map((d) => {
            const rules = [
              d.defaultFor.includes("organiser") && "organiser signage",
              d.defaultFor.includes("sponsor") && "sponsor signage",
            ].filter(Boolean);
            return (
              <section key={d.id} className="rounded-lg border" aria-label={`${d.name} approvers`}>
                <header className="border-b px-4 py-3">
                  <h3 className="font-semibold">{d.name}</h3>
                  <p className="text-muted-foreground text-xs">
                    {rules.length > 0
                      ? `Signs off ${rules.join(" and ")} by default`
                      : "Only when ticked on an item"}
                    {d.signsLast ? " · after the other departments" : ""}
                  </p>
                </header>
                <ul className="divide-y">
                  {d.approvers.length === 0 && (
                    <li className="text-muted-foreground px-4 py-2 text-sm">
                      Nobody signs off for {d.name} yet.
                    </li>
                  )}
                  {d.approvers.map((a) => (
                    <li key={a.id} className="flex items-center gap-2 px-4 py-2 text-sm">
                      {a.isMain ? (
                        <Star
                          className="size-4 shrink-0 fill-amber-400 text-amber-500"
                          role="img"
                          aria-label="Main approver"
                        />
                      ) : a.mainOnAccept ? (
                        <Star
                          className="size-4 shrink-0 text-amber-500"
                          role="img"
                          aria-label="Main approver when they accept"
                        />
                      ) : (
                        <span className="size-4 shrink-0" aria-hidden />
                      )}
                      <span className="min-w-0 flex-1">
                        <span className="font-medium">{a.name}</span>
                        {a.isMain && (
                          <span className="text-muted-foreground"> · main approver</span>
                        )}
                        {!a.isMain && a.mainOnAccept && (
                          <span className="text-muted-foreground">
                            {" "}
                            · main approver when they accept
                          </span>
                        )}
                        {(a.jobTitle || STATE_TEXT[a.state]) && (
                          <span className="text-muted-foreground block text-xs">
                            {[a.jobTitle, STATE_TEXT[a.state]].filter(Boolean).join(" · ")}
                          </span>
                        )}
                        {a.events && (
                          <span className="flex flex-wrap gap-1 pt-0.5">
                            <EventsTag text={a.events.text} title={a.events.title} />
                          </span>
                        )}
                      </span>
                    </li>
                  ))}
                </ul>
              </section>
            );
          })}
        </div>
      )}
    </section>
  );
}
