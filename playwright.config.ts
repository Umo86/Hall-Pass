import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "tests/e2e",
  timeout: 60_000,
  retries: process.env.CI ? 1 : 0,
  use: {
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:3901",
    trace: "retain-on-failure",
    // The sandboxed build environment pre-installs Chromium at a fixed path;
    // CI and local runs fall back to Playwright's own download.
    launchOptions: process.env.PW_CHROMIUM_PATH
      ? { executablePath: process.env.PW_CHROMIUM_PATH }
      : undefined,
  },
  webServer: {
    command: "pnpm dev -p 3901",
    url: "http://localhost:3901/login",
    reuseExistingServer: true,
    timeout: 120_000,
  },
});
