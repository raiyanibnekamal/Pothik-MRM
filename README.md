# Pothik MRM — BD Ride Share (বিডি রাইড শেয়ার)

Uber-class ride-hailing for Bangladesh — monorepo.

| Layer | Stack |
|---|---|
| **Backend** | Laravel 9 · MySQL 8 · Redis · JWT |
| **Passenger / Driver** | Flutter (`packages/mobile_core`) |
| **Admin** | React + Vite + Tailwind |

**Docs:** [PRD](docs/PRD.md) · [Architecture](docs/ARCHITECTURE.md) · [Contributing](docs/CONTRIBUTING.md)

---

## Quick start

### Windows (recommended)

```powershell
.\scripts\setup.ps1
cd apps\api; php artisan serve
# new terminal
pnpm dev:admin
```

### Linux / macOS

```bash
./scripts/setup.sh
cd apps/api && php artisan serve
pnpm dev:admin
```

---

## URLs

| Service | URL |
|---------|-----|
| API | http://localhost:8000 |
| Health | http://localhost:8000/api/v1/health |
| Admin | http://localhost:5173 |

**Admin login:** `admin@bdride.share` / `Admin@12345`

**Passenger OTP (local):** phone `0152170004`, OTP `123456` (see API log if SMS mock)

---

## Environment files

| App | File | Key vars |
|-----|------|----------|
| API | `apps/api/.env` | MySQL `bdride`/`bdride`, Redis `127.0.0.1:6379` |
| Admin | `apps/admin-panel/.env` | `VITE_API_URL=http://localhost:8000/api/v1`, `VITE_USE_MOCK=false` |

Docker MySQL credentials match `infra/docker/docker-compose.yml`.

---

## Flutter (real API)

```bash
cd apps/passenger-app
flutter run --dart-define=USE_API=true --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Emulator uses `10.0.2.2`; physical device use your PC LAN IP.

---

## Tests & CI

```bash
# Backend
cd apps/api && php artisan test

# Admin build
pnpm build:admin

# E2E smoke (mock admin login)
pnpm test:e2e
```

GitHub Actions runs 4 checks on every push: **Laravel API**, **Admin panel**, **Flutter analyze**, **Admin E2E**.

---

## Team workflow

- **`main`** — protected (owner merges only). See [CONTRIBUTING.md](docs/CONTRIBUTING.md).
- Feature branch: `git checkout -b feature/your-task` → PR → CI green → owner review → merge.
- **Owner:** enable branch lock once: `gh auth login` then `.\scripts\setup-branch-protection.ps1`

---

## Project structure

```
apps/api/              Laravel backend
apps/passenger-app/    Flutter shell
apps/driver-app/       Flutter shell + native GPS
apps/admin-panel/      React admin
packages/mobile_core/  Shared Flutter UI + API client
packages/shared-types/ Socket events + TS types
packages/shared-constants/ Error codes
infra/docker/          MySQL + Redis
docs/                  PRD, architecture, contributing
test/e2e/              Playwright admin smoke
.github/workflows/     CI
scripts/               setup + branch protection
```

---

## Still on the roadmap (P0 → P1)

- WebSockets (Laravel Reverb) for live dispatch / SOS
- Full mobile ride flow on real API (auth wired; rides still mock)
- bKash / Nagad (P1)
- Staging deploy
