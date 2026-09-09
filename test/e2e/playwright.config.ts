import { defineConfig } from "@playwright/test"

export default defineConfig({
  testDir: "./specs",
  timeout: 60_000,
  retries: process.env.CI ? 1 : 0,
  use: {
    baseURL: "http://127.0.0.1:5173",
    trace: "on-first-retry",
  },
  webServer: {
    command: "pnpm --filter admin-panel dev -- --host 127.0.0.1 --port 5173",
    url: "http://127.0.0.1:5173",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: {
      VITE_USE_MOCK: "true",
      VITE_API_URL: "http://localhost:8000/api/v1",
    },
  },
})
