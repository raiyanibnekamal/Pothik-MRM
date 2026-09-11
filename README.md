# Pothik MRM — BD Ride Share (বিডি রাইড শেয়ার)

Uber-class ride-hailing platform for Bangladesh — a **pnpm + Flutter monorepo** with a Laravel API, React admin panel, and shared mobile core for passenger and driver apps.

| Layer | Stack |
|---|---|
| **Backend** | Laravel 9 · PHP 8.2 · MySQL 8 · Redis · JWT |
| **Passenger / Driver** | Flutter · flutter_bloc · go_router · `packages/mobile_core` |
| **Admin** | React 19 · Vite · Tailwind · Leaflet · Pusher-js |
| **Maps (mobile)** | flutter_map · OpenStreetMap tiles · Nominatim · OSRM |
| **Real-time** | Laravel Reverb (Docker) · broadcast events · Pusher client |
| **CI** | GitHub Actions — API, Admin, Flutter, E2E |

**Docs:** [PRD](docs/PRD.md) · [Architecture](docs/ARCHITECTURE.md) · [Project structure](docs/PROJECT_STRUCTURE.md) · [Contributing](docs/CONTRIBUTING.md) · [Production readiness report](docs/report.md)

---

## What’s in the repo

| App | Path | Description |
|---|---|---|
| **API** | `apps/api` | REST API — auth, rides, dispatch, driver onboarding, SOS, admin |
| **Passenger** | `apps/passenger-app` | Flutter shell — book, track, pay, SOS |
| **Driver** | `apps/driver-app` | Flutter shell + native background GPS |
| **Admin** | `apps/admin-panel` | Ops dashboard — drivers, KYC queue, rides, SOS, finance |
| **Mobile core** | `packages/mobile_core` | Shared UI, maps, ride/driver cubits, mock + real API client |

**Implemented today**

- Full passenger/driver UX flows (mock backend by default)
- Live GPS + unified `BrandedMap` (pickup/drop search, route polyline, tracking)
- Laravel ride lifecycle, dispatch, fare, SOS, and admin endpoints
- Admin KYC pending queue, SOS realtime hook (Pusher/Reverb)
- Gateway scaffolding: SMS (SSL Wireless), FCM, bKash/Nagad (null drivers for local dev)
- Feature tests (PHP), Vitest (admin), Flutter unit tests

**Still in progress** — see [docs/report.md](docs/report.md) for the full gap analysis (~58/100 production score):

- Mobile ride/driver flow on real API (auth + SOS wired; booking/dispatch mostly mock)
- End-to-end WebSocket dispatch in production
- Production SMS, FCM push, and digital payments
- Staging/production deploy

---

## Prerequisites

| Tool | Version |
|---|---|
| PHP | 8.2+ |
| Composer | 2.x |
| Node.js | 20+ |
| pnpm | 10+ |
| Flutter | stable channel |
| Docker Desktop | optional (MySQL, Redis, full stack) |

---

## Quick start

### Windows

```powershell
.\scripts\setup.ps1

# Terminal 1 — API
cd apps\api
php artisan serve

# Terminal 2 — Admin
pnpm dev:admin
```

### Linux / macOS

```bash
./scripts/setup.sh

cd apps/api && php artisan serve
# new terminal
pnpm dev:admin
```

`setup.ps1` / `setup.sh` starts Docker MySQL + Redis, runs migrations/seeds, installs pnpm and Flutter dependencies.

---

## Run all services locally

| Service | Command | URL |
|---|---|---|
| **API** | `cd apps/api && php artisan serve` | http://localhost:8000 |
| **Health** | — | http://localhost:8000/api/v1/health |
| **Admin** | `pnpm dev:admin` | http://localhost:5173 |
| **Passenger (web)** | `cd apps/passenger-app && flutter run -d chrome --web-port=5174` | http://localhost:5174 |
| **Driver (web)** | `cd apps/driver-app && flutter run -d chrome --web-port=5175` | http://localhost:5175 |
| **Passenger (Android)** | `cd apps/passenger-app && flutter run` | emulator/device |
| **Driver (Android)** | `cd apps/driver-app && flutter run` | emulator/device |

### Docker full stack (API + queue + scheduler + Reverb)

```bash
docker compose -f infra/docker/docker-compose.yml up -d
```

Services: `mysql`, `redis`, `api` (:8000), `queue`, `scheduler`, `ws` (:8080 Reverb).

For local `php artisan serve` instead, start only infra:

