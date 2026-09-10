# ADR 002 — Laravel + MySQL instead of NestJS + PostgreSQL

| Status | Accepted |
|---|---|
| Date | 2026-09-09 |

## Context

Original docs (PRD v3.0, ARCHITECTURE v1.0) specified NestJS + Prisma + PostgreSQL + PostGIS.

The backend owner chose **Laravel 9 + MySQL + Redis** for faster delivery with familiar tooling.

## Decision

- `apps/api` is Laravel, not NestJS.
- MySQL replaces PostgreSQL; geo uses Haversine + Redis (no PostGIS in P0).
- Migrations are Laravel migrations, not Prisma.
- Jobs use Laravel queue, not BullMQ.
- WebSockets: Laravel broadcasting scaffold; Reverb/Socket.IO adapter is P1 before multi-replica.

## Consequences

- PRD decision **D2** is overridden for this repo.
- Admin + mobile clients use `/api/v1` envelope — unchanged.
- `packages/shared-types` and `shared-constants` remain the cross-team contract.
- Original ADR 001 (NestJS) is superseded by this ADR for **Pothik MRM**.

## Unchanged

- Monorepo layout, JWT auth model, SOS pipeline order, fare rules, P0 feature IDs in PRD.
