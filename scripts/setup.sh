#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Starting Docker (MySQL + Redis)..."
docker compose -f "$ROOT/infra/docker/docker-compose.yml" up -d mysql redis

echo "==> Installing API dependencies..."
cd "$ROOT/apps/api"
composer install --no-interaction

if [ ! -f .env ]; then
  cp .env.example .env
  php artisan key:generate
  php artisan jwt:secret -f
fi

echo "==> Waiting for MySQL..."
sleep 10

echo "==> Running migrations + seed..."
php artisan migrate --force
php artisan db:seed --force

echo ""
echo "BD Ride Share backend is ready."
echo "  API:    http://localhost:8000"
echo "  Health: http://localhost:8000/api/v1/health"
echo ""
echo "Run API: cd apps/api && php artisan serve"
echo "Run admin: pnpm dev:admin  (from repo root)"
echo "Admin login: admin@bdride.share / Admin@12345"
echo "Lock main (owner): gh auth login && ./scripts/setup-branch-protection.ps1"
