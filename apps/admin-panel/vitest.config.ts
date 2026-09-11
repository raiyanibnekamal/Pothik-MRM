import { defineConfig, mergeConfig } from "vitest/config";
import viteConfig from "./vite.config.ts";

/**
 * Vitest configuration for the admin panel.
 *
 * Merges the Vite config so @vitejs/plugin-react and Tailwind are available
 * when transforming TSX in CI (Linux runners are stricter than local Windows).
 *
 * jsdom is required because `realtimeClient.ts` short-circuits to the
 * null client when `typeof window === "undefined"`. The tests below
 * exercise the Pusher wiring, so we mount a real (mocked) DOM.
 */
export default mergeConfig(
  viteConfig,
  defineConfig({
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
  }),
);
