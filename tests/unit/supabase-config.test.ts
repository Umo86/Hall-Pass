import { describe, expect, it } from "vitest";
import { resolveSupabaseKey, resolveSupabaseUrl } from "@/lib/auth/supabase-config";

const REF = "uymemosqktczdjxlsryj";
const DB = `postgresql://postgres.${REF}:secret@aws-1-eu-central-1.pooler.supabase.com:6543/postgres`;

describe("resolveSupabaseUrl", () => {
  it("keeps a correct URL", () => {
    expect(
      resolveSupabaseUrl({
        NEXT_PUBLIC_SUPABASE_URL: `https://${REF}.supabase.co`,
        DATABASE_URL: DB,
      }),
    ).toEqual({ url: `https://${REF}.supabase.co`, source: "env" });
  });

  it("cleans spaces, quotes, a missing https:// and a trailing path", () => {
    for (const raw of [
      ` "https://${REF}.supabase.co/" `,
      `${REF}.supabase.co`,
      `https://${REF}.supabase.co/rest/v1`,
    ]) {
      expect(resolveSupabaseUrl({ NEXT_PUBLIC_SUPABASE_URL: raw, DATABASE_URL: DB }).url).toBe(
        `https://${REF}.supabase.co`,
      );
    }
  });

  it("uses the database's project when the URL is missing, the database host or another project", () => {
    for (const raw of [
      undefined,
      `https://db.${REF}.supabase.co`,
      "https://oldprojectaaaaaaaaaa.supabase.co",
      "not a url at all",
    ]) {
      const r = resolveSupabaseUrl({ NEXT_PUBLIC_SUPABASE_URL: raw, DATABASE_URL: DB });
      expect(r.url).toBe(`https://${REF}.supabase.co`);
      expect(r.source).toBe("derived from database");
    }
  });

  it("reads the project from a direct database URL too", () => {
    expect(
      resolveSupabaseUrl({
        DATABASE_URL: `postgresql://postgres:pw@db.${REF}.supabase.co:5432/postgres`,
      }).url,
    ).toBe(`https://${REF}.supabase.co`);
  });

  it("keeps a custom domain and any URL when the database isn't on Supabase", () => {
    expect(
      resolveSupabaseUrl({ NEXT_PUBLIC_SUPABASE_URL: "https://auth.example.com", DATABASE_URL: DB })
        .url,
    ).toBe("https://auth.example.com");
    expect(
      resolveSupabaseUrl({
        NEXT_PUBLIC_SUPABASE_URL: "https://other1234567890abcd.supabase.co",
        DATABASE_URL: "postgres://u:p@localhost:5432/x",
      }),
    ).toEqual({ url: "https://other1234567890abcd.supabase.co", source: "env" });
    expect(resolveSupabaseUrl({ DATABASE_URL: "postgres://u:p@localhost:5432/x" })).toEqual({
      url: null,
      source: "not set",
    });
  });
});

describe("resolveSupabaseKey", () => {
  const jwt = (ref: string) =>
    `h.${Buffer.from(JSON.stringify({ ref, role: "anon" })).toString("base64url")}.s`;

  it("skips an anon key from another project when a publishable key is set", () => {
    expect(
      resolveSupabaseKey({
        DATABASE_URL: DB,
        NEXT_PUBLIC_SUPABASE_ANON_KEY: jwt("oldprojectaaaaaaaaaa"),
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_new",
      }),
    ).toBe("sb_publishable_new");
  });

  it("keeps a matching anon key, and whichever key is the only one set", () => {
    expect(
      resolveSupabaseKey({
        DATABASE_URL: DB,
        NEXT_PUBLIC_SUPABASE_ANON_KEY: jwt(REF),
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_new",
      }),
    ).toBe(jwt(REF));
    expect(resolveSupabaseKey({ NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: " sb_publishable_x " })).toBe(
      "sb_publishable_x",
    );
    expect(resolveSupabaseKey({})).toBeUndefined();
  });
});
