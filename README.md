# Pothik MRM — BD Ride Share (বিডি রাইড শেয়ার)

Uber-class ride-hailing platform for Bangladesh — monorepo.

| Layer | Stack |
|---|---|
| **Backend** | Laravel 9 · MySQL 8 · Redis · JWT · Broadcasting |
| **Mobile** | Flutter (passenger + driver) — separate team |
| **Admin** | React + Vite — separate team |

## Quick start (backend)

### Prerequisites
- PHP 8.0+
- Composer
- MySQL 8
- Redis
- Docker (optional)

### Local setup

```bash
# 1. Start MySQL + Redis (Docker)
docker compose -f infra/docker/docker-compose.yml up -d mysql redis

# 2. API setup
cd apps/api
cp .env.example .env
composer install
php artisan key:generate
php artisan jwt:secret -f

# Edit .env — set DB_DATABASE=bd_ride_share, DB_PASSWORD=secret (or your values)

# 3. Migrate + seed
php artisan migrate --seed

# 4. Run
php artisan serve
# API → http://localhost:8000
```

Health check: `GET http://localhost:8000/api/v1/health`

### Default admin (local seed)
- Email: `admin@bdride.share`
- Password: `Admin@12345`

### OTP (local)
OTP codes are logged to `storage/logs/laravel.log` — no SMS in local.

## API base URL

All routes: `/api/v1/...`

Response envelope:
```json
{ "success": true, "data": {}, "message": "..." }
{ "success": false, "error": { "code": "OTP_EXPIRED", "message": "..." } }
```

## P0 modules (backend)

| Module | Endpoints |
|---|---|
| Auth | OTP, refresh, logout, admin login, device token |
| Profile | GET/PATCH profile, emergency contacts |
| Driver | onboarding, docs, availability, location, earnings |
| Rides | estimate, book, accept/decline, PIN, cash, rate, history |
| SOS | trigger, cancel, resolve, admin war room |
| Admin | dashboard, live map, KYC, config, holding |
| Public | `/public/track/{token}` — guardian tracking |

## Project structure

```
apps/api/           ← Laravel backend (you)
apps/passenger-app/ ← Flutter (frontend team)
apps/driver-app/
apps/admin-panel/
packages/shared-types/
packages/shared-constants/
infra/docker/
docs/
scripts/
```

## Queue & scheduler

```bash
php artisan queue:work redis
php artisan schedule:work   # releases held payouts hourly
```

## Tests

```bash
cd apps/api
php artisan test
```
