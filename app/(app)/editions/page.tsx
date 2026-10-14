import { redirect } from "next/navigation";

/** The events list moved to /events. */
export default function OldEditionsPage() {
  redirect("/events");
}
