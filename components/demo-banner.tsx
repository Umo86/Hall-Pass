import { devAuthEnabled } from "@/lib/auth/actor";

/** A loud reminder while one-click demo sign-in is switched on. */
export function DemoBanner() {
  if (!devAuthEnabled()) return null;
  return (
    <div
      role="alert"
      className="bg-destructive px-3 py-1.5 text-center text-xs font-medium text-white"
    >
      Demo sign-in is on: anyone with this link can sign in as any demo account. Remove DEV_AUTH
      before real use.
    </div>
  );
}
