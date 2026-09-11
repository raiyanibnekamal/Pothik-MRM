import { useEffect, useMemo } from "react";
import {
  createRealtimeClient,
  type RealtimeClient,
  type SosAlertPayload,
} from "../realtime/realtimeClient";
import { store, type SosRow } from "../api/client";

/**
 * Realtime counterpart to `useSosPolling`.
 *
 * Subscribes to the admin SOS channel and pushes any new alert into the
 * shared store immediately, so the SOS banner / dashboard refresh without
 * waiting for the next 5s poll. The polling hook stays as a safety net
 * (it covers missed socket events when the WS drops).
 *
 * When the realtime client is in `null` mode (no Reverb env, demo build)
 * the hook still mounts cleanly — subscribe() is a no-op and the
 * polling fallback does the heavy lifting.
 */
export function useSosRealtime(adminToken: string | null) {
  const client: RealtimeClient = useMemo(() => createRealtimeClient(), []);

  useEffect(() => {
    if (!adminToken) return;
    let detach: (() => void) | null = null;

    (async () => {
      await client.connect(adminToken);
      detach = client.subscribe("admin:sos:alert", (raw) => {
        const payload = raw as SosAlertPayload;
        // Push to the top of the list if we don't already know about it.
        if (
          payload?.alert_id &&
          !store.sos.some((s) => s.id === payload.alert_id)
        ) {
          const enriched: SosRow = {
            id: payload.alert_id,
            // The realtime payload carries the user/ride ids; the admin
            // row model needs display strings. Until the lookup is
            // wired in the API response, we leave rider/driver/plate
            // blank — the polling refresh (every 5s) hydrates them.
            rider: "",
            driver: "",
            plate: "",
            lat: typeof payload.lat === "number" ? payload.lat : 0,
            lng: typeof payload.lng === "number" ? payload.lng : 0,
            createdAt: payload.created_at ?? new Date().toISOString(),
          };
          store.sos = [enriched, ...store.sos];
        }
      });
    })();

    return () => {
      if (detach) detach();
      void client.disconnect();
    };
  }, [adminToken, client]);

  return { mode: client.mode, isConnected: client.isConnected };
}
