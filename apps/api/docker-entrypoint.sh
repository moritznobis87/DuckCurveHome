#!/bin/sh
# Start der API im Container: im Live-Modus zuerst die Datenbankmigration (idempotent), dann uvicorn.
# Unabhängig davon, ob die Plattform einen Pre-Deploy-Schritt ausführt (Railway tat es nicht zuverlässig).
set -eu
if [ "${DCH_MODE:-demo}" = "live" ] && [ "${DCH_MIGRATE_ON_START:-true}" = "true" ]; then
  echo "[entrypoint] running database migrations (alembic upgrade head)"
  alembic -c /app/apps/api/alembic.ini upgrade head
fi
# Host leer = alle Adressen beider Familien (0.0.0.0 und ::). "::" allein wäre IPv6-only, weil asyncio
# IPV6_V6ONLY setzt: Railways privates Netz (IPv6) ginge, der öffentliche Proxy (IPv4) bekäme 502.
exec uvicorn dch_api.main:app --host "" --port "${PORT:-8000}"
