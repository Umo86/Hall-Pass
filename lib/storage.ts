/**
 * File storage abstraction, in priority order:
 *  1. S3-compatible object storage (Cloudflare R2, AWS S3, MinIO…) when the
 *     S3_* variables are set — keys are {bucket}/{storagePath}, downloads are
 *     short-lived signed URLs and large artwork goes browser → bucket through
 *     a presigned PUT, so it never passes through the server.
 *  2. Vercel Blob when BLOB_READ_WRITE_TOKEN is set — pathnames are
 *     {bucket}/{storagePath}, URLs are unguessable (every path carries a
 *     uuid segment) and downloads are served straight from the blob CDN.
 *     While both 1 and 2 are configured, reads fall back to Blob for files
 *     not yet copied to the bucket (see /api/admin/storage/migrate).
 *  3. Supabase Storage private buckets with signed URLs.
 *  4. Local filesystem (development/demo), files under .data/uploads served
 *     through the authenticated /api/files route.
 * Paths follow {organisation_id}/{edition_id}/{entity_type}/{entity_id}/{uuid}-{name}.
 */
import { createHash, randomUUID } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { supabaseUrl } from "@/lib/auth/supabase-config";
import path from "node:path";
import { createClient } from "@supabase/supabase-js";
import type { S3Client } from "@aws-sdk/client-s3";

export type Bucket = "artwork" | "documents" | "photos" | "floorplans" | "exports";

const LOCAL_ROOT = path.join(process.cwd(), ".data", "uploads");

/** Signed download links live this long. */
export const SIGNED_URL_SECONDS = 60 * 15;
/** A presigned upload must start within this window. */
export const UPLOAD_URL_SECONDS = 60 * 10;
/** Direct browser uploads (artwork) are capped here; server uploads are smaller. */
export const MAX_DIRECT_UPLOAD_BYTES = 2 * 1024 * 1024 * 1024; // 2 GB

/** A file under the local store — never outside it (no "../" tricks). */
function localPath(bucket: Bucket, storagePath: string): string {
  const root = path.resolve(LOCAL_ROOT, bucket);
  const full = path.resolve(root, storagePath);
  if (!full.startsWith(root + path.sep)) throw new Error("Invalid storage path");
  return full;
}

// ----------------------------------------------------------- S3 / R2 backend

export type S3Config = {
  bucket: string;
  endpoint: string;
  region: string;
  accessKeyId: string;
  secretAccessKey: string;
};

/** The S3 settings from the environment, or null when any is missing. */
export function s3Config(env: Record<string, string | undefined> = process.env): S3Config | null {
  const bucket = env.S3_BUCKET;
  const endpoint = env.S3_ENDPOINT;
  const accessKeyId = env.S3_ACCESS_KEY_ID;
  const secretAccessKey = env.S3_SECRET_ACCESS_KEY;
  if (!bucket || !endpoint || !accessKeyId || !secretAccessKey) return null;
  // Cloudflare R2 wants "auto"; AWS wants the bucket's region.
  return { bucket, endpoint, region: env.S3_REGION || "auto", accessKeyId, secretAccessKey };
}

export function s3Enabled(): boolean {
  return s3Config() !== null;
}

let s3ClientCache: { key: string; client: S3Client } | null = null;

async function s3Client(): Promise<{ client: S3Client; bucket: string }> {
  const cfg = s3Config();
  if (!cfg) throw new Error("S3 storage is not configured");
  const key = `${cfg.endpoint}|${cfg.bucket}|${cfg.accessKeyId}`;
  if (!s3ClientCache || s3ClientCache.key !== key) {
    const { S3Client } = await import("@aws-sdk/client-s3");
    s3ClientCache = {
      key,
      client: new S3Client({
        region: cfg.region,
        endpoint: cfg.endpoint,
        credentials: { accessKeyId: cfg.accessKeyId, secretAccessKey: cfg.secretAccessKey },
        // Bucket-in-path works everywhere (R2, MinIO, AWS); virtual-host style does not.
        forcePathStyle: true,
      }),
    };
  }
  return { client: s3ClientCache.client, bucket: cfg.bucket };
}

/** The object key for a file: the bucket name is the first path segment. */
export function objectKey(bucket: Bucket, storagePath: string): string {
  if (storagePath.includes("..") || storagePath.startsWith("/")) {
    throw new Error("Invalid storage path");
  }
  return `${bucket}/${storagePath}`;
}

const CONTENT_TYPES: Record<string, string> = {
  pdf: "application/pdf",
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  webp: "image/webp",
  gif: "image/gif",
  tif: "image/tiff",
  tiff: "image/tiff",
  svg: "image/svg+xml",
  ai: "application/postscript",
  eps: "application/postscript",
  zip: "application/zip",
  xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  csv: "text/csv",
  docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ics: "text/calendar",
  json: "application/json",
  txt: "text/plain",
};

