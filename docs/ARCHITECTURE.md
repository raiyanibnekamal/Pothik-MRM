# BD Ride Share — System Architecture

| Field | Value |
|---|---|
| **Version** | 1.2 |
| **Date** | 2026-09-11 |
| **Stack** | Laravel 9 · PHP 8.2 · MySQL · Redis · Flutter · React Admin |
| **Production score** | **54/100** — see [report.md](report.md) |

Features: [PRD.md](PRD.md). Folders: [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md).

---

## 1. Goals

1. One city can run with cash, live matching, and SOS.
2. Fare, payout, and SOS gating are **server-authoritative**.
3. Haversine for estimates; **one** Google Distance Matrix at fare lock (PIN verify).
4. Native driver GPS (Kotlin/Swift), not Flutter background plugins.
5. Clear FE/BE/QA seams in a monorepo.

---

## 2. System context

```
Clients:  Flutter Passenger | Flutter Driver | Admin SPA
          GET /public/track/:token (guardian, no login)

                    ┌─────────────────────────┐
                    │   Nginx / Cloudflare    │  ← not deployed yet
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │   Laravel API (apps/api) │
                    └───┬─────────────┬───────┘
                        │             │
                 ┌──────▼──────┐ ┌────▼────────────┐
                 │   MySQL     │ │  Redis          │
                 │  (source)   │ │ location/OTP/JWT│
                 └─────────────┘ └─────────────────┘
                        │
                 ┌──────▼──────────────────────┐
                 │  Laravel Reverb (ws :8080)  │  ← Docker defined;
                 │  Pusher protocol            │    package not in composer yet
                 └─────────────────────────────┘

External P0: SMS gateway, FCM, object storage
Implemented (null default): SSL Wireless SMS, Firebase FCM, bKash/Nagad gateways
Maps (mobile): Nominatim + OSRM (dev); production geospatial TBD
```

---

## 3. Backend (Laravel modular monolith)

```
HTTP + Broadcast (Reverb/Pusher/test driver)
        │
   Middleware: JWT, jwt.blacklist, Roles, Throttle
        │
   Controllers → Services → Models / Redis / Jobs
        │
   { success, data, message } envelope
```

### Modules

| Module | Responsibility | Test coverage |
|---|---|---|
| Auth | OTP, JWT 15m + refresh 7d, admin login | ✅ AuthOtp, OtpRateLimit |
| Profile | User profile, emergency contacts | ⚠️ No HTTP tests |
| Driver | Onboarding, KYC, online, GPS ingest | ✅ DriverOnboarding |
| Rides | Estimate, book, dispatch, PIN, cash, rate | ✅ RideLifecycle, RideEstimate |
| SOS | Trigger, cancel, resolve, admin alerts | ⚠️ Unit only |
| Admin | Dashboard, KYC, config, live map, users | ❌ No tests |
| Health | DB + Redis status | ❌ No tests |
| Integrations | SMS, FCM, payment gateways | ✅ Gateway tests |

### Jobs & scheduler

| Job / command | Schedule |
|---|---|
| `DispatchTimeoutJob` | Queue (15s cascade) |
| `ReleaseHeldPayoutJob` | Hourly |
| `pothik:sweep-stale-dispatches` | Every 5 min |
| `pothik:prune-otps` | Daily |

Docker compose runs `queue:work`, `schedule:work`, and `reverb:start` (ws service).

### Redis keys

- `driver:{id}:location` — TTL 60s
- OTP rate limits, JWT blacklist (via predis)

---

## 4. API contract

- Base: `/api/v1/...`
- Envelope: `{ success, data, message }` / `{ success: false, error: { code, message } }`
- Error codes: `packages/shared-constants` ↔ `app/Constants/ErrorCodes.php`
- Socket events: `packages/shared-types` ↔ Laravel broadcast events
- Broadcasting auth: `POST /api/v1/broadcasting/auth` (JWT required)

Admin login: `POST /auth/admin/login` (not `/auth/login`).

---

## 5. Client architecture

### Flutter (`mobile_core`)

```
Presentation (screens)
    → MockBackend (default) | ApiBackend (USE_API=true)
    → Dio + JWT interceptor (401 refresh)
    → Secure storage for tokens (refresh not restored on launch — fix pending)
Native: driver GPS service (driver-app only)
Realtime: PusherRealtimeClient + socket_service.dart (scaffold — not wired to cubits)
Maps: LocationCubit → BrandedMap (flutter_map + OSRM/Nominatim)
```

**API mode status:** Auth, profile, SOS, onboarding, and ride/driver HTTP methods exist in `ApiBackend`, but release builds default to mock. Dispatch uses HTTP polling, not WebSocket.

### Admin (React)

```
Pages → api/client.ts → realApi.ts (Laravel mapping)
Mock default: VITE_USE_MOCK !== "false"
Live SOS: useSosPolling (5s) — useSosRealtime hook exists but not mounted
KYC: /kyc/pending page wired to /admin/kyc/*
Realtime client: realtimeClient.ts (Pusher/Reverb when env set)
```

Set `VITE_USE_MOCK=false` + Reverb env vars for staging/production.

---

## 6. Critical flows

**Book → trip (server):** estimate → POST ride → dispatch job → accept → PIN → in_progress → cash confirm → holding.

**Book → trip (client today):** mock timers by default; API mode uses HTTP poll for match/offer.

**SOS:** authenticate → gating → dedup → insert → SMS + admin alert → location until resolved.

**Cash:** `amountCollected === lockedFare`; idempotent confirm; commission debt row.

---

## 7. Security

- HTTPS/WSS only in prod
- Role guards on every admin route
- JWT blacklist on protected routes
- CORS locked via `CORS_ALLOWED_ORIGINS` env (not `*`)
- OTP throttle: per-phone + per-IP
- **Open issues:** unrate-limited refresh; role change on OTP verify; PIN in API responses
- Mask phones in logs; never log OTP/JWT/NID

---

## 8. CI/CD

| Job | What runs |
|---|---|
| Laravel API | SQLite migrate + **91 tests** |
| Admin panel | `tsc -b` + Vite build |
| Flutter | analyze + test (mobile_core, passenger, driver) |
| Admin E2E | Playwright mock login (1 spec) |

**Gaps:** no deploy workflow, admin vitest not in CI, no Docker build validation, no monitoring.

Staging: not deployed. Target: migrate + health curl before deploy.

---

## 9. Explicit non-goals (P0)

- PostGIS (Haversine + Redis for P0)
- Microservices split
- Distance Matrix per GPS tick
- Firebase RTDB as SOS source of truth

---

## Related

- [PRD.md](PRD.md)
- [report.md](report.md) — Production audit & scores
- [adr/002-laravel-mysql-stack.md](adr/002-laravel-mysql-stack.md)
