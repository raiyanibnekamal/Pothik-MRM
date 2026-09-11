# Staging Deploy Walkthrough — Pothik MRM

Step-by-step guide to deploy the Laravel API + Reverb + Caddy stack to a VPS.
Use this **once** for first boot, then rely on [`runbook-staging.md`](./runbook-staging.md) for daily ops.

| Field | Value |
|-------|-------|
| **Repo** | [github.com/raiyanibnekamal/Pothik-MRM](https://github.com/raiyanibnekamal/Pothik-MRM) |
| **Workflow** | `.github/workflows/deploy-staging.yml` |
| **Compose** | `infra/docker/docker-compose.prod.yml` |
| **Last verified** | 2026-09-12 (CI #25 green on `main` @ `f31cefc`) |

---

## What you need before starting

| Item | Example |
|------|---------|
| VPS | Ubuntu 22.04, 2 vCPU / 2 GB RAM minimum |
| Domain | `staging.yourdomain.com` (or subdomains below) |
| DNS A-records | `api.`, `ws.`, `admin.` → VPS public IP |
| GitHub secrets | `STAGING_SSH_KEY`, `STAGING_VPS_HOST`, `STAGING_VPS_USER` |
| SSL Wireless | SID, token, masking (real OTP) |
| Sentry DSN | optional but recommended |
| Firebase JSON | optional for FCM push |

---

## Phase 1 — VPS bootstrap (one-time, ~30 min)

### 1.1 Create deploy user + Docker

```bash
ssh root@YOUR_VPS_IP

adduser deploy
usermod -aG sudo deploy
usermod -aG docker deploy   # after Docker install

# Docker CE (Ubuntu 22.04)
apt update && apt install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list
apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### 1.2 SSH key for GitHub Actions

On **your laptop**:

```powershell
ssh-keygen -t ed25519 -C "pothik-staging-deploy" -f "$env:USERPROFILE\.ssh\pothik_staging_deploy"
```

- Public key → VPS: `ssh-copy-id -i pothik_staging_deploy.pub deploy@YOUR_VPS_IP`
- Private key → GitHub → **Settings → Secrets → Actions** as `STAGING_SSH_KEY`
- Also add secrets:
  - `STAGING_VPS_HOST` = `api.yourdomain.com` (health check hostname)
  - `STAGING_VPS_USER` = `deploy`

### 1.3 Clone repo on VPS

```bash
ssh deploy@YOUR_VPS_IP
sudo mkdir -p /opt/pothik && sudo chown deploy:deploy /opt/pothik
git clone https://github.com/raiyanibnekamal/Pothik-MRM.git /opt/pothik
cd /opt/pothik
git checkout main   # or staging after you create that branch
```

### 1.4 Production env file

```bash
mkdir -p /opt/pothik/secrets && chmod 700 /opt/pothik/secrets
openssl rand -hex 16 > /opt/pothik/secrets/mysql_root_pw.txt
openssl rand -hex 16 > /opt/pothik/secrets/mysql_pw.txt
chmod 600 /opt/pothik/secrets/*.txt

# Start from API example, then tune for production
cp /opt/pothik/apps/api/.env.example /opt/pothik/.env.production
chmod 600 /opt/pothik/.env.production
nano /opt/pothik/.env.production
```

**Minimum values to set:**

```env
APP_ENV=production
APP_DEBUG=false
APP_URL=https://api.yourdomain.com

DB_CONNECTION=mysql
DB_HOST=mysql
DB_DATABASE=pothik
DB_USERNAME=pothik
DB_PASSWORD=<from secrets/mysql_pw.txt>

CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
REDIS_HOST=redis

BROADCAST_DRIVER=reverb
REVERB_APP_ID=pothik-staging
REVERB_APP_KEY=pothik-staging-key
REVERB_APP_SECRET=<openssl rand -hex 16>
REVERB_HOST=0.0.0.0
REVERB_PORT=8080
REVERB_SCHEME=https

SMS_DEFAULT_PROVIDER=ssl_wireless
SMS_PROVIDERS_SSL_WIRELESS_SID=...
SMS_PROVIDERS_SSL_WIRELESS_TOKEN=...
SMS_PROVIDERS_SSL_WIRELESS_MASKING=...

SENTRY_LARAVEL_DSN=https://...@sentry.io/...
SENTRY_ENVIRONMENT=staging

CORS_ALLOWED_ORIGINS=https://admin.yourdomain.com
```

Copy env into docker dir (compose reads relative path):

```bash
cp /opt/pothik/.env.production /opt/pothik/infra/docker/.env.production
```

Generate Laravel keys **inside the stack after first `up`** (step 1.5).

### 1.5 DNS

| Host | Points to |
|------|-----------|
| `api.yourdomain.com` | VPS IP |
| `ws.yourdomain.com` | VPS IP |
| `admin.yourdomain.com` | VPS IP (Caddy serves admin static later) |

Wait for propagation (`dig api.yourdomain.com +short`).

### 1.6 First manual stack boot

```bash
cd /opt/pothik/infra/docker
docker compose -f docker-compose.prod.yml --env-file .env.production up -d

# One-time keys
docker compose -f docker-compose.prod.yml exec api php artisan key:generate --force
docker compose -f docker-compose.prod.yml exec api php artisan jwt:secret -f
docker compose -f docker-compose.prod.yml exec api php artisan migrate --force
docker compose -f docker-compose.prod.yml exec api php artisan db:seed --force   # optional QA data
```

### 1.7 Smoke checks (manual)

```bash
curl -fsS https://api.yourdomain.com/api/v1/health
# expect: {"success":true,"data":{"status":"ok","db":"up","redis":"up",...}}

curl -sk -o /dev/null -w '%{http_code}\n' https://ws.yourdomain.com/
# expect: 426 (Upgrade Required) = Reverb reachable via Caddy
```

---

## Phase 2 — GitHub automated deploy

### 2.1 Create `staging` branch

```bash
git checkout -b staging
git push -u origin staging
```

Pushes to `staging` trigger `deploy-staging.yml` automatically.

### 2.2 What the workflow does

1. `rsync` `infra/` + `apps/api/` to `/opt/pothik/` on VPS
2. `docker compose build` api, worker, scheduler, reverb
3. `docker compose up -d` those services
4. `php artisan migrate --force`
5. Curl `/api/v1/health` (200) + Reverb probe (426)

Monitor: **GitHub → Actions → deploy-staging**

### 2.3 Redeploy a specific commit

```bash
gh workflow run deploy-staging.yml --ref f31cefc
```

Or merge `main` → `staging`:

```bash
git checkout staging
git merge main
git push origin staging
```

---

## Phase 3 — Admin + mobile against staging

### 3.1 Admin panel

Build locally or in CI with staging API:

```bash
cd apps/admin-panel
# .env.production.local or build-time vars:
# VITE_API_URL=https://api.yourdomain.com/api/v1
# VITE_WS_URL=wss://ws.yourdomain.com
# VITE_USE_MOCK=false
pnpm build
```

Serve `dist/` via Caddy `admin.` block (see `infra/docker/Caddyfile`) or upload to static host.

### 3.2 Flutter apps

```bash
flutter run --dart-define=USE_API=true \
  --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
```

Passenger + driver on two emulators/devices → full ride flow.

---

## Phase 4 — Verification checklist

| # | Check | Pass criteria |
|---|-------|---------------|
| 1 | Health | `GET /api/v1/health` → 200, `db=up`, `redis=up` |
| 2 | OTP | Real phone receives SMS via SSL Wireless |
| 3 | Ride | Passenger books → driver accepts → PIN → cash |
| 4 | SOS | Admin dashboard shows alert within 5s |
| 5 | CI | `main` push → 4/4 jobs green (API, Admin, Flutter, E2E) |
| 6 | Sentry | Trigger test 500 → event in Sentry project |

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Health 503 `redis: down` | `docker compose restart redis` |
| Reverb 502 | Check `REVERB_*` in `.env.production`, restart `reverb` |
| Caddy no cert | DNS not propagated; check `docker compose logs caddy` |
| Deploy SSH fail | Re-add `STAGING_SSH_KEY`, verify `deploy` in `docker` group |
| Migrate error | Fix migration locally, push, redeploy |

Full ops reference: [`docs/runbook-staging.md`](./runbook-staging.md)

---

## Quick command reference

```bash
# Logs
cd /opt/pothik/infra/docker
docker compose -f docker-compose.prod.yml logs -f api worker reverb caddy

# Rollback to known-good SHA
gh workflow run deploy-staging.yml --ref <good-sha>

# DB backup
docker compose -f docker-compose.prod.yml exec mysql \
  mysqldump -u pothik -p pothik > pothik-$(date -I).sql
```
