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
   - **api**: Root Directory leer lassen, `RAILWAY_DOCKERFILE_PATH=apps/api/Dockerfile`; Konfiguration aus
     `apps/api/railway.json` (Start `uvicorn`, Pre-Deploy `alembic upgrade head`, Healthcheck `/health`).
   - **web**: Root Directory `apps/web`; Konfiguration aus `apps/web/railway.json` (Healthcheck `/api/health`).
2. Variablen **api**:

   | Variable | Wert |
   |---|---|
   | `DATABASE_URL` | Referenz `${{Postgres.DATABASE_URL}}` |
   | `DCH_MODE` | `live` |
   | `DCH_ROLE` | `all` (API + Regler in einem Prozess; Worker-Trennung später) |
   | `DCH_BRIDGE_TOKENS` | `["<zufälliges Token, z. B. openssl rand -hex 32>"]` |
   | `DCH_API_TOKEN` | zweites zufälliges Token (nur Web ↔ API) |
   | `DCH_TIBBER_TOKEN` | Tibber-Developer-Token (optional; ohne Token keine Preisregeln) |
   | `DCH_CONFIG_FILE` | optional Pfad zu einer YAML wie `config/hems.example.yaml` (im Image mitgeliefert) |
   | `DCH_ACTUATION_ENABLED` | `false` in Phase 2 |
   | `DCH_CORS_ORIGINS` | `[]` (Web spricht serverseitig über das BFF) |

3. Variablen **web**:

   | Variable | Wert |
   |---|---|
   | `DCH_API_URL` | `http://${{api.RAILWAY_PRIVATE_DOMAIN}}:8000` |
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