```bash
docker compose -f infra/docker/docker-compose.yml up -d mysql redis
```

---

## Local credentials

| Role | Login | Notes |
|---|---|---|
| **Admin** | `admin@bdride.share` / `Admin@12345` | Seeded admin user |
| **Passenger / Driver (QA)** | phone `0152170004` · OTP `123456` | Works with real API when SMS provider is `null` (OTP logged) |
| **Ride PIN (mock mode)** | `4821` | Driver PIN verify in demo flow |

---

## Environment files

Copy from `.env.example` if missing.

| App | File | Key vars |
|---|---|---|
| **API** | `apps/api/.env` | `DB_*`, `REDIS_*`, `JWT_SECRET`, `BROADCAST_DRIVER`, `SMS_DEFAULT_PROVIDER=null` |
| **Admin** | `apps/admin-panel/.env` | `VITE_API_URL`, `VITE_SOCKET_URL`, `VITE_USE_MOCK=false` |

Docker MySQL defaults (`infra/docker/docker-compose.yml`): database `bd_ride_share`, user `bdride` / password `bdride`.

---

## Mobile: mock vs real API

**Default:** `MockBackend` — full demo UX without the API.

**Real API:** pass compile-time flags (Android emulator uses `10.0.2.2` for host loopback):

```bash
cd apps/passenger-app
flutter run --dart-define=USE_API=true --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

On a physical device, replace `10.0.2.2` with your PC’s LAN IP.

| Feature | Real API | Mock |
|---|---|---|
| OTP auth | ✅ | ✅ |
| Profile patch | ✅ | ✅ |
| SOS trigger/cancel | ✅ | ✅ |
| Book ride / dispatch / driver online | ❌ (partial wiring) | ✅ |

Toggle: `packages/mobile_core/lib/core/network/backend_factory.dart`

---

## Admin panel

Set `VITE_USE_MOCK=false` in `apps/admin-panel/.env` to use the Laravel API.

| Route | Purpose |
|---|---|
| `/` | Dashboard |
| `/map` | Live map |
| `/drivers`, `/drivers/:id` | Driver management |
| `/kyc/pending` | KYC review queue |
| `/rides` | Ride list |
| `/sos` | SOS alerts (realtime via Pusher when Reverb is running) |
| `/track/:token` | Public trip tracking (no login) |

---

## Tests & CI

```bash
# Backend (SQLite in CI; MySQL locally)
cd apps/api && php artisan test

# Admin unit tests
pnpm --filter admin-panel test

# Flutter (mobile_core + apps)
cd packages/mobile_core && flutter test

# Admin production build
pnpm build:admin

# E2E smoke (mock admin login)
pnpm test:e2e
```

GitHub Actions (`.github/workflows/ci.yml`) on every push to `main`:

1. **Laravel API** — migrate + `php artisan test`
2. **Admin panel** — build
3. **Flutter** — analyze + test (mobile_core, passenger, driver)
4. **Admin E2E** — Playwright smoke

---

## Project structure

```
apps/
  api/                 Laravel REST API + broadcast events + gateway services
  passenger-app/       Flutter passenger shell
  driver-app/          Flutter driver shell + native GPS
  admin-panel/         React ops dashboard
packages/
  mobile_core/         Shared Flutter UI, maps, cubits, api/mock backend
  shared-types/        Socket events + TypeScript types
  shared-constants/    Error codes aligned with Laravel
  ui/                  Design tokens for admin
infra/docker/          MySQL, Redis, API, queue, scheduler, Reverb
docs/                  PRD, architecture, ADRs, production report
test/e2e/              Playwright admin smoke tests
scripts/               setup, branch protection
.github/workflows/     CI pipeline
```

---

## Team workflow

- **`main`** — integration branch. See [CONTRIBUTING.md](docs/CONTRIBUTING.md).
- Feature branch → PR → CI green → review → merge.
- Enable branch protection (owner once): `gh auth login` then `.\scripts\setup-branch-protection.ps1`

---

## Roadmap (P0 → P1)

1. Wire mobile ride + driver dispatch to Laravel (`api_backend.dart`)
2. Run Reverb in staging; connect mobile Pusher client end-to-end
3. Production SMS (SSL Wireless) + OTP hardening
4. FCM push for dispatch and SOS
5. bKash / Nagad payment gateways
6. Staging deploy + locked CORS

Details, scores, and step-by-step fixes: **[docs/report.md](docs/report.md)**

---

## License

Private — BD Ride Share / Pothik MRM team.
