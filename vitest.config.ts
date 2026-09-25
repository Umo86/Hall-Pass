import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: {
    tsconfigPaths: true,
    alias: { "server-only": new URL("./tests/mocks/empty.ts", import.meta.url).pathname },
  },
  test: {
    include: ["tests/unit/**/*.test.ts"],
    globalSetup: ["tests/global-setup.ts"],
    environment: "node",
    // DB-backed tests (RLS, audit trigger, refs) read TEST_DATABASE_URL and
    // skip themselves when it is not set, so `pnpm test` works everywhere.
    testTimeout: 20000,
  },
});
