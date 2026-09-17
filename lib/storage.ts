/**
 * File storage abstraction. Production uses Supabase Storage private buckets
 * with signed URLs; when Supabase is not configured the local-filesystem
 * backend keeps development and demo deployments working (files under
 * .data/uploads, served through an authenticated route). Paths follow
 * {organisation_id}/{edition_id}/{entity_type}/{entity_id}/{uuid}-{name}.
 */
import { createHash, randomUUID } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { createClient } from "@supabase/supabase-js";

export type Bucket = "artwork" | "documents" | "photos" | "floorplans" | "exports";

const LOCAL_ROOT = path.join(process.cwd(), ".data", "uploads");

function supabaseAdmin() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
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
  const supabase = supabaseAdmin();
  if (supabase) {
    const { error } = await supabase.storage
      .from(bucket)
      .upload(storagePath, data, { upsert: true });
    if (error) throw new Error(`Storage upload failed: ${error.message}`);
    return;
  }
  const full = path.join(LOCAL_ROOT, bucket, storagePath);
  await mkdir(path.dirname(full), { recursive: true });
  await writeFile(full, data);
}

export async function getObject(bucket: Bucket, storagePath: string): Promise<Buffer> {
  const supabase = supabaseAdmin();
  if (supabase) {
    const { data, error } = await supabase.storage.from(bucket).download(storagePath);
    if (error || !data) throw new Error(`Storage download failed: ${error?.message}`);
    return Buffer.from(await data.arrayBuffer());
  }
  return readFile(path.join(LOCAL_ROOT, bucket, storagePath));
}

/**
 * A short-lived URL the browser can fetch. Supabase issues a 15-minute
 * signed URL; the local backend serves through the authenticated
 * /api/files route.
 */
export async function getDownloadUrl(bucket: Bucket, storagePath: string): Promise<string> {
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
