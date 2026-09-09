# Pothik MRM — BD Ride Share (বিডি রাইড শেয়ার)

Uber-class ride-hailing platform for Bangladesh — monorepo.

| Layer | Stack |
|---|---|
| **Backend** | Laravel 9 · MySQL 8 · Redis · JWT |
| **Passenger / Driver** | Flutter |
| **Admin** | React + Vite + Tailwind |

## Project structure

```
apps/
  api/              ← Laravel backend
  passenger-app/    ← Flutter
  driver-app/       ← Flutter
  admin-panel/      ← React admin
packages/
  mobile_core/      ← shared Flutter
  ui/               ← design tokens
  shared-types/     ← socket events (BE + FE)
  shared-constants/
infra/docker/       ← MySQL + Redis
scripts/
```

---

## Backend (API)

```bash
docker compose -f infra/docker/docker-compose.yml up -d mysql redis

cd apps/api
cp .env.example .env
composer install
php artisan key:generate
php artisan jwt:secret -f
php artisan migrate --seed
php artisan serve
# → http://localhost:8000
```

Health: `GET http://localhost:8000/api/v1/health`

**Seed admin:** `admin@bdride.share` / `Admin@12345`

**Local OTP:** logged to `apps/api/storage/logs/laravel.log`

All routes: `/api/v1/...`

---

## Frontend

### Admin (http://localhost:5173)

```bash
pnpm install
cd apps/admin-panel
pnpm dev
```

Set `VITE_API_URL=http://localhost:8000/api/v1` in `apps/admin-panel/.env`

### Passenger / Driver (Flutter)

```bash
cd apps/passenger-app && flutter pub get && flutter run
cd apps/driver-app && flutter pub get && flutter run
```

### Test user (frontend mock / staging)

| Field | Value |
|---|---|
| Phone | `0152170004` |
| OTP | `123456` |
| Ride PIN | `4821` |
| Admin alt | `ops@bdrideshare.com` / `Admin@1234` |

---

## Run everything locally

```bash
# Terminal 1 — API
cd apps/api && php artisan serve

# Terminal 2 — Admin
cd apps/admin-panel && pnpm dev

# Terminal 3 — Flutter
cd apps/passenger-app && flutter run
```

---

## Git workflow (team)

- **`main`** — full monorepo (backend + frontend merged)
- Feature branches from `main`: `feature/backend-*`, `feature/frontend-*`
- PR → `main`

---

## Tests

```bash
cd apps/api && php artisan test
```
