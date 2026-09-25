import type { NextConfig } from "next";

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
      "img-src 'self' data: blob: https://*.supabase.co https://*.blob.vercel-storage.com",
      // Browser → Vercel Blob direct uploads talk to the Blob API.
      "connect-src 'self' https://*.supabase.co https://vercel.com https://*.blob.vercel-storage.com",
      // Artwork proofs are previewed in a frame from storage or /api/files.
      "frame-src 'self' https://*.supabase.co https://*.blob.vercel-storage.com",
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
      // local storage backend; Supabase deployments use signed upload URLs.
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