/** The media type a stored file should be served with, from its name. */
export function contentTypeFor(fileName: string): string {
  const ext = fileName.split(".").pop()?.toLowerCase() ?? "";
  return CONTENT_TYPES[ext] ?? "application/octet-stream";
}

// Types safe to show inline; anything else (SVG included — it can carry
// scripts) is sent as a download. SVG artwork is previewed rasterised.
const INLINE_SAFE = new Set([
  "application/pdf",
  "image/png",
  "image/jpeg",
  "image/webp",
  "image/gif",
]);

async function s3Put(
  bucket: Bucket,
  storagePath: string,
  data: Buffer,
  contentType?: string,
): Promise<void> {
  const { client, bucket: name } = await s3Client();
  const { PutObjectCommand } = await import("@aws-sdk/client-s3");
  await client.send(
    new PutObjectCommand({
      Bucket: name,
      Key: objectKey(bucket, storagePath),
      Body: data,
      ContentType: contentType ?? contentTypeFor(storagePath),
    }),
  );
}

async function s3Get(bucket: Bucket, storagePath: string): Promise<Buffer> {
  const { client, bucket: name } = await s3Client();
  const { GetObjectCommand } = await import("@aws-sdk/client-s3");
  const res = await client.send(
    new GetObjectCommand({ Bucket: name, Key: objectKey(bucket, storagePath) }),
  );
  if (!res.Body) throw new Error("Empty object");
  return Buffer.from(await res.Body.transformToByteArray());
}

