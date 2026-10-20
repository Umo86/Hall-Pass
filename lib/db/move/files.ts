/**
 * Does every file the database refers to exist in the bucket? A read-only
 * report for the move (files stay in R2; only the database moves). Values
 * starting "seed/" are demo samples (never uploaded), and values without a
 * "/" are not stored files (exports keep a file name only; an install photo
 * can be a note). Nothing is ever deleted.
 */
import { ident, type Queryable } from "./connect";

type BucketName = "artwork" | "documents" | "photos" | "floorplans" | "exports";

export const FILE_COLUMNS: readonly {
  table: string;
  column: string;
  /** Null: no code path writes it yet, so it is looked for in every bucket. */
  bucket: BucketName | null;
}[] = [
  { table: "artwork_versions", column: "file_path", bucket: "artwork" },
  { table: "artwork_versions", column: "preview_path", bucket: "artwork" },
  { table: "documents", column: "file_path", bucket: "documents" },
  { table: "task_attachments", column: "file_path", bucket: "documents" },
  { table: "editions", column: "logo_path", bucket: "documents" },
  { table: "signage_items", column: "photo_path", bucket: "photos" },
  { table: "signage_items", column: "install_photo_path", bucket: "photos" },
  { table: "snags", column: "photo_path", bucket: "photos" },
  { table: "snags", column: "resolution_photo_path", bucket: "photos" },
  { table: "stand_submissions", column: "build_check_photo_path", bucket: "photos" },
  { table: "halls", column: "floorplan_path", bucket: null },
  { table: "organisations", column: "logo_path", bucket: null },
  { table: "users", column: "avatar_path", bucket: null },
  { table: "exports", column: "file_path", bucket: "exports" },
];

export const FILE_BUCKETS: readonly BucketName[] = [
  "artwork",
  "documents",
  "photos",
  "floorplans",
  "exports",
];

export type FileRef = { table: string; column: string; id: string; value: string };

/** Lists object keys under a prefix, a page at a time (lib/storage.ts:s3List). */
export type Lister = (
  prefix: string,
  cursor?: string,
) => Promise<{ objects: { key: string }[]; nextCursor?: string }>;

export type FilesReport = {
  references: number;
  present: number;
  samples: number;
  notFiles: number;
  missing: (FileRef & { key: string })[];
  /** Objects no row refers to (informational; nothing is deleted). */
  unreferencedObjects: number;
};

/** Every non-empty file column value in the database. */
export async function readFileRefs(q: Queryable): Promise<FileRef[]> {
  const out: FileRef[] = [];
  for (const f of FILE_COLUMNS) {
    const rows = await q.unsafe<{ id: string; value: string }[]>(
      `SELECT id::text AS id, ${ident(f.column)} AS value FROM public.${ident(f.table)}
       WHERE ${ident(f.column)} IS NOT NULL AND ${ident(f.column)} <> ''
       ORDER BY 1`,
    );
    for (const r of rows) out.push({ table: f.table, column: f.column, id: r.id, value: r.value });
  }
  return out;
}

/** Checks references against the bucket: each bucket prefix is listed once. */
export async function checkFiles(refs: FileRef[], lister: Lister): Promise<FilesReport> {
  const keys = new Set<string>();
  for (const bucket of FILE_BUCKETS) {
    let cursor: string | undefined;
    do {
      const page = await lister(`${bucket}/`, cursor);
      for (const o of page.objects) keys.add(o.key);
      cursor = page.nextCursor;
    } while (cursor);
  }
  const bucketOf = new Map(FILE_COLUMNS.map((f) => [`${f.table}.${f.column}`, f.bucket]));
  const report: FilesReport = {
    references: refs.length,
    present: 0,
    samples: 0,
    notFiles: 0,
    missing: [],
    unreferencedObjects: 0,
  };
  const referenced = new Set<string>();
  for (const ref of refs) {
    if (ref.value.startsWith("seed/")) {
      report.samples++;
      continue;
    }
    if (!ref.value.includes("/")) {
      report.notFiles++;
      continue;
    }
    const bucket = bucketOf.get(`${ref.table}.${ref.column}`) ?? null;
    const candidates = (bucket ? [bucket] : FILE_BUCKETS).map((b) => `${b}/${ref.value}`);
    const found = candidates.find((k) => keys.has(k));
    if (found) {
      report.present++;
      referenced.add(found);
    } else {
      report.missing.push({ ...ref, key: candidates[0] });
    }
  }
  report.unreferencedObjects = [...keys].filter((k) => !referenced.has(k)).length;
  return report;
}
