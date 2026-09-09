# BD Ride Share — Product Requirements (P0 focus)

| Product | BD Ride Share / বিডি রাইড শেয়ার |
|---|---|
| Version | 3.0 (repo snapshot 2026-09-09) |
| Stack note | Backend implemented as **Laravel + MySQL** — see [adr/002-laravel-mysql-stack.md](adr/002-laravel-mysql-stack.md) |

This file is the **product source of truth** for P0 launch. Full feature catalog (P0–P4) was authored 2026-09-08; sections below lock what **must ship** for first city.

---

## Team

| Role | Owns |
|---|---|
| Frontend | Flutter passenger/driver, React admin, `mobile_core`, UI/i18n |
| Backend | `apps/api`, infra, shared-types/constants, jobs, admin APIs |
| QA | E2E, device matrix, go/no-go |

---

## P0 launch scope

### Passenger

- Phone OTP (+880), profile setup, BN/EN
- Home map, places search, Bike + Car estimate (Haversine)
- Book → finding driver → driver sheet → live track → PIN → complete → cash → rate
- SOS hold 3s + 5s cancel; share trip link
- History list

### Driver

- OTP, onboarding (personal + vehicle + docs), 24h grace
- Online/offline, 15s request card, accept/decline
- Navigate, arrived, PIN verify, complete, cash confirm
- Earnings today, commission debt warning
- SOS while online

### Admin

- Email + password login (throttle)
- Dashboard KPIs, live map snapshot, drivers + KYC approve/reject
- Users list + block, rides explorer, SOS war room, config (commission, debt cap, maintenance)
- Holding transactions view

### Platform

- Dispatch cascade 15s × 5 / 90s max
- Fare: estimate Haversine; lock 1× Matrix at PIN
- Cash confirm idempotent + 20% commission debt + 24h holding
- SOS server pipeline with dedup + SMS + admin alert
- Health: db + redis

---

## Out of scope (this product)

Food, parcel, grocery, hotels, freight — separate PRD if ever.

---

## Definition of done (P0 feature)

1. BE API + tests on staging  
2. FE screens + BN/EN + empty/error/loading  
3. QA E2E or signed manual script  
4. No open SEV-1/2 on that path  

---

## Key business rules

- Login OTP: 6 digits; ride PIN: 4 digits  
- Access JWT 15m, refresh 7d  
- Passenger SOS only `in_progress`; driver SOS when online  
- Cancel free 2 min after match; no-show after 5 min wait  
- Never trust client fare amount  
- Bangla error messages — see `packages/shared-constants`  

---

## Phases after P0

| Phase | Examples |
|---|---|
| P1 | bKash/Nagad, masked call, chat, RideCheck, KYC encryption |
| P2 | CNG, scheduled rides, surge, promo |
| P3 | Connect, bidding, RBAC, intercity |
| P4 | Family, dark mode, voice book |

Full ID catalog (P-ACC-*, D-ON-*, A-*, S1–S38, PL-*) remains valid for roadmap planning; implement by phase, not all at once.

---

## Related

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)
