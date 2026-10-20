import bcrypt from "bcryptjs";
import { describe, expect, it } from "vitest";
import { hashPassword, isLegacyHash, verifyPassword } from "@/lib/auth/password";

describe("passwords: bcrypt (carried over by migration 0014) and scrypt (Better Auth)", () => {
  it("verifies $2a$ and $2b$ bcrypt hashes", async () => {
    for (const prefix of ["$2a$", "$2b$"]) {
      const hash = bcrypt.hashSync("correct horse", 4).replace(/^\$2[aby]\$/, prefix);
      expect(hash.startsWith(prefix)).toBe(true);
      expect(isLegacyHash(hash)).toBe(true);
      expect(await verifyPassword({ hash, password: "correct horse" })).toBe(true);
      expect(await verifyPassword({ hash, password: "Correct horse" })).toBe(false);
    }
  });

  it("verifies a $2y$ hash (PHP-style bcrypt) too", async () => {
    const hash = bcrypt.hashSync("battery staple", 4).replace(/^\$2[aby]\$/, "$2y$");
    expect(isLegacyHash(hash)).toBe(true);
    expect(await verifyPassword({ hash, password: "battery staple" })).toBe(true);
  });

  it("hashes new passwords with scrypt, and verifies them", async () => {
    const hash = await hashPassword("s3cure-pass");
    expect(hash).toMatch(/^[0-9a-f]{32}:[0-9a-f]{128}$/);
    expect(isLegacyHash(hash)).toBe(false);
    expect(await verifyPassword({ hash, password: "s3cure-pass" })).toBe(true);
    expect(await verifyPassword({ hash, password: "s3cure-pas" })).toBe(false);
    // Salted: the same password hashes differently each time.
    expect(await hashPassword("s3cure-pass")).not.toBe(hash);
  });

  it("treats a malformed hash as a wrong password, never an error", async () => {
    for (const hash of [
      "",
      "not-a-hash",
      "abc:def",
      "$2a$10$short",
      "$argon2id$v=19$m=1,t=1,p=1$x$y",
    ]) {
      await expect(verifyPassword({ hash, password: "anything" }), hash).resolves.toBe(false);
    }
  });

  it("only calls bcrypt hashes legacy", () => {
    expect(isLegacyHash("$2a$10$abcdefghijklmnopqrstuuabcdefghijklmnopqrstuvwxyz01234")).toBe(true);
    expect(isLegacyHash("$2x$10$abcdefghijklmnopqrstuu")).toBe(false);
    expect(isLegacyHash(`${"a".repeat(32)}:${"b".repeat(128)}`)).toBe(false);
    expect(isLegacyHash("")).toBe(false);
  });
});
