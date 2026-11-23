#!/usr/bin/env bash
# Dienst und Oberflaeche hochfahren, die Rauchprobe der Anmeldung fahren, alles wieder abraeumen.
#
# Braucht Playwright mit Chromium (keine Abhaengigkeit dieses Projekts). Alles, was hier geprueft
# wird, steht zusaetzlich in apps/api/tests/test_auth.py - nur ohne Browser. Was NUR hier
# auffaellt, ist das Zusammenspiel mit Next: siehe docs/ZUGANG.md, "Geprueft im Browser".
set -u
cd "$(dirname "$0")/.."
RAUCH="${RAUCH:-$(mktemp -d)}"
DB="$RAUCH/rauch.sqlite"
rm -f "$DB"

export DCH_MODE=live
export DATABASE_URL="sqlite+aiosqlite:///$DB"
export DCH_DB_CREATE_ALL=true
export DCH_API_TOKEN=api-geheim
export DCH_PASSKEY_RP_ID=localhost
export DCH_PASSKEY_HERKUENFTE='["http://localhost:3000"]'
export DCH_ANMELDE_URL=http://localhost:3000
export DCH_ERSTE_PERSON=moritz@example.org
export DCH_WEATHER_REFRESH_MIN=0
export DCH_PRICE_REFRESH_MIN=0
export DCH_ROLE=api
export DCH_HEAT_PUMP_ACTUATION_ENABLED=false
export DCH_GERAET_DIR=

uv run uvicorn dch_api.main:app --port 8010 --log-level warning > "$RAUCH/api.log" 2>&1 &
API=$!

export DCH_API_URL=http://localhost:8010
(cd apps/web && pnpm exec next dev --port 3000 > "$RAUCH/web.log" 2>&1 &
 echo $! > "$RAUCH/web.pid")

for i in $(seq 1 60); do
  curl -sf http://localhost:8010/health > /dev/null && break || sleep 1
done
for i in $(seq 1 90); do
  curl -sf http://localhost:3000/anmeldung > /dev/null && break || sleep 1
done
echo "--- Dienste stehen ---"
curl -s http://localhost:8010/api/v1/auth/zustand && echo

# Den Einladungslink des ersten Hausherrn aus dem Protokoll holen - so, wie ihn ein Betreiber
# beim ersten Start aus den Logs von Railway oder des Hausgeraets fischt.
EINLADUNG=$(sed -n 's/.*"link": "\([^"]*\)".*/\1/p' "$RAUCH/api.log" | tail -1)
echo "Einladung: ${EINLADUNG:-(keine gefunden)}"

BASIS=http://localhost:3000 EINLADUNG="$EINLADUNG" BILD="${BILD:-$RAUCH/anmeldung.png}" \
  node tools/rauchprobe-anmeldung.mjs
ERG=$?

kill $API 2>/dev/null
[ -f "$RAUCH/web.pid" ] && kill "$(cat "$RAUCH/web.pid")" 2>/dev/null
pkill -f "next dev --port 3000" 2>/dev/null
sleep 1
echo "--- Ende, Ergebnis $ERG ---"
tail -5 "$RAUCH/api.log"
exit $ERG
