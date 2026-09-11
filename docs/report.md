# Pothik MRM — Production Readiness Report

| Field | Value |
|-------|-------|
| **Project** | Pothik MRM / BD Ride Share (বিডি রাইড শেয়ার) |
| **Version** | 1.0 |
| **Date** | 2026-09-11 |
| **Repo** | [github.com/raiyanibnekamal/Pothik-MRM](https://github.com/raiyanibnekamal/Pothik-MRM) |
| **Purpose** | Gap analysis, production score, and step-by-step fix roadmap |

---

## Executive Summary

| Metric | Current | Target (Production) |
|--------|---------|------------------------|
| **Overall score** | **58/100** | **85–90/100** (real launch) |
| **Backend API** | ~85% built | 95%+ hardened |
| **Mobile ↔ API** | ~25% wired | 95%+ wired |
| **Admin ↔ API** | ~70% (mock default) | 100% real + WebSocket |
| **Real-time dispatch** | ~5% | 100% |
| **Tests** | ~15% | 70%+ critical paths |
| **Deploy / ops** | ~35% | 90%+ |

**Verdict:** Architecture and UI are a **strong prototype**. The core ride engine (book → match → live track → pay) is **mostly mock** — that is the main gap.

> **100% “Uber-level”** is not realistic for a small team in the short term.  
> **85–90% = one-city beta launch** — achievable with the roadmap below.

### Score by context

| Context | Score |
|---------|-------|
| Production launch (real rides) | **58/100** |
| Investor / demo pitch | **68/100** |
| University / portfolio project | **78/100** |
| Team learning monorepo | **82/100** |

### Score breakdown

| Area | Score | Notes |
|------|-------|-------|
| Architecture & docs | 75/100 | Monorepo, PRD, ARCHITECTURE — good |
| UI/UX (mobile + admin) | 72/100 | Uber-style flow, BN/EN, maps |
| Backend API design | 65/100 | Routes and modules well structured |
| Backend implementation | 55/100 | Logic exists; not fully hardened |
| Mobile ↔ API integration | 35/100 | Auth/SOS wired; rides mock |
| Real-time (WebSocket) | 15/100 | Events defined; server not running |
| Testing | 28/100 | ~7 PHP, ~5 Flutter, 1 E2E |
| DevOps / deploy | 40/100 | CI yes; staging/prod no |
| External services | 45/100 | SMS, FCM, payment not production |
| Security & scale | 50/100 | JWT yes; CORS open, low test coverage |

---

## Part 1 — Current State

### What is strong (keep and build on)

| Area | Status | Location |
|------|--------|----------|
| Monorepo structure | ✅ | `apps/`, `packages/`, `docs/` |
| PRD + Architecture docs | ✅ | `docs/PRD.md`, `docs/ARCHITECTURE.md` |
| Laravel REST API surface | ✅ | `apps/api/routes/api.php` |
| JWT + OTP auth (backend) | ✅ | `AuthController`, `OtpService`, `TokenService` |
| Ride lifecycle (backend logic) | ✅ | `RideService`, `DispatchService`, `FareService` |
| Driver onboarding API | ✅ | `DriverController` |
| SOS backend + guardian SMS | ✅ | `SosService` |
| Admin API endpoints | ✅ | `AdminController` |
| Flutter shared core | ✅ | `packages/mobile_core/` |
| Passenger/Driver UI flows | ✅ | Mock-driven but complete UX |
| Map + GPS integration | ✅ | `BrandedMap`, `LocationCubit`, OSM/OSRM |
| Native driver GPS | ✅ | `BackgroundLocationService.kt`, iOS Swift |
| CI pipeline | ✅ | `.github/workflows/ci.yml` |
| Docker (dev) | ✅ | `infra/docker/docker-compose.yml` |

### What is weak (must fix for production)

| Area | Status | Impact |
|------|--------|--------|
| Mobile ride flow on real API | ❌ Mock | **Critical** |
| Driver dispatch on real API | ❌ Mock | **Critical** |
| WebSocket live updates | ❌ Not running | **Critical** |
| SMS production gateway | ❌ Mock/logs | **Critical** |
| Test coverage | ❌ Minimal | High |
| Staging/production deploy | ❌ Missing | High |
| FCM push notifications | ❌ Not built | Medium |
| Digital payment (bKash/Nagad) | ❌ Not built | Medium (cash OK for P0) |
| CORS locked down | ❌ `*` open | Medium |
| Branch protection | ❌ Manual only | Medium |

---

## Part 2 — Tech Stack Reference

| Layer | Stack | Where |
|-------|-------|-------|
| Backend | Laravel 9, PHP 8+, JWT, MySQL/SQLite, Redis | `apps/api` |
| Passenger / Driver | Flutter, flutter_bloc, go_router, Dio | `apps/*-app`, `packages/mobile_core` |
| Admin | React 19, Vite, Tailwind, Leaflet | `apps/admin-panel` |
| Maps (mobile) | flutter_map, Nominatim, OSRM, CARTO tiles | `packages/mobile_core` |
| Maps (backend fare) | Google Distance Matrix (optional key) | `FareService.php` |
| Real-time (planned) | Laravel Reverb / Pusher / Socket.IO | Not deployed |
| CI | GitHub Actions | `.github/workflows/ci.yml` |
| E2E | Playwright | `test/e2e/` |

---

## Part 3 — Gap Analysis (Layer by Layer)

### GAP 1 — Mobile app: Mock vs Real API

**Default:** `MockBackend` via `packages/mobile_core/lib/core/network/backend_factory.dart`  
**Real API:** Only with `--dart-define=USE_API=true`, and even then partial.

#### Wired to Laravel ✅

| Feature | File | API |
|---------|------|-----|
| OTP request/verify | `api_backend.dart` | `POST /auth/otp/request`, `POST /auth/otp/verify` |
| Profile patch | `api_backend.dart` | `PATCH /profile` |
| SOS trigger/cancel | `api_backend.dart` | `POST /sos/trigger`, `POST /sos/{id}/cancel` |
| Share link | `api_backend.dart` | `GET /rides/{id}/share-link` |

#### Still mock ❌

| Feature | File | Mock / local behavior |
|---------|------|------------------------|
| Vehicle types + fare | `ride_cubit.dart` | `backend.types`, `estimate()` |
| Book ride | `ride_cubit.dart` | `createRide()`, `matchDemo()` |
| Trip status | `ride_cubit.dart` | `advance()` |
| Complete + rate | `ride_cubit.dart` | `confirmCash()`, `completeAndRate()` |
| Driver go online | `driver_session_cubit.dart` | `driverOnline` flag only |
| Driver request card | `driver_session_cubit.dart` | `spawnRequest()` timer |
| Accept/decline/cash | `driver_session_cubit.dart` | Local state |
| PIN verify | `driver_session_cubit.dart` | Hardcoded `4821` |
| Driver onboarding | `onboarding_screens.dart` | `setOnboarding()` local only |
| Emergency contacts | `profile_screens.dart` | `MockBackend.guardians` |
| JWT refresh | — | Not implemented |
| Driver GPS → server | — | No `POST /driver/location` |

**Fix:** Extend `packages/mobile_core/lib/core/network/api_backend.dart` to override all ride/driver methods.

---

### GAP 2 — Real-time (WebSocket)

Designed but not operational.

| Component | File | Status |
|-----------|------|--------|
| Broadcast events | `apps/api/app/Events/RideDispatched.php` | ✅ Code exists |
| Channel routes | `apps/api/routes/channels.php` | ✅ Defined |
| Socket event constants | `packages/shared-types/src/socket-events.ts` | ✅ Synced |
| BroadcastServiceProvider | `apps/api/config/app.php` | ❌ Commented out |
| Reverb / Socket.IO server | — | ❌ Not installed |
| Docker WS container | `infra/docker/docker-compose.yml` | ❌ Missing |
| Mobile socket client | `pubspec.yaml` has `socket_io_client` | ❌ Zero usage |
| Admin live updates | `useSosPolling.ts` | ⚠️ 5s HTTP poll only |

**Without this:** Driver offers and passenger “driver found” rely on fake timers.

---

### GAP 3 — Backend: built but not fully connected

| Issue | Detail |
|-------|--------|
| Queue worker | `DispatchTimeoutJob` needs `queue:work` — not in Docker |
| Scheduler | `ReleaseHeldPayoutJob` hourly — no cron in compose |
| Document upload | `uploadDocument()` expects URL, not file — no S3 |
| Google fare lock | Optional — falls back to Haversine without key |
| FCM | Token store exists; no send service |
| Payment | Cash only in `PaymentService.php` |

#### Laravel API routes (reference)

Base: `http://localhost:8000/api/v1`

**Public:** `/health`, `/public/track/{token}`, `/auth/otp/*`, `/auth/admin/login`, `/rides/vehicle-types`

**Authenticated:** `/profile`, `/rides/*`, `/driver/*`, `/sos/*`, `/admin/*`

Full list: `apps/api/routes/api.php`

---

### GAP 4 — Admin panel

| Mode | Default | Issue |
|------|---------|-------|
| Mock | `VITE_USE_MOCK !== "false"` | Demo data, hardcoded login |
| Real API | `VITE_USE_MOCK=false` | Dashboard, drivers, SOS work |

**Missing:**

- KYC pending queue UI (`GET /admin/kyc/pending` — API exists)
- WebSocket SOS (polling only)
- CI/E2E always runs mock (`playwright.config.ts`)
- Hardcoded demo credentials in `apps/admin-panel/src/api/client.ts`

---

### GAP 5 — Testing

| Layer | Count | Gap |
|-------|-------|-----|
| PHP unit/feature | ~7 tests | No auth/ride/dispatch HTTP tests |
| Flutter | ~5 tests | CI runs `flutter analyze` only, not `flutter test` |
| E2E Playwright | 1 test | Admin mock login only |
| Mobile E2E | 0 | — |
| Load / security test | 0 | — |

**Test files:**

- `apps/api/tests/Unit/FareServiceTest.php`
- `apps/api/tests/Unit/SosServiceTest.php`
- `packages/mobile_core/test/mobile_core_test.dart`
- `test/e2e/specs/admin-login.spec.ts`

---

### GAP 6 — Infrastructure & deploy

| Item | Status |
|------|--------|
| Local Docker (MySQL, Redis, API) | ✅ Dev only |
| Production Dockerfile | ⚠️ PHP 8.0 (CI uses 8.2) |
| Nginx + TLS | ❌ |
| Staging environment | ❌ |
| Deploy workflow | ❌ |
| Monitoring (Sentry, etc.) | ❌ |
| Secrets management | ❌ |
| Android release signing | ❌ TODO in Gradle |

---

### GAP 7 — External services (paid vs free)

| Service | Dev | Production |
|---------|-----|------------|
| Laravel API | Self-hosted | VPS/cloud |
| Nominatim (OSM) | Free | Rate-limited; own server at scale |
| OSRM public demo | Free | Not for heavy production |
| CARTO map tiles | Free tier | Commercial license at scale |
| Google Maps deep link | Free | No key needed |
| Google Distance Matrix | Optional | Paid (~$5/1000 req) |
| SMS gateway | Mock/log | **Paid** (~৳0.25–1/SMS) |
| FCM | — | Free (Google) |
| bKash / Nagad | — | Merchant + transaction fees |

**Minimum launch cost:** SMS gateway + VPS (~$10–20/month) + optional Google Maps key.

---

### GAP 8 — Security

| Item | Status |
|------|--------|
| JWT + Redis blacklist | ✅ |
| OTP rate limit | ✅ |
| Admin login throttle | ✅ |
| CORS | ❌ `allowed_origins: ['*']` in `config/cors.php` |
| Branch protection on `main` | ❌ Not enforced |
| OTP logged in local | ⚠️ Dev only — disable in prod |
| Mock admin passwords in client | ⚠️ Remove for prod |
| Broadcast auth | ❌ Provider disabled |

---

## Part 4 — Roadmap to Production

### Phase 0 — Foundation (Week 1–2) → 58 → 65

**Goal:** Stable dev, security basics, honest CI.

| # | Task | Where | Owner |
|---|------|-------|-------|
| 0.1 | Enable branch protection on `main` | GitHub / `scripts/setup-branch-protection.ps1` | Owner |
| 0.2 | Wire `CORS_ALLOWED_ORIGINS` | `apps/api/config/cors.php` | Backend |
| 0.3 | Align Docker PHP 8.2 with CI | `apps/api/Dockerfile` | Backend |
| 0.4 | Add `queue:work` + scheduler to Docker | `infra/docker/docker-compose.yml` | Backend |
| 0.5 | Admin `VITE_USE_MOCK=false` on staging | `apps/admin-panel/.env` | Frontend |
| 0.6 | Add `flutter test` to CI | `.github/workflows/ci.yml` | Frontend |
| 0.7 | Remove hardcoded mock admin creds from prod | `admin-panel/src/api/client.ts` | Frontend |

---

### Phase 1 — Core ride engine (Week 3–6) → 65 → 78

**Goal:** Real ride end-to-end on API — no mock for booking.

#### 1A — Passenger API wiring

| # | Task | File(s) |
|---|------|---------|
| 1.1 | `GET /rides/vehicle-types` | `api_backend.dart`, `ride_cubit.dart` |
| 1.2 | `GET /rides/estimate` | `api_backend.dart` |
| 1.3 | `POST /rides` | `api_backend.dart` |
| 1.4 | Match via poll or WS — replace `matchDemo()` | `ride_cubit.dart` |
| 1.5 | Ride status from API — replace `advance()` | `api_backend.dart` |
| 1.6 | `POST /rides/{id}/cancel` | `api_backend.dart` |
| 1.7 | `POST /rides/{id}/rate` + cash flow | `api_backend.dart` |
| 1.8 | `USE_API=true` in release builds | App build config, CI |

#### 1B — Driver API wiring

| # | Task | File(s) |
|---|------|---------|
| 1.9 | `POST /driver/availability` | `api_backend.dart`, `driver_session_cubit.dart` |
| 1.10 | `POST /driver/location` every 3–5s | `api_backend.dart`, `location_cubit.dart` |
| 1.11 | Dispatch offer via WS/poll — replace `spawnRequest()` | `driver_session_cubit.dart` |
| 1.12 | `POST /rides/{id}/accept`, `decline` | `api_backend.dart` |
| 1.13 | `arrived`, `pin/verify`, `cash-confirm` | `api_backend.dart` |
| 1.14 | Remove hardcoded PIN `4821` | `driver_session_cubit.dart` |
| 1.15 | `GET /driver/earnings` | `api_backend.dart` |

#### 1C — Driver onboarding

| # | Task | File(s) |
|---|------|---------|
| 1.16 | Wire `/driver/personal`, `/vehicle`, `/documents`, `/submit` | `onboarding_screens.dart`, `api_backend.dart` |
| 1.17 | Object storage (S3/R2) + multipart upload | `DriverController`, new `StorageService` |

**Done when:** Full ride on emulator — book → accept → PIN → cash — all persisted in Laravel DB.

---

### Phase 2 — Real-time (Week 7–8) → 78 → 85

| # | Task | Where |
|---|------|-------|
| 2.1 | Install Laravel Reverb or Soketi | `apps/api/composer.json` |
| 2.2 | Enable `BroadcastServiceProvider` | `config/app.php` |
| 2.3 | Add WS server to Docker | `infra/docker/` |
| 2.4 | Mobile socket client | New `socket_service.dart` |
| 2.5 | Listen: `RideDispatched`, location, SOS | Cubits |
| 2.6 | Admin: WebSocket SOS | Replace `useSosPolling.ts` |
| 2.7 | Passenger live driver marker | `tracking_screen.dart` |

**Done when:** Driver online → passenger books → driver gets offer within ~2s without manual refresh.

---

### Phase 3 — Production services (Week 9–10) → 85 → 88

| # | Task | Detail |
|---|------|--------|
| 3.1 | SMS gateway (SSL Wireless / GreenWeb / Twilio) | `SMS_GATEWAY_*` in `.env` |
| 3.2 | Stop logging OTP outside local | `OtpService.php` |
| 3.3 | FCM: `FcmService` + mobile `firebase_messaging` | Dispatch + SOS push |
| 3.4 | JWT refresh on 401 | `api_backend.dart` Dio interceptor |
| 3.5 | Google Maps key for fare lock | `GOOGLE_MAPS_API_KEY` |
| 3.6 | Emergency contacts API | `profile_screens.dart` |
| 3.7 | Admin KYC pending page | New admin route |

---

### Phase 4 — Quality & deploy (Week 11–12) → 88 → 90+

#### Minimum tests to add

| Area | Tests |
|------|-------|
| API Feature | Auth OTP, create ride, accept, PIN, cancel, SOS |
| API Unit | DispatchService, PaymentService, LocationService |
| Flutter | RideCubit with mocked HTTP |
| E2E | Admin real login, one ride smoke |
| Load | 50 concurrent ride requests |

#### Deploy checklist

| # | Task |
|---|------|
| 4.1 | Staging server (DigitalOcean / AWS / etc.) |
| 4.2 | Nginx + TLS (Let's Encrypt) |
| 4.3 | Production MySQL + Redis |
| 4.4 | GitHub Actions deploy workflow |
| 4.5 | Error monitoring (Sentry) |
| 4.6 | Android release signing + Play internal track |
| 4.7 | iOS TestFlight (if Mac available) |
| 4.8 | Runbook: backup, rollback, on-call |

---

### Phase 5 — Scale & payment (post-launch) → 90 → 95+

| # | Task |
|---|------|
| 5.1 | bKash / Nagad merchant integration |
| 5.2 | Own OSRM or Google Directions |
| 5.3 | Own Nominatim or Google Places |
| 5.4 | Multi-city service zones |
| 5.5 | Analytics dashboard |
| 5.6 | Security / penetration audit |

---

## Part 5 — File-by-File Fix Map

```
packages/mobile_core/
├── lib/core/network/
│   ├── api_backend.dart          ← EXTEND: rides, driver, guardians, refresh
│   ├── mock_backend.dart         ← Keep for offline demo only
│   └── backend_factory.dart      ← USE_API=true in production
├── lib/core/ride/ride_cubit.dart
├── lib/core/driver/driver_session_cubit.dart
├── lib/features/driver/onboarding_screens.dart
├── lib/features/profile/profile_screens.dart
└── lib/core/socket/ (NEW)        ← WebSocket client

apps/api/
├── config/app.php                ← Enable BroadcastServiceProvider
├── config/cors.php               ← Lock origins
├── app/Services/FcmService.php   ← NEW
├── app/Services/StorageService.php ← NEW (S3/R2)
└── routes/channels.php

apps/admin-panel/
├── src/api/client.ts
├── src/hooks/useSosSocket.ts     ← NEW
└── src/pages/KycPendingPage.tsx  ← NEW

infra/docker/
├── docker-compose.yml            ← + reverb, queue worker, scheduler
└── docker-compose.prod.yml       ← NEW

.github/workflows/
├── ci.yml                        ← + flutter test, API feature tests
└── deploy-staging.yml            ← NEW
```

---

## Part 6 — Team Responsibility Matrix

| Phase | Backend | Frontend (Mobile + Admin) | QA |
|-------|---------|---------------------------|-----|
| 0 | CORS, Docker, queue | CI flutter test, admin env | Verify CI |
| 1 | API bugs, dispatch edge cases | Wire `api_backend.dart` | Full ride manual + auto |
| 2 | Reverb, broadcast auth | Socket clients | Live dispatch test |
| 3 | SMS, FCM, S3 | FCM, guardians UI | Real SMS OTP test |
| 4 | Deploy, monitoring | Store builds | Go/no-go checklist |

---

## Part 7 — Definition of Done

### Minimum launch (85/100) — one-city beta

- [ ] Real OTP via SMS gateway
- [ ] Passenger book → driver accept → PIN → cash on Laravel DB
- [ ] Driver location POST every ~5s when online
- [ ] WebSocket dispatch (or reliable poll &lt; 3s)
- [ ] Admin live SOS + resolve
- [ ] Staging deployed with TLS
- [ ] 20+ API feature tests passing
- [ ] CORS locked, branch protection on
- [ ] No mock backend in production builds

### Full production (90+/100)

- [ ] Above + FCM push
- [ ] Above + 50+ tests, load test passed
- [ ] Above + monitoring/alerting
- [ ] Above + Play Store internal track
- [ ] Above + runbook + backup

### Industry leader (95–100) — long term

- Digital payments live
- Own map/routing infrastructure
- Multi-city operations
- 99.9% uptime SLA
- Security audit passed
- Bangladesh ride-hailing compliance

---

## Part 8 — This week priority list

| Priority | Action | Est. impact |
|----------|--------|-------------|
| **#1** | Wire `createRide`, `accept`, `advance` in `api_backend.dart` | +15 pts |
| **#2** | Wire `POST /driver/location` + `availability` | +8 pts |
| **#3** | Queue worker in Docker | +5 pts |
| **#4** | SMS gateway account + `.env` | +5 pts |
| **#5** | 10 API feature tests | +5 pts |
| **#6** | Reverb + enable broadcast | +10 pts |
| **#7** | Staging deploy script | +5 pts |

---

## Part 9 — Local dev quick reference

| Service | URL | Login |
|---------|-----|-------|
| API | http://127.0.0.1:8000 | — |
| Health | http://127.0.0.1:8000/api/v1/health | — |
| Admin | http://127.0.0.1:5173 | `admin@bdride.share` / `Admin@12345` |
| Passenger web | http://127.0.0.1:5174 | `0152170004` / OTP `123456` |
| Driver web | http://127.0.0.1:5175 | Same QA user (driver role) |

**Flutter real API:**

```bash
cd apps/passenger-app
flutter run --dart-define=USE_API=true --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

---

## Appendix A — Related docs

- [PRD.md](./PRD.md) — Product requirements
- [ARCHITECTURE.md](./ARCHITECTURE.md) — System design
- [CONTRIBUTING.md](./CONTRIBUTING.md) — Team workflow
- [BRANCH_PROTECTION.md](./BRANCH_PROTECTION.md) — GitHub rules

---

## Appendix B — One-line verdict

> **Foundation is solid and not throw-away work. Production score today is 58/100 because the client layer still runs on mocks for the core ride path. With ~12 weeks focused work on API wiring, WebSockets, SMS, tests, and deploy, an 85/100 one-city beta is realistic.**

---

*Report generated for Pothik MRM team internal use. Update this file as phases complete.*
