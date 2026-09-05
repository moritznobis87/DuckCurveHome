# Deployment (Phase 2): Railway + Home-Assistant-Add-on

```
Home Assistant OS (Haus)                          Railway
┌──────────────────────────────┐   ausgehend WSS   ┌─────────────────────────────────────┐
│ Add-on „Duck Curve Home      │ ────────────────► │ api  (FastAPI, /bridge/ws, SSE)     │
│ Bridge“ liest Entitäten,     │                   │ web  (Next.js, BFF, Kiosk-Session)  │
│ schaltet über HA-Dienste     │                   │ postgres (Railway)                  │
└──────────────────────────────┘                   └─────────────────────────────────────┘
```

## 1. Railway

1. Neues Projekt, GitHub-Repository verbinden, **drei** Services anlegen:
   - **postgres**: Railway-PostgreSQL-Template.
   - **api**: Root Directory **leer lassen**. Die Konfiguration liegt in `railway.json` im Repo-Root
     (Dockerfile-Build `apps/api/Dockerfile`, Start `uvicorn`, Pre-Deploy `alembic upgrade head`, Healthcheck
     `/health`). Wird sie nicht übernommen, in den Service-Einstellungen unter „Config-as-code“ den Pfad
     `railway.json` eintragen oder den Builder manuell auf „Dockerfile“ mit Pfad `apps/api/Dockerfile` stellen.
     Erscheint im Build „Railpack … No start command detected“, wurde die Datei nicht gelesen.
   - **web**: Root Directory `apps/web`; Konfiguration aus `apps/web/railway.json` (Healthcheck `/api/health`).
2. Variablen **api**:

   | Variable | Wert |
   |---|---|
   | `DATABASE_URL` | Referenz `${{Postgres.DATABASE_URL}}` |
   | `PORT` | `8000` (fest setzen – sonst vergibt Railway einen zufälligen Port und die Web-App findet die API im privaten Netz nicht) |
   | `DCH_MODE` | `live` |
   | `DCH_ROLE` | `all` (API + Regler in einem Prozess; Worker-Trennung später) |
   | `DCH_BRIDGE_TOKENS` | `<zufälliges Token, z. B. openssl rand -hex 32>` (einzelnes Token; mehrere kommagetrennt oder als JSON-Liste) |
   | `DCH_API_TOKEN` | zweites zufälliges Token (nur Web ↔ API) |
   | `DCH_TIBBER_TOKEN` | Tibber-Developer-Token (optional; ohne Token keine Preisregeln) |
   | `DCH_CONFIG_FILE` | optional Pfad zu einer YAML wie `config/hems.example.yaml` (im Image mitgeliefert) |
   | `DCH_ACTUATION_ENABLED` | `false` in Phase 2 |
   | `DCH_MIGRATE_ON_START` | `true` (Standard): Alembic-Migration läuft beim Containerstart, bevor die API hochfährt |
   | `DCH_CORS_ORIGINS` | `[]` (Web spricht serverseitig über das BFF) |

3. Variablen **web**:

   | Variable | Wert |
   |---|---|
   | `DCH_API_URL` | `http://${{api.RAILWAY_PRIVATE_DOMAIN}}:${{api.PORT}}` (privates Netz, IPv6; `api` = Name des API-Services) |
   | `DCH_API_TOKEN` | gleicher Wert wie in api |
   | `DCH_SESSION_SECRET` | ≥ 32 zufällige Zeichen (signiert das Kiosk-Cookie) |
   | `DCH_KIOSK_TOKEN` | Pairing-Token für neue Geräte |

4. Öffentliche Domains: web (z. B. `home.duckcurve.de`) und api (z. B. `api-home.duckcurve.de`, nur für
   `/health` und `/bridge/ws` genutzt; alle `/api/v1/*`-Aufrufe verlangen `DCH_API_TOKEN`).
5. **iPad koppeln:** einmalig `https://home.duckcurve.de/pair?token=<DCH_KIOSK_TOKEN>&name=iPad-Flur` öffnen.
   Das Gerät bleibt 180 Tage angemeldet. Danach die Seite als Web-App zum Home-Bildschirm hinzufügen und
   in Guided Access mit deaktivierter Auto-Sperre betreiben.

Migrationen laufen vor jedem Deploy (`preDeployCommand`). Nur additive Migrationen automatisch; destruktive
Schritte manuell (Plan 23.4).

### Fehlersuche: Dashboard zeigt „Verbindung unterbrochen“

