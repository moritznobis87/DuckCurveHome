#!/usr/bin/env sh
# Erzeugt docs/openapi.json aus der FastAPI-App und daraus die TypeScript-Typen des Frontends.
set -eu
cd "$(dirname "$0")/.."
uv run python -c "import json; from dch_api.main import create_app; from dch_api.settings import Settings; json.dump(create_app(Settings(demo_autostart=False)).openapi(), open('docs/openapi.json','w'), indent=2, ensure_ascii=False)"
cd apps/web && pnpm gen:types
