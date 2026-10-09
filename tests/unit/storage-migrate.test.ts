import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// The copy runs against Vercel Blob's list() and the bucket; both are faked here.
const listMock = vi.fn();
vi.mock("@vercel/blob", () => ({ list: (...args: unknown[]) => listMock(...args) }));

const statMock = vi.fn();
const putMock = vi.fn();
vi.mock("@/lib/storage", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/storage")>();
  return {
    ...actual,
    s3Enabled: () => true,
    blobEnabled: () => true,
    s3Stat: (...args: unknown[]) => statMock(...args),
    s3PutStream: (...args: unknown[]) => putMock(...args),
  };
});

const blob = (pathname: string, size = 10) => ({
  pathname,
  size,
  url: `https://blob.test/${pathname}`,
  uploadedAt: new Date(),
  downloadUrl: `https://blob.test/${pathname}`,
});

describe("copying files from Vercel Blob into the bucket", () => {
  const realFetch = globalThis.fetch;
  beforeEach(() => {
    listMock.mockReset();
    statMock.mockReset();
    putMock.mockReset();
    globalThis.fetch = vi.fn(
      async () =>
        new Response("file-bytes", { status: 200, headers: { "content-type": "image/png" } }),
    ) as typeof fetch;
  });
  afterEach(() => {
    globalThis.fetch = realFetch;
  });

  it("copies what is missing, skips what is already there, and reports done", async () => {
    const { copyBlobBatch } = await import("@/lib/storage-migrate");
    listMock.mockResolvedValue({
      blobs: [
        blob("artwork/org/ed/signage_item/a/x.png"),
        blob("photos/org/ed/signage_item/b/y.jpg"),
      ],
      hasMore: false,
      cursor: undefined,
    });
    statMock
      .mockResolvedValueOnce(null) // first file not in the bucket yet
      .mockResolvedValueOnce({ size: 10, contentType: "image/jpeg" }); // second already copied
    const r = await copyBlobBatch({ limit: 50 });
    expect(r).toMatchObject({
      copied: 1,
      skipped: 0 + 1,
      failed: [],
      done: true,
      incomplete: false,
    });
    expect(putMock).toHaveBeenCalledTimes(1);
    expect(putMock.mock.calls[0][0]).toBe("artwork/org/ed/signage_item/a/x.png");
    expect(putMock.mock.calls[0][2]).toBe("image/png");
  });

  it("hands back the next cursor while there are more pages, and flags unknown paths", async () => {
    const { copyBlobBatch } = await import("@/lib/storage-migrate");
    listMock.mockResolvedValue({
      blobs: [blob("stray/file.bin")],
      hasMore: true,
      cursor: "page-2",
    });
    const r = await copyBlobBatch({});
    expect(r.failed).toEqual([{ pathname: "stray/file.bin", error: "Not under a known bucket" }]);
    expect(r.done).toBe(false);
    expect(r.nextCursor).toBe("page-2");
    expect(putMock).not.toHaveBeenCalled();
  });

  it("stops on the time budget and asks for the same cursor again", async () => {
    const { copyBlobBatch } = await import("@/lib/storage-migrate");
    listMock.mockResolvedValue({
      blobs: [blob("artwork/a/1.pdf"), blob("artwork/a/2.pdf"), blob("artwork/a/3.pdf")],
      hasMore: false,
      cursor: undefined,
    });
    statMock.mockResolvedValue(null);
    const r = await copyBlobBatch({ cursor: "page-7", budgetMs: 0 });
    expect(r.copied).toBe(1);
    expect(r.incomplete).toBe(true);
    expect(r.done).toBe(false);
    expect(r.nextCursor).toBe("page-7");
  });

  it("counts without copying on a dry run", async () => {
    const { copyBlobBatch } = await import("@/lib/storage-migrate");
    listMock.mockResolvedValue({ blobs: [blob("documents/a/b.pdf")], hasMore: false });
    statMock.mockResolvedValue(null);
    const r = await copyBlobBatch({ dryRun: true });
    expect(r).toMatchObject({ dryRun: true, copied: 1, done: true });
    expect(putMock).not.toHaveBeenCalled();
  });
});
