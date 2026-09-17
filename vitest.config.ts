import { defineConfig } from "vitest/config";
import tsconfigPaths from "vite-tsconfig-paths";

export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    include: ["tests/unit/**/*.test.ts"],
    environment: "node",
    // DB-backed tests (RLS, audit trigger, refs) read TEST_DATABASE_URL and
    // skip themselves when it is not set, so `pnpm test` works everywhere.
    testTimeout: 20000,
  },
});
