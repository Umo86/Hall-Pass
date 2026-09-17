import { PlaceholderPage } from "@/components/placeholder-page";

export const metadata = { title: "Dashboard" };

export default function Page() {
  return (
    <PlaceholderPage
      title="Dashboard"
      description="Items by status, sitting-with counts, overdue approvals, upcoming deadlines, budget position and the stand submission funnel."
      phase="Phase 1"
    />
  );
}
