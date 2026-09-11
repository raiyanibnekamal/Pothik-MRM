# Pothik MRM — Staging Runbook (S6)

This runbook covers the staging deploy documented in `docs/report.md` S6. It
assumes a single $10 VPS running Ubuntu 22.04 LTS in the Dhaka region.

> **Audience:** on-call engineer with shell + docker access. No app
> knowledge required.

---

## 1 — Bootstrap (one-time)

```bash
# 1.1 — VM init
ssh deploy@staging.pothik.example.com
sudo apt update && sudo apt install -y ca-certificates curl gnupg jq
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker deploy
exit

# 1.2 — Repo checkout
ssh deploy@staging.pothik.example.com "git clone https://github.com/pothik/bd-ride-share.git /opt/pothik"

# 1.3 — Secrets (NEVER commit these)
ssh deploy@staging.pothik.example.com
mkdir -p /opt/pothik/secrets && chmod 700 /opt/pothik/secrets
openssl rand -hex 16 > /opt/pothik/secrets/mysql_root_pw.txt
openssl rand -hex 16 > /opt/pothik/secrets/mysql_pw.txt
chmod 600 /opt/pothik/secrets/*.txt
cp /opt/pothik/infra/docker/.env.production.example /opt/pothik/.env.production
chmod 600 /opt/pothik/.env.production

# 1.4 — DNS A-records
# api.pothik.example.com → <vps-ip>
# ws.pothik.example.com  → <vps-ip>
# admin.pothik.example.com → <vps-ip>  (placeholder until S7)
```

## 2 — Daily deploy

`push to staging` → GH Actions runs `ci.yml` → on success, `deploy-staging.yml`.

If you need to redeploy a pinned sha manually:

```bash
gh workflow run deploy-staging.yml --ref <sha-or-tag>
```

## 3 — Smoke checks (run after every deploy)

```bash
# 3.1 — API
curl -fsS https://api.pothik.example.com/api/v1/health
# Expect: {"success":true,"data":{"status":"ok","db":"up","redis":"up",...}}

# 3.2 — Reverb WS
curl -sk -o /dev/null -w '%{http_code}\n' https://ws.pothik.example.com/
# Expect: 426 (Upgrade Required) — proves Caddy → Reverb path works

# 3.3 — One full ride on the mobile app (manual)
# passenger: login → enter pickup → request ride → receive driver dispatch
# driver: login → accept ride → enter PIN → confirm cash
```

## 4 — Common operations

### Tail logs

```bash
cd /opt/pothik/infra/docker
docker compose -f docker-compose.prod.yml --env-file /opt/pothik/.env.production logs -f api
docker compose -f docker-compose.prod.yml --env-file /opt/pothik/.env.production logs -f worker
docker compose -f docker-compose.prod.yml --env-file /opt/pothik/.env.production logs -f caddy
```

### Run a one-off artisan command

```bash
cd /opt/pothik
docker compose -f infra/docker/docker-compose.prod.yml --env-file /opt/pothik/.env.production exec api php artisan <command>
```

### Roll back

The `reverb` container is the most likely source of regressions. Force a
restart:

```bash
cd /opt/pothik/infra/docker
docker compose -f docker-compose.prod.yml --env-file /opt/pothik/.env.production restart reverb worker
```

For a code roll-back, redeploy a known-good sha:

```bash
gh workflow run deploy-staging.yml --ref <known-good-sha>
```

### Database backup (manual)

```bash
docker compose -f /opt/pothik/infra/docker/docker-compose.prod.yml \
    --env-file /opt/pothik/.env.production exec mysql \
    mysqldump -u pothik -p pothik > pothik-$(date -I).sql
```

## 5 — Monitoring checklist

| Signal            | Where to look                                      |
|-------------------|----------------------------------------------------|
| API 5xx           | Sentry project `pothik-api`                        |
| Reverb disconnects | `docker logs reverb` + `caddy logs`                |
| MySQL connection pressure | Sentry breadcrumb + mysql CPU   |
| Disk full on `/var` | `df -h` — caddy data grows with cert cache       |
| OTP flood         | Laravel log → `auth.otp.rate-limit`                 |

## 6 — Alerting

Sentry triggers Slack `#pothik-ops` on:
- New error fingerprint not seen in 7 days
- `5xx` rate above 0.5% over 10 minutes
- Any unhandled exception in `App\Exceptions\Handler`

Pager rotation lives in Linear (ops team). Initial on-call: ops@pothik.example.

## 7 — Failure modes we have seen (and fixes)

| Symptom                                         | Fix                                                                 |
|-------------------------------------------------|---------------------------------------------------------------------|
| `/api/v1/health` returns 503 with `redis: down` | `docker compose restart redis` then check `redis-cli ping`          |
| Reverb returns 502 from Caddy                   | Missing `REVERB_*` env — re-pull secrets, rebuild `reverb`          |
| MySQL container won't start                     | Stale `mysql_data` after partial upgrade — `down -v` and restore    |
| `artisan migrate --force` errors                | New migration not forward-only — revert commit, fix, redeploy       |
| Sentry silent                                   | `SENTRY_LARAVEL_DSN` empty in `.env.production`                     |

---

Last verified: 2026-09-11 (S6.1 + S6.2 + S6.3 in place).
