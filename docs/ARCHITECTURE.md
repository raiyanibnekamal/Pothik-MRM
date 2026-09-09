# BD Ride Share — System Architecture

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-09 |
| **Stack** | Laravel 9 · MySQL · Redis · Flutter · React Admin |

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
                    │   Nginx / Cloudflare    │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │   Laravel API (apps/api) │
                    └───┬─────────────┬───────┘
                        │             │
                 ┌──────▼──────┐ ┌────▼────┐
                 │   MySQL     │ │  Redis  │
                 │  (source)   │ │ location│
                 └─────────────┘ │ OTP/JWT │
                                 └─────────┘

External P0: Google Maps (Places + 1× Matrix), SMS, FCM, object storage
Later: bKash, Nagad, Laravel Reverb / Socket.IO adapter
```

---

## 3. Backend (Laravel modular monolith)

```
HTTP / (future) WebSockets
        │
   Middleware: JWT, Roles, Envelope, Throttle
        │
   Controllers → Services → Models / Redis / Jobs
        │
   { success, data, message } envelope
```

### Modules (P0)

| Module | Responsibility |
|---|---|
| Auth | OTP, JWT 15m + refresh 7d, admin login |
| Profile | User profile, emergency contacts |
| Driver | Onboarding, KYC, online, GPS ingest |
| Rides | Estimate, book, dispatch, PIN, cash, rate |
| SOS | Trigger, cancel, resolve, admin alerts |
| Admin | Dashboard, KYC, config, live map, users |
| Health | DB + Redis status |

### Jobs

- `DispatchTimeoutJob` — 15s cascade
- `ReleaseHeldPayoutJob` — holding release

### Redis keys (P0)

- `driver:{id}:location` — TTL 60s
- OTP rate limits, JWT blacklist (via predis)

---

## 4. API contract

- Base: `/api/v1/...`
- Envelope: `{ success, data, message }` / `{ success: false, error: { code, message } }`
- Error codes: `packages/shared-constants` ↔ `app/Constants/ErrorCodes.php`
- Socket events: `packages/shared-types` ↔ `app/Constants/SocketEvents.php`

Admin login: `POST /auth/admin/login` (not `/auth/login`).

---

## 5. Client architecture

### Flutter (`mobile_core`)

```
Presentation (screens)
    → MockBackend | ApiBackend (Dio, USE_API flag)
    → Secure storage for tokens
Native: driver GPS service (driver-app only)
```

P0: Auth + profile on real API; ride flow still mock until WebSocket dispatch ships.

### Admin (React)

```
Pages → api/client.ts → realApi.ts (Laravel mapping)
Live SOS: 15s poll until Reverb wired
```

---

## 6. Critical flows (P0)

**Book → trip:** estimate → POST ride → dispatch job → accept → PIN → in_progress → cash confirm → holding.

**SOS:** authenticate → gating → dedup → insert → SMS + admin alert → 1s location until resolved.

**Cash:** `amountCollected === lockedFare`; idempotent confirm; commission debt row.

---

## 7. Security

- HTTPS/WSS only in prod
- Role guards on every admin route
- No client-submitted fare truth
- OTP throttle 3/10min
- Mask phones in logs; never log OTP/JWT/NID

---

## 8. CI/CD (P0)

PR → PHP unit tests → admin `tsc` + build → Flutter analyze → Playwright smoke (optional job).

Staging: migrate + health curl before deploy.

---

## 9. Explicit non-goals (P0)

- PostGIS (Haversine + Redis for P0)
- Microservices split
- Distance Matrix per GPS tick
- Firebase RTDB as SOS source of truth

---

## Related

- [PRD.md](PRD.md)
- [adr/002-laravel-mysql-stack.md](adr/002-laravel-mysql-stack.md)
