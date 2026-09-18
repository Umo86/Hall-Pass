import "server-only";
import { existsSync } from "node:fs";
import path from "node:path";

export type BrandImageSlot = "hero" | "office" | "login" | "portal";

const EXTENSIONS = ["jpg", "jpeg", "png", "webp"];

/**
 * Photo override slots: drop AI-generated or licensed photography into
 * public/images/<slot>.<ext> (hero, office, login, portal) and the pages use
 * it in place of the built-in vector scenes — no code changes needed.
 */
export function brandImage(slot: BrandImageSlot): string | null {
  for (const ext of EXTENSIONS) {
    const rel = `images/${slot}.${ext}`;
    if (existsSync(path.join(process.cwd(), "public", rel))) return `/${rel}`;
  }
  return null;
}
