import { describe, expect, it } from "vitest";
import { describeConfigShape, describeDbError } from "@/lib/db/diagnose";

const GOOD = "postgresql://postgres.ref:secret@aws-1-eu-west-2.pooler.supabase.com:6543/postgres";

describe("describeConfigShape", () => {
  it("accepts a well-formed pooler URI", () => {
    expect(describeConfigShape(GOOD)).toBeNull();
  });
  it("catches quote wrapping", () => {
    expect(describeConfigShape(`"${GOOD}"`)).toMatch(/quote marks/);
  });
  it("catches the password placeholder", () => {
    expect(describeConfigShape(GOOD.replace("secret", "[YOUR-PASSWORD]"))).toMatch(/placeholder/);
  });
  it("catches spaces and line breaks", () => {
    expect(describeConfigShape(GOOD.replace("pooler", "poo ler"))).toMatch(/space or line break/);
  });
  it("catches a non-URI value", () => {
    expect(describeConfigShape("aws-1-eu-west-2.pooler.supabase.com")).toMatch(/postgresql:\/\//);
  });
  it("catches the IPv6-only direct address", () => {
    expect(
      describeConfigShape("postgresql://postgres:secret@db.abc.supabase.co:5432/postgres"),
    ).toMatch(/direct address/);
  });
  it("catches a missing final m in the domain", () => {
    expect(describeConfigShape(GOOD.replace("supabase.com", "supabase.co"))).toMatch(/final "m"/);
  });
});

describe("describeDbError", () => {
  it("prefers shape problems over network errors", () => {
    const err = new Error("getaddrinfo ENOTFOUND x");
    expect(describeDbError(err, `"${GOOD}"`)).toMatch(/quote marks/);
  });
  it("names the host it tried on DNS failures", () => {
    const err = new Error("getaddrinfo ENOTFOUND aws-1-eu-west-2.pooler.supabse.com");
    const bad = GOOD.replace("supabase.com", "supabse.com");
    expect(describeDbError(err, bad)).toContain("aws-1-eu-west-2.pooler.supabse.com:6543");
  });
  it("never echoes credentials", () => {
    const err = new Error(`connection failed for ${GOOD}`);
    expect(describeDbError(err, GOOD)).not.toContain("secret");
  });
});

describe("describeDbError on Neon", () => {
  const NEON =
    "postgresql://neondb_owner:secret@ep-cool-sea-a1b2c3d4-pooler.eu-west-2.aws.neon.tech/neondb?sslmode=require";
  it("points a wrong password at Vercel → Storage, naming the variable", () => {
    const err = new Error('password authentication failed for user "neondb_owner"');
    expect(describeDbError(err, NEON, "POSTGRES_URL")).toMatch(
      /Re-copy POSTGRES_URL from Vercel → Storage/,
    );
  });
  it("explains the Free plan allowance and a disabled compute", () => {
    expect(
      describeDbError(
        new Error(
          "Your account or project has exceeded the compute time quota. Upgrade your plan.",
        ),
        NEON,
      ),
    ).toMatch(/Free plan allowance is used up/);
    expect(
      describeDbError(
        new Error("The endpoint has been disabled. Enable it using Neon API and retry."),
        NEON,
      ),
    ).toMatch(/compute is disabled/);
  });
  it("says to remove channel_binding", () => {
    const err = new Error('unrecognized configuration parameter "channel_binding"');
    expect(describeDbError(err, NEON)).toMatch(/Remove channel_binding/);
  });
  it("gives Neon wording for timeouts and unknown hosts, and never the password", () => {
    const timeout = describeDbError(new Error("connect ETIMEDOUT"), NEON);
    expect(timeout).toMatch(/Neon database did not answer/);
    expect(timeout).not.toContain("secret");
    expect(describeDbError(new Error("getaddrinfo ENOTFOUND x"), NEON)).toMatch(/Vercel → Storage/);
  });
  it("names the variable in paste mistakes", () => {
    expect(describeConfigShape(`"${NEON}"`, "POSTGRES_URL")).toMatch(/^POSTGRES_URL is wrapped/);
  });
});
