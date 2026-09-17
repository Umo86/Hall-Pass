import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth/actor";
import { getObject, type Bucket } from "@/lib/storage";

const BUCKETS: Bucket[] = ["artwork", "documents", "photos", "floorplans", "exports"];

/**
 * Local-backend file serving (development/demo). Supabase deployments issue
 * signed URLs instead and never hit this route. Requires a signed-in session;
 * record-level scoping is enforced where files are listed, and paths are
 * unguessable (uuid segment per file).
 */
export async function GET(
  _req: Request,
  { params }: { params: Promise<{ path: string[] }> },
) {
  const session = await getSession();
  if (!session) return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  const { path } = await params;
  const [bucket, ...rest] = path;
  if (!BUCKETS.includes(bucket as Bucket) || rest.length === 0) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }
  try {
    const data = await getObject(bucket as Bucket, rest.join("/"));
    return new NextResponse(new Uint8Array(data), {
      headers: {
        "Content-Type": "application/octet-stream",
        "Content-Disposition": `attachment; filename="${rest[rest.length - 1]}"`,
        "X-Content-Type-Options": "nosniff",
      },
    });
  } catch {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }
}
