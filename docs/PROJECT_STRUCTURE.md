# BD Ride Share — Project Structure

| Field | Value |
|---|---|
| **Version** | 1.3 |
| **Date** | 2026-09-11 |
| **Layout** | Monorepo (pnpm workspaces + Flutter packages) |
| **Backend stack** | **Laravel 9 + PHP 8.2 + MySQL + Redis** |
| **Production score** | **54/100** — see [report.md](report.md) |

Product rules: [PRD.md](PRD.md). Runtime: [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Root tree

```
Pothik MRM/
├── apps/
│   ├── api/                 # Laravel API — auth, rides, dispatch, SOS, admin
│   ├── passenger-app/       # Flutter shell → mobile_core (passenger role)
│   ├── driver-app/          # Flutter shell + native GPS hooks
│   └── admin-panel/         # React 19 + Vite + Tailwind ops dashboard
├── packages/
│   ├── shared-types/        # Socket events + TS types (BE source of truth)
│   ├── shared-constants/    # Error codes aligned with Laravel
│   ├── ui/                  # Design tokens for admin
│   └── mobile_core/         # Shared Flutter UI, maps, cubits, api/mock backend
├── infra/docker/            # dev + prod compose, Dockerfile.prod, Caddyfile, prod env template, secrets/
├── docs/                    # PRD, architecture, ADRs, production report, staging runbook
├── test/e2e/                # Playwright admin smoke (1 spec)
├── scripts/                 # setup, branch protection
├── .github/workflows/       # ci.yml (4 jobs) + deploy-staging.yml (rsync + compose up + health-probe)
├── package.json
└── pnpm-workspace.yaml
```

---

## Ownership

| Path | Owner |
|---|---|
| `apps/api/` | Backend |
| `apps/passenger-app`, `driver-app`, `admin-panel` | Frontend |
| `packages/mobile_core/` | Frontend |
| `packages/shared-types`, `shared-constants` | Backend writes, Frontend consumes |
| `infra/` | Backend |
| `test/e2e/` | QA |
| `docs/report.md` | All teams (living audit doc) |

---

## Backend (`apps/api/`)

```
app/
├── Http/Controllers/Api/V1/   # Auth, Ride, Driver, SOS, Admin, Health
├── Http/Resources/            # Ride, Driver, Transaction, EmergencyContact
├── Services/
│   ├── RideService.php        # State machine, formatRide
│   ├── DispatchService.php    # Geo dispatch, timeout
│   ├── Sms/                   # GatewayManager, SslWireless, Null
│   ├── Fcm/                   # Firebase, Null
│   └── Payment/               # bKash, Nagad, Null
├── Events/                    # RideStatusChanged, RideDispatched, AdminSosAlert
└── Console/Commands/          # PruneOtps, SweepStaleDispatches
tests/
├── Feature/                   # 12 files, 84 tests (auth, rides, broadcast, gateways)
└── Unit/                      # 3 files (fare, SOS, example)
```

**Test run:** `cd apps/api && php artisan test` → **95 passed** (+ `SecurityHardeningTest` covering throttle / role lock / PIN gating / cash-only)

---

## Flutter layout

Two thin apps share `packages/mobile_core`:

| App | Entry | Role |
|-----|-------|------|
| `apps/passenger-app` | `main.dart` | `AppRole.passenger` |
| `apps/driver-app` | `main.dart` | `AppRole.driver` + native GPS |

```
packages/mobile_core/lib/
├── core/
│   ├── network/          # mock_backend.dart, api_backend.dart, backend_factory.dart
│   ├── ride/             # ride_cubit.dart
│   ├── driver/           # driver_session_cubit.dart
│   ├── location/         # location_cubit.dart, geo_service, route_service
│   └── widgets/          # branded_map.dart
├── features/             # passenger, driver, auth, profile screens
└── realtime/             # pusher_client.dart (unit tested; not wired to cubits)

apps/*/lib/services/        # socket_service.dart (scaffold; unused in flow)
```

**Default:** `MockBackend`. Real API: `--dart-define=USE_API=true`.

---

## Admin panel

```
apps/admin-panel/src/
├── api/
│   ├── client.ts           # Mock or real (VITE_USE_MOCK)
│   └── realApi.ts          # Laravel route + response mapping
├── pages/
│   ├── KycQueuePage.tsx    # /kyc/pending — approve/reject
│   ├── SosPage.tsx         # Active SOS + resolve
│   └── …                   # Dashboard, map, drivers, rides, finance
├── hooks/
│   ├── useSosPolling.ts    # 5s HTTP poll (active in AppShell)
│   └── useSosRealtime.ts   # Pusher hook (exists; not mounted)
├── realtime/
│   └── realtimeClient.ts   # Pusher/Reverb client + 14 unit tests
└── components/             # Layout, SOS banner, UI tokens
```

Env: `VITE_API_URL`, `VITE_USE_MOCK=false`, `VITE_SOCKET_URL` for staging.

---

## Infrastructure (`infra/docker/`)

| Service | Port | Purpose |
|---------|------|---------|
| mysql | 3306 | Primary database |
| redis | 6379 | Cache, queue, location, JWT blacklist |
| api | 8000 | Laravel (`artisan serve` — dev only) |
| queue | — | `queue:work` |
| scheduler | — | `schedule:work` |
| ws | 8080 | Reverb WebSocket (`reverb:start`) |

**Note:** `laravel/reverb` is not yet in `composer.json` — install before relying on `ws` service.

---

## Tests summary

| Layer | Location | Count |
|-------|----------|-------|
| PHP API | `apps/api/tests/` | **107 tests** (102 Feature + 5 Health) |
| Flutter | `packages/mobile_core/test/` + app tests | ~26 |
| Admin Vitest | `apps/admin-panel/src/**/*.test.ts(x)` | ~22 (not in CI — pending S5.3) |
| E2E | `test/e2e/specs/` | 1 |

---

## Local setup

```bash
./scripts/setup.sh          # or setup.ps1 on Windows
cd apps/api && php artisan serve
pnpm dev:admin              # http://localhost:5173
```

Full Docker stack: `docker compose -f infra/docker/docker-compose.yml up -d`

| Service | URL |
|---------|-----|
| API | http://localhost:8000 |
| Health | GET /api/v1/health |
| Admin | http://localhost:5173 |
| Passenger web | flutter run -d chrome --web-port=5174 |
| Driver web | flutter run -d chrome --web-port=5175 |

---

## Related

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [report.md](report.md) — Full production audit
- [PRD.md](PRD.md)
- [adr/002-laravel-mysql-stack.md](adr/002-laravel-mysql-stack.md)
