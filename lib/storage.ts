/**
 * File storage abstraction, in priority order:
 *  1. Vercel Blob when BLOB_READ_WRITE_TOKEN is set — pathnames are
 *     {bucket}/{storagePath}, URLs are unguessable (every path carries a
 *     uuid segment) and downloads are served straight from the blob CDN.
 *  2. Supabase Storage private buckets with signed URLs.
 *  3. Local filesystem (development/demo), files under .data/uploads served
 *     through the authenticated /api/files route.
 * Paths follow {organisation_id}/{edition_id}/{entity_type}/{entity_id}/{uuid}-{name}.
 */
import { createHash, randomUUID } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { createClient } from "@supabase/supabase-js";

export type Bucket = "artwork" | "documents" | "photos" | "floorplans" | "exports";

const LOCAL_ROOT = path.join(process.cwd(), ".data", "uploads");

/** A file under the local store — never outside it (no "../" tricks). */
function localPath(bucket: Bucket, storagePath: string): string {
  const root = path.resolve(LOCAL_ROOT, bucket);
  const full = path.resolve(root, storagePath);
  if (!full.startsWith(root + path.sep)) throw new Error("Invalid storage path");
  return full;
}

export function blobEnabled(): boolean {
  return Boolean(process.env.BLOB_READ_WRITE_TOKEN);
}

async function blobUrlFor(bucket: Bucket, storagePath: string): Promise<string> {
  const { list } = await import("@vercel/blob");
  const { blobs } = await list({ prefix: `${bucket}/${storagePath}`, limit: 1 });
  if (!blobs[0]) throw new Error(`Blob not found: ${bucket}/${storagePath}`);
  return blobs[0].url;
}

function supabaseAdmin() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  // New projects issue sb_secret_… keys in place of the legacy service role key.
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY ?? process.env.SUPABASE_SECRET_KEY;
  if (!url || !key) return null;
  return createClient(url, key, { auth: { persistSession: false } });
}

export function sanitiseFilename(name: string): string {
  return name.replace(/[^\w.-]+/g, "_").slice(0, 120);
}

export function buildStoragePath(opts: {
  organisationId: string;
  editionId: string | null;
  entityType: string;
  entityId: string;
  fileName: string;
}): string {
  const clean = sanitiseFilename(opts.fileName);
  return [
    opts.organisationId,
    opts.editionId ?? "org",
    opts.entityType,
    opts.entityId,
    `${randomUUID()}-${clean}`,
  ].join("/");
}

export function sha256Hex(data: Buffer | string): string {
  return createHash("sha256").update(data).digest("hex");
}

/** Store a file server-side (used by direct uploads and export generation). */
export async function putObject(bucket: Bucket, storagePath: string, data: Buffer): Promise<void> {
  if (blobEnabled()) {
    const { put } = await import("@vercel/blob");
    await put(`${bucket}/${storagePath}`, data, {
      access: "public",
      addRandomSuffix: false,
      allowOverwrite: true,
    });
    return;
  }
  const supabase = supabaseAdmin();
  if (supabase) {
    const { error } = await supabase.storage
      .from(bucket)
      .upload(storagePath, data, { upsert: true });
    if (error) throw new Error(`Storage upload failed: ${error.message}`);
    return;
  }
  const full = localPath(bucket, storagePath);
  await mkdir(path.dirname(full), { recursive: true });
  await writeFile(full, data);
}

export async function getObject(bucket: Bucket, storagePath: string): Promise<Buffer> {
  if (blobEnabled()) {
    const res = await fetch(await blobUrlFor(bucket, storagePath));
    if (!res.ok) throw new Error(`Blob download failed: ${res.status}`);
    return Buffer.from(await res.arrayBuffer());
  }
  const supabase = supabaseAdmin();
  if (supabase) {
    const { data, error } = await supabase.storage.from(bucket).download(storagePath);
    if (error || !data) throw new Error(`Storage download failed: ${error?.message}`);
    return Buffer.from(await data.arrayBuffer());
  }
  return readFile(localPath(bucket, storagePath));
}

/**
 * A short-lived URL the browser can fetch. Supabase issues a 15-minute
 * signed URL; the local backend serves through the authenticated
 * /api/files route.
 */
export async function getDownloadUrl(bucket: Bucket, storagePath: string): Promise<string> {
  if (blobEnabled()) return blobUrlFor(bucket, storagePath);
  const supabase = supabaseAdmin();
  if (supabase) {
    const { data, error } = await supabase.storage
      .from(bucket)
      .createSignedUrl(storagePath, 60 * 15);
    if (error || !data) throw new Error(`Signed URL failed: ${error?.message}`);
    return data.signedUrl;
  }
  return `/api/files/${bucket}/${storagePath}`;
}

/**
 * Like getDownloadUrl but for rendering in the page (image tags, PDF frames)
 * rather than saving: the local backend serves it inline with its real
 * content type. Supabase signed URLs already carry the stored content type.
 */
export async function getInlineUrl(bucket: Bucket, storagePath: string): Promise<string> {
  if (blobEnabled()) return blobUrlFor(bucket, storagePath);
  const supabase = supabaseAdmin();
  if (supabase) return getDownloadUrl(bucket, storagePath);
  return `/api/files/${bucket}/${storagePath}?inline=1`;
}
