# DROP THIS WHOLE DIRECTORY INTO .gitignore BEFORE FIRST COMMIT.
#
# `mysql_root_pw.txt` and `mysql_pw.txt` must exist on the deploy host before
# `docker compose -f docker-compose.prod.yml up -d` is run. Caddy will fail to
# request a TLS cert without them; the api container will fail healthchecks
# without them.
#
# Generate on the deploy host with:
#
#   mkdir -p /opt/pothik/secrets
#   chmod 700 /opt/pothik/secrets
#   openssl rand -hex 16 > /opt/pothik/secrets/mysql_root_pw.txt
#   openssl rand -hex 16 > /opt/pothik/secrets/mysql_pw.txt
#   chmod 600 /opt/pothik/secrets/*.txt
#
# Then point the compose `secrets:` block at the absolute paths on the host
# via the `--env-file` flag, or symlink them into ./secrets/.
#
# Never rotate these without also rotating the on-disk DB files. Touch
# `mysql_data` volume only with `docker compose down` (not `down -v`) to keep
# data intact across rotations.
