import { NextResponse } from "next/server";

// Placeholder — the tokenised iCal feed of install dates is built in Phase 3.
export async function GET() {
  return NextResponse.json({ error: "The iCal feed is not yet available" }, { status: 501 });
}
