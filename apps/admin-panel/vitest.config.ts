import { defineConfig } from "vitest/config";

/**
 * Vitest configuration for the admin panel.
 *
 * jsdom is required because `realtimeClient.ts` short-circuits to the
 * null client when `typeof window === "undefined"`. The tests below
 * exercise the Pusher wiring, so we mount a real (mocked) DOM.
 */
export default defineConfig({
  test: {
    environment: "jsdom",
    globals: false,
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
    coverage: {
      provider: "v8",
      reporter: ["text", "html"],
      include: ["src/realtime/**", "src/hooks/**"],
    },
  },
});
