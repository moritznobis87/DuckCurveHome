#!/bin/sh
# Start der API im Container: im Live-Modus zuerst die Datenbankmigration (idempotent), dann uvicorn.
# Unabhängig davon, ob die Plattform einen Pre-Deploy-Schritt ausführt (Railway tat es nicht zuverlässig).
set -eu
if [ "${DCH_MODE:-demo}" = "live" ] && [ "${DCH_MIGRATE_ON_START:-true}" = "true" ]; then
  echo "[entrypoint] running database migrations (alembic upgrade head)"
  alembic -c /app/apps/api/alembic.ini upgrade head
fi
exec uvicorn dch_api.main:app --host :: --port "${PORT:-8000}"
