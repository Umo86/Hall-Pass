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
    expect(
      describeConfigShape(GOOD.replace("secret", "[YOUR-PASSWORD]")),
    ).toMatch(/placeholder/);
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
