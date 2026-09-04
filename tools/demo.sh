#!/usr/bin/env sh
# Startet API und Web lokal im Demo-Modus (ohne Docker). Zeitraffer: DCH_DEMO_SPEED=288 tools/demo.sh
set -eu
cd "$(dirname "$0")/.."
export DCH_DEMO_SPEED="${DCH_DEMO_SPEED:-1}"
uv run uvicorn dch_api.main:app --port 8000 --reload &
API_PID=$!
trap 'kill $API_PID' EXIT INT TERM
cd apps/web && DCH_API_URL=http://localhost:8000 pnpm dev
