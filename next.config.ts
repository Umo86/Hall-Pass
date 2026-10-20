import type { NextConfig } from "next";

/**
 * File storage the browser talks to directly (uploads, previews, video):
 * Vercel Blob, Cloudflare R2, and whatever S3 endpoint is set.
 */
function storageOrigins(): string {
  const origins = ["https://*.blob.vercel-storage.com", "https://*.r2.cloudflarestorage.com"];
  const endpoint = (process.env.S3_ENDPOINT ?? "").trim();
  if (endpoint) {
    try {
      const url = new URL(endpoint.includes("://") ? endpoint : `https://${endpoint}`);
      origins.push(url.origin, `${url.protocol}//*.${url.host}`);
    } catch {
      // Not a URL: the storage check on Settings → System reports it.
    }
  }
  return [...new Set(origins)].join(" ");
}

const STORAGE = storageOrigins();

const securityHeaders = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  // SAMEORIGIN so the app can show its own PDF proofs (/api/files) in a frame.
  { key: "X-Frame-Options", value: "SAMEORIGIN" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains" },
  // The app never needs these device features.
  { key: "Permissions-Policy", value: "camera=(self), microphone=(), geolocation=(), payment=()" },
  {
    key: "Content-Security-Policy",
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline'",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "font-src 'self' https://fonts.gstatic.com data:",
      `img-src 'self' data: blob: ${STORAGE}`,
      // Video artwork plays straight from storage.
      `media-src 'self' blob: ${STORAGE}`,
      // Browser → storage direct uploads (Vercel Blob API, presigned R2/S3 PUTs).
      `connect-src 'self' https://vercel.com ${STORAGE}`,
      // Artwork proofs are previewed in a frame from storage or /api/files.
      `frame-src 'self' ${STORAGE}`,
      "frame-ancestors 'self'",
      "object-src 'none'",
      "base-uri 'self'",
      "form-action 'self'",
    ].join("; "),
  },
];

const nextConfig: NextConfig = {
  experimental: {
    serverActions: {
      // Direct artwork/document uploads flow through server actions on the
      // local storage backend; bucket deployments use signed upload URLs.
      bodySizeLimit: "25mb",
    },
  },
  // PDF exports load their fonts from disk at runtime.
  outputFileTracingIncludes: {
    "/api/exports/**": ["./lib/exports/fonts/**"],
  },
  async headers() {
    return [{ source: "/(.*)", headers: securityHeaders }];
  },
};

export default nextConfig;
