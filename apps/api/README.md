# BD Ride Share — Laravel API

Backend for BD Ride Share. MySQL + Redis + JWT.

## Setup

```bash
composer install
cp .env.example .env
php artisan key:generate
php artisan jwt:secret -f
php artisan migrate --seed
php artisan serve
```

## Environment

| Variable | Description |
|---|---|
| `DB_*` | MySQL connection |
| `REDIS_*` | Redis for location, OTP rate, JWT blacklist |
| `JWT_TTL` | Access token minutes (default 15) |
| `SMS_GATEWAY_*` | Production SMS |
| `GOOGLE_MAPS_API_KEY` | One Distance Matrix call at fare lock only |

## Architecture

```
HTTP /api/v1
  → JWT Guard + Role Middleware
  → Controllers
  → Services (Fare, Dispatch, SOS, Payment, Location)
  → MySQL + Redis + Queue Jobs
```

## Key services

- **OtpService** — 6-digit OTP, 3 sends/10min, bcrypt hash
- **TokenService** — JWT 15m + refresh 7d rotation
- **FareService** — Haversine estimate, ৳5 rounding, one Matrix at lock
- **DispatchService** — 15s cascade, max 5 drivers / 90s
- **SosService** — full pipeline per PRD §11
- **PaymentService** — idempotent cash confirm + commission debt + holding

## Scheduled jobs

```bash
php artisan schedule:work
php artisan queue:work redis
```

- `ReleaseHeldPayoutJob` — hourly, releases held transactions

## Tests

```bash
php artisan test
```
