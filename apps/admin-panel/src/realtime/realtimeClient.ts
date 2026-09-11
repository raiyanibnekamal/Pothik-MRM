/**
 * Realtime transport for the admin panel.
 *
 * Today the app polls /admin/sos/active every 5s (see useSosPolling). When
 * the backend ships Laravel Reverb (Phase 0d), this module owns the
 * WebSocket lifecycle and the components can prefer the realtime stream
 * over the polling fallback.
 *
 * The shape is intentionally broker-agnostic. The default export
 * (`createRealtimeClient`) returns either a live socket client (when
 * VITE_REVERB_URL is set) or a `NullRealtime` that no-ops every call —
 * the latter is what runs in the mock/demo build today, so the admin
 * panel never breaks when the WS broker isn't reachable.
 *
 * Backend channel layout (apps/api/routes/channels.php):
 *   private-admin.ops    — admin war-room feed (driver locations, ride stats)
 *   private-admin.sos    — admin SOS fan-out (high-priority alerts)
 *
 * Event → channel mapping happens here. The admin panel never references
 * a raw channel name — it subscribes by `RealtimeEvent`, and we resolve
 * to the right `private-*` channel so the backend's auth closure can
 * make the allow/deny decision.
 */

import Pusher, { type Channel } from "pusher-js";

export type RealtimeEvent =
  | "admin:sos:alert"
  | "admin:dashboard"
  | "server:driver:location";

export interface SosAlertPayload {
  alert_id: string;
  user_id: string;
  ride_id: string | null;
  lat: number | null;
  lng: number | null;
  trigger_type: string;
  created_at: string | null;
}

export interface RealtimeClient {
  readonly mode: "reverb" | "pusher" | "null";
  readonly isConnected: boolean;
  connect(adminToken: string): Promise<void>;
  subscribe(
    event: RealtimeEvent,
    handler: (payload: unknown) => void,
  ): () => void;
  disconnect(): Promise<void>;
}

export interface RealtimeClientOptions {
  /** wss:// endpoint (Laravel Reverb / Soketi / pusher.com). */
  wsUrl?: string;
  appKey?: string;
  /** Override the auth endpoint. Defaults to `${apiUrl}/broadcasting/auth`. */
  authEndpoint?: string;
  /**
   * Pusher constructor injected for tests. Defaults to the runtime import
   * so SSR / non-browser callers can short-circuit before Pusher touches
   * `window`. The return type is intentionally `unknown` so test doubles
   * don't have to satisfy pusher-js's full Pusher surface — only the
   * members this module actually touches (`connection`, `channel`,
   * `subscribe`, `unsubscribe`, `connect`, `disconnect`).
   */
  pusherFactory?: (
    appKey: string,
    options: Record<string, unknown>,
  ) => unknown;
}

const EVENT_TO_CHANNEL: Record<RealtimeEvent, string> = {
  "admin:sos:alert": "private-admin.sos",
  "admin:dashboard": "private-admin.ops",
  "server:driver:location": "private-admin.ops",
};

/**
 * Returns a no-op client. Used in:
 *   - dev when VITE_REVERB_URL is unset
 *   - the demo mock build
 *   - any environment where the WS broker is unreachable
 *
 * `.subscribe()` returns a function that detaches the (no-op) handler, so
 * callers can wire it up unconditionally and the UI behaviour stays
 * identical.
 */
export function createNullRealtime(): RealtimeClient {
  return {
    mode: "null",
    isConnected: false,
    async connect() {
      /* no-op */
    },
    subscribe(_event, _handler) {
      return () => {
        /* no-op */
      };
    },
    async disconnect() {
      /* no-op */
    },
  };
}

interface PusherRealtimeState {
  pusher: Pusher | null;
  connected: boolean;
  pendingHandlers: Map<string, Set<(payload: unknown) => void>>;
}

