import bcrypt from "bcryptjs";
import { hashPassword as scryptHash, verifyPassword as scryptVerify } from "better-auth/crypto";

/**
 * Password hashing for Better Auth (lib/auth/server.ts) and our own password
 * writes (lib/auth/accounts.ts, scripts/auth-set-password.ts). No
 * `server-only`: the command-line script uses it too.
 */
const BCRYPT = /^\$2[aby]\$\d{2}\$/;

/** A hash carried over from the old sign-in (bcrypt), rehashed at the next password sign-in. */
export function isLegacyHash(hash: string): boolean {
  return BCRYPT.test(hash);
}

/** New hashes: Better Auth's default scrypt (`<32-hex salt>:<128-hex key>`). */
export function hashPassword(password: string): Promise<string> {
  return scryptHash(password);
}

/** bcrypt or scrypt; a malformed hash is a wrong password, never an error. */
export async function verifyPassword({
  hash,
  password,
}: {
  hash: string;
  password: string;
}): Promise<boolean> {
  try {
    if (isLegacyHash(hash)) return await bcrypt.compare(password, hash);
    return await scryptVerify({ hash, password });
  } catch {
    return false;
  }
}