Das Banner bedeutet: Die Web-App bekommt keinen SSE-Stream von der API. Die fehlende Bridge ist **nicht**
die Ursache – ohne Bridge liefert die API trotzdem Snapshots (dann ist der Punkt im Kopf grün „live“, die
Werte bleiben Striche, weil noch keine Messwerte vorliegen). Prüfreihenfolge:

1. `https://<web-domain>/api/health` → erwartet `{"status":"ok","api":200}`.
   - `"api":"unreachable"`: `DCH_API_URL` falsch, Port stimmt nicht oder die API lauscht nur auf IPv4.
     Railways privates Netz ist **reines IPv6**, der öffentliche Proxy spricht IPv4 – die API bindet deshalb beide
     Familien (uvicorn `--host ""`; `::` allein wäre IPv6-only und liefert öffentlich 502 „Application failed to respond“).
     Im API-Service `PORT=8000` setzen (bzw. `${{api.PORT}}` referenzieren), Service-Name in der Referenz
     prüfen (aufgelöster Wert in Railway sichtbar, z. B. `http://api.railway.internal:8000`), beide Services
     neu deployen.
   - `"api":401`/`403`: kommt hier nicht vor (`/health` ist offen) – dann ist ein Proxy dazwischen.
2. `https://<api-domain>/health` → erwartet `"mode":"live"`, `"status":"ok"`.
3. Im Browser die Konsole/Netzwerk-Tab öffnen: `GET /api/dch/live/stream`.
   - Antwort `401` mit `unauthorized`: `DCH_API_TOKEN` in web und api ist nicht identisch (oder in web leer).
   - Antwort `503` mit `upstream_unreachable`: wie Punkt 1.
   - Antwort `200`, aber der Stream endet sofort: Logs des API-Services ansehen (`uvicorn`-Zeilen zu `/api/v1/live/stream`).
4. Logs des Web-Services: `fetch failed` oder `ECONNREFUSED` deutet auf Port/Domain, `ENOTFOUND` auf einen
   falschen Service-Namen in `${{api.RAILWAY_PRIVATE_DOMAIN}}`.

## 2. Home-Assistant-Add-on

1. Einstellungen → Add-ons → Add-on Store → ⋮ → Repositories → `https://github.com/moritznobis87/DuckCurveHome`.
2. „Duck Curve Home Bridge“ installieren (Home Assistant baut das Image lokal aus dem Repository).
3. `/config/duckcurve/entities.yaml` anlegen – Vorlage `addons/duckcurve_bridge/entities.example.yaml`.
   Entity-IDs findest du unter Entwicklerwerkzeuge → Zustände.
4. Optionen: `api_ws_url = wss://api-home.duckcurve.de/bridge/ws`, `api_token = <DCH_BRIDGE_TOKENS-Eintrag>`.
5. Starten, Protokoll prüfen („uplink connected“). In Home Assistant erscheint `sensor.duckcurve_bridge_heartbeat`.
6. Wächter-Automation aus `addons/duckcurve_bridge/DOCS.md` anlegen; Auto-Off-Timer in den Shelly-Relais der
   Wärmepumpen-Kontakte setzen (K1 30 min, K2 20 min).

## 3. Lokale Entwicklung im Live-Modus ohne Postgres

```bash
DCH_MODE=live DATABASE_URL=sqlite+aiosqlite:///./dev.sqlite DCH_DB_CREATE_ALL=true \
DCH_BRIDGE_TOKENS='["dev"]' uv run uvicorn dch_api.main:app --port 8000
# Bridge lokal gegen ein echtes HA (Long-Lived Token) und die lokale API:
DCH_BRIDGE_HA_WS_URL=ws://homeassistant.local:8123/api/websocket SUPERVISOR_TOKEN=<LLAT> \
DCH_BRIDGE_API_WS_URL=ws://localhost:8000/bridge/ws DCH_BRIDGE_API_TOKEN=dev \
DCH_BRIDGE_ENTITIES_FILE=./entities.yaml DCH_BRIDGE_OUTBOX_PATH=./outbox.sqlite uv run dch-bridge
```

## 4. Rückfallebenen (Kurzfassung, Details HEMS_CONTROL.md / Plan Abschnitt 11)

E0 Shelly-Auto-Off im Relais · E1 HA-Wächter-Automation auf den Bridge-Heartbeat · E2 Bridge setzt Kontakte
nach 180 s ohne Cloud zurück · E3 Guards und TTL im Regler. Ohne Duck Curve Home läuft die Wärmepumpe in
eigener Regelung weiter.
