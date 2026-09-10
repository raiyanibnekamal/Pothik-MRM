# BD Ride Share — one-command local setup (Windows)
# Usage: .\scripts\setup.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host "==> Starting Docker (MySQL + Redis)..." -ForegroundColor Cyan
docker compose -f "$Root\infra\docker\docker-compose.yml" up -d mysql redis

Write-Host "==> Installing API dependencies..." -ForegroundColor Cyan
Push-Location "$Root\apps\api"
if (-not (Test-Path .env)) {
  Copy-Item .env.example .env
  php artisan key:generate
  php artisan jwt:secret -f
}
composer install --no-interaction
Write-Host "==> Waiting for MySQL (15s)..." -ForegroundColor Cyan
Start-Sleep -Seconds 15
php artisan migrate --force
php artisan db:seed --force
Pop-Location

Write-Host "==> Installing admin (pnpm workspace)..." -ForegroundColor Cyan
Push-Location $Root
pnpm install --frozen-lockfile
Pop-Location

Write-Host "==> Flutter pub get..." -ForegroundColor Cyan
Push-Location "$Root\packages\mobile_core"
flutter pub get
Pop-Location
Push-Location "$Root\apps\passenger-app"
flutter pub get
Pop-Location
Push-Location "$Root\apps\driver-app"
flutter pub get
Pop-Location

Write-Host ""
Write-Host "BD Ride Share is ready." -ForegroundColor Green
Write-Host "  API:    http://localhost:8000  (cd apps/api; php artisan serve)"
Write-Host "  Admin:  http://localhost:5173  (pnpm dev:admin)"
Write-Host "  Health: http://localhost:8000/api/v1/health"
Write-Host "  Admin login: admin@bdride.share / Admin@12345"
Write-Host ""
Write-Host "Lock main branch (owner once): gh auth login; .\scripts\setup-branch-protection.ps1"