/** Size and type of a stored object, or null when it does not exist. */
export async function s3Stat(
  bucket: Bucket,
  storagePath: string,
): Promise<{ size: number; contentType: string | null } | null> {
  const { client, bucket: name } = await s3Client();
  const { HeadObjectCommand } = await import("@aws-sdk/client-s3");
  try {
    const res = await client.send(
      new HeadObjectCommand({ Bucket: name, Key: objectKey(bucket, storagePath) }),
    );
    return { size: Number(res.ContentLength ?? 0), contentType: res.ContentType ?? null };
  } catch (err) {
    const status = (err as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode;
    const code = (err as { name?: string }).name;
    if (status === 404 || code === "NotFound" || code === "NoSuchKey") return null;
    throw err;
  }
}

/** One page of objects under a prefix (the key includes the bucket segment). */
export async function s3List(
  prefix: string,
  cursor?: string,
): Promise<{ objects: { key: string; size: number; lastModified: Date }[]; nextCursor?: string }> {
  const { client, bucket: name } = await s3Client();
  const { ListObjectsV2Command } = await import("@aws-sdk/client-s3");
  const res = await client.send(
    new ListObjectsV2Command({
      Bucket: name,
      Prefix: prefix,
      ContinuationToken: cursor,
      MaxKeys: 1000,
    }),
  );
  return {
    objects: (res.Contents ?? [])
      .filter((o) => o.Key)
      .map((o) => ({
        key: o.Key!,
        size: Number(o.Size ?? 0),
        lastModified: o.LastModified ?? new Date(0),
      })),
    nextCursor: res.IsTruncated ? res.NextContinuationToken : undefined,
  };
}

export async function s3Delete(bucket: Bucket, storagePath: string): Promise<void> {
  const { client, bucket: name } = await s3Client();
  const { DeleteObjectCommand } = await import("@aws-sdk/client-s3");
  await client.send(new DeleteObjectCommand({ Bucket: name, Key: objectKey(bucket, storagePath) }));
}

async function s3SignedGet(
  bucket: Bucket,
  storagePath: string,
  disposition: "inline" | "attachment",
): Promise<string> {
  const { client, bucket: name } = await s3Client();
  const { GetObjectCommand } = await import("@aws-sdk/client-s3");
  const { getSignedUrl } = await import("@aws-sdk/s3-request-presigner");
  const fileName = storagePath.split("/").pop() ?? "file";
  const type = contentTypeFor(fileName);
  const inline = disposition === "inline" && INLINE_SAFE.has(type);
  return getSignedUrl(
    client,
    new GetObjectCommand({
      Bucket: name,
      Key: objectKey(bucket, storagePath),
      ResponseContentType: inline ? type : "application/octet-stream",
      ResponseContentDisposition: `${inline ? "inline" : "attachment"}; filename="${fileName.replace(/"/g, "")}"`,
    }),
    { expiresIn: SIGNED_URL_SECONDS },
  );
}

/**
 * A presigned PUT the browser uploads straight to the bucket with. The
 * content type is part of the signature, so the client must send exactly
 * this one. Size is checked afterwards with s3Stat (presigned PUTs cannot
 * cap it up front).
 */
export async function createDirectUploadUrl(
  bucket: Bucket,
  storagePath: string,
  contentType: string,
): Promise<{ url: string; key: string; contentType: string; expiresInSeconds: number }> {
  const { client, bucket: name } = await s3Client();
  const { PutObjectCommand } = await import("@aws-sdk/client-s3");
  const { getSignedUrl } = await import("@aws-sdk/s3-request-presigner");
  const key = objectKey(bucket, storagePath);
  const type = contentType || contentTypeFor(storagePath);
  const url = await getSignedUrl(
    client,
    new PutObjectCommand({ Bucket: name, Key: key, ContentType: type }),
    // Sign the content type too, so the browser cannot store it as something else.
    { expiresIn: UPLOAD_URL_SECONDS, signableHeaders: new Set(["content-type"]) },
  );
  return { url, key, contentType: type, expiresInSeconds: UPLOAD_URL_SECONDS };
}

/**
 * Stream an object of unknown length into the bucket (used when copying
 * files over from Vercel Blob). Multipart under the hood, so gigabyte files
 * are fine.
 */
export async function s3PutStream(
  key: string,
  body: ReadableStream<Uint8Array> | Buffer,
  contentType: string,
): Promise<void> {
  const { client, bucket: name } = await s3Client();
  const { Upload } = await import("@aws-sdk/lib-storage");
  const { Readable } = await import("node:stream");
  const upload = new Upload({
    client,
    params: {
      Bucket: name,
      Key: key,
      Body: Buffer.isBuffer(body)
        ? body
        : Readable.fromWeb(body as unknown as import("node:stream/web").ReadableStream),
      ContentType: contentType,
    },
    queueSize: 2,
    partSize: 16 * 1024 * 1024,
    leavePartsOnError: false,
  });
  await upload.done();
}

// --------------------------------------------------------- Vercel Blob backend

export function blobEnabled(): boolean {
  return Boolean(process.env.BLOB_READ_WRITE_TOKEN);
}

async function blobUrlFor(bucket: Bucket, storagePath: string): Promise<string> {
  const { list } = await import("@vercel/blob");
  const { blobs } = await list({ prefix: `${bucket}/${storagePath}`, limit: 1 });
  if (!blobs[0]) throw new Error(`Blob not found: ${bucket}/${storagePath}`);
  return blobs[0].url;
}

/** Which backend new files go to — shown on /api/health. */
export function storageBackend(): "s3" | "blob" | "supabase" | "local" {
  if (s3Enabled()) return "s3";
  if (blobEnabled()) return "blob";
  if (supabaseAdmin()) return "supabase";
  return "local";
}

/** Direct browser uploads are possible with these backends. */
export function directUploadMode(): "s3" | "blob" | null {
  if (s3Enabled()) return "s3";
  if (blobEnabled()) return "blob";
  return null;
}

function supabaseAdmin() {
  const url = supabaseUrl();
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

/**
 * While moving from Vercel Blob to the bucket, a file that is not in the
 * bucket yet is still read from Blob.
 */
async function inS3OrBlob(bucket: Bucket, storagePath: string): Promise<"s3" | "blob"> {
  if (!blobEnabled()) return "s3";
  return (await s3Stat(bucket, storagePath)) ? "s3" : "blob";
}

/** Store a file server-side (used by direct uploads and export generation). */
export async function putObject(bucket: Bucket, storagePath: string, data: Buffer): Promise<void> {
  if (s3Enabled()) {
    await s3Put(bucket, storagePath, data);
    return;
  }
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
  if (s3Enabled() && (await inS3OrBlob(bucket, storagePath)) === "s3") {
    return s3Get(bucket, storagePath);
  }
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
 * A short-lived URL the browser can fetch. S3 and Supabase issue 15-minute
 * signed URLs; the local backend serves through the authenticated
 * /api/files route.
 */
export async function getDownloadUrl(bucket: Bucket, storagePath: string): Promise<string> {
  if (s3Enabled() && (await inS3OrBlob(bucket, storagePath)) === "s3") {
    return s3SignedGet(bucket, storagePath, "attachment");
  }
  if (blobEnabled()) return blobUrlFor(bucket, storagePath);
  const supabase = supabaseAdmin();
  if (supabase) {
    const { data, error } = await supabase.storage
      .from(bucket)
      .createSignedUrl(storagePath, SIGNED_URL_SECONDS);
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
  if (s3Enabled() && (await inS3OrBlob(bucket, storagePath)) === "s3") {
    return s3SignedGet(bucket, storagePath, "inline");
  }
  if (blobEnabled()) return blobUrlFor(bucket, storagePath);
  const supabase = supabaseAdmin();
  if (supabase) return getDownloadUrl(bucket, storagePath);
  return `/api/files/${bucket}/${storagePath}?inline=1`;
}
