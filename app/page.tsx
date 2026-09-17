import { redirect } from "next/navigation";
import { getSession } from "@/lib/auth/actor";

export const dynamic = "force-dynamic";

export default async function Home() {
  const session = await getSession().catch(() => null);
  if (!session) redirect("/login");
  redirect(session.actor.kind === "staff" ? "/editions" : "/portal/approvals");
}
