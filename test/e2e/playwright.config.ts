import path from "node:path"
import { fileURLToPath } from "node:url"
import { defineConfig } from "@playwright/test"

const root = path.join(fileURLToPath(new URL(".", import.meta.url)), "../..")
const adminDir = path.join(root, "apps/admin-panel")

export default defineConfig({
  testDir: "./specs",
  timeout: 60_000,
  retries: process.env.CI ? 1 : 0,
  use: {
    baseURL: "http://127.0.0.1:5173",
    trace: "on-first-retry",
  },
  webServer: {
    command: "pnpm exec vite --host 127.0.0.1 --port 5173",
    cwd: adminDir,
    url: "http://127.0.0.1:5173",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: {
      VITE_USE_MOCK: "true",
      VITE_API_URL: "http://localhost:8000/api/v1",
      VITE_QA_PASSWORD: "123456",
    },
  },
})
