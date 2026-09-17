import { PlaceholderPage } from "@/components/placeholder-page";

export const metadata = { title: "My Items" };

export default function Page() {
  return (
    <PlaceholderPage
      title="My Items"
      description="The signage items you are scoped to, with the fields you are allowed to see."
      phase="Phase 1"
    />
  );
}
