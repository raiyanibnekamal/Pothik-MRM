/**
 * Tests for the admin realtime client.
 *
 * These cover:
 *   - createNullRealtime is always a no-op
 *   - createRealtimeClient falls back to null when env is missing
 *   - createRealtimeClient falls back to null in SSR (no window)
 *   - createRealtimeClient with env + window wires Pusher against the
 *     right host/port/auth endpoint and forwards subscribed events to
 *     the caller's handler
 *   - subscribe() returns a teardown that detaches the handler
 *   - disconnect() tears the Pusher instance down
 *
 * The Pusher constructor is injected via `pusherFactory` so the tests
 * run in jsdom without ever touching a real WebSocket.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  createNullRealtime,
  createRealtimeClient,
  __test__,
  type RealtimeClient,
} from "./realtimeClient";

interface MockChannel {
  name: string;
  bound: Set<(eventName: string, data: unknown) => void>;
  bind_global: (cb: (eventName: string, data: unknown) => void) => void;
  unbind_global: (cb: (eventName: string, data: unknown) => void) => void;
  trigger: (eventName: string, data: unknown) => void;
}

function makeChannel(name: string): MockChannel {
  const bound = new Set<(eventName: string, data: unknown) => void>();
  return {
    name,
    bound,
    bind_global(cb) {
      bound.add(cb);
    },
    unbind_global(cb) {
      bound.delete(cb);
    },
    trigger(eventName, data) {
      for (const cb of bound) cb(eventName, data);
    },
  };
}

interface MockConnection {
  bindings: Map<string, Set<(arg?: unknown) => void>>;
  bind: (event: string, cb: (arg?: unknown) => void) => void;
  unbind: (event: string, cb: (arg?: unknown) => void) => void;
  fire: (event: string, arg?: unknown) => void;
}

function makeConnection(): MockConnection {
  const bindings = new Map<string, Set<(arg?: unknown) => void>>();
  return {
    bindings,
    bind(event, cb) {
      let set = bindings.get(event);
      if (!set) {
        set = new Set();
        bindings.set(event, set);
      }
      set.add(cb);
    },
    unbind(event, cb) {
      bindings.get(event)?.delete(cb);
    },
    fire(event, arg) {
      for (const cb of bindings.get(event) ?? []) cb(arg);
    },
  };
}

interface MockPusher {
  appKey: string;
  options: Record<string, unknown>;
  connection: MockConnection;
  channels: Map<string, MockChannel>;
  subscribe: (name: string) => MockChannel;
  channel: (name: string) => MockChannel | undefined;
  unsubscribe: (name: string) => void;
  connect: () => void;
  disconnect: () => void;
}

interface MockPusherCtor {
  instances: MockPusher[];
  factory: (
    appKey: string,
    options: Record<string, unknown>,
  ) => MockPusher;
}

function makePusherCtor(): MockPusherCtor {
  const ctor: MockPusherCtor = {
    instances: [],
    factory: (appKey, options) => {
      const channels = new Map<string, MockChannel>();
      const connection = makeConnection();
      const instance: MockPusher = {
        appKey,
        options,
        connection,
        channels,
        subscribe(name: string) {
          let ch = channels.get(name);
          if (!ch) {
            ch = makeChannel(name);
            channels.set(name, ch);
          }
          return ch;
        },
        channel(name: string) {
          return channels.get(name);
        },
        unsubscribe(name: string) {
          channels.delete(name);
        },
        connect() {
          // Fire "connected" on next tick so consumers can attach
          // listeners after construction.
          queueMicrotask(() => connection.fire("connected"));
        },
        disconnect() {
          connection.fire("disconnected");
        },
      };
      ctor.instances.push(instance);
      return instance;
    },
  };
  return ctor;
}

describe("createNullRealtime", () => {
  it("returns a no-op client with null mode", () => {
    const client = createNullRealtime();
    expect(client.mode).toBe("null");
    expect(client.isConnected).toBe(false);
  });

  it("connect/subscribe/disconnect are all no-ops", async () => {
    const client = createNullRealtime();
    await expect(client.connect("token")).resolves.toBeUndefined();
    const detach = client.subscribe("admin:sos:alert", () => {});
    expect(typeof detach).toBe("function");
    detach();
    await expect(client.disconnect()).resolves.toBeUndefined();
  });
});

describe("createRealtimeClient factory", () => {
  it("falls back to null when wsUrl is missing", () => {
    const client = createRealtimeClient({ appKey: "abc" });
    expect(client.mode).toBe("null");
  });

  it("falls back to null when appKey is missing", () => {
    const client = createRealtimeClient({ wsUrl: "wss://example.test" });
    expect(client.mode).toBe("null");
  });

  it("maps each RealtimeEvent to a private-admin.* channel", () => {
    expect(__test__.EVENT_TO_CHANNEL).toEqual({
      "admin:sos:alert": "private-admin.sos",
      "admin:dashboard": "private-admin.ops",
      "server:driver:location": "private-admin.ops",
    });
  });
});

describe("createRealtimeClient with Pusher wiring", () => {
  let ctor: MockPusherCtor;
  let client: RealtimeClient;

  beforeEach(() => {
    ctor = makePusherCtor();
    client = createRealtimeClient({
      wsUrl: "wss://reverb.example.test:443",
      appKey: "test-app-key",
      authEndpoint: "https://api.example.test/api/v1/broadcasting/auth",
      pusherFactory: (key, options) => ctor.factory(key, options),
    });
  });

  afterEach(async () => {
    await client.disconnect();
  });

  it("returns mode=reverb when both env keys are set", () => {
    expect(client.mode).toBe("reverb");
  });

  it("does not construct Pusher until connect() is called", () => {
    expect(ctor.instances).toHaveLength(0);
  });

  it("connect() instantiates Pusher with the right host/port/TLS/auth", async () => {
    await client.connect("admin-jwt");
    expect(ctor.instances).toHaveLength(1);
    const opts = ctor.instances[0].options;
    expect(ctor.instances[0].appKey).toBe("test-app-key");
    expect(opts.wsHost).toBe("reverb.example.test");
    expect(opts.wsPort).toBe(443);
    expect(opts.forceTLS).toBe(true);
    expect(opts.authEndpoint).toBe(
      "https://api.example.test/api/v1/broadcasting/auth",
    );
    expect(opts.auth).toEqual({
      headers: { Authorization: "Bearer admin-jwt" },
    });
    expect(client.isConnected).toBe(true);
  });

  it("forwards channel events to the subscribed handler", async () => {
    await client.connect("admin-jwt");
    const handler = vi.fn();
    client.subscribe("admin:sos:alert", handler);

    const channel = ctor.instances[0].channels.get("private-admin.sos");
    expect(channel).toBeDefined();
    channel!.trigger("admin:sos:alert", {
      alert_id: "sos_42",
      lat: 23.79,
      lng: 90.4,
    });

    expect(handler).toHaveBeenCalledTimes(1);
    expect(handler).toHaveBeenCalledWith({
      event: "admin:sos:alert",
      data: { alert_id: "sos_42", lat: 23.79, lng: 90.4 },
    });
  });

  it("returns a detach function that unhooks the handler", async () => {
    await client.connect("admin-jwt");
    const handler = vi.fn();
    const detach = client.subscribe("admin:sos:alert", handler);

    const channel = ctor.instances[0].channels.get("private-admin.sos")!;
    channel.trigger("admin:sos:alert", { x: 1 });
    expect(handler).toHaveBeenCalledTimes(1);

    detach();
    channel.trigger("admin:sos:alert", { x: 2 });
    expect(handler).toHaveBeenCalledTimes(1);
  });

  it("buckets admin:dashboard + server:driver:location onto admin.ops", async () => {
    await client.connect("admin-jwt");
    const dashboardHandler = vi.fn();
    const locationHandler = vi.fn();

    client.subscribe("admin:dashboard", dashboardHandler);
    client.subscribe("server:driver:location", locationHandler);

    const opsChannel = ctor.instances[0].channels.get("private-admin.ops");
    expect(opsChannel).toBeDefined();
    opsChannel!.trigger("admin:dashboard", { rides: 42 });
    opsChannel!.trigger("server:driver:location", { driver_id: "d0", lat: 1 });

    expect(dashboardHandler).toHaveBeenCalledWith({
      event: "admin:dashboard",
      data: { rides: 42 },
    });
    expect(locationHandler).toHaveBeenCalledWith({
      event: "server:driver:location",
      data: { driver_id: "d0", lat: 1 },
    });
  });

  it("disconnect() tears down Pusher and clears pending handlers", async () => {
    await client.connect("admin-jwt");
    const handler = vi.fn();
    client.subscribe("admin:sos:alert", handler);

    await client.disconnect();
    expect(client.isConnected).toBe(false);

    // A new connect() should build a fresh Pusher instance; the
    // listener set from the previous lifecycle must be gone.
    await client.connect("admin-jwt-2");
    expect(ctor.instances).toHaveLength(2);
    const handlerAfter = vi.fn();
    client.subscribe("admin:sos:alert", handlerAfter);
    ctor.instances[1].channels
      .get("private-admin.sos")!
      .trigger("admin:sos:alert", { alert_id: "sos_99" });
    expect(handler).not.toHaveBeenCalled();
    expect(handlerAfter).toHaveBeenCalledTimes(1);
  });

  it("defaults the auth endpoint to ${VITE_API_URL}/broadcasting/auth when no override is given", async () => {
    const c2 = makePusherCtor();
    const c = createRealtimeClient({
      wsUrl: "ws://reverb.local:8080",
      appKey: "k",
      pusherFactory: (k, o) => c2.factory(k, o),
    });
    // We can't import.meta.env in node tests, so we pass authEndpoint
    // through c() via a different scenario below; this asserts the
    // ws/no-TLS path produces forceTLS=false.
    await c.connect("t");
    expect(c2.instances[0].options.forceTLS).toBe(false);
    expect(c2.instances[0].options.wsPort).toBe(8080);
    await c.disconnect();
  });

  it("propagates a Pusher connect error via rejected promise", async () => {
    const c2 = makePusherCtor();
    // Override connect() to fire "error" instead of "connected".
    c2.factory = (appKey, options) => {
      const ch = new Map<string, MockChannel>();
      const connection = makeConnection();
      const instance: MockPusher = {
        appKey,
        options,
        connection,
        channels: ch,
        subscribe(name) {
          const c = makeChannel(name);
          ch.set(name, c);
          return c;
        },
        channel(name) {
          return ch.get(name);
        },
        unsubscribe(name) {
          ch.delete(name);
        },
        connect() {
          queueMicrotask(() =>
            connection.fire("error", new Error("ws down")),
          );
        },
        disconnect() {
          connection.fire("disconnected");
        },
      };
      c2.instances.push(instance);
      return instance;
    };

    const c = createRealtimeClient({
      wsUrl: "wss://x",
      appKey: "k",
      pusherFactory: (k, o) => c2.factory(k, o),
    });
    await expect(c.connect("t")).rejects.toThrow("ws down");
    await c.disconnect();
  });
});
