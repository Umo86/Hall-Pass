import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth/actor";
import { getObject, type Bucket } from "@/lib/storage";

const BUCKETS: Bucket[] = ["artwork", "documents", "photos", "floorplans", "exports"];

// Types that are safe to render inline. Anything else (SVG included — it can
// carry scripts) downloads as an attachment; previews of SVGs are rasterised.
const INLINE_TYPES: Record<string, string> = {
  pdf: "application/pdf",
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  webp: "image/webp",
  gif: "image/gif",
};

/**
 * Local-backend file serving (development/demo). Supabase deployments issue
 * signed URLs instead and never hit this route. Requires a signed-in session;
 * record-level scoping is enforced where files are listed, and paths are
 * unguessable (uuid segment per file).
 */
export async function GET(req: Request, { params }: { params: Promise<{ path: string[] }> }) {
  const session = await getSession();
  if (!session) return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  const { path } = await params;
  const [bucket, ...rest] = path;
  if (!BUCKETS.includes(bucket as Bucket) || rest.length === 0) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }
  const fileName = rest[rest.length - 1];
  const ext = fileName.split(".").pop()?.toLowerCase() ?? "";
  const wantsInline = new URL(req.url).searchParams.get("inline") === "1";
  const inlineType = wantsInline ? INLINE_TYPES[ext] : undefined;
  try {
    const data = await getObject(bucket as Bucket, rest.join("/"));
    return new NextResponse(new Uint8Array(data), {
      headers: {
        "Content-Type": inlineType ?? "application/octet-stream",
        "Content-Disposition": `${inlineType ? "inline" : "attachment"}; filename="${fileName}"`,
        "X-Content-Type-Options": "nosniff",
      },
    });
  } catch {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }
}