/**
 * Returns the right client for the current env. Defaults to the null
 * implementation when WS env keys aren't set so the admin panel never
 * breaks during local dev / Phase 0a staging.
 *
 * When `VITE_REVERB_URL` + `VITE_REVERB_APP_KEY` are present AND we're
 * in a browser context, we instantiate `pusher-js` against the Reverb
 * endpoint. Reverb is wire-compatible with the Pusher protocol, so the
 * vanilla client handles subscription, presence, and private-channel
 * auth out of the box.
 */
export function createRealtimeClient(
  opts: RealtimeClientOptions = {},
): RealtimeClient {
  const wsUrl = opts.wsUrl ?? readEnv("VITE_REVERB_URL");
  const appKey = opts.appKey ?? readEnv("VITE_REVERB_APP_KEY");

  if (!wsUrl || !appKey) {
    return createNullRealtime();
  }

  // pusher-js touches `window` during construction; bail out for SSR /
  // Node-only tests so we don't crash on `undefined`.
  if (typeof window === "undefined") {
    return createNullRealtime();
  }

  return createPusherRealtime(wsUrl, appKey, opts);
}

function createPusherRealtime(
  wsUrl: string,
  appKey: string,
  opts: RealtimeClientOptions,
): RealtimeClient {
  const state: PusherRealtimeState = {
    pusher: null,
    connected: false,
    pendingHandlers: new Map(),
  };

  const defaultFactory: NonNullable<RealtimeClientOptions["pusherFactory"]> = (
    key,
    options,
  ) =>
    // pusher-js ships its own runtime types but doesn't re-export the
    // Options interface from the default entry. The Options type
    // lives in `pusher-js/types/src/core/options`, so we cast through
    // `unknown` here rather than dragging an internal type path into
    // production code.
    new Pusher(key, options as unknown as ConstructorParameters<typeof Pusher>[1]);

  const authEndpoint =
    opts.authEndpoint ??
    readEnv("VITE_REVERB_AUTH_ENDPOINT") ??
    defaultAuthEndpoint();

  const baseUrl = stripScheme(wsUrl);

  const initPusher = (token: string): Pusher => {
    if (state.pusher) return state.pusher;

    const pusher = (opts.pusherFactory ?? defaultFactory)(appKey, {
      // The factory return type is `unknown` (see RealtimeClientOptions);
      // we narrow it back to Pusher here since the default factory
      // always returns one and tests inject compatible doubles.
      wsHost: baseUrl.host,
      wsPort: baseUrl.port ?? (baseUrl.secure ? 443 : 80),
      wssPort: baseUrl.port ?? 443,
      forceTLS: baseUrl.secure,
      enabledTransports: ["ws", "wss"],
      // The channel auth endpoint runs through Laravel's
      // /broadcasting/auth route, which sits behind `auth:api` and
      // verifies the JWT we attach as a Bearer header.
      authEndpoint,
      auth: {
        headers: { Authorization: `Bearer ${token}` },
      },
      // Reverb speaks the Pusher v8 protocol. Cluster is required by
      // the PusherOptions type even though we override the host/port;
      // any value works for a self-hosted Reverb.
      cluster: "mt1",
    }) as Pusher;

    pusher.connection.bind("connected", () => {
      state.connected = true;
      // Re-attach handlers accumulated before connect().
      for (const [channelName, handlers] of state.pendingHandlers) {
        const channel =
          pusher.channel(channelName) ?? pusher.subscribe(channelName);
        for (const handler of handlers) bindChannelHandler(channel, handler);
      }
    });
    pusher.connection.bind("disconnected", () => {
      state.connected = false;
    });
    pusher.connection.bind("error", () => {
      state.connected = false;
    });

    state.pusher = pusher;
    return pusher;
  };

  const subscribeTo = (
    event: RealtimeEvent,
    handler: (payload: unknown) => void,
  ): (() => void) => {
    const channelName = EVENT_TO_CHANNEL[event];
    let channelHandlers = state.pendingHandlers.get(channelName);
    if (!channelHandlers) {
      channelHandlers = new Set();
      state.pendingHandlers.set(channelName, channelHandlers);
    }
    channelHandlers.add(handler);

    let boundCallback:
      | ((eventName: string, data: unknown) => void)
      | null = null;

    if (state.pusher && state.connected) {
      const channel =
        state.pusher.channel(channelName) ??
        state.pusher.subscribe(channelName);
      boundCallback = (eventName, data) =>
        handler({ event: eventName, data });
      channel.bind_global(boundCallback);
    } else if (state.pusher && !state.connected) {
      // Subscription queued in pendingHandlers; will bind on connect.
      state.pusher.subscribe(channelName);
    }

    return () => {
      channelHandlers?.delete(handler);
      if (channelHandlers && channelHandlers.size === 0) {
        state.pendingHandlers.delete(channelName);
        if (state.pusher && boundCallback) {
          const channel = state.pusher.channel(channelName);
          if (channel) channel.unbind_global(boundCallback);
          state.pusher.unsubscribe(channelName);
        }
      }
    };
  };

  return {
    mode: "reverb",
    get isConnected() {
      return state.connected;
    },
    async connect(adminToken: string) {
      const pusher = initPusher(adminToken);
      if (state.connected) return;
      // pusher.connect() is fire-and-forget; we await the next
      // "connected" event via a one-shot promise so callers can
      // `await client.connect(token)` reliably.
      await new Promise<void>((resolve, reject) => {
        const onConn = () => {
          pusher.connection.unbind("connected", onConn);
          pusher.connection.unbind("error", onErr);
          resolve();
        };
        const onErr = (err: unknown) => {
          pusher.connection.unbind("connected", onConn);
          pusher.connection.unbind("error", onErr);
          reject(
            err instanceof Error ? err : new Error("pusher connect failed"),
          );
        };
        pusher.connection.bind("connected", onConn);
        pusher.connection.bind("error", onErr);
        pusher.connect();
      });
    },
    subscribe(event, handler) {
      return subscribeTo(event, handler);
    },
    async disconnect() {
      if (!state.pusher) return;
      state.pusher.disconnect();
      state.pusher = null;
      state.connected = false;
      state.pendingHandlers.clear();
    },
  };
}

