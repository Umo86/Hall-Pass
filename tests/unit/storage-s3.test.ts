import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  MAX_DIRECT_UPLOAD_BYTES,
  contentTypeFor,
  createDirectUploadUrl,
  objectKey,
  s3Config,
  s3Enabled,
} from "@/lib/storage";

const ENV = {
  S3_BUCKET: "hall-pass",
  S3_ENDPOINT: "https://abc123.r2.cloudflarestorage.com",
  S3_ACCESS_KEY_ID: "AKIATEST",
  S3_SECRET_ACCESS_KEY: "secret",
};

describe("S3 / R2 storage backend", () => {
  const saved: Record<string, string | undefined> = {};
  beforeEach(() => {
    for (const k of [...Object.keys(ENV), "S3_REGION", "BLOB_READ_WRITE_TOKEN"]) {
      saved[k] = process.env[k];
      delete process.env[k];
    }
  });
  afterEach(() => {
    for (const [k, v] of Object.entries(saved)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
  });

  it("is off until all four variables are set, and defaults the region to auto", () => {
    expect(s3Enabled()).toBe(false);
    expect(s3Config({ ...ENV, S3_ENDPOINT: "" })).toBeNull();
    expect(s3Config(ENV)).toEqual({
      bucket: "hall-pass",
      endpoint: ENV.S3_ENDPOINT,
      region: "auto",
      accessKeyId: "AKIATEST",
      secretAccessKey: "secret",
    });
    expect(s3Config({ ...ENV, S3_REGION: "eu-west-2" })?.region).toBe("eu-west-2");
    Object.assign(process.env, ENV);
    expect(s3Enabled()).toBe(true);
  });

  it("keys files under their bucket and refuses path tricks", () => {
    expect(objectKey("artwork", "org/ed/signage_item/id/uuid-file.pdf")).toBe(
      "artwork/org/ed/signage_item/id/uuid-file.pdf",
    );
    expect(() => objectKey("artwork", "../secrets")).toThrow(/Invalid/);
    expect(() => objectKey("photos", "/etc/passwd")).toThrow(/Invalid/);
  });

  it("serves artwork with the right media type", () => {
    expect(contentTypeFor("proof.PDF")).toBe("application/pdf");
    expect(contentTypeFor("banner.tif")).toBe("image/tiff");
    expect(contentTypeFor("photo.jpeg")).toBe("image/jpeg");
    expect(contentTypeFor("archive.zip")).toBe("application/zip");
    expect(contentTypeFor("mystery.bin")).toBe("application/octet-stream");
    expect(contentTypeFor("noext")).toBe("application/octet-stream");
  });

  it("presigns a PUT to the bucket with the content type locked in", async () => {
    Object.assign(process.env, ENV);
    const signed = await createDirectUploadUrl(
      "artwork",
      "org/ed/signage_item/item/uuid-proof.pdf",
      "application/pdf",
    );
    const url = new URL(signed.url);
    expect(url.origin).toBe(ENV.S3_ENDPOINT);
    expect(url.pathname).toBe("/hall-pass/artwork/org/ed/signage_item/item/uuid-proof.pdf");
    expect(url.searchParams.get("X-Amz-Algorithm")).toBe("AWS4-HMAC-SHA256");
    expect(url.searchParams.get("X-Amz-Expires")).toBe(String(signed.expiresInSeconds));
    expect(url.searchParams.get("X-Amz-SignedHeaders")).toContain("content-type");
    expect(url.searchParams.get("X-Amz-Signature")).toMatch(/^[0-9a-f]{64}$/);
    expect(signed.key).toBe("artwork/org/ed/signage_item/item/uuid-proof.pdf");
    expect(signed.contentType).toBe("application/pdf");
    expect(MAX_DIRECT_UPLOAD_BYTES).toBe(2 * 1024 ** 3);
  });
});
