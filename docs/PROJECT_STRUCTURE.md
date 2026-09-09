# BD Ride Share — Project Structure

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-09 |
| **Layout** | Monorepo (pnpm workspaces + Flutter packages) |
| **Backend stack** | **Laravel 9 + MySQL + Redis** (see `docs/adr/002-laravel-mysql-stack.md`) |

Product rules: [PRD.md](PRD.md). Runtime: [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Root tree

```
Pothik MRM/
├── apps/
│   ├── api/                 # Laravel API — Backend
│   ├── passenger-app/       # Flutter shell → mobile_core
│   ├── driver-app/          # Flutter shell + native GPS hooks
│   └── admin-panel/         # React + Vite + Tailwind — Frontend
├── packages/
│   ├── shared-types/        # Socket events + TS types (BE source of truth)
│   ├── shared-constants/    # Error codes aligned with Laravel
│   ├── ui/                  # Design tokens for admin
│   └── mobile_core/         # Shared Flutter UI + network layer
├── infra/docker/            # MySQL + Redis (local)
├── docs/                    # PRD, architecture, ADRs
├── test/e2e/                # Playwright (admin smoke)
├── scripts/setup.sh
├── .github/workflows/ci.yml
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
| `docs/qa/` | QA |
| `test/e2e/` | QA |

---

## Flutter layout

Two thin apps share `packages/mobile_core`:

- `apps/passenger-app/lib/main.dart` — `AppRole.passenger`
- `apps/driver-app/lib/main.dart` — `AppRole.driver`

Real API: run with `--dart-define=USE_API=true` (see `backend_factory.dart`).

---

## Admin panel

```
apps/admin-panel/src/
├── api/client.ts       # Mock or real API (VITE_USE_MOCK)
├── api/realApi.ts      # Laravel route + response mapping
├── pages/              # Dashboard, map, drivers, rides, SOS, finance…
└── components/         # Layout, SOS banner, UI tokens
```

Env: `VITE_API_URL=http://localhost:8000/api/v1`, `VITE_USE_MOCK=false` for staging.

---

## Local setup

```bash
./scripts/setup.sh
# API:     http://localhost:8000
# Admin:   http://localhost:5173
# Health:  GET /api/v1/health
```

---

## Related

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [PRD.md](PRD.md)
- [adr/002-laravel-mysql-stack.md](adr/002-laravel-mysql-stack.md)