function bindChannelHandler(
  channel: Channel,
  handler: (payload: unknown) => void,
): void {
  // We bind to ALL events on the channel and let consumers filter by
  // the event name they registered for. Pusher channels dispatch
  // arbitrary server-named events ("admin:sos:alert", etc.); using
  // pusher's per-event `bind` would require us to know the server
  // event name ahead of time, which we do — but a single global
  // listener keeps the unsubscribe path uniform and matches the
  // broker-agnostic RealtimeClient contract.
  channel.bind_global((eventName: string, data: unknown) => {
    handler({ event: eventName, data });
  });
}

interface ParsedWsUrl {
  host: string;
  port: number | null;
  secure: boolean;
}

function stripScheme(raw: string): ParsedWsUrl {
  const secure = raw.startsWith("wss://") || raw.startsWith("https://");
  const cleaned = raw.replace(/^(wss?:\/\/|https?:\/\/)/, "");
  const [host, portRaw] = cleaned.split(":", 2);
  const port = portRaw ? Number.parseInt(portRaw, 10) : null;
  return { host, port: Number.isFinite(port as number) ? port : null, secure };
}

function defaultAuthEndpoint(): string {
  const apiUrl = readEnv("VITE_API_URL") ?? "http://localhost:8000/api/v1";
  return `${apiUrl.replace(/\/$/, "")}/broadcasting/auth`;
}

function readEnv(name: string): string | undefined {
  // Vite injects import.meta.env.VITE_* at build time; this fallback keeps
  // the file usable from plain Node tests too.
  const meta = (import.meta as unknown as { env?: Record<string, string> })
    .env;
  return meta?.[name] ?? undefined;
}

// Test-only seam: exported so vitest can inspect/reset internal state
// when poking at the pusher factory. Production callers should treat
// this as opaque.
export const __test__ = { EVENT_TO_CHANNEL };
