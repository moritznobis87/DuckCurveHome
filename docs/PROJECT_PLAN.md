# Duck Curve Home – Projektplan (Phase 0)

**Stand:** 4. September 2026 · **Status:** Analyse und Architekturvorschlag, noch keine Implementierung
**Repository:** `moritznobis87/DuckCurveHome` · **Branch:** `claude/duck-curve-home-project-9vfe9h`

Duck Curve Home ist ein Home-Energy-Management-System (HEMS) für ein einzelnes Wohnhaus in Geilenkirchen. Es
visualisiert Energieflüsse und Zustände, bedient ausgewählte Aktoren und optimiert in späteren Phasen die
Wärmepumpe als flexible thermische Last. Der primäre Bildschirm ist ein wandmontiertes iPad im Querformat.

**Revision 2 (4. September 2026):** Duck Curve Home ist ein **eigenständiges System**. Es hängt weder von Home
Assistant noch von der bestehenden InfluxDB ab. Ein lokaler Agent („Bridge“) spricht direkt mit den Geräten (Shelly,
MyEnergi, SolarEdge) und den Cloud-Diensten (Tibber, Wetter); alle Daten liegen in einer eigenen PostgreSQL-Datenbank.
Home Assistant kann parallel weiterlaufen, wird aber weder gelesen noch geschrieben. Da damit alle Datenquellen und
Aktoren im Haus liegen, stellt Abschnitt 15 zwei Hosting-Profile gegenüber – **lokaler Mini-Rechner (empfohlen)**
oder **Railway mit Bridge** – und bittet um eine Entscheidung vor Phase 2.

**Stand Phase 1 (4. September 2026):** Demo-Modus umgesetzt (siehe README, ARCHITECTURE.md, HEMS_CONTROL.md).
**Entscheidung für Phase 2 (ADR-0001):** Railway für App und Datenbank, **Home Assistant als Geräteschicht**,
Bridge als Home-Assistant-Add-on (kein Nabu Casa, HA OS). Damit gelten für die Geräteanbindung wieder die
Home-Assistant-Abschnitte der Revision 1 (WebSocket-API, Entity-Mapping, HA-Dienste), während die direkten
Shelly-/MyEnergi-/SolarEdge-Adapter aus Abschnitt 8 als spätere Ergänzung offen bleiben. Abschnitt 15 Profil B
beschreibt das Railway-Deployment; die Bridge läuft als Add-on statt als Docker-Compose.

Dieses Dokument ist das Ergebnis von **Phase 0** und beantwortet die im Auftrag genannten Punkte in der
angegebenen Reihenfolge. Es ist bewusst eine Entscheidungsgrundlage, kein Lastenheft: Wo Alternativen
bestehen, wird die Wahl begründet und die verworfene Option benannt. Abschnitt 25 sammelt die offenen Fragen,
die vor oder während Phase 1/2 mit dem Betreiber zu klären sind.

## Inhalt

1. Ist-Zustand der drei Repositories
2. Wiederverwendbare Patterns und bewusste Abweichungen
3. Vorgeschlagene Gesamtarchitektur
4. Datenfluss
5. Technologieentscheidung
6. Komponentenstruktur (Projektstruktur)
7. Datenmodell und Vorzeichenkonvention
8. Integrationsstrategie Geräte (Shelly, MyEnergi, SolarEdge, Tibber)
9. Strategie für Live-Daten
10. Wärmepumpen-Steuerungsarchitektur
11. Safety-Konzept
12. Optimierungs-Roadmap
13. UI-/UX-Konzept
14. Empfohlene Projektphasen
15. Hosting-Zielarchitektur: lokal (empfohlen) oder Railway
16. PostgreSQL-Datenmodell
17. Sichere Verbindung Railway ↔ Haus
18. Weather Forecast Provider
19. PV Forecast Provider
20. Heat Demand Model
21. Forecast Persistence
22. 15-Minuten-Planungsmodell
23. CI/CD-Konzept
24. Übernahme des Duck-Curve-Designsystems
25. Offene technische Fragen
26. Glossar und Konventionen

---

## 1. Ist-Zustand der drei Repositories

### 1.1 DuckCurveHome

Leeres Repository: keine Commits, keine Dateien, Branch `claude/duck-curve-home-project-9vfe9h` ohne Historie. Es
gibt also keine Altlasten, aber auch keine Vorgaben (kein Lizenztext, keine `.gitignore`, kein CI). Alles in diesem
Plan ist Neubau.

### 1.2 Duckcurve_Website (`moritznobis87/Duckcurve_Website`)

**Zweck:** öffentliche Marketing-Website `www.duckcurve.de` für „Duck Curve – Energy Investment Analytics“ (die
valyze-Anwendung läuft unter `app.duckcurve.de`).

**Technik:**

| Aspekt | Befund |
|---|---|
| Framework | `vinext 1.0.0-beta.2` (Vite-basierte Next.js-kompatible Laufzeit, App Router), React 19.2, TypeScript 5.9 strict |
| Styling | **eine** handgeschriebene `app/globals.css` (≈87 KB, ~150 Klassen), CSS-Custom-Properties als Tokens. Tailwind 4 ist als PostCSS-Plugin installiert, aber praktisch nicht verwendet (keine Utility-Klassen im Markup) |
| Schriften | IBM Plex Sans 400/600 und IBM Plex Mono 400 als lokale OTF in `public/brand/`, per `@font-face` |
| Komponenten | Server Components ohne eigene Client-Komponenten (bewusst: „Seite funktioniert ohne JavaScript“); mobile Navigation als `<details>` |
| Visuals | alle Diagramme als reines SVG/CSS in `app/visuals.tsx` – keine Chart-Bibliothek |
| Hosting | Node-Worker (`worker/kern.ts`, `worker/node.ts`) für Railway; alternativ Cloudflare-Worker (`worker/index.ts`). Sitzung, Einwilligungsbanner, Messung, Rate-Limit (`worker/schutz.ts`) und Sicherheits-Header laufen im Worker, nicht in Next |
| Daten | keine eigene Datenbank; Kontaktanfragen und Messung gehen an die valyze-API (`worker/api.ts`, `WEBSITE_SCHLUESSEL`) |
| Tests | `tests/rendered-html.test.mjs` (node:test) prüft das **gerenderte** HTML des Workers, nicht Quelltext |
| CI/CD | **keine** `.github/workflows`; Deployment über Railway-GitHub-Integration (Build `vinext build && node bau-worker.mjs`, Start `node server.mjs`) |
| Sprache | Kommentare und Bezeichner deutsch, Klassen teilweise englisch (`hero`, `button-amber`), teilweise deutsch (`stat-kacheln`) |

**Design-Befund (Kurzfassung, Details in Abschnitt 24):** Dark-Hero auf `--deep`/`--petrol`-Verlauf mit feinem
58-px-Raster, Glas-Header (blur 18 px), sehr kleine Radien (2/3/6 px), 1-px-Linien mit geringer Deckkraft statt
Schatten für Struktur, Mono-Kicker in Versalien mit 0,13 em Laufweite, riesige SemiBold-Headlines mit negativer
Laufweite, Solar Amber sparsam als Akzent (Punkte, 3-px-Balken, Primärbutton), Dunkelkarten `#123544`, in Charts
Amber = Hauptserie, Mist = Referenz, gestrichelt (7 7) = Vergleichsserie.

### 1.3 valyze (`moritznobis87/valyze`)

**Zweck:** PV-/Wind-/Speicher-Wirtschaftlichkeitsplattform (Österreich EAG, deutsche Ausschreibung, Speicherdispatch).

**Technik (Kurzfassung der Detailanalyse):**

| Aspekt | Befund |
|---|---|
| Struktur | drei strikt geschichtete Teile: `engine/` (reine Domäne, Pydantic + pandas, kein HTTP), `valyze/` (FastAPI, Auth, Ablage, DB, Client), `frontend/` (Next.js 15, spricht nur HTTP). Schichtgrenze wird per Test erzwungen (`tests/test_valyze_api.py::TestSchichtgrenze`) |
| Backend | FastAPI ≥ 0.115, Pydantic ≥ 2.10, SQLAlchemy 2, Alembic (8 Revisionen, `YYYYMMDD_<rev>_<slug>`), psycopg 3, Argon2id, App-Factory `anwendung()`, Auth als Router-Dependency, ein Fehler-Envelope `{"fehler": {code, meldung, details}}`, hybrides Schema (relationale Spalten + JSONB-Payload), eigenes Schema `valyze` mit RLS |
| Settings | handgeschriebenes `valyze/settings.py` (~520 Zeilen `os.environ.get`), kein pydantic-settings |
| Frontend | Next.js 15 App Router, React 19, TS strict, **kein Tailwind**, eine `globals.css` (2094 Zeilen) mit `:root`-Tokens (`--akzent #f2a900`, `--brand #0f2e3d`, `--mist`, `--wash`, `--positiv`, `--negativ`), IBM Plex via `next/font/local`, BFF-Proxy `app/api/valyze/[...pfad]/route.ts` mit iron-session-Cookie, Server Components + kleine Client-Inseln, kein globaler State-Manager |
| Charts | **ECharts 6** über `echarts/core` (tree-shaken) in genau einem Wrapper `frontend/src/lib/diagramm.tsx`; Serienfarben sind aus den Markenfarben **abgeleitet**, weil die rohen Markentöne die Palettenprüfung (Lightness, Chroma, CVD, Kontrast) nicht bestehen |
| Zeitreihen | stündlich (8760/8784), CSV bzw. `csv.gz`, pandas, LP-Dispatch (HiGHS via scipy) für Speicher über ein volles Jahr |
| Tests | 47 pytest-Module, xdist, per-Worker-Datenverzeichnis, separater Test-DB-Schema-Name, `--langsam`-Schalter; Frontend vitest + Testing Library |
| CI/CD | nur zwei Workflows: `frontend.yml` (tsc → vitest → build) und `datenbank.yml` (manueller `workflow_dispatch` mit Bestätigungswort, `environment: production`, `alembic check`). **Kein Python-Lint/Test-Workflow**, obwohl im README behauptet |
| Deployment | Railway, zwei Services aus einem Repo: API per `Procfile` (`uvicorn valyze.api.main:app`), Frontend per `Dockerfile.web` vom Repo-Root; keine `railway.json`; Migrationen **nie automatisch** |
| i18n | vier Sprachen in YAML (`locales/`), eine Quelle für Python und TypeScript, Paritätstest |
| Sprache | deutsche Bezeichner in Zugriffs- und UI-Schicht, englische in älteren Engine-Teilen, englische API-Pfade mit deutschen Fehlercodes |
| Doku | ausgezeichnete „Warum“-Docstrings mit gemessenen Zahlen; `docs/fachmodell`, `docs/rechenmodell`, `docs/architektur`; Test, der Doku-Zahlen gegen die Engine prüft |

---

## 2. Wiederverwendbare Patterns und bewusste Abweichungen

### 2.1 Was aus valyze übernommen wird

| Pattern | Quelle | Verwendung in Duck Curve Home |
|---|---|---|
| Strikte Schichtung Domäne ↔ Zugriff ↔ UI, per Test erzwungen | `engine/` vs. `valyze/`, `TestSchichtgrenze` | `packages/hems-core` ist I/O-frei; ein Import-Linter-Test (`import-linter` oder eigener Test) verbietet Importe aus `integrations/`/`infrastructure/` in den Kern |
| Pydantic-Modelle als Wire-Format, OpenAPI → TS-Typen | `valyze/api/schemas.py`, `docs/openapi.json` | `openapi-typescript` generiert `apps/web/src/lib/api/types.ts` im Build; keine Hand-Duplikate |
| App-Factory `create_app()` | `valyze/api/main.py::anwendung` | gleiches Muster, Tests bekommen saubere Instanzen und eigene Settings |
| Auth als Router-Dependency | `include_router(..., dependencies=[Depends(angemeldet)])` | alle `/api/v1/*`-Router geschützt, öffentlich nur `/health` und `/auth/*` |
| Ein Fehler-Envelope mit maschinenlesbarem Code | `valyze/api/errors.py` | `{"error": {"code": "heat_pump_locked_by_override", "message": …, "details": …}}` + typisierter `ApiError` im Frontend |
| Storage-`Protocol` + Test-Set zweimal ausführen | `valyze/ablage/protokoll.py`, `test_valyze_ablage.py` | Repositories als Protokolle; Demo-Modus (In-Memory) und Postgres laufen durch dieselben Tests |
| Hybrides Schema: Spalten für Abfragen, JSONB für Payload | `valyze/db/modelle.py` | Konfiguration, Forecast-Punkte, Entscheidungs-Kontext als JSONB; Zeit, Typ, Gerät als Spalten |
| Alembic liest `DATABASE_URL` aus den App-Settings, `compare_type=True`, `alembic check` in CI | `valyze/db/migrationen/env.py`, `datenbank.yml` | identisch; zusätzlich Up/Down-Test auf leerer DB in CI |
| BFF-Proxy mit HttpOnly-Session-Cookie, `Sec-Fetch-Site`-Prüfung bei Mutationen | `frontend/src/app/api/valyze/[...pfad]/route.ts` | Kiosk-Token bleibt serverseitig; das iPad hält nur ein Session-Cookie |
| Ein Chart-Wrapper mit Thema, Resize, Dispose | `frontend/src/lib/diagramm.tsx` | `components/charts/EChart.tsx`, aber mit `setOption` statt Re-Init (siehe 2.3) |
| Abgeleitete, geprüfte Datenfarben statt roher Markenfarben | Kommentar in `diagramm.tsx` | Dashboard-Palette wird auf dunklem Grund neu geprüft (Abschnitt 24) |
| Test-Isolation: Test-DB niemals `DATABASE_URL`, eigener Schema-Name pro Worker | `tests/conftest.py` | `DCH_TEST_DATABASE_URL`, Schema `dch_test_<worker>` |
| Manuell bestätigte DB-Aktionen mit `environment: production` | `datenbank.yml` | für destruktive Migrationen/Backfills; reguläre Migrationen laufen automatisiert, aber nur additiv (Abschnitt 23) |
| „Warum“-Dokumentation mit Messwerten | Modul-Docstrings | als ADRs in `docs/decisions/` statt in 80-Zeilen-Docstrings |

### 2.2 Was aus Duckcurve_Website übernommen wird

| Element | Übernahme |
|---|---|
| Farb-Tokens `--petrol --deep --amber --amber-soft --mist --paper --cloud --ink --line` | 1:1 als Basis-Tokens, ergänzt um Dashboard-Semantik |
| IBM Plex Sans 400/600, IBM Plex Mono 400 (lokale OTF) | gleiche Dateien, gleiche Gewichte; Mono für alle Zahlen |
| Kicker-Stil (Mono, Versalien, 0,13 em) | für Kartentitel und Achsenbeschriftungen, auf 12–13 px vergrößert |
| Radien 2/3/6 px, 1-px-Linien mit 0,10–0,17 Alpha, Glas-Header | identisch |
| Dunkelkarte `#123544` auf `--deep`, Hover `#173f50` | Kartenhierarchie des Dashboards |
| Chart-Grammatik: Grid 0,09, Achse 0,20, Achsentext 0,42, Linien 3,5 px rund, Amber = Hauptserie, Mist = Referenz, 7-7-Strich = Vergleich/Prognose, Labels als `rx=3`-Rechteck mit Amber-Mono-Text | als ECharts-Theme umgesetzt |
| Bewegungssprache: 0,18 s `ease`, `translateY(-2px)` Hover, `prefers-reduced-motion` respektiert | identisch; Flussanimation wird unter `reduce` statisch |
| 58-px-Rasterhintergrund mit Maske | dezent im Dashboard-Hintergrund |
| Markenzeichen `duck-curve-mark.svg`, Header-Logo | im Dashboard-Header (Mark + „Home“) |
| Rendered-HTML-Test-Idee | Playwright-Smoke-Test gegen das gebaute Dashboard im Demo-Modus |

### 2.3 Bewusste Abweichungen

| Thema | valyze / Website | Duck Curve Home | Grund |
|---|---|---|---|
| Bezeichner-Sprache | deutsch (gemischt) | **Code, API, DB, Reason-Codes englisch; UI-Texte, Doku, Commit-Messages deutsch** | Der Auftrag definiert englische Feldnamen (`pv_power_kw`); Bibliotheken, Optimierer und Typ-Generatoren sind englisch; Mischformen wie `Projektsteckbrief.aus()` vermeiden |
| Settings | handgeschrieben | `pydantic-settings` mit `DCH_`-Präfix, YAML für Anlagen-/Regler-Konfiguration | Validierung, Typen, testbare Instanz |
| Styling | eine globale CSS-Datei | `tokens.css` (Custom Properties) + Tailwind 4 `@theme`, das die Tokens referenziert, + kleine komponentennahe CSS-Module für Animationen | Tokens bleiben eine Quelle; Utilities halten die Komponentendateien lesbar; kein 2000-Zeilen-Stylesheet |
| Framework | vinext (Website) | Standard-Next.js 15 (wie valyze) | vinext ist Beta; für ein 24/7-Kiosk-Gerät zählt Stabilität |
| Chart-Wrapper | Re-Init bei jeder Option | `setOption(option, {replaceMerge})` auf lebender Instanz | Live-Daten jede Sekunde; Re-Init killt Animation und kostet CPU auf dem iPad |
| CI | Python ohne CI | ruff + mypy + pytest + Alembic-Check bei jedem Push | Regler-Code ohne CI ist im Heizungsumfeld nicht vertretbar |
| Migrationen | nur manuell | automatisch im Deploy für additive Migrationen; destruktive nur manuell mit Gate | ein Betreiber, viele Deploys; Verfahren in 23.4 |
| Docstrings | sehr lang | kurz; Entscheidungen in `docs/decisions/ADR-xxx.md` | Navigierbarkeit |
| Zeitauflösung | stündlich | 15 Minuten als Planungsraster, 1 s–10 s Live | Tibber-Viertelstundenpreise, Regler-Dynamik |
| Zustandsverwaltung Frontend | keine | ein kleiner Store (Zustand) für den Live-State + SSE-Client | Dutzende Komponenten hängen an demselben Live-Snapshot |

## 3. Vorgeschlagene Gesamtarchitektur

### 3.1 Leitgedanken

1. **Eigenständig.** Duck Curve Home hat eigene Geräteintegrationen, eine eigene Datenbank und eine eigene
   Steuerlogik. Home Assistant und InfluxDB sind keine Abhängigkeiten – weder für Daten noch für Schaltbefehle. Sie
   dürfen weiterlaufen; Abschnitt 8.7 beschreibt, worauf beim Parallelbetrieb zu achten ist.
2. **Das Haus bleibt ohne Duck Curve Home funktionsfähig.** MyEnergi-HEMS und die Wärmepumpen-Regelung arbeiten wie
   heute weiter. Duck Curve Home greift nur über die zwei dafür vorgesehenen potenzialfreien Kontakte ein. Jeder
   Eingriff ist zeitlich begrenzt (TTL) und fällt ohne Bestätigung von selbst zurück.
3. **Verbindung nur von innen nach außen.** Die Bridge im Haus baut eine ausgehende, authentifizierte WSS-Verbindung
   zu Railway auf. Kein Gerät im Haus wird ins Internet gestellt.
4. **Hexagonale Architektur.** Domänenmodell, Regler und Planer sind reines Python ohne I/O. Integrationen (Shelly,
   MyEnergi, SolarEdge, Tibber, Open-Meteo, PV-Forecast) sind austauschbare Adapter hinter Protokollen. Der Regler
   kann später unverändert vom Cloud-Backend auf die Bridge (Edge) wandern.
5. **Erklärbarkeit ist ein Datenmodell, kein UI-Text.** Jede Entscheidung wird als strukturierter Datensatz mit
   Reason-Codes, Eingangsgrößen und Gültigkeit persistiert. Das Dashboard rendert daraus „Was / Warum / Was kommt“.
6. **Stufenweise Intelligenz.** Regelbasiert → prognosebewusst → rollierende Optimierung; jede Stufe ist ein
   `Planner`-Adapter hinter demselben Interface, der Regler-Kern und die Safety-Schicht bleiben gleich.

### 3.2 Systemübersicht

```
┌──────────────────────────────── Haus (LAN, Geilenkirchen) ────────────────────────────────┐
│                                                                                            │
│  Shelly-Relais (K1, K2, Kaffee, Lichter)   Shelly 3EM (WP)   Shelly-Temperatur ×4 (Puffer) │
│        │ MQTT (lokal, push) + RPC/HTTP (Befehle, Status)                                    │
│        ▼                                                                                    │
│  ┌── Mosquitto (lokaler MQTT-Broker, nur LAN) ──┐                                           │
│  │                                              │                                           │
│  │   ┌──────────────────────────────────────────▼──────────────────────────────┐            │
│  │   │  duckcurve-bridge (Python, Docker-Compose auf einem Mini-Rechner)       │            │
│  │   │  • integrations/shelly     MQTT-Abonnent, RPC-Client, Auto-Off-Timer     │            │
│  │   │  • integrations/myenergi   Cloud-API (Zappi, Libbi, Harvi) alle 10–15 s  │◄── Cloud   │
│  │   │  • integrations/solaredge  Modbus TCP (SunSpec) lokal, 1–2 s             │◄── Inverter│
│  │   │  • Normalisierung, Vorzeichen, Qualität, lokaler Ringpuffer (SQLite)     │            │
│  │   │  • Kommando-Ausführung mit TTL + Ack, lokaler Wächterprozess (Guardian)  │            │
│  │   │  • Status-Seite http://bridge.local:8080 (nur LAN)                       │            │
│  │   └──────────────────────────────┬──────────────────────────────────────────┘            │
│  └─────────────────────────────────┼─────────────────────────────────────────────────────── │
└────────────────────────────────────┼───────────────────────────────────────────────────────┘
                                     │ ausgehend WSS + Device-Token
                                     ▼
┌──────────────────────────────────── Railway Project ───────────────────────────────────────┐
│                                                                                            │
│  ┌───────────────┐   SSE (Live-State)   ┌──────────────────────────────────────────────┐   │
│  │  web (Next.js)│◄─────────────────────│  api (FastAPI)                               │   │
│  │  iPad-Kiosk   │──── REST (Befehle) ─►│  • /bridge/ws (Ingest)  • /live/stream (SSE) │   │
│  └───────────────┘                      │  • REST /api/v1/*       • Auth (Kiosk-Token) │   │
│                                         │  • LiveState (in-memory) • Persist-Batcher   │   │
│                                         └───────────────┬──────────────────────────────┘   │
│                                                         │ SQLAlchemy async                 │
│  ┌──────────────────────────────────┐                   ▼                                  │
│  │  worker (gleiches Python-Image)  │◄──────────► PostgreSQL (Railway) – EINZIGE Datenbank │
│  │  • Control-Loop (10 s Takt)      │              Rohmesswerte (partitioniert, gestuft),   │
│  │  • Forecast-Jobs (Wetter/PV/Preis)│             Aggregate, Konfiguration, Entscheidungen,│
│  │  • Planner (alle 15 min)         │              Forecasts, Pläne, Events                 │
│  │  • Aggregation/Retention/Backup  │                                                      │
│  └──────────────┬───────────────────┘                                                      │
│                 │ ausgehend HTTPS / WSS                                                     │
└─────────────────┼──────────────────────────────────────────────────────────────────────────┘
                  ▼
   Tibber GraphQL (+ Pulse-Live, falls vorhanden) · Open-Meteo · Forecast.Solar/Solcast (optional)
```

Das Bild zeigt **Profil B (Railway + Bridge)**. Im empfohlenen **Profil A (lokal)** laufen die Railway-Kästen
ebenfalls auf dem Mini-Rechner im Haus, die Bridge wird zum Modul des Workers, und der WSS-Uplink entfällt; der
Zugriff von außen erfolgt über einen Cloudflare Tunnel (Abschnitt 15).

**Warum ein lokaler MQTT-Broker?** Shelly-Geräte aller Generationen können ihre Zustände per MQTT pushen; das ist
der einzige Weg, batteriebetriebene Sensoren (schlafen, wachen periodisch auf) und Relais-Statusänderungen
verzögerungsfrei zu erhalten, ohne zu pollen. Mosquitto läuft im selben Docker-Compose wie die Bridge, nur im LAN,
mit Benutzer/Passwort. Für Befehle nutzt die Bridge die Shelly-RPC-/HTTP-Schnittstelle direkt (synchron, mit
Antwort), MQTT dient dem Lesen.

**Warum Control-Loop in der Cloud und nicht auf der Bridge?** Deployment, Beobachtbarkeit, Tests und Konfiguration
sind in der Cloud einfacher; Latenz spielt bei einem 10-Sekunden-Takt keine Rolle. Bei Internet-Ausfall findet keine
Optimierung statt – akzeptabel, weil die Wärmepumpe dann in ihre eigene Regelung zurückfällt (Safety-Konzept). Der
Regler-Kern ist I/O-frei und kann in einer späteren Phase auf der Bridge laufen, wenn Offline-Optimierung gewünscht
wird.

**Warum Worker und API getrennt?** Control-Loop und Planer müssen genau einmal laufen. Der Worker ist ein Service
mit genau einer Replika und sichert das per PostgreSQL-Advisory-Lock. In Phase 1 laufen API und Worker aus demselben
Docker-Image mit anderem Startkommando; lokal kann beides in einem Prozess laufen (`DCH_ROLE=all`).

### 3.3 Schichten im Backend

```
apps/api, apps/worker (FastAPI / Prozess-Hülle)
   │
   ▼
application/           Use-Cases: ingest_frame, switch_actuator, set_mode, run_control_tick, run_planner
   │
   ▼
packages/hems-core/    Domäne (reines Python, keine I/O):
   domain/             EnergySnapshot, BufferState, HeatPumpState, Decision, Plan, Forecast …
   control/            Guards (Hysterese, Mindestzeiten, TTL), HeatPumpController, ModeMachine
   thermal/            Thermal-SOC, Pufferspeichermodell, Gebäudemodell, Wärmebedarf
   planning/           RuleBasedPlanner, ForecastAwarePlanner, (später) RollingHorizonOptimizer
   forecasting/        Provider-Protokolle, Kalibrierung
   │
   ▼
integrations/          Cloud-Adapter: tibber, open_meteo, forecast_solar, pvlib_forecast, bridge_protocol, demo
infrastructure/        Postgres-Repositories (SQLAlchemy), SSE-Broker, Settings, Logging, Scheduler

apps/bridge/integrations/   Geräte-Adapter: shelly (MQTT + RPC), myenergi (Cloud-API), solaredge (Modbus TCP)
```

Die Domänenschicht kennt keine Shelly-Topics und keine MyEnergi-Feldnamen. Adapter übersetzen in Domänenobjekte; die
Zuordnung (z. B. `shellyplus1-abc/status/switch:0 → hp_release_contact`) ist Konfiguration.

## 4. Datenfluss

### 4.1 Live-Pfad (Ziel: 1–5 s Ende-zu-Ende)

```
Shelly (MQTT push ≈ 1 s) · SolarEdge (Modbus 1–2 s) · MyEnergi (Cloud-Poll 10–15 s)
  → Bridge: Normalisierung (Einheit, Vorzeichen, Qualität, observed_at je Quelle)
  → Bridge: Ringpuffer (SQLite, 7 Tage Rohwerte) + Telemetrie-Frame alle 1 s (nur Änderungen) → WSS → api
  → api: LiveState.apply(frame) → EnergySnapshot (vollständig, mit Qualitätsflags, Bilanzprüfung)
  → api: SSE-Broker fan-out (max. 1 Frame/s pro Client, Koaleszierung)
  → web: Store aktualisiert → Energiefluss/Tank/KPIs rendern
  → api: Persist-Batcher schreibt alle 5 s in measurements_raw (Postgres, COPY-Batch)
  → worker: liest live_state-Spiegel aus Postgres (alle 2 s); entscheidet; schreibt control_decisions;
    stellt actuator_commands ein → api (LISTEN/NOTIFY) → Bridge → Shelly RPC → Ack zurück
```

Die API besitzt die Bridge-Verbindung, der Worker besitzt die Regelung; Kopplung ausschließlich über Postgres.

### 4.2 Historischer Pfad

```
measurements_raw (14 Tage)  ─► stündlicher Job ─► measurements_10s (180 Tage) ─► measurements_1min (3 Jahre)
                                                 ─► measurements_15min (unbegrenzt) ─► energy_daily
24h-Chart: measurements_1min (heute/gestern) + Live-Fortschreibung + Forecast-Reihen + Plan-Fenster
Nachlieferung: Bridge sendet nach Verbindungsabbruch den Ringpuffer ab letzter bestätigter Sequenz;
               länger als 1 h Rückstand → verdichtet auf 10-s-Mittel (Rohwerte bleiben 7 Tage auf der Bridge)
```

Es gibt keine zweite Zeitreihendatenbank. Alles, was das Dashboard und die Modelle brauchen, liegt in PostgreSQL.
Optional (nicht Teil der Architektur): ein einmaliger CSV-Import historischer Daten aus dem bisherigen System für
die Modellkalibrierung (`tools/import-history`), der danach nicht mehr benötigt wird.

### 4.3 Steuerpfad

```
worker: ControlTick (10 s)
  Inputs: EnergySnapshot, BufferState, HeatPumpState, Preise, Plan, Modus, Override, Forecasts
  → Planner-Empfehlung → HeatPumpController (Zustandsmaschine)
  → Guards (Mindestlaufzeit, Mindestauszeit, Hysterese, max. Sperrdauer, Frostschutz, Sensorqualität)
  → Decision {k1_release, k2_block, reason_codes[], explanation, valid_until}
  → nur bei Änderung/Refresh: ActuatorCommand {target, state, ttl_s, decision_id} → api → Bridge
  → Bridge: Shelly RPC `Switch.Set {on, toggle_after: ttl_s}` → liest Status zurück → Ack/Fail → Event
```

### 4.4 Planungspfad

```
worker: alle 15 min + bei neuen Preisen/Forecasts/Modus-Wechsel
  → Forecast-Refresh (Wetter 1 h, PV 1 h, Preise 13:00–15:00 für morgen, danach stündlich)
  → HeatDemandModel (48 h, 15 min) → BufferModel-Simulation
  → Planner erzeugt Plan[96] mit reason je Intervall → plans/plan_intervals
  → Dashboard: Plan-Fenster im 24h-Chart, Intelligence Card „Nächste Aktion“
```

## 5. Technologieentscheidung

Die Präferenz aus dem Auftrag (Next.js/React/TypeScript, FastAPI, Postgres) wurde gegen die beiden Bestandsrepos
geprüft. Ergebnis: Sie passt, und sie ist mit valyze bereits erprobt. Die wichtigsten Einzelentscheidungen:

| Bereich | Entscheidung | Alternativen und Begründung |
|---|---|---|
| Frontend-Framework | **Next.js 15 (App Router), React 19, TypeScript 5.9 `strict`** | vinext (Website) ist Beta; SvelteKit/Vite-SPA hätten kein BFF-Muster wie valyze. Next liefert BFF-Route für Session-Cookie, `next/font/local`, statisches Export-Fallback. Das Dashboard selbst ist eine Client-Insel; SSR liefert nur Rahmen + Erstzustand |
| Paketmanager Web | **pnpm** | schneller, strikter als npm; Lockfile deterministisch |
| Styling | **CSS-Tokens (`tokens.css`) + Tailwind 4 (`@theme` bindet die Tokens) + CSS-Module für Animationen** | reines CSS (Website/valyze) skaliert schlecht; Tailwind allein würde die Markenwerte in `tailwind.config` verstecken. Mit `@theme` bleibt `tokens.css` die einzige Quelle |
| Zeitreihen-Charts | **Apache ECharts 6** über `echarts/core` (Canvas) | Plotly: 3+ MB, träge auf iPad, Stil schwer an die Marke anzupassen. Recharts: SVG-DOM mit 4 Serien × 1440 Punkten pro Sekunde neu gerendert wird auf dem iPad zäh; zweite Y-Achse und `markArea` (geplante Laufzeiten) sind mühsam. uPlot: schnellste Option, aber Tooltip/Touch/Doppelachse selbst zu bauen. ECharts hat Doppelachse, `markLine` (Jetzt-Linie), `markArea` (Planfenster), `dataZoom`, Touch-Tooltip, negative Werte, `setOption`-Merge für Live-Updates, und valyze hat bereits einen Wrapper und ein Farbkonzept |
| Energiefluss-Grafik | **eigene SVG-Komponente** (kein Diagramm-Framework) | Sankey-Bibliotheken (d3-sankey, ECharts Sankey) sind für Bilanzen gedacht, nicht für ein festes Knotenbild mit Richtungspfeilen; die Website beweist, dass SVG + CSS die Markenästhetik am besten trifft |
| Pufferspeicher-Grafik | **eigene SVG-Komponente** mit `linearGradient`-Stops aus den vier Temperaturen | trivial in SVG, in Charting-Bibliotheken unnatürlich |
| Frontend-State | **Zustand** (kleiner Store) + eigener SSE-Client mit Reconnect | Redux zu schwer; React Query passt nicht zu Push-Daten; Context allein re-rendert zu breit |
| Backend | **Python 3.12, FastAPI ≥ 0.115, Pydantic 2, pydantic-settings, SQLAlchemy 2 async + asyncpg, Alembic, httpx, structlog** | Python wegen Optimierung (pvlib, scipy/HiGHS, später OR-Tools/Pyomo). Node-Backend wäre für Live-Daten gleichwertig, aber die Optimierung müsste dann als zweiter Dienst existieren |
| Paketmanager Python | **uv** (Workspace mit `packages/hems-core`, `apps/api`, `apps/bridge`) | pip/requirements (valyze) hat keine Lockfile; Poetry langsamer; uv-Workspaces erlauben, dass API und Bridge denselben Kern teilen |
| Scheduler/Control-Loop | **asyncio-Tasks im Worker** mit Postgres-Advisory-Lock; APScheduler nur für Cron-artige Jobs (Forecast-Refresh, Retention) | Celery/RQ brauchen Redis – unnötig für eine Handvoll Jobs; der 10-s-Regeltakt gehört in einen langlebigen Prozess, nicht in eine Job-Queue |
| Live-Transport Dashboard | **Server-Sent Events** (HTTP, `EventSource`) | WebSocket wäre bidirektional, aber das Dashboard sendet Befehle selten (REST reicht). `EventSource` bringt Auto-Reconnect und `Last-Event-ID` mit, läuft problemlos durch Railway-Proxy und iPad-Safari, keine Ping/Pong-Logik nötig |
| Transport Bridge ↔ Cloud | **ausgehende WebSocket-Verbindung (WSS)** mit JSON-Frames, Device-Token, Sequenznummern und Ack | MQTT-Broker (z. B. Mosquitto auf Railway) wäre Standard im IoT, aber ein zusätzlicher Dienst mit eigener Auth; Tailscale/VPN würde HA erreichbar machen, aber die Cloud muss dann in das Hausnetz „hinein“ – umgekehrt zur gewünschten Richtung. Das Transport-Protokoll ist gekapselt (`BridgeTransport`), MQTT kann später ergänzt werden |
| Datenbank | **PostgreSQL 16 als einzige Datenbank** (lokal im Compose oder Railway-Managed, Abschnitt 15) – Rohmesswerte gestuft (14 Tage roh, 180 Tage 10 s, 3 Jahre 1 min, 15 min unbegrenzt), native Partitionierung, Retention-Job | keine zweite Zeitreihen-DB (kein InfluxDB, kein VictoriaMetrics): ein System, ein Backup, ein Abfragepfad. TimescaleDB ist auf Railways Standard-Postgres nicht verfügbar; natives Partitioning reicht für ~15 Sensoren. Bewertung Timescale in 16.5 |
| Geräte-Integration Shelly | **MQTT (lokaler Mosquitto) zum Lesen, Shelly-RPC/HTTP zum Schalten** (`aiomqtt`, `httpx`) | Polling per HTTP verpasst Zustände und weckt keine Batteriesensoren; CoIoT (Gen1) ist proprietär und in Gen2 entfallen; Shelly-Cloud-API ist nicht lokal |
| Geräte-Integration MyEnergi | **MyEnergi-Cloud-API** (Digest-Auth mit Hub-Seriennummer + API-Key, `cgi-jstatus-*`), Poll 10–15 s | es gibt keine offizielle lokale API des Hubs; die Cloud-API liefert Zappi, Libbi und Harvi in einem Aufruf |
| Geräte-Integration SolarEdge | **Modbus TCP (SunSpec) am Wechselrichter**, 1–2 s, `pymodbus` | die SolarEdge-Monitoring-Cloud-API ist auf 300 Aufrufe/Tag und 15-min-Auflösung begrenzt – untauglich für Live; sie dient nur der täglichen Energie-Abstimmung. PV-Leistung ist zusätzlich über den MyEnergi-CT (`gen`) verfügbar |
| Strompreise / Zählerlive | **Tibber GraphQL** (Preise) und optional **Tibber-Live-Subscription** (Pulse) aus dem Worker | – |
| Auth | **Single-Tenant**: Admin-Passwort (Argon2id) + Kiosk-Pairing-Code → langlebiges Geräte-Session-Cookie (HttpOnly) über Next-BFF; Bridge mit eigenem Device-Token (rotierbar) | kein OAuth-Provider nötig; valyze-Muster (iron-session, Bearer bleibt serverseitig) wird übernommen |
| Haus-Rechner | **Docker Compose** auf einem kleinen Always-on-Rechner im LAN (Raspberry Pi 5 / Intel NUC): Profil A das ganze System, Profil B nur bridge + mosquitto + guardian; Auto-Restart, Hardware-Watchdog | Betrieb als HA-Add-on entfällt bewusst (Eigenständigkeit); Details Abschnitt 15 |
| Konfiguration | **`.env` für Secrets/Umgebung (pydantic-settings), YAML für Anlage/Haus/Regler (versioniert in Postgres, Datei als Seed)** | TOML ist gleichwertig; YAML deckt sich mit HA-Konventionen und dem Auftragsbeispiel |
| Logging | **structlog → JSON** (Railway-Logs), Korrelation über `decision_id`/`command_id` | – |
| Tests Backend | **pytest, pytest-asyncio, hypothesis (Guards), freezegun/time-machine (Mindestzeiten)**, Testcontainers-freie Postgres über GitHub-Service-Container | – |
| Tests Frontend | **vitest + Testing Library**, **Playwright** Smoke-Test des Demo-Dashboards (iPad-Viewport 1180×820) | – |
| Lint/Format | ruff (Lint + Format), mypy `--strict` für `hems-core`, ESLint 9 + `typescript-eslint`, Prettier | valyze nutzt ruff mit `E501` ignoriert; wir halten 100 Zeichen ohne Ausnahme |
| Container | ein Python-Dockerfile (Multi-Stage, uv), ein Node-Dockerfile (Multi-Stage, pnpm, `output: standalone`) | valyze baut Frontend vom Repo-Root; wir bauen jeden Service aus seinem Verzeichnis mit Railway „Root Directory“ |

## 6. Komponentenstruktur (Projektstruktur)

Monorepo mit klaren Grenzen; jede App ist einzeln deploybar.

```
DuckCurveHome/
├── README.md
├── ARCHITECTURE.md                  # Kurzfassung von Abschnitt 3/4, verlinkt ADRs
├── CONFIGURATION.md                 # alle Env-Variablen und YAML-Schlüssel
├── HEMS_CONTROL.md                  # Regler, Zustandsmaschine, Safety, Reason-Codes
├── .env.example
├── docker-compose.yml               # lokal: postgres + api + worker + web (+ bridge im Demo-Modus)
├── pyproject.toml                   # uv-Workspace (members: packages/*, apps/api, apps/bridge)
├── uv.lock
├── pnpm-workspace.yaml              # apps/web (+ später packages/ui)
├── .github/workflows/
│   ├── web.yml                      # lint, typecheck, vitest, build, playwright-smoke
│   ├── python.yml                   # ruff, mypy, pytest (core, api, bridge) mit Postgres-Service
│   ├── migrations.yml               # alembic upgrade head auf leerer DB, alembic check, downgrade -1
│   └── docker.yml                   # Image-Builds als Smoke (kein Push)
├── docs/
│   ├── PROJECT_PLAN.md              # dieses Dokument
│   ├── decisions/ADR-0001-….md      # Architekturentscheidungen
│   ├── design-system.md             # Tokens, Komponenten, Chart-Theme
│   └── openapi.json                 # generiert, Quelle der TS-Typen
│
├── packages/
│   └── hems-core/                   # reines Python, mypy --strict, keine I/O
│       └── src/hems_core/
│           ├── domain/              # EnergySnapshot, Quality, BufferState, HeatPumpState, Decision, Plan …
│           ├── control/             # guards.py, heat_pump_controller.py, modes.py, reasons.py
│           ├── thermal/             # buffer_soc.py, buffer_model.py, building_model.py, heat_demand.py
│           ├── planning/            # planner.py (Protocol), rule_based.py, forecast_aware.py, horizon.py
│           ├── forecasting/         # protocols.py (WeatherProvider, PvForecastProvider …), calibration.py
│           ├── balance/             # energy_balance.py (Bilanzierung, Plausibilität)
│           └── simulation/          # demo_house.py (Simulationsmodell für Demo-Modus)
│
├── apps/
│   ├── api/                         # FastAPI + Worker (ein Image, zwei Startkommandos)
│   │   ├── Dockerfile
│   │   ├── railway.json
│   │   ├── alembic.ini
│   │   └── src/dch_api/
│   │       ├── main.py              # create_app()
│   │       ├── settings.py          # pydantic-settings (DCH_*)
│   │       ├── worker.py            # Control-Loop, Planner, Forecast-Jobs, Leader-Lock
│   │       ├── routers/             # health, auth, live (SSE), history, control, config, plan, events, bridge (WS)
│   │       ├── application/         # Use-Cases
│   │       ├── integrations/        # tibber/, open_meteo/, forecast_solar/, pvlib_forecast/, bridge_protocol/, demo/
│   │       ├── infrastructure/      # db/ (models, repositories, migrations/), sse_broker.py, live_state.py, logging.py
│   │       └── schemas/             # API-Schemas, wo sie von Domänenmodellen abweichen
│   │
│   ├── bridge/                      # lokaler Agent im Haus (eigenständig, ohne Home Assistant)
│   │   ├── Dockerfile
│   │   ├── docker-compose.yml       # bridge + mosquitto + guardian
│   │   ├── mosquitto/               # mosquitto.conf, ACL-Vorlage
│   │   ├── devices.example.yaml     # Geräte-Mapping (IPs, Topics, Seriennummern → Domänenschlüssel)
│   │   └── src/dch_bridge/
│   │       ├── main.py
│   │       ├── settings.py          # DCH_BRIDGE_*
│   │       ├── integrations/
│   │       │   ├── shelly/          # mqtt_listener.py, rpc_client.py (Gen2/Gen3), gen1_client.py, models.py
│   │       │   ├── myenergi/        # client.py (Digest-Auth, Director-Redirect), parser.py, models.py
│   │       │   ├── solaredge/       # modbus_client.py (SunSpec), registers.py
│   │       │   └── protocol.py      # DeviceSource-Protocol (read stream), Actuator-Protocol (set/verify)
│   │       ├── normalize/           # units.py, signs.py, quality.py, mapping.py
│   │       ├── store/               # ring_buffer.py (SQLite WAL, 7 Tage), outbox.py (Sequenzen, Acks)
│   │       ├── uplink/              # ws_uplink.py, protocol.py, backoff.py
│   │       ├── actuators/           # executor.py (TTL via toggle_after, Ack), refresh.py
│   │       ├── guardian.py          # eigener Prozess: Wächter, setzt Kontakte bei Ausfall zurück
│   │       ├── status_page.py       # http://bridge:8080 (nur LAN)
│   │       └── discovery.py         # scannt Shelly (mDNS/MQTT-Announce), listet MyEnergi-Geräte, Modbus-Test
│   │
│   └── web/                         # Next.js
│       ├── Dockerfile
│       ├── railway.json
│       ├── public/brand/            # Mark, Logo, IBM Plex OTF
│       └── src/
│           ├── app/
│           │   ├── layout.tsx       # Fonts, Tokens, Theme
│           │   ├── page.tsx         # Dashboard (Kiosk)
│           │   ├── settings/        # Konfiguration, Overrides, Diagnose (Phase 3+)
│           │   ├── history/         # Zeitraum-Ansichten (Phase 2+)
│           │   ├── pair/            # Kiosk-Pairing
│           │   └── api/dch/[...path]/route.ts   # BFF-Proxy (Session-Cookie → Bearer)
│           ├── styles/tokens.css    # Design-Tokens (einzige Quelle)
│           ├── styles/theme.css     # Tailwind @theme, das die Tokens referenziert
│           ├── components/
│           │   ├── layout/          # DashboardShell, Header, StatusBar
│           │   ├── energy-flow/     # EnergyFlow.tsx, FlowEdge.tsx, FlowNode.tsx, layout.ts
│           │   ├── buffer/          # BufferTank.tsx, thermalGradient.ts
│           │   ├── charts/          # EChart.tsx (Wrapper), DayChart.tsx, theme.ts
│           │   ├── intelligence/    # IntelligenceCard.tsx (Jetzt / Entscheidung / Warum / Ausblick)
│           │   ├── controls/        # ControlTile.tsx, ModeSegment.tsx, OverrideBadge.tsx
│           │   └── ui/              # Card, Kpi, Kicker, Pill, Dot, Skeleton
│           ├── lib/
│           │   ├── api/             # client.ts, types.ts (generiert), errors.ts
│           │   ├── live/            # sseClient.ts, liveStore.ts (Zustand), staleness.ts
│           │   ├── format/          # kw.ts, price.ts, time.ts (de-DE, Komma)
│           │   └── kiosk/           # wakeGuard.ts, reloadPolicy.ts
│           └── test/
└── tools/
    ├── gen-types.sh                 # openapi.json → types.ts
    └── demo.sh                      # startet alles im Demo-Modus
```

**Abgrenzung der Pakete:** `hems-core` darf nur Standardbibliothek, Pydantic und numerische Bibliotheken
importieren. `apps/api` und `apps/bridge` hängen von `hems-core` ab, nie umgekehrt. `apps/web` kennt nur die
OpenAPI-Typen. Ein Test in `hems-core` prüft die Importgrenze.

## 7. Datenmodell und Vorzeichenkonvention

### 7.1 Vorzeichenkonvention (verbindlich im gesamten System)

**Grundregel: Aus Sicht des Hauses. Was ins Haus fließt, ist positiv. Erzeuger sind positiv. Verbraucher sind
positiv. Speicher: Entladen (liefert ans Haus) positiv, Laden negativ.** Genau eine Ausnahme gibt es nicht – auch
das Netz folgt der Regel: Bezug (fließt ins Haus) positiv, Einspeisung negativ.

| Feld | Einheit | > 0 bedeutet | < 0 bedeutet |
|---|---|---|---|
| `pv_power_kw` | kW | Erzeugung | nie (Nachtverbrauch des Wechselrichters wird auf 0 geklemmt und als `pv_standby_kw` separat geführt, falls messbar) |
| `grid_power_kw` | kW | **Netzbezug** | **Netzeinspeisung** |
| `battery_power_kw` | kW | **Entladen** (Batterie → Haus) | **Laden** (Haus → Batterie) |
| `battery_soc` | 0–1 | – | – |
| `house_power_kw` | kW | Gesamtverbrauch des Hauses **inkl.** Wärmepumpe und Wallbox | nie |
| `base_load_kw` | kW | Verbrauch **ohne** Wärmepumpe und Wallbox (abgeleitet) | nie (negativ = Messabweichung, wird geklemmt und geflaggt) |
| `heat_pump_power_kw` | kW | Verbrauch Wärmepumpe (Shelly 3EM, Summe der drei Phasen) | nie |
| `ev_power_kw` | kW | Ladeleistung Zappi | nie in v1 (V2H nicht vorhanden) |
| `electricity_price_ct_kwh` | ct/kWh | Bezugspreis (Tibber, inkl. Steuern, Netzentgelte, Abgaben, laut Tibber `total`) | negativer Preis (wird korrekt negativ geführt) |
| `feed_in_tariff_ct_kwh` | ct/kWh | Einspeisevergütung (Konfiguration) | – |
| `buffer_temp_top_c` … `buffer_temp_bottom_c` | °C | – | – |
| `outdoor_temp_c` | °C | – | – |

Bilanzgleichung, die in jedem Snapshot gelten muss (Toleranz konfigurierbar, Default 0,3 kW):

```
pv_power_kw + grid_power_kw + battery_power_kw  =  house_power_kw
house_power_kw = base_load_kw + heat_pump_power_kw + ev_power_kw
```

Wenn `house_power_kw` nicht gemessen wird (kein eigener Zähler), wird es aus der linken Seite **berechnet** und als
`derived` markiert. Wenn die Gleichung um mehr als die Toleranz verletzt ist, setzt der Bilanzierer
`balance_residual_kw` und `quality=inconsistent`; das Dashboard zeigt dann einen kleinen Hinweis statt falsche
Pfeile.

Energie (kWh) folgt derselben Konvention; Zeitstempel sind immer UTC in der Persistenz und werden erst in der UI
nach `Europe/Berlin` umgerechnet. Intervalle sind links-abgeschlossen: `[start, start+15min)`.

### 7.2 Kern-Domänenobjekte (Pydantic, `hems_core.domain`)

```python
class Quality(StrEnum):
    OK = "ok"                 # frischer, plausibler Wert
    STALE = "stale"           # letzter Wert älter als Schwellwert des Sensors
    UNAVAILABLE = "unavailable"
    UNKNOWN = "unknown"
    DERIVED = "derived"       # aus anderen Werten berechnet
    INCONSISTENT = "inconsistent"

class Measurement(BaseModel):
    value: float | None
    observed_at: datetime      # Zeitpunkt der Messung (Quelle), nicht des Empfangs
    quality: Quality
    source: str                # z. B. "shelly:shellypro3em-a1b2c3/em:0" oder "myenergi:harvi/12345678"

class EnergySnapshot(BaseModel):
    timestamp: datetime        # Zeitpunkt der Zusammenstellung (UTC)
    pv_power_kw: Measurement
    grid_power_kw: Measurement
    battery_power_kw: Measurement
    battery_soc: Measurement
    house_power_kw: Measurement
    base_load_kw: Measurement
    heat_pump_power_kw: Measurement
    ev_power_kw: Measurement
    electricity_price_ct_kwh: Measurement
    buffer_temps_c: BufferTemperatures     # top, mid_top, mid_bottom, bottom (je Measurement)
    outdoor_temp_c: Measurement
    balance_residual_kw: float
    # Stellgrößen-Ist (am Relais zurückgelesen, nicht was wir gesendet haben):
    hp_release_contact: Measurement        # K1 „PV-Überschuss“ (bool als 0/1)
    hp_block_contact: Measurement          # K2 „Netzbetreiber-Shutdown“ (bool als 0/1)
    actuators: dict[str, Measurement]      # coffee_machine, terrace_light, garden_fence_light …

class BufferState(BaseModel):
    temps_c: BufferTemperatures
    soc: float                 # 0–1, thermischer Ladezustand (geschätzt)
    usable_energy_kwh: float   # oberhalb T_min
    capacity_kwh: float        # zwischen T_min und T_max
    status: Literal["cold", "partial", "warm", "full"]
    method: str                # z. B. "layered_energy_v1"

class HeatPumpState(BaseModel):
    running: bool              # aus elektrischer Leistung abgeleitet (Debounce)
    running_since: datetime | None
    stopped_since: datetime | None
    power_kw: float
    release_contact_on: bool
    block_contact_on: bool
    starts_today: int
```

Entscheidung, Plan, Forecast und Konfigurationsobjekte folgen in Abschnitten 10, 21 und 22.

### 7.3 Abgeleitete Größen (Bilanzierer, `hems_core.balance`)

- `pv_surplus_kw` (für die Regelung): `max(0, -grid_power_kw)` plus optional `max(0, -battery_power_kw)` wenn
  `battery_soc ≥ config.pv.count_battery_charging_above_soc`, plus optional `ev_power_kw` wenn
  `config.pv.heat_pump_before_ev`. Wenn die Wärmepumpe läuft, wird für die Halte-Bedingung
  `pv_surplus_kw + heat_pump_power_kw` betrachtet (sonst würde sie sich selbst abschalten).
- `self_consumption_kw`, `autarky_ratio`, `today_kwh` je Fluss – nur für Anzeige.
- Geglättete Werte: exponentiell gewichteter Mittelwert (`ewma_seconds`, Default 180 s) für jede Regelgröße; die
  Guards arbeiten nur auf geglätteten Werten.

## 8. Integrationsstrategie Geräte (Shelly, MyEnergi, SolarEdge, Tibber)

### 8.1 Grundsatz

Duck Curve Home liest und schaltet **direkt an den Geräten**. Es gibt keine Zwischenschicht (kein Home Assistant),
keine Fremddatenbank (kein InfluxDB). Jede Geräteklasse hat einen Adapter in der Bridge, der ein gemeinsames
Protokoll erfüllt:

```python
class DeviceSource(Protocol):
    name: str
    async def stream(self) -> AsyncIterator[RawReading]: ...     # RawReading: source_ref, value, unit, observed_at, quality
    async def health(self) -> SourceHealth: ...

class Actuator(Protocol):
    async def set(self, on: bool, ttl_s: int | None) -> ActuatorResult: ...   # setzt und verifiziert
    async def read(self) -> bool | None: ...
```

Das Mapping von Geräteschlüsseln auf Domänengrößen ist Konfiguration (`devices.yaml`, Beispiel in 8.6). Vorzeichen
und Einheiten werden **ausschließlich** in der Bridge normalisiert; ab dem Uplink gilt die Konvention aus
Abschnitt 7.

### 8.2 Shelly (Relais, 3EM, Temperatursensoren)

**Lesen über MQTT.** Ein lokaler Mosquitto-Broker (Docker, nur LAN, Benutzer/Passwort, ACL pro Gerät) empfängt die
Zustände aller Shellys. In jedem Shelly wird MQTT auf den Broker konfiguriert (einmalig, Weboberfläche des Geräts).

| Gerätetyp | Generation | Topics / Verhalten | Rate |
|---|---|---|---|
| Relais (K1, K2, Kaffee, Lichter): Shelly 1/1PM/Plus 1/Plus 1PM/Pro | Gen1: `shellies/<id>/relay/0`, Gen2/3: `<id>/status/switch:0` (JSON mit `output`, `apower`, `temperature`) | Push bei Änderung + periodisch (Gen2 `status` alle 60 s konfigurierbar) | sofort |
| Shelly 3EM (Wärmepumpe) | Gen1: `shellies/<id>/emeter/<0..2>/power`, `…/energy`; Pro 3EM (Gen2): `<id>/status/em:0` mit `total_act_power`, Phasen | Gen1 sendet Leistung jede Sekunde, Gen2 bei Änderung (Schwelle konfigurierbar) | ≈ 1 s |
| Temperatursensoren Puffer | vermutlich **Shelly Plus 1 (PM) mit Plus Add-on und bis zu 5 DS18B20-Fühlern** (`<id>/status/temperature:100…104`) oder vier **Shelly H&T** (Batterie, `shellies/<id>/sensor/temperature`, meldet bei Änderung ≥ 0,5 K bzw. periodisch) | Add-on: Push bei Änderung (0,5 K Standard, einstellbar) plus Periodik; H&T: nur beim Aufwachen | 10 s – 10 min |

Wichtige Gerätedetails werden in Phase 2 verifiziert (offene Frage 25.1): exakte Modelle, Firmware-Generation,
Topic-Präfixe. Adapter für Gen1 und Gen2/3 sind getrennt implementiert, weil sich Topic-Struktur und RPC unterscheiden.

**Schalten über RPC/HTTP** (nicht über MQTT, weil eine synchrone Antwort gebraucht wird):

- Gen2/3: `POST http://<ip>/rpc/Switch.Set {"id":0,"on":true,"toggle_after":1200}` – `toggle_after` ist der
  **hardwareseitige Auto-Off-Timer** (Rückfallebene E0, Abschnitt 11). Anschließend `Switch.GetStatus` zur
  Verifikation. Authentifizierung: Digest (Gerätepasswort, nur in der Bridge).
- Gen1: `GET http://<ip>/relay/0?turn=on&timer=1200` – gleiche Semantik über den `timer`-Parameter; Verifikation über
  `GET /status`.
- Für Wärmepumpen-Kontakte wird `toggle_after`/`timer` **immer** gesetzt (Default 1200 s bei K2, 1800 s bei K1) und vom
  Regler alle 10 min aufgefrischt. Kaffee und Lichter erhalten optional einen Timer (Kaffeemaschine z. B. 2 h).
- Statische IPs oder DHCP-Reservierungen für alle Shellys (Discovery per mDNS `_shelly._tcp` und MQTT-Announce
  als Hilfe).

### 8.3 MyEnergi (Zappi, Libbi, Harvi)

- Es gibt keine offizielle lokale API; der Hub spricht nur mit der MyEnergi-Cloud. Die Bridge nutzt die inoffizielle,
  aber seit Jahren stabile Cloud-API: Director `https://director.myenergi.net` liefert per Header den zuständigen
  Server (`s18.myenergi.net` o. Ä.), Anmeldung per HTTP-Digest mit **Hub-Seriennummer** als Benutzer und dem in der
  MyEnergi-App erzeugten **API-Key** als Passwort. Endpunkt `/cgi-jstatus-*` liefert alle Geräte in einem Aufruf.
- Poll-Intervall 10–15 s (Community-Erfahrung: darunter drosselt der Dienst; Duck Curve Home hält sich an 10 s und
  reduziert bei HTTP 429/5xx exponentiell). Jeder Wert erhält `observed_at` aus dem Antwort-Zeitstempel des Hubs,
  nicht aus der Empfangszeit.
- Gelesene Größen: Netzleistung (Harvi/Zappi `grd`, Vorzeichen: MyEnergi positiv = Import → passt zur Konvention),
  PV-Erzeugung (`gen`), Zappi-Ladeleistung (`div`) und -Status (`sta`, `pst`), Libbi-Leistung, -SOC und -Modus.
  Die exakten Libbi-Feldnamen werden in Phase 2 gegen die Antwort verifiziert und in `parser.py` dokumentiert.
- Fällt die Cloud aus, werden Netz-/Batteriewerte `STALE`; die Wärmepumpen-Regelung nach PV-Überschuss pausiert dann
  (Netzleistung ist Pflichtgröße), sofern nicht ein zweiter Netzmesser konfiguriert ist (Tibber Pulse, 8.5).
- Die MyEnergi-App und der Hub sind vom Lesen nicht betroffen; Duck Curve Home schreibt in v1 nichts an MyEnergi.
  Wenn Home Assistant parallel dieselbe API pollt, verdoppelt sich die Last – siehe 8.7.

### 8.4 SolarEdge

- **Primär: Modbus TCP (SunSpec)** am Wechselrichter, Port 1502 (in SetApp/Installer-Menü aktivieren). Register
  `I_AC_Power` (+ Skalierungsfaktor), `I_AC_Energy_WH`, `I_DC_Power`, `I_Temp_Sink`, `I_Status`. Poll 2 s. Nur lesen.
  Hinweis: Modbus TCP am SolarEdge lässt nur eine begrenzte Zahl gleichzeitiger Verbindungen zu (meist eine) – wenn
  Home Assistant ebenfalls per Modbus liest, gewinnt einer (8.7).
- **Sekundär: MyEnergi `gen`** (CT-Klemme) als redundante PV-Messung; bei Abweichung > 10 % dauerhaft → Event
  (Kalibrierungshinweis).
- **Cloud-Monitoring-API** (`monitoringapi.solaredge.com`, API-Key, 300 Aufrufe/Tag) nur für die Tagesenergie um
  23:30 zur Abstimmung und als Fallback, wenn Modbus nicht aktivierbar ist (dann 15-min-Auflösung, kein Live).

### 8.5 Tibber

- Preise per GraphQL aus dem Worker (`viewer.homes[].currentSubscription.priceInfo { today tomorrow }`, sobald
  verfügbar 15-Minuten-Auflösung), Abruf 13:00–15:00 halbstündlich, sonst stündlich. Persistiert als
  `forecasts(kind="price")`.
- Falls ein **Tibber Pulse** vorhanden ist (25.4): `liveMeasurement`-Subscription (WebSocket
  `wss://websocket-api.tibber.com/v1-beta/gql/subscriptions`) liefert Netzleistung und Zählerstände alle 2–10 s.
  Das ist eine zweite, unabhängige Netzmessung und würde die Abhängigkeit von der MyEnergi-Cloud für die
  PV-Überschuss-Regelung beseitigen. Der Adapter läuft im Worker (Cloud → Tibber), nicht in der Bridge.
- Ausfall: letzte Preise bleiben mit `stale`-Kennzeichnung; preisbasierte Regeln pausieren nach `price_max_age_h`
  (30 h), PV-Regeln laufen weiter, Heizbetrieb nie betroffen.

### 8.6 Geräte-Mapping (`apps/bridge/devices.yaml`, Beispiel)

```yaml
mqtt:
  host: mosquitto
  username: dch
  password_env: DCH_BRIDGE_MQTT_PASSWORD
shelly:
  devices:
    - id: shellypro3em-a1b2c3         # Wärmepumpe
      gen: 2
      ip: 192.168.1.41
      password_env: DCH_BRIDGE_SHELLY_PASSWORD
      reads:
        heat_pump_power_kw: { topic: status/em:0, field: total_act_power, unit: W, scale: 0.001, stale_after_s: 30 }
    - id: shellyplus1-d4e5f6           # Puffer-Temperaturen (Add-on, 4× DS18B20)
      gen: 2
      ip: 192.168.1.42
      reads:
        buffer_temp_top_c:        { topic: status/temperature:100, field: tC, stale_after_s: 900 }
        buffer_temp_mid_top_c:    { topic: status/temperature:101, field: tC, stale_after_s: 900 }
        buffer_temp_mid_bottom_c: { topic: status/temperature:102, field: tC, stale_after_s: 900 }
        buffer_temp_bottom_c:     { topic: status/temperature:103, field: tC, stale_after_s: 900 }
    - id: shellyplus1-778899           # K1 PV-Freigabe
      gen: 2
      ip: 192.168.1.43
      actuator: { key: hp_release_contact, channel: 0, safety_class: heat_pump, safe_state: off, hw_auto_off_s: 1800 }
    - id: shellyplus1-aabbcc           # K2 EVU-Sperre
      gen: 2
      ip: 192.168.1.44
      actuator: { key: hp_block_contact, channel: 0, safety_class: heat_pump, safe_state: off, hw_auto_off_s: 1200 }
    - id: shelly1-112233               # Kaffeemaschine (Gen1)
      gen: 1
      ip: 192.168.1.50
      actuator: { key: coffee_machine, channel: 0, safety_class: none, hw_auto_off_s: 7200 }
    - id: shelly1-445566
      gen: 1
      ip: 192.168.1.51
      actuator: { key: terrace_light, channel: 0, safety_class: none }
    - id: shelly1-778800
      gen: 1
      ip: 192.168.1.52
      actuator: { key: garden_fence_light, channel: 0, safety_class: none }
myenergi:
  hub_serial_env: DCH_BRIDGE_MYENERGI_SERIAL
  api_key_env: DCH_BRIDGE_MYENERGI_API_KEY
  poll_s: 10
  reads:
    grid_power_kw:    { device: harvi, serial: "12345678", field: ectp1+ectp2+ectp3, unit: W, scale: 0.001, sign: import_positive }
    pv_power_kw_ct:   { device: zappi, field: gen, unit: W, scale: 0.001 }
    ev_power_kw:      { device: zappi, field: div, unit: W, scale: 0.001 }
    battery_power_kw: { device: libbi, field: TODO_verify, unit: W, scale: 0.001, sign: discharge_positive }
    battery_soc:      { device: libbi, field: soc, unit: "%", scale: 0.01 }
solaredge:
  modbus: { host: 192.168.1.60, port: 1502, unit_id: 1, poll_s: 2 }
  reads:
    pv_power_kw: { register: I_AC_Power, unit: W, scale: 0.001, stale_after_s: 20 }
  cloud: { site_id_env: DCH_BRIDGE_SOLAREDGE_SITE, api_key_env: DCH_BRIDGE_SOLAREDGE_KEY, daily_reconcile: true }
priority:
  pv_power_kw: [solaredge.pv_power_kw, myenergi.pv_power_kw_ct]   # erste frische Quelle gewinnt
```

`discover` (`dch-bridge discover`) scannt das LAN nach Shellys (mDNS, MQTT-Announce), listet MyEnergi-Geräte mit
Seriennummern und prüft die Modbus-Verbindung, um diese Datei zu erstellen.

### 8.7 Parallelbetrieb mit Home Assistant

Home Assistant wird nicht benötigt und kann abgeschaltet werden. Läuft es weiter, gilt:

- **Shelly Gen1 + MQTT:** Bei Gen1-Geräten schließen MQTT und Shelly-Cloud einander aus; HA liest Gen1 typischerweise
  per CoIoT/REST, das bleibt parallel möglich. Gen2/3 können MQTT, RPC-WebSocket und Cloud gleichzeitig.
- **MyEnergi:** zwei Poller verdoppeln die Cloud-Last; empfohlen, die HA-Integration zu deaktivieren oder ihr
  Intervall zu verlängern.
- **SolarEdge Modbus:** meist nur eine gleichzeitige Verbindung; entweder HA oder Duck Curve Home. Bis zur
  Entscheidung liefert der MyEnergi-CT die PV-Leistung.
- **Wärmepumpen-Kontakte:** Es darf nur **ein** System schalten. Die bestehende HA-Regel („WP Auto“) wird spätestens
  in Phase 3 deaktiviert; bis dahin bleibt Duck Curve Home im Modus OFF (nur beobachten). Zwei Automatiken auf
  denselben Relais sind ein Sicherheitsrisiko.

## 9. Strategie für Live-Daten

### 9.1 Ziel und Budget

| Strecke | Ziel |
|---|---|
| Gerät → Bridge | Shelly per MQTT ≈ 1 s (3EM jede Sekunde), SolarEdge Modbus 2 s, MyEnergi-Cloud 10–15 s (Poll) |
| Bridge → API | Frame alle 1 s (koalesziert), < 300 ms Laufzeit |
| API → Dashboard | SSE, max. 1 Frame/s, < 200 ms |
| **Ende-zu-Ende (Shelly/Modbus-Werte)** | **≈ 1–3 s**; MyEnergi-Werte (Netz, Batterie, Wallbox) tragen ihr eigenes `observed_at` und werden mit Alter angezeigt; mit Tibber Pulse (8.5) käme die Netzleistung alle 2–10 s |

Damit „live wirken“ nicht an der langsamsten Quelle hängt, zeigt das Dashboard je Knoten das Alter des Wertes an
(dezent, erst ab 30 s sichtbar) und animiert Flüsse nur mit frischen Werten.

### 9.2 Server-Sent Events

- Endpoint `GET /api/v1/live/stream` (über BFF-Proxy, Cookie-Auth). Events:
  `snapshot` (vollständiger `EnergySnapshot`, alle 1 s bei Änderung, spätestens alle 5 s als Heartbeat),
  `decision` (bei neuer Regler-Entscheidung), `plan` (bei neuem Plan), `actuator` (Ack/Fail eines Kommandos),
  `system` (Bridge online/offline, Backend-Version, Zeitversatz).
- Jeder Event trägt `id` (monoton); Client sendet `Last-Event-ID`, Server liefert beim Reconnect den aktuellen
  Zustand komplett (kein Replay nötig – der Verlauf kommt aus der History-API).
- `retry: 2000` im Stream; Client-Backoff bis 30 s mit Jitter.
- Backend-Broker: ein `asyncio.Queue` pro Verbindung mit Größe 5; bei Überlauf werden ältere `snapshot`-Events
  verworfen (Koaleszenz), nie `decision`/`actuator`-Events.

### 9.3 Robustheit auf dem iPad

| Störung | Verhalten |
|---|---|
| WLAN-Unterbrechung | `EventSource` reconnectet; Store setzt `connection=reconnecting`; nach 15 s ohne Frame: Statusleiste „Verbindung unterbrochen – letzte Daten 00:42“ und alle Werte gedimmt; Flussanimation stoppt |
| Backend-Neustart | Deploy-Rollover < 30 s; identisch zu WLAN-Fall; Client holt nach Reconnect `GET /live/state` + `GET /history/today` |
| Bridge offline | Backend sendet `system{bridge: offline, since}`; Dashboard zeigt Banner „Haus nicht erreichbar“; Werte bleiben mit Alter stehen; Regler geht in `FAILSAFE_RELEASED` (Abschnitt 11) |
| Einzelnes Gerät offline (Shelly ohne WLAN, MyEnergi-Cloud down, Modbus-Timeout) | Bridge meldet `SourceHealth` je Quelle; betroffene Werte `UNAVAILABLE`; Dashboard zeigt am Knoten ein Gerätesymbol mit „seit 12:41“ |
| Sensor `unavailable`/`unknown` | Knoten zeigt „–“ mit Sensor-Symbol, Fluss ausgeblendet, Bilanz rechnet ohne den Wert und markiert `derived` |
| Veraltete Werte | pro Sensor `stale_after_s`; stale → Quality `STALE`, UI grau + Alter; Regler behandelt stale wie fehlend |
| Tibber/Wetter-API-Ausfall | Forecast-Reihen bleiben als „Stand 13:05“ stehen; Intelligence Card nennt die Einschränkung |
| Speicherleck über Tage | ECharts erhält nur `setOption` mit begrenzten Arrays (max. 1440 Punkte/Serie), Store hält keine Historie außer dem Tagesfenster; ein `reloadPolicy` lädt die Seite täglich um 03:30 neu und nach jedem erkannten Backend-Versionswechsel |
| Uhrzeitdrift | Server sendet `server_time`; Client rechnet Offset; „Jetzt“-Linie nutzt Serverzeit |
| iPad-Display | Betrieb per Guided Access mit deaktivierter Auto-Sperre; PWA-Manifest (`display: standalone`, `apple-mobile-web-app-status-bar-style: black-translucent`), `viewport-fit=cover`, Safe-Area-Insets |

### 9.4 Kein Polling im Frontend

Das Frontend pollt nichts. Ausnahmen: (1) nach Reconnect ein einmaliger Fetch von Zustand und Tagesverlauf,
(2) täglicher Reload. Der Tagesverlauf wird inkrementell aus den `snapshot`-Events fortgeschrieben (1-min-Bins
clientseitig), sodass der History-Endpoint nur beim Laden und nach Reconnect gebraucht wird.

## 10. Wärmepumpen-Steuerungsarchitektur

### 10.1 Was die beiden Kontakte tun – und was nicht

| Kontakt | Bedeutung für die ELCO AERO | Wirkung | Risiko bei Fehlbedienung |
|---|---|---|---|
| **K1 „PV-Überschuss“** (SG-Ready-ähnliche Anforderung) | „Du darfst/sollst mehr Wärme erzeugen“ – typischerweise erhöht die Regelung Sollwerte (Puffer/Warmwasser) oder startet eine Beladung | **Anforderung**, keine Garantie. Die Wärmepumpe entscheidet selbst, ob und wie lange sie läuft (eigene Hysteresen, Abtauung, Verdichter-Mindestzeiten) | gering: häufiges Toggeln kann zu unnötigen Starts führen, die Wärmepumpe schützt sich aber selbst. Dauerhaft an = höhere Speichertemperatur, mehr Verluste, ggf. ineffizienter Betrieb |
| **K2 „Netzbetreiber-Shutdown“** (EVU-Sperre) | „Du darfst jetzt nicht laufen“ | **Sperre**, hart. Bei Sperre gilt bei den meisten Geräten Frostschutz weiter, aber kein Heiz-/Warmwasserbetrieb | **hoch**: Ein Softwarefehler, der K2 dauerhaft setzt, lässt das Haus auskühlen und das Warmwasser kalt werden. Hersteller begrenzen EVU-Sperren üblicherweise auf wenige Stunden pro Tag – genau diese Grenze übernimmt das HEMS |

Konsequenzen für das HEMS-Design:

1. **K1 ist das Arbeitsinstrument**, K2 ist die Ausnahme. Phasen 4 und 5 arbeiten zunächst **nur mit K1**. K2 wird
   erst freigeschaltet, wenn Laufzeitverhalten und Puffermodell mit echten Daten validiert sind, und bleibt
   standardmäßig deaktiviert (`block_contact.enabled: false`).
2. **Ist-Zustand aus der Leistung, nicht aus dem Kontakt.** Ob die Wärmepumpe läuft, wird über den Shelly 3EM
   erkannt (`running_threshold_kw`, Default 0,5 kW, Debounce 60 s). Mindestlaufzeit und Mindestauszeit beziehen sich
   auf diesen Ist-Zustand, nicht auf K1.
3. **Beide Kontakte niemals gleichzeitig aktiv.** Der Guard verhindert den Widerspruch (Freigabe + Sperre) hart.
4. **Jede Aktivierung hat eine TTL.** Ohne Verlängerung durch den Regler fällt der Kontakt in der Bridge zurück (K1
   nach `release_ttl_min`, Default 20 min; K2 nach `block_ttl_min`, Default 15 min). Der Regler verlängert alle
   10 s, solange die Entscheidung gilt.

Prüfpunkte an der realen Anlage (Phase 3, vor Phase 4): Wie reagiert die ELCO konkret auf K1 (Sollwert-Anhebung um
wie viel Kelvin? Warmwasser oder Heizung oder beides?), wie auf K2 (Frostschutz aktiv? Anzeige/Störmeldung?), wie
lange bleibt sie nach Wegfall von K1 noch laufen? Diese Antworten werden im Konfigurationsobjekt `heat_pump.behaviour`
dokumentiert und fließen in die Simulation ein.

### 10.2 Betriebsmodi

```
system_mode:  OFF | MANUAL | AUTO
auto_profile: ECO | PV | PRICE | SMART        (nur relevant bei AUTO)
override:     none | force_release | force_block | inhibit_release   (zeitlich begrenzt, max. 12 h Default)
```

- **OFF:** Duck Curve Home beobachtet nur und schaltet nichts. Beide Kontakte aus (bzw. so, wie ein anderes System sie hinterlassen hat – nur in der Übergangszeit vor Phase 3, siehe 8.7).
- **MANUAL:** Nutzer schaltet K1 (und, wenn freigegeben, K2) direkt über das Dashboard; jede manuelle Schaltung hat
  eine Dauer (Default 2 h, wählbar), danach Rückfall nach `AUTO` bzw. `OFF`. Dashboard zeigt sichtbar „MANUELL bis
  16:30“.
- **AUTO/ECO:** nur PV-Überschuss, konservative Schwellen. **AUTO/PV:** PV-Überschuss mit Batterie-/EV-Anrechnung
  nach Konfiguration. **AUTO/PRICE:** PV + Preisfenster (negativ, günstigstes Quantil). **AUTO/SMART:** zusätzlich
  Forecast-/Plan-basiert (Phase 5+).
- Ein Override überlagert AUTO temporär und wird groß angezeigt; er wird durch die Guards begrenzt (auch
  `force_block` endet nach `block.max_duration_min`).

### 10.3 Zustandsmaschine des Wärmepumpen-Controllers (K1-Pfad)

```
                    ┌──────────────────────────────────────────────────────┐
                    │                      IDLE                            │
                    │  K1 aus. Beobachtet Überschuss, Preis, Plan.         │
                    └──────┬───────────────────────────────────────────────┘
        Trigger erfüllt    │  (PV: surplus_ewma ≥ on_kw; PRICE: Fenster aktiv; PLAN: Intervall geplant)
        UND Puffer hat     ▼  UND stopped_since ≥ min_offtime UND keine Sperre UND Sensoren OK
                    ┌──────────────────────────────────────────────────────┐
                    │                  ARMING (Wartezeit)                  │
                    │  Bedingung muss on_delay_min durchgehend halten.     │
                    │  Ausblick im UI: „Start in 3 min, wenn Überschuss    │
                    │  bleibt“.                                           │
                    └──────┬───────────────────────────────────────────────┘
                           │ Bedingung gehalten            │ Bedingung verletzt → IDLE
                           ▼
                    ┌──────────────────────────────────────────────────────┐
                    │                RELEASED (K1 an, TTL läuft)           │
                    │  Erwartet Anlauf innerhalb start_timeout_min.        │
                    │  Läuft die WP nicht an → NO_RESPONSE (K1 bleibt,     │
                    │  aber Ereignis und Hinweis; nach 2×Timeout → IDLE    │
                    │  mit Sperrzeit „WP folgt nicht“).                    │
                    └──────┬───────────────────────────────────────────────┘
                           │ running erkannt
                           ▼
                    ┌──────────────────────────────────────────────────────┐
                    │              RUNNING_RELEASED (K1 an)                │
                    │  Halten solange: (surplus_ewma + hp_power) ≥ off_kw  │
                    │  ODER Preisfenster aktiv ODER min_runtime nicht      │
                    │  erreicht. Abbruch nur bei: Puffer voll (T_top ≥     │
                    │  T_max ODER soc ≥ soc_full), Override, Sensorausfall,│
                    │  Failsafe.                                           │
                    └──────┬───────────────────────────────────────────────┘
                           │ Haltebedingung off_delay_min lang verletzt UND min_runtime erreicht
                           ▼
                    ┌──────────────────────────────────────────────────────┐
                    │                 COOLDOWN (K1 aus)                    │
                    │  WP läuft ggf. selbst noch aus. Kein neuer Start     │
                    │  vor min_offtime (ab tatsächlichem Stopp).           │
                    └──────────────────────────────────────────────────────┘
```

Parallel dazu (Phase 5+) der **K2-Pfad** mit eigener Maschine `UNBLOCKED → BLOCK_ARMING → BLOCKED → UNBLOCKED`, der
nur betreten wird, wenn `block_contact.enabled`, Heizbedarf ≠ FORCED, `buffer.soc ≥ block.min_soc`, Außentemperatur
> `block.min_outdoor_temp_c`, Preisrang im teuersten Quantil, und der `block.max_duration_min` (Default 120) sowie
`block.max_per_day` (Default 2) einhält. Die Sperre endet außerdem sofort, wenn `T_top < T_min_comfort` oder der
Heizbedarf auf FORCED wechselt.

### 10.4 Regelparameter (Ausschnitt, alle konfigurierbar, siehe CONFIGURATION.md in Phase 1)

```yaml
heat_pump:
  minimum_electric_power_kw: 3.5
  nominal_electric_power_kw: 4.5
  running_threshold_kw: 0.5
  running_debounce_s: 60
  min_runtime_min: 30
  min_offtime_min: 20
  start_timeout_min: 10
  max_starts_per_day: 8
  release_ttl_min: 20
control:
  ewma_seconds: 180
  pv:
    on_surplus_kw: 4.0            # Reserve über minimum_electric_power_kw
    off_import_kw: 1.5            # Ausschalten, wenn im Mittel mehr als 1,5 kW bezogen wird
    on_delay_min: 5
    off_delay_min: 10
    count_battery_charging_above_soc: 0.8
    heat_pump_before_ev: false
    min_buffer_headroom_soc: 0.10 # nur starten, wenn mind. 10 % Ladehub möglich
  price:
    negative_price_release: true
    cheap_quantile: 0.10          # günstigstes Dezil des Tages
    min_window_min: 30
    price_max_age_h: 30
  block:
    enabled: false
    expensive_quantile: 0.85
    max_duration_min: 120
    max_per_day: 2
    min_soc: 0.6
    min_outdoor_temp_c: 3.0
    block_ttl_min: 15
```

### 10.5 Wärmebedarfs-Modi (Näherung ohne Wärmepumpen-Schnittstelle)

```
FORCED       Heizperiode UND (T_out ≤ forced_below_c [Default 0 °C] ODER buffer.T_top < T_min_comfort
             ODER WP lief in den letzten 6 h > 70 % der Zeit)          → K2 verboten, K1 erlaubt
SHIFTABLE    Heizperiode, Puffer zwischen T_min_comfort und T_target    → Zeitfenster wählbar
EXTRA_CHARGE Puffer ≥ T_target, aber < T_max, PV/Preis günstig           → nur bei Überschuss/negativ
NONE         Puffer ≥ T_max ODER (Sommer UND Warmwasser über Ziel)       → K1 aus
```

Heizperiode: gleitendes 24-h-Mittel der Außentemperatur < `heating_limit_c` (Default 15 °C) oder Kalenderfenster
(Oktober–April), konfigurierbar. Die Modul-Grenze (`hems_core.thermal.heat_demand.HeatDemandClassifier`) ist so
gezogen, dass später ein gelerntes Modell dieselbe Enum liefert.

### 10.6 Entscheidungsobjekt und Erklärbarkeit

```python
class Decision(BaseModel):
    id: UUID
    at: datetime
    controller_state: str                    # IDLE | ARMING | RELEASED | RUNNING_RELEASED | COOLDOWN | …
    k1_release: bool
    k2_block: bool
    reasons: list[ReasonCode]                # geordnet: Hauptgrund zuerst
    blocked_by: list[ReasonCode]             # was einen Start/Stopp verhindert hat
    inputs: DecisionInputs                   # surplus_ewma_kw, price_ct, price_rank, buffer_soc, t_out, running, …
    valid_until: datetime                    # TTL
    next_expected: NextExpected | None       # {"action": "start", "at": …, "because": ReasonCode}
    explanation_de: str                      # gerenderter Satz für das Dashboard
```

Reason-Codes sind eine geschlossene Enum (Auszug): `PV_SURPLUS`, `PV_SURPLUS_FADING`, `PRICE_NEGATIVE`,
`PRICE_CHEAP_WINDOW`, `PLANNED_WINDOW`, `HEAT_DEMAND_FORCED`, `BUFFER_FULL`, `BUFFER_NO_HEADROOM`,
`MIN_OFFTIME_PENDING`, `MIN_RUNTIME_HOLD`, `MAX_STARTS_REACHED`, `MANUAL_OVERRIDE`, `SENSOR_STALE`,
`SENSOR_UNAVAILABLE`, `PRICE_DATA_STALE`, `BRIDGE_OFFLINE`, `FAILSAFE`, `HP_NOT_RESPONDING`, `MODE_OFF`.
Die deutschen Sätze („Wärmepumpe wartet – Mindeststillstandszeit noch 8 Minuten“) werden aus Code + Inputs
gerendert; die Codes sind stabil, die Texte frei änderbar. Jede Decision wird persistiert; das Dashboard zeigt die
aktuelle und die letzten Übergänge als Zeitleiste.

## 11. Safety-Konzept

### 11.1 Sicherer Grundzustand

**Beide Kontakte aus = kein Eingriff = Wärmepumpe regelt sich selbst wie vor Duck Curve Home.** Jede Schicht des
Systems muss diesen Zustand ohne Mitwirkung der darüberliegenden Schichten erreichen können.

### 11.2 Vier unabhängige Rückfallebenen

| Ebene | Ort | Mechanismus | Greift wenn |
|---|---|---|---|
| **E0 Hardware** | Shelly-Relais | Auto-Off-Timer im Relais, bei **jedem** Einschaltbefehl mitgegeben (Gen2/3 `Switch.Set … toggle_after`, Gen1 `?turn=on&timer=`): K2 1200 s, K1 1800 s. Zusätzlich als Geräteeinstellung „Auto-Off“ hinterlegt, falls ein Befehl ohne Timer käme. Ein gesetzter Kontakt fällt also auch dann, wenn Bridge, Broker, Netz und Cloud gleichzeitig ausfallen | alles oberhalb tot |
| **E1 Guardian** | eigener Prozess/Container auf dem Bridge-Host (`dch-guardian`), unabhängig von der Bridge-Software | Liest eine Heartbeat-Datei/SQLite-Zeile, die die Bridge alle 30 s schreibt. Fehlt der Heartbeat > 5 min oder stürzt die Bridge ab → Guardian schaltet K1/K2 direkt per Shelly-RPC aus (eigene, minimale Implementierung, ~100 Zeilen, keine gemeinsamen Bibliotheken) und protokolliert. Optional: Hardware-Watchdog des Hosts (Raspberry Pi `bcm2835_wdt`) startet den Rechner bei Hängern neu | Bridge-Software tot, Broker tot |
| **E2 Gateway** | Geräteschicht (Profil A: im Worker; Profil B: Bridge) | TTL-Tabelle je Aktor; ohne Verlängerung durch den Regler → `safe_state`. Profil B zusätzlich: Cloud-Verbindung > `offline_release_s` (Default 180 s) weg → alle Wärmepumpen-Kontakte sofort auf `safe_state`, Event lokal gepuffert | Regler tot (A) / Cloud oder Internet tot (B) |
| **E3 Cloud-Regler** | Worker | Guards (Mindestzeiten, Max-Sperrdauer, Max-Starts, Plausibilität), Sensorqualitäts-Gate, Preisdaten-Alter, `FAILSAFE`-Zustand mit Auto-Recovery, Leader-Lock gegen doppelte Regler | Logikfehler, Datenfehler |

Ebene E0 ist die wichtigste und kostet nichts. Sie erzwingt, dass der Regler K1/K2 regelmäßig „nachsetzt“ (Bridge
sendet bei Bedarf alle 10 min ein Refresh mit neuem Timer); das ist gewollt: Ein Zustand, der aktiv gehalten werden
muss, kann nicht versehentlich ewig bleiben. Elektrisch sollten K1/K2 als Schließer (NO) verdrahtet sein, sodass
auch ein stromloses Relais „kein Eingriff“ bedeutet (25.10).

### 11.3 Regeln im Regler (Guards, alle testpflichtig)

1. Nie K1 und K2 gleichzeitig.
2. K2 nur wenn `block.enabled`, nie bei `HeatDemand.FORCED`, nie bei `T_out < block.min_outdoor_temp_c`, nie länger als
   `max_duration_min`, nie öfter als `max_per_day`, nie wenn `buffer.T_top < T_min_comfort`.
3. Kein K1-Start vor Ablauf von `min_offtime_min` seit letztem **tatsächlichem** Stopp, kein K1-Stopp (durch Regel)
   vor `min_runtime_min` seit **tatsächlichem** Start – Ausnahmen: Puffer voll (T_max), Override, Failsafe.
4. Kein Start, wenn eine für die Entscheidung notwendige Größe `STALE/UNAVAILABLE/UNKNOWN` ist. Notwendig für PV:
   `grid_power_kw`, `heat_pump_power_kw`, Puffertemperaturen; für PRICE: zusätzlich Preisreihe nicht älter als
   `price_max_age_h`. Ein laufender K1 wird bei Sensorausfall nach `sensor_grace_min` (Default 5) beendet – das ist
   sicher, weil die Wärmepumpe dann nur in Normalbetrieb zurückfällt.
5. Maximal `max_starts_per_day` durch DCH ausgelöste Starts.
6. Jede Änderung eines Wärmepumpen-Kontakts erzeugt ein `system_event` mit Decision-Referenz. Mehr als
   `max_toggles_per_hour` (Default 4) → Regler geht in `FAILSAFE` (K1/K2 aus, 60 min Pause, Benachrichtigung).
7. `FAILSAFE`-Zustand bei: Bridge offline, Leader-Lock verloren, unbehandelte Exception im Tick, Konfigurations-
   Validierungsfehler, Uhrzeitversatz Bridge/Cloud > 60 s. Auto-Recovery nach Ursachenbehebung + `failsafe_hold_min`.
8. Overrides (MANUAL) sind immer zeitlich begrenzt und unterliegen Regel 1 und 2 (auch der Mensch kann K2 nicht
   länger als `max_duration_min` setzen – wer das braucht, nutzt den physischen Schalter der Anlage).

### 11.4 Externe Abhängigkeiten und ihr Ausfallverhalten

| Ausfall | Folge für Heizbetrieb | Folge für DCH |
|---|---|---|
| Tibber | keine | Preisregeln pausieren; PV-Regeln laufen; Anzeige „Preise Stand …“ |
| Open-Meteo / PV-Forecast | keine | Planer fällt auf regelbasiert zurück; Card sagt es |
| Postgres (Railway) | keine (E2 räumt auf) | API liefert 503, Worker geht in FAILSAFE, Dashboard zeigt Störung |
| Railway komplett | keine (E2 nach 180 s) | Dashboard zeigt Störung, letzte Werte |
| Bridge-Host komplett (Strom, Defekt) | keine (E0 nach ≤ 30 min) | keine Live-Daten, Dashboard zeigt Störung; Ringpuffer geht ab Ausfall verloren |
| Mosquitto / WLAN im Haus | keine (E1/E0) | Shelly-Werte `UNAVAILABLE`; Regler stoppt K1 nach `sensor_grace_min` |
| MyEnergi-Cloud | keine | Netz/Batterie/Wallbox `STALE`; PV-Regel pausiert, außer Tibber Pulse liefert Netzleistung |
| Duck Curve Home vollständig entfernt | keine | – |

### 11.5 Watchdog-Konzept zusammengefasst

```
Cloud-Regler ──10 s──► Decision (valid_until = now + TTL)
      │
      ▼ Kommando/Refresh nur bei Änderung oder alle 10 min
Bridge ──30 s──► Heartbeat (lokal)        ──► Guardian schaltet nach 5 min ohne Heartbeat K1/K2 aus
      │
      ▼ Switch.Set on + toggle_after      ──► Relais fällt nach 20–30 min selbst
Shelly-Relais
```

### 11.6 Was das HEMS ausdrücklich nicht tut

- keine Sollwerte, Heizkurven, Ventile oder Verdichter-Parameter der Wärmepumpe verändern;
- keine Steuerung von Libbi/Zappi (nur lesen) in v1;
- kein Eingriff in den Pelletofen;
- keine Automatik für Aktoren ohne Sicherheitsrelevanz ohne ausdrückliche Konfiguration (Kaffeemaschine bleibt manuell).

## 12. Optimierungs-Roadmap

Alle Stufen implementieren dasselbe Protokoll:

```python
class Planner(Protocol):
    def plan(self, ctx: PlanningContext) -> Plan: ...
    # PlanningContext: now, prices[96], pv_forecast[96], t_out_forecast[96], heat_demand[96],
    #                  buffer_state, battery_soc, hp_state, config, overrides
    # Plan: intervals[96] mit planned_hp_state, planned_buffer_soc, reason, confidence
```

Der Regler behandelt den Plan als **Empfehlung**: `PLANNED_WINDOW` ist ein Trigger wie `PV_SURPLUS`; die Guards
gelten unverändert. Kein Planer kann die Safety-Schicht umgehen.

| Stufe | Phase | Inhalt | Eingaben | Ausgabe |
|---|---|---|---|---|
| **1 Rule-Based** | 4 | Zustandsmaschine aus 10.3, PV-Überschuss, negative Preise, günstigstes Preisdezil des laufenden Tages | Live-Snapshot, Tagespreise | Decision; „Plan“ = nur Preisfenster des Tages |
| **2 Forecast-Aware** | 5 | Regelbasierte Tagesplanung: Wärmebedarf 24 h aus T_out-Forecast, benötigte Beladungen aus Puffer-Bilanz, Zuordnung zu Zeitfenstern nach Rangfolge (1) PV-Überschuss-Prognose, (2) negative Preise, (3) günstigste Preise unter Berücksichtigung von Mindestlaufzeiten; Vorheizen des Puffers vor Hochpreisphasen | + PV-Forecast, Wetter, Wärmebedarf, Puffermodell | Plan[96] mit Begründungen, Intelligence-Card-Ausblick |
| **3 Rolling-Horizon** | 6 | MILP über 24–36 h, 15 min: Variablen `hp_on[t] ∈ {0,1}`, `hp_start[t]`, `E_buffer[t]`, `T_building[t]` (RC-Modell); Ziel: Kosten + Komfortstrafe + Schaltstrafe + Spitzenstrafe; Nebenbedingungen: Pufferbilanz, Grenzen, Mindestlauf-/-auszeit (per Start-Variablen), Leistungsgrenze, Sperrdauer. Solver HiGHS (scipy ≥ 1.9 `milp`) wie in valyze | + Kalibrierte Modelle | Plan[96] + Sensitivität (Schattenpreise) |

Erweiterungen nach Stufe 3 (nicht geplant, aber architektonisch offen): Batterie-Ladeleistung als Variable (nur
wenn MyEnergi eine schreibende API stabil erlaubt), Wallbox-Ladefenster, weitere Verbraucher, stochastische
PV-Szenarien.

**Kalibrierung (ab Phase 5, laufend):** täglich um 23:30 vergleicht ein Job (a) PV-Forecast vs. Ist (kWh/Tag,
kWh/Stunde), (b) Wärmebedarfsmodell vs. elektrische Energie × COP-Schätzung, (c) Puffermodell vs. gemessene
Temperaturverläufe. Ergebnisse landen in `model_calibrations` und werden als Korrekturfaktoren mit EWMA
übernommen (Details 19.4 und 20.3).

## 13. UI-/UX-Konzept

### 13.1 Rahmenbedingungen

- Gerät: iPad im Querformat an der Wand, ca. 1180×820 CSS-px (iPad Air/Pro 11") bzw. 1024×768 (ältere iPads).
  Layout wird für 1024–1366 px Breite bei Seitenverhältnis 4:3 bis 3:2 ausgelegt; darunter (Handy) eine gestapelte
  Fallback-Ansicht ohne Anspruch auf Kiosk-Qualität.
- Leseabstand 1–3 m: Primär-KPIs 56–72 px Mono, Sekundärwerte 28–32 px, Labels ≥ 13 px, Kontrast ≥ 4,5:1 auf
  `--deep`. Kein Text unter 12 px.
- Dark Mode ist der einzige Modus in v1 (Wandbetrieb, nachts nicht blendend). Ein Light-Theme wird über die Tokens
  vorbereitet, aber nicht gebaut.
- Touch: Mindestzielgröße 56×56 px, Abstände ≥ 12 px, keine Hover-Abhängigkeit, kein Long-Press für Kernfunktionen.
- Ruhe: Es bewegt sich nur, was Information trägt (Flussrichtung, Jetzt-Linie, ein Statuspunkt). Maximal eine
  Akzentfarbe (Amber) pro Blick­feld dominant; Warnfarbe (Ember) nur bei echten Störungen.

### 13.2 Informationshierarchie

1. **Was passiert gerade?** Energiefluss (links) – der größte Block, weil er in einer Sekunde begreifbar ist.
2. **Warum und was kommt?** Intelligence Card (Mitte) – das Alleinstellungsmerkmal; sie bekommt eine ganze Spalte.
3. **Thermischer Zustand** – Pufferspeicher (rechts), hoch und schmal wie das Objekt selbst.
4. **Tagesverlauf mit Prognose** – Chart über die volle Breite, halbhoch.
5. **Bedienung** – Kachelleiste unten, immer erreichbar, aber visuell zurückgenommen.

### 13.3 Layout (Landscape, 12-Spalten-Raster, 20-px-Gutter, 24-px-Rand)

```
┌────────────────────────────────────────────────────────────────────────────────────────────┐
│ [Mark] DUCK CURVE HOME      Freitag, 4. September · 19:22        ● live   AUTO · SMART   ⋯  │  56 px
├───────────────────────────────────┬──────────────────────────────────┬─────────────────────┤
│ ENERGIEFLUSS                      │ DUCK CURVE HOME                  │ PUFFERSPEICHER      │
│                                   │                                  │                     │
│            PV  ◉ 6,8 kW           │ JETZT                            │   ┌───┐  60 °       │
│              ╲                    │ PV 6,8 · Haus 0,7 · Batt 100 %   │   │███│             │
│  Netz ◉ ── ◉ Haus ── ◉ Batterie   │ Export 6,1 kW                    │   │███│  59 °       │
│  −6,1 kW   0,7 kW    100 %        │                                  │   │▓▓▓│             │
│            ╱    ╲                 │ ENTSCHEIDUNG                     │   │▒▒▒│  48 °       │
│   Wärmepumpe   Wallbox            │ Wärmepumpe startet in 4 min      │   │░░░│             │
│   ◉ 0 kW       ◉ 0 kW             │                                  │   └───┘  32 °       │
│                                   │ WARUM                            │                     │
│                                   │ · PV-Überschuss ≥ 4 kW seit 1 min│   62 %              │
│                                   │ · Puffer 46 % – Platz vorhanden  │   teilgeladen       │
│                                   │ · Stillstand 38 min ≥ 20 min     │   +1,2 K/h          │
│                                   │                                  │                     │
│                                   │ AUSBLICK                         │                     │
│                                   │ Laufzeit ≈ 45 min · Ziel 85 %    │                     │
│                                   │ Nächstes Preistief 02:15–04:00   │                     │
├───────────────────────────────────┴──────────────────────────────────┴─────────────────────┤
│ HEUTE · PV / WÄRMEPUMPE / WALLBOX · STROMPREIS                        ▢ Heute ▢ Gestern ▢ 7 T │
│  kW ┤        ╭──╮                                                          ct/kWh              │
│     ┤   ╭────╯  ╰──╮        ┆ jetzt     ┄┄┄ Prognose ┄┄┄                                     │
│     ┤ ╭─╯  ▒▒▒▒▒▒  ╰─╮      ┆     ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄                              │
│     ┴─────────────────────────────────────────────────────────────────                        │
│      00    04    08    12    16    20    00          ▒ geplante Laufzeit · ▓ günstiges Fenster │
├────────────────────────────────────────────────────────────────────────────────────────────┤
│ [ Wärmepumpe  AUTO | AN | AUS ]   [ ☕ Kaffee  aus ]   [ ◐ Terrasse  an ]   [ ◐ Gartenzaun  aus ] │  ≈ 96 px
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

Spaltenanteile: Energiefluss 5/12, Intelligence Card 4/12, Puffer 3/12. Zeilenhöhen: Header 56, Oberer Block
≈ 52 %, Chart ≈ 30 %, Steuerleiste ≈ 96 px. Bei 1024×768 wird die Card knapper (nur „Entscheidung“ + ein
„Warum“-Satz), der Rest bleibt.

### 13.4 Komponenten

**Header:** Marke links (Mark + Wortmarke „Duck Curve“ + Mono-Kicker „HOME“), Datum/Uhrzeit in Mono, rechts ein
Verbindungspunkt (Amber pulsiert dezent = live; Mist = reconnect; Ember = offline) und der Modus als Pill. Kein
Menü im Kiosk; ein Zahnrad öffnet die Einstellungen (mit PIN ab Phase 3).

**Energiefluss (`EnergyFlow`):** fünf bis sechs Knoten in fester Anordnung (PV oben, Haus Mitte, Netz links,
Batterie rechts, Wärmepumpe und Wallbox unten). Kanten als Bezier-Pfade; Fluss durch wandernde Punkte
(`stroke-dasharray` + `stroke-dashoffset`-Animation), Geschwindigkeit in drei Stufen (< 0,5 kW: still, 0,5–3 kW:
langsam, > 3 kW: schneller), Linienstärke 2–5 px ∝ Leistung, Richtung durch Punktbewegung, nicht durch Pfeilspitzen.
Farben: PV Amber, Netz Mist (Bezug) / Amber-Soft (Export), Batterie Teal (`--battery`), Wärmepumpe/Wallbox neutral
(`--paper` 60 %). Wert am Knoten als Mono-Zahl 28 px, Einheit 13 px. Kein Fluss unter 0,05 kW. Bei `STALE` wird
der Knoten gedimmt und mit Alter versehen. Unter `prefers-reduced-motion` stehen die Punkte und die Richtung wird
durch einen kleinen Chevron gezeigt.

**Intelligence Card (`IntelligenceCard`):** vier Abschnitte mit Mono-Kickern JETZT / ENTSCHEIDUNG / WARUM /
AUSBLICK. Die Entscheidung ist der größte Text der Karte (22–26 px SemiBold). „Warum“ als Liste der Reason-Codes
mit Inputs (max. 3). „Ausblick“ aus `next_expected` und Plan. Der Header trägt eine dünne 3-px-Amber-Linie oben
wie das `product-window` der Website. Bei Override färbt sich der Kicker „ENTSCHEIDUNG“ zu „MANUELL BIS 16:30“.

**Pufferspeicher (`BufferTank`):** vertikaler Zylinder (SVG, `rx` klein, 2 px Kontur mit 0,17 Alpha), Füllung als
`linearGradient` mit vier Stops an den Sensorhöhen (Farbe aus der Temperatur über eine Skala: ≤ 25 °C Petrol-Blau
`#1F4C66`, 40 °C Mist, 50 °C Amber-Soft, 60 °C Amber, ≥ 70 °C Ember). Zwischen den Stops interpoliert der Browser
weich. Die vier Messwerte stehen rechts auf Sensorhöhe (Mono 20 px), darunter SOC in 40 px, Status-Wort und
Trend (K/h aus 30-min-Differenz). Optional eine Marke für T_min/T_target am Zylinder. Pelletofen-Hinweis: Wenn der
Puffer sich erwärmt, ohne dass die Wärmepumpe läuft, zeigt die Karte dezent „Fremdwärme (Pelletofen?)“.

**Tageschart (`DayChart`, ECharts):** linke Achse kW (PV Amber gefüllt mit 0,18-Alpha-Verlauf, Wärmepumpe Paper
70 %, Wallbox Mist), rechte Achse ct/kWh (Stufenlinie, Mist, 2 px; negative Preise unter der Nullinie mit
Ember-Füllung). Jetzt-Linie als `markLine` gestrichelt Amber. Zukunft: PV-Prognose als gestrichelte Amber-Linie
(7-7), Preis für morgen als gestrichelte Mist-Linie, Außentemperatur optional als dünne dritte Serie.
`markArea`-Bänder: geplante Laufzeiten (Amber 0,10), günstiges Fenster (Mist 0,08), „vermeiden“ (Ember 0,06),
jeweils mit Kurz-Label am oberen Rand. Tooltip bei Tipp/Halten: Zeit, alle Werte, Reason des Intervalls.
Zeitraumwahl (Heute/Gestern/7 Tage/benutzerdefiniert) als Segmentschalter oben rechts (Phase 2).

**Steuerkacheln (`ControlTile`):** 96 px hoch, Icon links, Label Sans 15 px, Zustand Mono 13 px Versalien
(AN/AUS/AUTO), rechter Rand 3 px Amber wenn aktiv. Tippen → optimistischer Zustand mit Ladepunkt → Ack → fest;
Fehlschlag → Ember-Rand + „Fehler – nicht bestätigt“ + Rücksprung. Wärmepumpe als Segment AUTO | AN | AUS, bei
AN/AUS mit Dauer-Chooser (30 min / 2 h / 6 h) im Bottom-Sheet und Restzeit-Anzeige. Ein Long-Press zeigt Details
(Entität, letzte Schaltung, TTL).

**Zustände:** Skeletons beim Laden (keine leeren Karten), „–“ statt 0 bei fehlenden Werten, Offline-Banner unter
dem Header, Fehlertexte in ganzen Sätzen auf Deutsch.

### 13.5 Abgrenzung zum heutigen Home-Assistant-Dashboard

Das HA-Dashboard zeigt vieles gleichwertig nebeneinander (Chart, Tank, Fluss, Schalter). Duck Curve Home ordnet
nach Frage (was / warum / was kommt), reduziert Rahmen auf 1-px-Linien, ersetzt gesättigte Signalfarben durch die
Markenpalette mit einem Akzent, macht Zahlen zu Typografie (Mono, groß, Komma-Dezimal) und gibt der Begründung
eine eigene Spalte statt eines Tooltips.

## 14. Empfohlene Projektphasen

| Phase | Inhalt | Definition of Done | Aufwand (grob) |
|---|---|---|---|
| **0 Analyse** | dieses Dokument | Freigabe der Architektur und der offenen Fragen | erledigt |
| **Entscheidung Hosting** | Profil A (lokal) oder B (Railway), Abschnitt 15 | Entscheidung des Betreibers, spätestens vor Phase 2 | – |
| **1 UI-Prototyp / Demo-Modus** | Monorepo-Skelett, Tokens/Design-System, `hems-core` mit Domänenmodell, Thermal-SOC, Bilanzierer, Simulation (`demo_house`), API mit In-Memory-Repositories und SSE, Dashboard mit Energiefluss, Tageschart, Puffer, Steuerkacheln (gegen Simulation), Intelligence Card mit simulierten Entscheidungen, Zeitraffer (24 h in 5 min), CI (Web + Python), Docker-Compose, README/ARCHITECTURE/CONFIGURATION/HEMS_CONTROL Erstfassung | `docker compose up` startet Demo ohne Haus; Playwright-Smoke grün; Tests für SOC, Bilanz, Simulation; Dashboard läuft 24 h stabil im Browser-Kiosk | 2–3 Wochen |
| **2 Read-only Live** | Bridge mit eigenen Geräteintegrationen (Shelly über Mosquitto/MQTT, MyEnergi-Cloud-API, SolarEdge Modbus), `devices.yaml` + Discovery, Ringpuffer, Uplink; API-Ingest; Postgres + Alembic (Messwerte gestuft, Events, Konfiguration); Tibber-Preise (+ Pulse, falls vorhanden); Wetter (Open-Meteo); PV-Forecast v1; History-API; Zeitraumwahl; Deployment nach gewähltem Profil (A: Compose auf dem Haus-Rechner + Cloudflare Tunnel; B: Railway + Bridge-Host); Kiosk-Pairing | echte Werte auf dem iPad ohne Home Assistant; Ausfallszenarien (WLAN, Bridge-Neustart, Backend-Deploy, MyEnergi-Cloud down) getestet; Nachlieferung aus dem Ringpuffer nach 1 h Offline nachgewiesen | 4–5 Wochen |
| **3 Manuelle Steuerung** | Shelly-Kommandos mit `toggle_after`/TTL/Ack über Bridge, Kacheln aktiv, Wärmepumpe MANUAL mit Dauer, Guardian-Prozess, Auto-Off als Geräteeinstellung, bestehende HA-Automation für die Wärmepumpe deaktiviert, Verhalten der ELCO auf K1/K2 protokolliert | Kaffee/Licht/K1 schaltbar; Rückfall-Tests E0–E2 durchgeführt und dokumentiert | 2 Wochen |
| **4 Rule-Based HEMS** | Controller-Zustandsmaschine, Guards, PV-/Preisregeln, Reason-Codes, Decision-Persistenz, Intelligence Card mit echten Begründungen, vollständige Unit-Tests der geforderten Fälle (Hysterese, Mindestzeiten, PV, negative Preise, Puffer voll, Override, Sensorausfall, Tibber-Ausfall) | mindestens 2 Wochen Betrieb AUTO/PV ohne Eingriff; Events zeigen keine Guard-Verletzung | 3 Wochen |
| **5 Smart Scheduler** | Wärmebedarfsmodell, Puffermodell, Forecast-Aware-Planner, Plan-Persistenz, Plan-Bänder im Chart, Kalibrierungsjobs, optional K2 nach Validierung | Plan erklärt jedes Intervall; PV-Forecast-Fehler < 20 % Tages-kWh nach Kalibrierung; K2 nur mit dokumentiertem Freigabetest | 3–4 Wochen |
| **6 Optimizer** | MILP-Planer (HiGHS), Gebäude-RC-Modell, Komfortgrenzen, Vergleich Regel vs. Optimum im Dashboard | Optimum-Plan im Schattenbetrieb 4 Wochen mit Kostenvergleich, dann aktiv | 4+ Wochen |

Jede Phase beginnt mit einer kurzen Standortbestimmung (Was ist da, was hat sich geändert, Plan in 10 Zeilen), endet
mit Tests, Doku-Update und einer ADR pro wesentlicher Entscheidung.

## 15. Hosting-Zielarchitektur: lokal (empfohlen) oder Railway

Der Auftrag nennt Railway als Zielplattform. Nach der Entscheidung, ohne Home Assistant direkt auf die Geräte
zuzugreifen, verschiebt sich die Abwägung: Alle Datenquellen und alle Aktoren stehen im Haus, das Anzeigegerät auch.
Deshalb werden **zwei Deployment-Profile** vorgesehen, die dieselben Docker-Images und denselben Code nutzen. Der
einzige Unterschied ist, wo Datenbank, API, Worker und Geräteschicht laufen und ob die Geräteschicht als eigener
Prozess mit Uplink („Bridge“) oder als Modul im Worker („in-process“) arbeitet.

### 15.1 Vergleich

| Kriterium | **Profil A: lokal auf einem Mini-Rechner** (Raspberry Pi 5 / Intel NUC, Docker Compose) | **Profil B: Railway + Bridge im Haus** |
|---|---|---|
| Geräte erreichen | direkt im LAN, kein Tunnel | nur über Bridge und ausgehende WSS-Verbindung (Abschnitt 17) |
| Regelung bei Internetausfall | **läuft weiter** (PV-Regel, Guards, Plan mit zuletzt bekannten Preisen) | pausiert; Kontakte fallen nach 3 min zurück |
| Dashboard auf dem iPad | über LAN, ~1 s Latenz, funktioniert ohne Internet | über Internet, abhängig von WLAN **und** Internet |
| Externe Erreichbarkeit (unterwegs) | Cloudflare Tunnel (`cloudflared`, kostenlos, kein offener Port) + Cloudflare Access als Login davor; alternativ Tailscale | nativ öffentlich, eigene Auth |
| Komponenten | 1 Host: postgres, api, worker (inkl. Geräteschicht), web, mosquitto, guardian, cloudflared | Railway: web, api, worker, postgres · Haus: bridge, mosquitto, guardian |
| Protokolle zu bauen | keiner (Geräteschicht ruft Repositories direkt) | Bridge-Uplink-Protokoll mit Sequenzen, Acks, Ringpuffer, Token-Rotation (17.2) |
| Deployment | GitHub Actions baut Images (arm64/amd64) → GHCR; Host aktualisiert per Watchtower oder `compose pull` nach Tag; Migrationen im Start-Container | Railway-GitHub-Integration, `preDeployCommand` |
| Betrieb/Zuverlässigkeit | Hardware selbst verantwortet: SSD statt SD-Karte, USV empfehlenswert, Hardware-Watchdog; Postgres-Backups per Job in Objektspeicher | Managed Postgres mit Snapshots, Neustart durch Plattform; Bridge-Host bleibt trotzdem nötig |
| Kosten | einmalig 100–250 € Hardware, Strom ~5 W | ~10–25 €/Monat |
| Update-Komfort | gut mit Watchtower, aber ein Host, den man warten muss | sehr gut |
| Rechenleistung | Pi 5 (8 GB) reicht für Postgres + FastAPI + Next.js + MILP (HiGHS, Sekundenbereich); NUC komfortabler | unbegrenzt |
| Sicherheitsfläche | kein eingehender Port; Cloudflare Access/Tailscale vor dem Dashboard | ein öffentlicher API-Endpunkt für die Bridge |

**Empfehlung: Profil A.** Ein HEMS, dessen Sensoren und Aktoren ausnahmslos im Haus stehen, gehört ins Haus. Die
Regelung ist dann vom Internet unabhängig, die Architektur hat eine Schicht weniger, und der externe Zugriff ist über
einen Tunnel ohne offenen Port lösbar. Railway bleibt als Profil B vollständig unterstützt (gleiche Images, gleiche
Konfiguration, zusätzlich Bridge-Uplink) – zum Beispiel, wenn später mehrere Häuser oder ein Betrieb ohne eigene
Hardware gewünscht sind. Die Entscheidung ist **vor Phase 2** zu treffen; Phase 1 (Demo-Modus) ist davon unabhängig,
weil sie ohnehin per Docker Compose läuft.

Damit beide Profile ohne Code-Duplikation funktionieren, ist die Geräteschicht (`apps/bridge`, intern
`dch_gateway`) eine Bibliothek mit zwei Hüllen: `in-process` (Worker importiert sie und schreibt direkt in Postgres)
und `uplink` (eigener Prozess mit Ringpuffer und WSS). Die Adapter für Shelly, MyEnergi und SolarEdge sind in beiden
Fällen identisch.

### 15.2 Profil A – lokaler Host

```
Mini-Rechner im LAN (Docker Compose, arm64 oder amd64)
├── postgres     PostgreSQL 16, Volume auf SSD, tägliches pg_dump → Objektspeicher (R2/B2) + lokale Kopie
├── api          FastAPI, Port 8000 (nur intern), SSE, REST
├── worker       Control-Loop, Planer, Forecast-Jobs, Aggregation, Geräteschicht in-process
├── web          Next.js, Port 3000 (nur intern)
├── mosquitto    MQTT-Broker für Shellys, Port 1883 (nur LAN)
├── guardian     unabhängiger Wächter (11.2 E1)
├── caddy        Reverse-Proxy mit lokalem TLS (home.local / mDNS) für das iPad im LAN
└── cloudflared  Tunnel → home.duckcurve.de, davor Cloudflare Access (E-Mail-OTP oder Google-Login)
```

- Das iPad spricht `https://home.local` (Caddy, internes Zertifikat, Root-CA einmal auf dem iPad installiert) oder
  direkt `http://<ip>:3000` – kein Internet nötig.
- Von außen: `https://home.duckcurve.de` → Cloudflare Access (Identität) → Tunnel → Caddy → web. Die Anwendung
  behält zusätzlich ihre eigene Session (Kiosk-Pairing), Cloudflare Access ist die zweite Schranke.
- Updates: GitHub Release-Tag → Images auf GHCR → Watchtower zieht in einem Wartungsfenster (03:30) oder manuell.
  Migrationen laufen in einem `migrate`-Init-Container vor `api`/`worker` (`alembic upgrade head`), nur additiv
  (23.4).
- Health: `api`/`worker` exportieren `/health`; ein kleiner Uptime-Check (Cloudflare Health Check oder Healthchecks.io
  Ping aus dem Worker) meldet Ausfälle aufs Handy.
- Hardware: Pi 5 8 GB mit NVMe-HAT oder NUC, USV (z. B. kleine Line-Interactive-USV oder Pi-UPS-HAT), LAN-Kabel,
  Hardware-Watchdog aktiviert.

### 15.3 Profil B – Railway

```
Railway Project „duckcurve-home“  (Region: EU-West, gleiche Region für alle Services)
│
├── web        Next.js (Dockerfile apps/web)        Root Directory: apps/web
│              PORT von Railway, öffentlich: home.duckcurve.de (Custom Domain, TLS von Railway)
│              Env: DCH_API_URL=http://api.railway.internal:8000, DCH_SESSION_SECRET
│              Healthcheck: GET /api/health (BFF prüft API-Erreichbarkeit)
│
├── api        FastAPI (Dockerfile apps/api, CMD uvicorn)   Build-Kontext Repo-Root*
│              öffentlich NUR für den Bridge-Endpunkt wss://api-home.duckcurve.de/bridge/ws
│              intern für web über *.railway.internal (IPv6 → uvicorn --host ::)
│              Env: DATABASE_URL, DCH_ROLE=api, DCH_BRIDGE_TOKEN_PEPPER, DCH_TIBBER_TOKEN, …
│              Healthcheck: GET /health  (DB-Ping, Bridge-Status, Version)  ·  Replicas: 1
│
├── worker     gleiches Image wie api, CMD python -m dch_api.worker, DCH_GATEWAY=remote
│              Healthcheck: GET /health auf Port 8001 (Tick-Alter, Leader-Status)  ·  Replicas: genau 1 + Advisory-Lock
│
├── postgres   Railway PostgreSQL 16, tägliches Backup (Railway) + wöchentlicher pg_dump nach R2/B2 (Job)
│
└── Haus: bridge + mosquitto + guardian (Docker Compose auf einem Mini-Rechner)
```

\* Weil `apps/api` das Workspace-Paket `packages/hems-core` braucht, wird das Python-Image vom Repo-Root gebaut
(`RAILWAY_DOCKERFILE_PATH=apps/api/Dockerfile`, Root Directory leer, Watch Paths `apps/api/**`, `packages/**`).

`railway.json` je Service:

```json
{
  "$schema": "https://railway.com/railway.schema.json",
  "build": { "builder": "DOCKERFILE", "dockerfilePath": "apps/api/Dockerfile" },
  "deploy": {
    "startCommand": "uvicorn dch_api.main:app --host :: --port $PORT",
    "preDeployCommand": "alembic upgrade head",
    "healthcheckPath": "/health",
    "healthcheckTimeout": 120,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 5,
    "numReplicas": 1
  }
}
```

Skalierung und Zustand: Die API hält die Bridge-WebSocket- und die SSE-Verbindungen prozesslokal; mit einer Replika
unkritisch. Deploy-Rollover: Bridge reconnectet in < 5 s, Ringpuffer überbrückt, Dashboard reconnectet. Domains:
`home.duckcurve.de` → web, `api-home.duckcurve.de` → api (nur `/health` und `/bridge/ws` öffentlich nutzbar).

### 15.4 Gemeinsam für beide Profile

- Ein Satz Images (`duckcurve-api`, `duckcurve-web`, `duckcurve-bridge`), Konfiguration über `DCH_*`-Variablen,
  `DCH_GATEWAY=inprocess|remote` wählt das Profil.
- Dieselbe Postgres-Struktur, dieselben Migrationen, dieselbe Retention.
- Dieselbe Sicherheitsarchitektur für die Kontakte (Abschnitt 11) – der Guardian läuft in beiden Profilen auf dem
  Haus-Rechner.

## 16. PostgreSQL-Datenmodell

Schema `dch` (nicht `public`), Zeitstempel `timestamptz`, IDs `uuid` (v7 wenn verfügbar, sonst v4), Konfigurationen
und variable Strukturen als `jsonb` mit Pydantic-Validierung im Backend. Zeilen, die abgefragt oder gefiltert werden,
bekommen Spalten; alles andere bleibt Payload (valyze-Regel).

### 16.1 Tabellen

**Stammdaten und Konfiguration**

| Tabelle | Zweck | Wichtige Spalten |
|---|---|---|
| `devices` | Geräte (PV, Batterie, Wallbox, Wärmepumpe, Puffer, Relais, Sensoren) | `id, kind, name, vendor, model, location, meta jsonb` |
| `sensors` | Messpunkte mit Quelle und Mapping (Spiegel der `devices.yaml`, von der Bridge beim Handshake gemeldet) | `id, device_id, key` (z. B. `pv_power_kw`), `source` (`shelly`, `myenergi`, `solaredge`, `tibber`, `derived`), `source_ref` (Topic/Register/Feld), `unit, stale_after_s, sign_convention, priority, enabled` |
| `actuators` | steuerbare Ausgänge | `id, device_id, key, source_ref` (Shelly-ID + Kanal), `label, safety_class` (`none`, `heat_pump`), `safe_state, default_ttl_s, hw_auto_off_s` |
| `device_health` | letzter Gesundheitszustand je Quelle (von der Bridge gemeldet) | `source pk, status, since, last_ok_at, error, details jsonb` |
| `config_versions` | versionierte Gesamtkonfiguration (Haus, Anlage, Regler, Komfort) | `id, created_at, created_by, kind` (`site`, `control`, `comfort`, `dashboard`), `payload jsonb, comment, active bool` – genau eine aktive Version je `kind` |
| `users` | Betreiberkonten | `id, email, password_hash (argon2id), role, created_at` |
| `kiosk_devices` | gepaarte Anzeigegeräte | `id, name, paired_at, last_seen_at, session_token_hash, revoked_at` |
| `bridge_credentials` | Bridge-Tokens | `id, name, token_hash, created_at, rotated_at, last_seen_at, revoked_at` |

**Zustand und Steuerung**

| Tabelle | Zweck | Spalten |
|---|---|---|
| `live_state` | Spiegel des letzten Werts je Sensor (für Worker, Health, Reconnect) | `sensor_key pk, value, observed_at, quality, source, received_at` |
| `system_modes` | Verlauf der Betriebsmodi | `id, at, system_mode, auto_profile, set_by, reason` |
| `overrides` | manuelle Übersteuerungen | `id, target` (`heat_pump`, `actuator:<key>`), `kind, state, started_at, ends_at, set_by, ended_at, ended_reason` |
| `control_decisions` | jede Regler-Entscheidung (auch „keine Änderung“ nur bei Zustandswechsel oder alle 5 min) | `id, at, controller_state, k1_release, k2_block, reasons text[], blocked_by text[], inputs jsonb, valid_until, next_expected jsonb, explanation_de, plan_id` |
| `actuator_commands` | Kommandos an die Bridge | `id, at, actuator_key, desired_state, ttl_s, decision_id, override_id, status` (`queued, sent, acked, failed, expired`), `sent_at, acked_at, error` |
| `heat_pump_runs` | erkannte Laufphasen (aus Leistung) | `id, started_at, ended_at, energy_kwh, avg_power_kw, triggered_by_decision_id, reason_code` |
| `system_events` | Ereignisse/Fehler (Bridge online/offline, Failsafe, Sensor stale, Deploy) | `id, at, severity, code, message, context jsonb, acknowledged_at` |
| `bridge_sessions` | Verbindungsprotokoll der Bridge | `id, connected_at, disconnected_at, remote_version, clock_offset_ms, frames_in, frames_out` |

**Messwerte**

| Tabelle | Zweck | Spalten / Besonderheit |
|---|---|---|
| `measurements_raw` | Rohwerte in Gerätetaktung (1–15 s) – **die einzige Rohdatenquelle des Systems** | `(sensor_key, observed_at) pk, value real, quality smallint`; **partitioniert nach Tag** (`PARTITION BY RANGE (observed_at)`), Retention 14 Tage (Partition droppen, nicht `DELETE`) |
| `measurements_10s` | 10-Sekunden-Mittel (für Detailansichten und Regler-Nachanalyse) | `(sensor_key, bucket) pk, avg, min, max, samples`; Partition wöchentlich, Retention 180 Tage |
| `measurements_1min` | Minutenmittel (Tages-/Wochencharts) | `(sensor_key, bucket) pk, avg, min, max, samples`; Partition monatlich, Retention 3 Jahre |
| `measurements_15min` | Planungsraster, Kalibrierung | `(sensor_key, bucket) pk, avg_kw, energy_kwh, min, max, samples`; unbegrenzt |
| `counters` | Zählerstände (Shelly-Energie, Zappi/Libbi-Energie, Wechselrichter-Gesamtertrag) für exakte Energiebilanzen | `(counter_key, observed_at) pk, value_kwh`; 15-min-Stützstellen, unbegrenzt |
| `energy_daily` | Tagesbilanzen | `date, pv_kwh, import_kwh, export_kwh, battery_in_kwh, battery_out_kwh, hp_kwh, ev_kwh, base_kwh, cost_eur, revenue_eur, self_sufficiency` |

**Forecasts und Pläne** (Details 21/22)

| Tabelle | Zweck |
|---|---|
| `forecast_runs` | ein Abruf/eine Berechnung: `id, kind` (`weather`, `pv`, `price`, `heat_demand`, `load`), `provider, issued_at, horizon_start, horizon_end, resolution_min, params jsonb, quality jsonb` |
| `forecast_points` | Werte: `(run_id, ts) pk, value, value_lo, value_hi` (Bänder optional) – Partition monatlich |
| `forecast_latest` | Materialisierte Sicht: aktuellster Wert je `kind, ts` für die Chart-Abfrage |
| `plans` | Planlauf: `id, planner, created_at, horizon_start, horizon_end, inputs jsonb, objective jsonb, status` |
| `plan_intervals` | `(plan_id, ts) pk, expected_pv_kw, expected_load_kw, expected_heat_demand_kw_th, price_ct_kwh, planned_hp_state, planned_buffer_soc, reason_code, note` |
| `model_calibrations` | `id, model` (`pv`, `heat_demand`, `buffer`), `valid_from, params jsonb, metrics jsonb` |

### 16.2 Indizes und Zugriffsmuster

- `measurements_*`: PK `(sensor_key, ts)` deckt die Chart-Abfrage „Sensor X von–bis“ ab; zusätzlicher BRIN auf `ts`
  für Partition-Pruning-Hilfe ist bei Tagespartitionen unnötig.
- `control_decisions(at desc)`, `system_events(at desc, severity)`, `actuator_commands(status, at)`.
- `forecast_points(run_id, ts)`; `forecast_latest` als Tabelle, die der Worker nach jedem Run neu schreibt (kein
  `REFRESH MATERIALIZED VIEW` auf großen Tabellen).

### 16.3 Retention und Aggregation

Worker-Job alle 10 min: `raw → 10s → 1min` (für den letzten abgeschlossenen Zeitraum), stündlich `1min → 15min`,
täglich `15min → daily`; danach Partitionen älter als Retention droppen. Aggregation ist idempotent
(`INSERT … ON CONFLICT DO UPDATE`), damit die Nachlieferung aus dem Bridge-Ringpuffer dieselben Wege nutzt.

Volumenabschätzung (≈ 15 Sensoren): Rohwerte ≈ 0,6–1,3 Mio. Zeilen/Tag → 14 Tage ≈ 15 Mio. Zeilen ≈ 1 GB;
10-s-Stufe 180 Tage ≈ 23 Mio. Zeilen ≈ 1,2 GB; 1-min-Stufe 3 Jahre ≈ 24 Mio. Zeilen ≈ 1,3 GB; 15-min unbegrenzt
≈ 0,5 Mio. Zeilen/Jahr. Gesamt stabil unter ~5 GB – im Railway-Rahmen unkritisch.

### 16.4 Eine Datenbank, klare Rollen

| Datenart | Ort | Aufbewahrung |
|---|---|---|
| Rohmesswerte aller gemappten Sensoren | `measurements_raw` (Postgres) | 14 Tage |
| Verdichtete Zeitreihen | `measurements_10s/1min/15min`, `energy_daily`, `counters` | 180 Tage / 3 Jahre / unbegrenzt |
| Lokale Reserve | Ringpuffer der Bridge (SQLite) | 7 Tage, nur für Nachlieferung |
| Konfiguration, Modi, Overrides, Entscheidungen, Kommandos, Forecasts, Pläne, Events | Postgres | unbegrenzt bzw. gemäß Tabelle |

Backups: Railway-Snapshots täglich; zusätzlich wöchentlicher `pg_dump` (komprimiert) in einen Objektspeicher
(Cloudflare R2 oder Backblaze B2, Env-konfiguriert) als Worker-Job; Wiederherstellung ist dokumentierter Bestandteil
von Phase 2 (Restore-Probe auf leere DB in CI).

### 16.5 TimescaleDB-Bewertung

Da Postgres nun **alle** Rohmesswerte trägt, ist der Nutzen von Timescale (Hypertables, Compression, Continuous
Aggregates) größer als in Revision 1. Dagegen spricht weiterhin: Railways Standard-Postgres hat die Extension nicht;
ein eigenes Timescale-Image bedeutet Backup/Upgrade in eigener Hand. Bei ~15 Sensoren bleiben native Partitionen
mit gestufter Retention beherrschbar (16.3). **Entscheidung:** Postgres nativ in v1; Repository-Schicht und
Aggregationsjob so schneiden, dass ein Wechsel zu Hypertables nur Migrationen betrifft. Re-Evaluation, wenn mehr als
~50 Sensoren, dauerhaft > 1 Hz oder eine Rohdaten-Aufbewahrung > 30 Tage gewünscht wird.

## 17. Sichere Verbindung Railway ↔ Haus

### 17.1 Bewertete Optionen

Ausgangslage: Die Shellys, der MyEnergi-Hub und der SolarEdge-Wechselrichter haben private LAN-Adressen und sind
aus dem Internet **nicht erreichbar** – und sollen es auch nicht werden. Eine Cloud kann sie also nie direkt
ansprechen. Dieser Abschnitt gilt für das Profil **B (Railway)** aus Abschnitt 15; im Profil **A (lokal)** entfällt
der Tunnel, weil Anwendung und Geräte im selben LAN stehen.

| Option | Richtung | Bewertung |
|---|---|---|
| Geräte per Port-Forwarding öffentlich machen | Cloud → Haus | **abgelehnt**: Shelly-Weboberflächen und Modbus ohne TLS im Internet sind ein erhebliches Risiko |
| Shelly-Cloud-API + MyEnergi-Cloud + SolarEdge-Cloud direkt aus Railway | Cloud → Hersteller-Clouds | für MyEnergi ohnehin nötig; Shelly-Cloud nur Gen2 mit eigenem Key, Latenz mehrere Sekunden, Batteriesensoren nur Cloud-seitig gecacht, SolarEdge-Cloud 15-min – kein Live, kein lokaler Betrieb, drei Fremdabhängigkeiten für Schaltbefehle: **abgelehnt** |
| Home Assistant als Vermittler (REST/WebSocket, Nabu-Casa-URL) | Cloud → HA | technisch möglich, macht Duck Curve Home aber dauerhaft von HA abhängig – vom Betreiber ausgeschlossen |
| VPN/Tailscale zwischen Railway und Haus | beidseitig | Railway hat keinen nativen Tailscale-Sidecar; Userspace-Tailscale im Container ist möglich, aber fragil bei Deploys; die Cloud bekäme Zugriff auf das ganze Hausnetz – mehr als nötig |
| MQTT-Broker in der Cloud, Shellys publizieren direkt | Haus → Cloud | Shellys können nur einen Broker; TLS/Auth auf jedem Gerät pflegen; Gen1 ohne TLS-MQTT; Modbus/MyEnergi bräuchten trotzdem einen lokalen Vermittler |
| **Lokaler Agent (Bridge) mit ausgehender WSS-Verbindung** | **Haus → Cloud** | **gewählt für Profil B**: minimale Angriffsfläche (kein offener Port im Haus), volle Kontrolle über Protokoll, Puffer und Failsafe, alle Gerätezugänge bleiben im LAN, ein einziger Tunnel nach außen |

### 17.2 Bridge-Protokoll (v1)

- Transport: `wss://api-home.duckcurve.de/bridge/ws`, TLS 1.2+ (Railway-Zertifikat), Pinning der Railway-CA nicht
  nötig; optional mTLS später, wenn Railway Client-Zertifikate durchreicht (heute nicht) – daher Token-Auth.
- Authentifizierung: `Authorization: Bearer <bridge_token>` im Upgrade-Request. Token = 32 Byte zufällig,
  serverseitig nur als Argon2id/SHA-256-HMAC-Hash mit Pepper gespeichert. Erstausgabe über die Einstellungs-UI
  (einmal anzeigen), Rotation: neuer Token wird ausgegeben, alter bleibt `grace_h` (Default 24) gültig, dann
  widerrufen; die Bridge holt den neuen Token beim nächsten Handshake ab (Frame `credentials.rotate`) und schreibt
  ihn in ihre lokale Secret-Datei (0600).
- Frames (JSON, später optional MessagePack):
  `hello {bridge_version, entity_map_hash, clock}` → `welcome {server_time, config_version, wanted_entities}`;
  `telemetry {seq, items:[{key, value, observed_at, quality}]}` → `ack {seq}`;
  `command {command_id, actuator_key, state, ttl_s}` → `command_result {command_id, ok, observed_state, error}`;
  `heartbeat` beidseitig alle 15 s; `backlog {seq_from, items…}` (Nachlieferung aus dem Ringpuffer); `device_health {source, status, …}`;
  `event {code, message, context}`.
- Sequenznummern und Ack: Die Bridge hält eine SQLite-Queue (`queue.db`, WAL). Frames werden erst nach `ack`
  gelöscht. Nach Reconnect sendet sie ab der letzten nicht bestätigten Sequenz (Backlog komprimiert auf 1-min-Bins,
  wenn > 1 h Rückstand; Rohdaten bleiben 7 Tage im Ringpuffer der Bridge). Maximale Queue 7 Tage, danach älteste verwerfen.
- Reconnect: exponentiell 1 s → 60 s mit Jitter, DNS neu auflösen, TLS-Fehler protokollieren.
- Uhrzeit: Bridge nutzt NTP des Hosts; Server misst Offset im Handshake; > 60 s Offset → Event + FAILSAFE (11.3).
- Replay-Schutz: `command_id` einmalig, Kommandos mit `issued_at` älter als 30 s werden von der Bridge verworfen.
- Rate-Limits serverseitig pro Bridge-Token; nur eine gleichzeitige Verbindung pro Token (neuere gewinnt, ältere
  wird mit Code `superseded` geschlossen).

### 17.3 Secrets Management

| Secret | Ort | Rotation |
|---|---|---|
| `DATABASE_URL` | Railway-Variable (Referenz auf Postgres-Service) | Railway |
| `DCH_SESSION_SECRET` (web) | Railway-Variable, ≥ 32 Byte | manuell, invalidiert Kiosk-Sessions |
| `DCH_BRIDGE_TOKEN_PEPPER` (api) | Railway-Variable | praktisch nie (macht alle Bridge-Tokens ungültig) |
| Bridge-Token | Bridge-Host `/etc/duckcurve/bridge.secret` (0600) oder Docker-Secret | über UI, Grace-Period |
| Shelly-Gerätepasswörter | nur Bridge (`DCH_BRIDGE_SHELLY_PASSWORD`, optional je Gerät) | am Gerät ändern, Bridge-Env tauschen |
| Mosquitto-Zugang | nur Bridge-Compose (`DCH_BRIDGE_MQTT_PASSWORD`), Passwortdatei im Broker-Volume | lokal |
| MyEnergi Hub-Seriennummer + API-Key | nur Bridge (`DCH_BRIDGE_MYENERGI_*`) | API-Key in der MyEnergi-App neu erzeugen |
| SolarEdge Cloud-API-Key (optional) | nur Bridge | im Monitoring-Portal |
| Tibber-Token, Solcast-Key | Railway-Variablen (worker) | Anbieter |
| Kiosk-Session | HttpOnly-Cookie (iron-session-Muster), 180 Tage, widerrufbar | in UI |

Regeln: keine Secrets im Repo (`.env.example` enthält nur Namen), `gitleaks` in CI, Secrets erscheinen nie in Logs
(structlog-Processor maskiert bekannte Schlüssel), `/health` gibt keine Verbindungsdaten preis.

### 17.4 Offline-Betrieb der Bridge

Ohne Cloud: Die Bridge liest weiter alle Geräte und füllt den Ringpuffer (7 Tage), hält den lokalen Heartbeat für
den Guardian, setzt nach `offline_release_s` alle Wärmepumpen-Kontakte auf `safe_state` und schreibt einen lokalen
Event. Es gibt in Profil B **keine** lokale Regelung – die Wärmepumpe läuft dann so, wie sie es auch ohne Duck Curve
Home täte. Die Status-Seite der Bridge (`http://bridge:8080`, nur LAN) zeigt Live-Werte, Gerätegesundheit,
Puffer-Stand, Verbindung, Uhrzeitversatz und letzte Kommandos – ein Minimal-Dashboard für den Störfall. (Im Profil A
läuft die Regelung lokal und ist vom Internet unabhängig – einer der Hauptgründe für die Empfehlung.)

## 18. Weather Forecast Provider

### 18.1 Interface (`hems_core.forecasting.protocols`)

```python
class WeatherPoint(BaseModel):
    ts: datetime                    # Intervallbeginn UTC
    temp_c: float
    apparent_temp_c: float | None
    ghi_w_m2: float | None          # Globalstrahlung horizontal
    dni_w_m2: float | None
    dhi_w_m2: float | None
    cloud_cover: float | None       # 0–1
    precipitation_mm: float | None
    wind_speed_m_s: float | None
    humidity: float | None

class WeatherForecast(BaseModel):
    provider: str
    issued_at: datetime
    location: GeoPoint
    resolution_min: int             # 60 (Open-Meteo hourly) oder 15 (Open-Meteo minutely_15 für 3 Tage)
    points: list[WeatherPoint]
    sun_events: list[SunEvent]      # sunrise/sunset je Tag

class WeatherProvider(Protocol):
    name: str
    async def fetch(self, location: GeoPoint, horizon_h: int) -> WeatherForecast: ...
```

### 18.2 Provider v1: Open-Meteo

- Endpoint `https://api.open-meteo.com/v1/forecast` mit `hourly=temperature_2m,apparent_temperature,
  shortwave_radiation,direct_normal_irradiance,diffuse_radiation,cloud_cover,precipitation,wind_speed_10m,
  relative_humidity_2m`, `daily=sunrise,sunset`, `forecast_days=7`, `timezone=UTC`, `models=best_match` (für
  Deutschland ICON-D2/ICON-EU). Optional `minutely_15` für die ersten 72 h (passend zum Planungsraster).
- Kostenlos ohne Key (Fair Use ≤ 10.000 Anfragen/Tag); wir rufen stündlich ab → 24/Tag.
- Standort aus Konfiguration (`site.latitude/longitude/elevation`, Geilenkirchen ≈ 50,97 N / 6,12 O; genaue
  Koordinaten offene Frage 25.6).
- Fehlerfall: letzter Forecast bleibt gültig (mit `issued_at`-Anzeige); nach 12 h ohne Update Event `weather_stale`.

Weitere Provider (Interface identisch): DWD Open Data (MOSMIX, ICON-D2 direkt), Met.no, Bright Sky (DWD-Wrapper,
sehr einfach). Ein `CompositeWeatherProvider` kann Fallback-Reihenfolgen abbilden.

### 18.3 Persistenz

Jeder Abruf → `forecast_runs(kind="weather", provider="open_meteo")` + `forecast_points` je Größe (mehrere Größen
in `forecast_points` über `variable`-Spalte; Alternative: eine breite Tabelle `weather_points` – gewählt: breite
Tabelle für Wetter, weil immer alle Größen zusammen gelesen werden; generische `forecast_points` für skalare
Reihen wie PV und Preis). Historische Forecasts bleiben 90 Tage (für Kalibrierung Forecast vs. Ist), ältere werden
auf den „letzten Forecast vor Intervallbeginn“ verdichtet.

## 19. PV Forecast Provider

### 19.1 Konfiguration

```yaml
site:
  name: Geilenkirchen
  latitude: 50.97      # TODO exakt
  longitude: 6.12
  elevation_m: 80
  timezone: Europe/Berlin
pv_system:
  arrays:
    - name: main_roof
      capacity_kwp: 9.9        # TODO
      azimuth_deg: 180         # 0 = Nord, 90 = Ost, 180 = Süd, 270 = West
      tilt_deg: 35
      module_temp_coeff_per_k: -0.0035
    # - name: east_roof …
  inverter_ac_kw: 8.25         # SolarEdge, TODO
  loss_factor: 0.14            # Kabel, Verschmutzung, Mismatch, Optimierer
  export_limit_kw: null        # 70-%-Regel o. Ä., falls vorhanden
```

### 19.2 Zwei Strategien hinter einem Interface

```python
class PvForecast(BaseModel):
    provider: str
    issued_at: datetime
    resolution_min: int
    points: list[PvPoint]          # ts, ac_kw, ac_kw_lo, ac_kw_hi (optional)
    energy_kwh_by_day: dict[date, float]

class PvForecastProvider(Protocol):
    name: str
    async def forecast(self, system: PvSystemConfig, weather: WeatherForecast | None, horizon_h: int) -> PvForecast: ...
```

| Strategie | Provider | Bewertung |
|---|---|---|
| **A externer Dienst** | **Forecast.Solar** (kostenlos, ohne Key, je Fläche ein Aufruf, stündlich, 12 Aufrufe/h Limit; Personal-Plan mit Key liefert 15 min) | einfach, gut für Cross-Check; keine Bänder, Ratenlimit bei mehreren Flächen |
| | **Solcast** (Hobbyist: 10 Aufrufe/Tag, 30-min-Auflösung, P10/P50/P90) | beste Qualität, aber Kontingent klein; nur mit Key |
| **B eigene Berechnung** | **pvlib** aus Open-Meteo-Strahlung (GHI/DNI/DHI): Transposition (Perez/Hay-Davies) → POA → PVWatts-DC-Modell (Temperaturkoeffizient, Zelltemperatur nach Faiman) → Wechselrichter-Clipping → Verluste | keine externen Limits, mehrere Flächen frei, 15-min möglich, deterministisch testbar; Qualität hängt an der Strahlungsprognose |

**Entscheidung v1:** Strategie **B (pvlib)** als Standard, weil die Wetterdaten ohnehin geladen werden, keine
Kontingente existieren und die Kalibrierung (19.4) direkt an den Modellparametern ansetzen kann. Forecast.Solar
als zweiter Provider zum Vergleich (Anzeige der Abweichung in den Einstellungen, nicht auf dem Dashboard).
Solcast optional bei vorhandenem Key. `CompositePvProvider` kann gewichtet mitteln.

### 19.3 Persistenz

`forecast_runs(kind="pv", provider=…)` + `forecast_points`. Dashboard liest `forecast_latest(kind="pv")`. Die
Simulation im Demo-Modus nutzt dasselbe pvlib-Modell mit synthetischem Wetter, damit Chart und Planer im Demo
realistisch aussehen.

### 19.4 Kalibrierung aus echten Erzeugungsdaten

Täglich (23:30) für den abgelaufenen Tag: `ratio_day = E_actual / E_forecast_issued_at_06:00`. Zusätzlich
stündliche Residuen nach Sonnenstand-Klasse (Elevation-Bins) und Bewölkungs-Klasse. Ableitung:

1. **Globaler Skalierungsfaktor** `k_global` als EWMA (α = 0,1) der Tagesverhältnisse, begrenzt auf [0,6; 1,3] –
   fängt systematische Fehler (falsche kWp, Verluste, Verschattung im Mittel).
2. **Sonnenstands-Korrektur** `k_elev[bin]` (z. B. 0–10°, 10–20°, …) – fängt Horizontverschattung und
   Morgen-/Abendfehler.
3. Später: Regression `E_actual ~ E_forecast + cloud_cover + season` (Ridge) als eigener Provider
   `CalibratedPvProvider`, der jeden Basis-Provider umhüllt.

Alle Faktoren landen in `model_calibrations(model="pv")` mit Metriken (MAE, MAPE, Bias je Monat). Eine Kalibrierung
wird erst nach `min_days` (Default 14) aktiv und pro Tag höchstens um 5 % verändert (Dämpfung gegen Ausreißer wie
Schneebedeckung).

## 20. Heat Demand Model

### 20.1 Konfiguration

```yaml
house:
  heated_area_m2: 180
  construction_year: 1998
  renovation_level: partial          # none | partial | full | passive
  design_outdoor_temperature_c: -10
  indoor_target_temperature_c: 21.0
  estimated_heat_loss_coefficient_kw_per_k: 0.22   # H; wenn null → aus Fläche/Baujahr geschätzt
  thermal_mass_kwh_per_k: 12.0                     # C_building; RC-Modell
  internal_gains_kw: 0.4
  solar_gain_factor_kw_per_kw_m2: 0.0              # optional, Phase 6
  heating_limit_c: 15.0
  heating_curve:                                   # optional, nur informativ
    - { outdoor_c: -10, flow_c: 45 }
    - { outdoor_c: 15, flow_c: 28 }
heat_pump:
  nominal_thermal_power_kw: 12
  approximate_cop_curve:                           # COP über Außentemperatur bei Puffer-Zieltemperatur
    - { outdoor_c: -7, cop: 2.4 }
    - { outdoor_c: 2,  cop: 3.0 }
    - { outdoor_c: 7,  cop: 3.5 }
    - { outdoor_c: 15, cop: 4.2 }
  dhw_share_of_daily_kwh: 8.0                      # Warmwasser kWh_th/Tag, konstant
buffer:
  volume_liters: 800
  layers: [0.25, 0.25, 0.25, 0.25]                 # Volumenanteile zu den 4 Sensoren (oben→unten)
  min_useful_temperature_c: 35
  target_temperature_c: 50
  max_temperature_c: 62
  loss_kw_per_k: 0.004                             # Stillstandsverlust gegen Raum
  comfort_min_top_c: 42                            # unter dieser Kopftemperatur gilt FORCED
comfort:
  target_temperature_c: 21.0
  min_temperature_c: 20.5
  max_preheat_temperature_c: 21.8
```

### 20.2 Modell v1 (Phase 5)

Für jedes 15-min-Intervall t:

```
Q_loss(t)   = H · max(0, T_in_target − T_out(t))                       [kW_th]
Q_heat(t)   = max(0, Q_loss(t) − Q_internal − Q_solar(t))               [kW_th]
Q_dhw(t)    = dhw_share_of_daily_kwh / 24 · profile(t)                   [kW_th]  (Profil: morgens/abends erhöht)
Q_demand(t) = Q_heat(t) + Q_dhw(t)                                       [kW_th]
P_el(t)     = Q_demand(t) / COP(T_out(t))                                [kW_el]
```

Außerhalb der Heizperiode ist `Q_heat = 0`. `H` wird, wenn nicht konfiguriert, aus `heated_area_m2` und einem
Kennwert je `renovation_level` (z. B. 1,2 / 0,9 / 0,6 / 0,3 W/(m²·K) × Hüllflächenfaktor) grob geschätzt und als
„Schätzung“ markiert.

### 20.3 Pufferspeichermodell und thermischer SOC

Der Puffer wird als vier Schichten mit Volumenanteilen `layers` modelliert. Thermischer SOC (Methode
`layered_energy_v1`, konfigurierbar):

```
E_usable  = Σ_i  V_i · ρ · c_p · max(0, T_i − T_min)          [kWh]
E_cap     = Σ_i  V_i · ρ · c_p · (T_max − T_min)               [kWh]
soc       = clamp(E_usable / E_cap, 0, 1)
status    = cold (< 0,2) | partial (< 0,6) | warm (< 0,9) | full (≥ 0,9)   (Schwellen konfigurierbar)
```

Alternative Methode `weighted_mean_v1`: gewichtete Mitteltemperatur `T_w = Σ w_i T_i` mit frei wählbaren Gewichten,
`soc = (T_w − T_min)/(T_max − T_min)`. Beide liefern `method` im `BufferState`, damit die UI die Herkunft zeigt.
Für die Planung wird die Schichtung vereinfacht als ein Energiespeicher `E_buffer[t]` mit Verlust
`loss_kw_per_k · (T_mean − T_room)` fortgeschrieben; Beladung durch die Wärmepumpe mit `nominal_thermal_power_kw`,
Entladung durch `Q_demand`. Fremdwärme (Pelletofen) wird als beobachteter Anstieg ohne Wärmepumpenlauf erkannt
(`d(E_buffer)/dt > 0 ∧ hp.running = false`) und im Plan als Residual berücksichtigt, nie als Wärmepumpenleistung
gezählt.

### 20.4 Kalibrierung (Phase 5/6)

Aus `heat_pump_runs` (elektrische Energie) × COP(T_out) ergibt sich die gelieferte thermische Energie je Tag;
minus Warmwasseranteil ergibt Heizenergie. Regression über Heizgradstunden `Σ max(0, T_in − T_out)·Δt` liefert `H`
(Steigung) und Grundlast (Achsenabschnitt). Ergebnis nach `model_calibrations(model="heat_demand")`, Anzeige der
Güte (R², Anzahl Tage) in den Einstellungen. Gebäude-Zeitkonstante τ = C/H wird aus Abkühlphasen (Nacht ohne
Heizung) geschätzt, sofern eine Innentemperatur vorliegt (25.7).

## 21. Forecast Persistence

Grundsatz: **Forecasts werden nie überschrieben, sondern versioniert.** Jeder Abruf ist ein `forecast_run`; die
Punkte hängen am Run. Die UI liest die neueste Version, die Kalibrierung liest den Forecast, der zu einem
definierten Zeitpunkt (z. B. 06:00) gültig war.

| Kind | Provider | Auflösung | Horizont | Refresh | Aufbewahrung Rohläufe |
|---|---|---|---|---|---|
| `weather` | open_meteo (…) | 60 min (15 min für 72 h optional) | 7 Tage | stündlich | 90 Tage, danach 1 Run/Tag |
| `pv` | pvlib_open_meteo, forecast_solar, solcast | 15 min | 72 h | stündlich (nach Wetter) | 90 Tage, danach 1 Run/Tag |
| `price` | tibber | 60 min → 15 min | bis Ende morgen | 13:00–15:00 alle 30 min, sonst stündlich | unbegrenzt (klein) |
| `heat_demand` | model_v1 | 15 min | 48 h | mit jedem Planlauf | 30 Tage |
| `load` (Grundlast) | profile_v1 (Median letzter 4 Wochen je Wochentag/Viertelstunde) | 15 min | 48 h | täglich | 30 Tage |

`forecast_latest(kind, ts) → value, run_id, issued_at` wird vom Worker nach jedem Run für den Horizont neu
geschrieben (UPSERT), damit die Chart-Abfrage ein einfacher Range-Scan ist. Für die Kalibrierung gibt es
`forecast_as_of(kind, ts, as_of)` als SQL-Funktion (neuester Run mit `issued_at ≤ as_of`).

Alle Forecast-Zeitstempel sind Intervallbeginn UTC; Umrechnung in `Europe/Berlin` (inkl. Zeitumstellung mit 92/100
Viertelstunden am Umstellungstag) erfolgt nur in der Anzeige. Preise werden in ct/kWh mit vier Nachkommastellen
gespeichert; `total` von Tibber ist der maßgebliche Bezugspreis, `energy` und `tax` werden zusätzlich abgelegt.

## 22. 15-Minuten-Planungsmodell

### 22.1 Raster und Auslösung

- Zeitschritt 15 min, Horizont 24–36 h (bis Ende des Tages, für den Tibber-Preise vorliegen, mindestens 24 h; ohne
  Morgenpreise werden die heutigen Preise als Schätzung wiederholt und als `estimated` markiert).
- Neuplanung: alle 15 min zur Viertelstundengrenze; zusätzlich bei neuen Tibber-Preisen, neuem PV-Forecast mit
  Tagesenergie-Abweichung > 15 %, Moduswechsel, Override-Beginn/-Ende, Failsafe-Ende.
- Jeder Planlauf ist ein `plans`-Datensatz; das Dashboard zeigt den neuesten mit `status=active`. Frühere Pläne
  bleiben zum Vergleich „geplant vs. passiert“ (Phase 6).

### 22.2 Ein-/Ausgaben je Intervall

```python
class PlanInterval(BaseModel):
    ts: datetime
    expected_pv_kw: float
    expected_base_load_kw: float
    expected_heat_demand_kw_th: float
    expected_cop: float
    electricity_price_ct_kwh: float
    price_rank: float                 # 0 = günstigstes Intervall des Horizonts, 1 = teuerstes
    expected_surplus_kw: float        # pv − base_load − (Batterie-Ladung laut Heuristik) − (EV laut Heuristik)
    planned_hp_state: Literal["off", "release", "block", "free"]   # free = keine Vorgabe, WP entscheidet
    planned_buffer_soc: float
    planned_building_offset_k: float  # Phase 6 (Vorheizen)
    reason_code: ReasonCode
    note_de: str | None
    confidence: float                 # 0–1 aus Forecast-Alter und -Streuung
```

### 22.3 Regelbasierter Planer (Stufe 2, Phase 5) – Ablauf

1. **Bedarf:** `Q_demand[t]` aus dem Wärmebedarfsmodell; kumulierter Bedarf bis zum nächsten Morgen.
2. **Pufferbilanz vorwärts:** ausgehend vom aktuellen `soc`, mit Verlusten, ohne Wärmepumpe → erster Zeitpunkt,
   an dem `soc < soc_min_comfort` unterschritten würde („spätester Ladezeitpunkt“).
3. **Fenster bewerten:** Für jedes Intervall Kosten je kWh_th = `price / cop` bzw. 0 bei erwarteter
   `expected_surplus_kw ≥ on_surplus_kw` (Eigenverbrauch statt Einspeisung, Opportunitätskosten =
   `feed_in_tariff / cop`, konfigurierbar) und negativ bei negativen Preisen.
4. **Zuordnen:** Vor jedem „spätesten Ladezeitpunkt“ die benötigte Energiemenge in die günstigsten
   zusammenhängenden Fenster legen, die Mindestlaufzeit und Mindestauszeit einhalten; Puffer-Obergrenze beachten.
   Mehrere Runs pro Tag zulässig (Deckel `max_starts_per_day`).
5. **Vorlaufen vor Hochpreisphasen:** Wenn im Horizont Intervalle mit `price_rank ≥ expensive_quantile` liegen und
   der Puffer die Bedarfsmenge dieser Phase aufnehmen kann, wird das günstigste vorausgehende Fenster mit
   Zielpuffer `soc_target_before_peak` (Default 0,85) belegt; die Hochpreisphase erhält `planned_hp_state=block`
   nur, wenn K2 freigegeben ist, sonst `free` mit Note „Wärmepumpe vermeiden, wenn thermisch möglich“.
6. **Begründen:** Jedes Intervall erhält den Reason-Code der Zuordnung (`PLANNED_PV_SURPLUS`,
   `PLANNED_CHEAP_WINDOW`, `PLANNED_PRE_PEAK_CHARGE`, `PLANNED_AVOID_PEAK`, `PLANNED_FORCED_DEMAND`, `NONE`).
7. **Übergabe:** Der Regler liest `planned_hp_state` des aktuellen Intervalls als Trigger `PLANNED_WINDOW`; die
   Live-Guards entscheiden endgültig (z. B. Start entfällt, wenn Überschuss real nicht eintritt und Preis nicht
   günstig ist → Umplanung im nächsten Lauf).

### 22.4 Optimierer (Stufe 3, Phase 6) – Formulierung (Skizze)

```
min  Σ_t [ p_t · P_el,t · Δt  −  f · P_export,t · Δt ]  +  c_start · Σ_t s_t  +  c_comfort · Σ_t (u_t + v_t)  +  c_peak · P_peak
s.t.  E_{t+1} = E_t + η · COP_t · P_el,t · Δt − Q_demand,t · Δt − Q_loss,t · Δt      (Pufferbilanz)
      E_min − u_t ≤ E_t ≤ E_max                                                       (u_t Komfortverletzung)
      P_el,t = P_hp · x_t          x_t ∈ {0,1}                                         (Ein/Aus, konstante Leistung v1)
      s_t ≥ x_t − x_{t−1}                                                             (Start-Indikator)
      Σ_{k=t}^{t+R−1} x_k ≥ R · s_t        (Mindestlaufzeit R Intervalle)
      Σ_{k=t}^{t+O−1} (1−x_k) ≥ O · (x_{t−1} − x_t)   (Mindestauszeit O Intervalle)
      x_t = 1 wenn HeatDemand_t = FORCED-Zwang mit leerem Puffer (Vorab-Fixierung)
      P_import,t − P_export,t = base_t + P_el,t − pv_t (+ Batterie-Heuristik) ; P_import,t ≤ P_peak
      Gebäude (optional): T_{t+1} = T_t + Δt/C · (Q_heat,t − H·(T_t − T_out,t)),  T_min ≤ T_t ≤ T_max_preheat
```

Gelöst mit `scipy.optimize.milp` (HiGHS), 96–144 binäre Variablen → Sekundenbereich. Ergebnis wird in dasselbe
`PlanInterval`-Format übersetzt; Reason-Codes werden aus den aktiven Nebenbedingungen abgeleitet
(z. B. `PLANNED_CHEAP_WINDOW`, wenn `x_t = 1` und `price_rank < 0,3`).

## 23. CI/CD-Konzept

### 23.1 Was aus den Bestandsrepos gelernt wurde

- valyze: Frontend-Workflow „billigstes zuerst“ (tsc → vitest → build) übernehmen; `alembic check` gegen Modell-
  Drift übernehmen; manueller, bestätigter Workflow mit `environment: production` für gefährliche DB-Aktionen
  übernehmen. **Nicht** übernehmen: fehlende Python-CI, rein manuelle Migrationen.
- Website: kein CI, Deploy via Railway-GitHub-Integration – reicht für eine statische Seite, nicht für einen Regler.

### 23.2 Workflows

```
.github/workflows/
├── web.yml         push/PR auf apps/web/**, packages/ui/**, docs/openapi.json
│                   pnpm install --frozen-lockfile → eslint → tsc --noEmit → vitest run → next build
│                   → playwright smoke (Demo-Modus gegen `next start`, Viewport 1180×820, Screenshot als Artefakt)
├── python.yml      push/PR auf apps/api/**, apps/bridge/**, packages/**
│                   uv sync --frozen → ruff check → ruff format --check → mypy (strict für hems-core)
│                   → pytest packages/hems-core (schnell, ohne DB, mit hypothesis)
│                   → pytest apps/api mit services: postgres:16 (DCH_TEST_DATABASE_URL) → pytest apps/bridge
│                   → import-linter (Schichtgrenzen)
├── migrations.yml  push/PR auf apps/api/src/dch_api/infrastructure/db/**
│                   leere Postgres → alembic upgrade head → alembic check → alembic downgrade -1 → upgrade head
│                   → Schema-Dump als Artefakt (Diff im PR sichtbar)
├── docker.yml      PR: docker build aller drei Images (api/worker, web, bridge) ohne Push, Trivy-Scan (Warnstufe);
│                   zusätzlich linux/arm64 (Raspberry Pi) per QEMU; Release-Tag → Push nach GHCR
│                   (`ghcr.io/moritznobis87/duckcurve-*`); der lokale Host zieht per `docker compose pull` (Profil A)
├── secrets.yml     gitleaks auf jedem Push
└── db-maintenance.yml   workflow_dispatch: backfill | retention-dry-run | destructive-migration
                    mit Bestätigungswort und environment: production (valyze-Muster)
```

Matrix: Python 3.12 (eine Version, bewusst; `.python-version` und `requires-python` identisch), Node 22.
Caches: uv-Cache, pnpm-Store. Laufzeitziel je Workflow < 5 min.

### 23.3 Deployment-Fluss

```
PR → CI grün → Squash-Merge auf main
  → Railway (GitHub-Integration, Branch main, Watch Paths je Service):
      web:    build → healthcheck → switch
      api:    build → preDeployCommand `alembic upgrade head` → start → healthcheck → switch
      worker: build → start (wartet, bis api-Version = eigene Version oder 60 s) → Leader-Lock → Ticks
  → Post-Deploy-Check (GitHub Action, optional): GET https://api-home…/health muss neue Version melden
```

Feature-Branches erzeugen keine Railway-Umgebungen (Kostengründe); ein manuell angelegtes `staging`-Environment
kann per Railway-PR-Environment aktiviert werden, wenn Phase 4 beginnt (Regler gegen Demo-Simulation in der Cloud
testen).

### 23.4 Migrationen sicher automatisieren

1. **Nur additive Migrationen automatisch** (neue Tabellen/Spalten mit Default oder NULL, neue Indizes
   `CONCURRENTLY` außerhalb von Transaktionen). Ein Test in `migrations.yml` (`alembic-autogen-check` + eigene
   Prüfung auf `DROP`/`ALTER TYPE`/`NOT NULL ohne Default`) lässt destruktive Migrationen im automatischen Pfad
   fehlschlagen.
2. **Expand/Contract:** Umbenennungen und Löschungen in zwei Releases: erst neue Struktur + Code, der beides
   versteht; später `db-maintenance.yml` (manuell, bestätigt) für den Contract-Schritt.
3. **Alte Instanz muss mit neuem Schema laufen** (Rollover), deshalb Regel 1.
4. Migrationen sind idempotent gegenüber Wiederholung (`IF NOT EXISTS` wo möglich), weil `preDeployCommand` bei
   Retry erneut läuft.
5. Datenbank-Backup vor jeder nicht-additiven Migration (Railway-Snapshot oder `pg_dump`-Job) ist Teil des
   manuellen Workflows.

### 23.5 Qualitätsschranken

- Coverage-Bericht als Artefakt; harte Schwelle nur für `hems_core.control` (≥ 95 % Zeilen) und
  `hems_core.thermal` (≥ 90 %).
- Jeder Reason-Code braucht mindestens einen Test, der ihn erzeugt (Test iteriert über die Enum).
- Playwright-Screenshot des Demo-Dashboards wird pro PR als Artefakt angehängt (visuelle Kontrolle ohne
  Pixel-Diff-Zwang).

## 24. Übernahme des Duck-Curve-Designsystems

### 24.1 Befund aus `Duckcurve_Website/app/globals.css` (Quelle der Wahrheit)

| Kategorie | Befund (exakt) |
|---|---|
| Farben | `--petrol #0f2e3d`, `--deep #082431`, `--amber #f2a900`, `--amber-soft #ffd778`, `--mist #7fa3b3`, `--paper #fff`, `--cloud #f1f5f5`, `--ink #102e3c`, `--line rgba(15,46,61,.15)`; Dunkelkarte `#123544`; Petrol-Hover `#173f50`; Amber-Hover `#ffb71c`; Charge-Teal `#4f7b88`; Label-Muted `#345d6b`; Verlauf-Ende `#153c4c`; Menü-Dunkel `#07202c` |
| Schrift | IBM Plex Sans 400/600 (nur zwei Gewichte), IBM Plex Mono 400; lokale OTF, `font-display: swap`; `-webkit-font-smoothing: antialiased` |
| Typo-System | Kicker: Mono, Versalien, `letter-spacing .13em`, 11 px (auf der Seite 7–11 px), Farbe Mist; Headline: Sans 600, `letter-spacing -.045em`, `line-height 1.07`, `em` als Amber-Zeile in Gewicht 400; Fließtext 15–19 px, `line-height 1.65–1.75`, Paper mit 0,72 Alpha auf Dunkel; große Zahlen 34 px `letter-spacing -.03em` (`.stat-kacheln strong`) |
| Radien | 2 px (Pills, Menülinks), 3 px (Buttons, Labels), 6 px (Product-Window), 50 % (Punkte) – **nie** größer |
| Linien | 1 px, auf Dunkel `rgba(255,255,255,.10–.17)`, auf Hell `--line`; Karten-Grids mit 1-px-Gap in `--line`-Farbe statt Rahmen (`.storage-modes`, `.thema-kennzahlen`) |
| Schatten | groß und weich, nur für „schwebende“ Elemente: `0 18px 60px rgba(0,0,0,.09)` Header, `0 44px 120px rgba(0,0,0,.36)` Product-Window, `0 26px 60px rgba(0,0,0,.42)` Menü; Buttons Amber `0 18px 48px rgba(0,0,0,.22)`; Fokusring `0 0 0 6px rgba(242,169,0,.12)` |
| Abstände | Shell `min(1220px, 100% − 64px)`; Section 124 px; Kartenpadding 30–38 px; Grid-Gaps 16–22 px; Header 82 px |
| Buttons | `min-height 54px`, `padding 0 24px`, Radius 3, 15 px 600; Varianten amber/petrol/outline/linie/small (42 px); Hover `translateY(-2px)` |
| Header | Grid `1fr auto 1fr`, Glas: `rgba(8,36,49,.38)` + `backdrop-filter blur(18px)` + 1-px-Rahmen `.17` |
| Hintergrund | `linear-gradient(130deg, --deep, --petrol 62%, #153c4c)` + radialer Mist-Schein + 58-px-Raster (`rgba(255,255,255,.09)`, Opazität .18, nach unten maskiert) |
| Akzente | Eyebrow-Punkt 7 px Amber mit 6-px-Amber-Halo; 3-px-Amber-Linie oben am Product-Window (Verlauf Amber → Amber-Soft → transparent bei 86 %); 3-px-Amber-Linksrand für hervorgehobene Kacheln |
| Status-Pills | `padding 2px 9px`, Radius 2, Mono 11 px Versalien `.08em`; offen = Amber 22 % + `#6b4a00`, beantwortet = Petrol 12 %, erledigt = Petrol 6 % |
| Charts (SVG) | Grid `rgba(255,255,255,.09)`, Achse `.20`, Achsentext Mono 8 px `.42` Laufweite `.1em`; Linie 3,5 px `round`; Amber Hauptserie, Mist Referenz, `stroke-dasharray 7 7` Vergleich; Fläche Amber-Verlauf `.32 → .03`; Label = Rechteck `rx 3` Fill `--deep` Rahmen `.14` + Amber-Mono-Text; Dispatch: Laden Teal `#4f7b88`, Entladen Amber; SoC-Balken Paper `.26` mit 2-px-Oberkante `.68` |
| Animation | `.18s ease` für alles Interaktive; Eintritt `cubic-bezier(.22,.61,.36,1)`; Keyframes für Linien-Zeichnen (`pathLength`), Balken-Wachsen, Puls; `prefers-reduced-motion: reduce` → `transition-duration .01ms` |
| Responsiv | Breakpoints 1020 / 760 / 700 / 420 px; Grids kollabieren auf 1 Spalte |
| Dark Mode | kein Umschalter – dunkle und helle **Abschnitte** wechseln sich ab (Hero/Analytics/Footer dunkel, Rest hell) |
| Marke | `duck-curve-mark.svg` (Balkenreihe als Entenkurve, Mist auf Petrol), `duck-curve-header.png` (Wortmarke), Maskottchen nur auf CTA |

valyze verwendet dieselben Grundfarben als helle App (`--wash #f4f7f8`, `--line #dce5ea`, `--positiv #2e7d32`,
`--negativ #c0392b`) und leitet Datenfarben ab (`#0b70a0`, `#c77f02`, `#6a7dc9`). Für das dunkle Dashboard sind
diese Ableitungen nicht übertragbar (zu dunkel auf `--deep`), das Prinzip aber schon.

### 24.2 Design-Tokens für Duck Curve Home (`apps/web/src/styles/tokens.css`)

```css
:root {
  /* Marke – identisch zur Website */
  --petrol: #0f2e3d;  --deep: #082431;  --amber: #f2a900;  --amber-soft: #ffd778;
  --mist: #7fa3b3;    --paper: #ffffff; --cloud: #f1f5f5;  --ink: #102e3c;

  /* Dunkle Oberflächen (Website: Hero, Analytics-Karten, Menü) */
  --bg:            var(--deep);
  --bg-gradient:   linear-gradient(130deg, var(--deep), var(--petrol) 62%, #153c4c);
  --surface-1:     #0f2e3d;                 /* Karte Stufe 1 = Petrol */
  --surface-2:     #123544;                 /* Karte Stufe 2 = Website-Analysis-Card */
  --surface-3:     #173f50;                 /* Hover / aktive Kachel */
  --surface-glass: rgba(8, 36, 49, .38);    /* Header */
  --line-1:        rgba(255, 255, 255, .10);
  --line-2:        rgba(255, 255, 255, .17);
  --grid-line:     rgba(255, 255, 255, .09);

  /* Text auf Dunkel */
  --text-1: rgba(255, 255, 255, .92);
  --text-2: rgba(255, 255, 255, .72);
  --text-3: rgba(255, 255, 255, .48);
  --text-kicker: var(--mist);

  /* Semantik Energie (neu, sparsam) */
  --pv:       var(--amber);
  --grid-in:  var(--mist);                  /* Netzbezug */
  --grid-out: var(--amber-soft);            /* Einspeisung */
  --battery:  #4f7b88;                      /* Website-„Laden“-Teal */
  --load:     rgba(255, 255, 255, .62);     /* Haus, Wärmepumpe, Wallbox */
  --price:    var(--mist);

  /* Status (neu, nur für Zustände) */
  --ok:    var(--mist);
  --warn:  var(--amber);
  --alert: #e0533d;                          /* „Ember“ – einzige neue Hue, nur Fehler/Störung/negativer Preis */

  /* Thermische Skala (Pufferspeicher) */
  --heat-0: #1f4c66;  /* ≤ 25 °C */  --heat-1: #7fa3b3;  /* 40 °C */
  --heat-2: #ffd778;  /* 50 °C */    --heat-3: #f2a900;  /* 60 °C */  --heat-4: #e0533d;  /* ≥ 70 °C */

  /* Typografie */
  --font-sans: "IBM Plex Sans", system-ui, sans-serif;
  --font-mono: "IBM Plex Mono", ui-monospace, monospace;
  --kicker: 400 13px/1.2 var(--font-mono);   letter-spacing: .13em; text-transform: uppercase;  /* Website: 11px */
  --kpi-xl: 400 64px/1 var(--font-mono);     letter-spacing: -.03em;
  --kpi-l:  400 40px/1 var(--font-mono);     letter-spacing: -.03em;
  --kpi-m:  400 28px/1 var(--font-mono);     letter-spacing: -.02em;
  --title:  600 22px/1.2 var(--font-sans);   letter-spacing: -.02em;
  --body:   400 15px/1.5 var(--font-sans);
  --label:  400 13px/1.3 var(--font-sans);

  /* Form */
  --radius-1: 2px; --radius-2: 3px; --radius-3: 6px;
  --space-1: 4px; --space-2: 8px; --space-3: 12px; --space-4: 16px; --space-5: 20px; --space-6: 24px; --space-8: 32px;
  --shadow-float: 0 18px 60px rgba(0, 0, 0, .09);
  --shadow-sheet: 0 26px 60px rgba(0, 0, 0, .42);
  --focus-ring: 0 0 0 6px rgba(242, 169, 0, .12);
  --accent-bar: linear-gradient(90deg, var(--amber), var(--amber-soft), transparent 86%);

  /* Bewegung */
  --ease: ease; --dur: .18s; --ease-enter: cubic-bezier(.22, .61, .36, 1);
}
@media (prefers-reduced-motion: reduce) { :root { --dur: .01ms; } }
```

Tailwind 4 bindet diese Variablen in `theme.css` per `@theme { --color-amber: var(--amber); … }`, sodass
`bg-surface-2 text-text-2 font-mono` in Komponenten verfügbar sind, aber jede Farbe genau einmal definiert ist.
Ein Light-Theme kann später allein durch Überschreiben der `--bg/--surface/--text/--line`-Gruppe entstehen.

### 24.3 Komponentensprache

| Komponente | Website-Vorbild | Dashboard-Umsetzung |
|---|---|---|
| Karte | `.analysis-card` (#123544, 1-px-Rahmen .10, Padding 38) | `Card`: `--surface-2`, `--line-1`, Padding 24 (Kiosk-Dichte), Radius 3, optionale `accent`-Variante mit 3-px-Amber-Linie oben (Intelligence Card) |
| Kicker | `.section-kicker` | `Kicker`: Mono 13 px Versalien Mist, Abstand 12 px darunter |
| KPI | `.stat-kacheln strong` / `.metric-row` | `Kpi`: Zahl Mono groß, Einheit Sans 13 px `--text-3` mit 6 px Abstand, Label als Kicker darüber; Komma-Dezimaltrennung (`de-DE`) |
| Button | `.button` (54 px, Radius 3, 600) | `ControlTile` 96 px hoch mit Icon; `Button` 54 px für Dialoge; Segment aus drei 54-px-Buttons mit 1-px-Trennlinien und Amber-Füllung für aktiv |
| Pill | `.stat-stand-*` | `Pill`: Mono 12 px Versalien Radius 2, Varianten `neutral / amber / alert`; z. B. AUTO · SMART, MANUELL BIS 16:30, OFFLINE |
| Statuspunkt | `.eyebrow span` (7 px + Halo) | `Dot`: 8 px + 6-px-Halo, Pulsanimation nur bei `live` |
| Header | `.site-header` Glas | `Header` 56 px, Glas, Mark 28 px hoch, Uhrzeit Mono |
| Hintergrund | `.hero` Verlauf + Raster | `DashboardShell`: `--bg-gradient` + 58-px-Raster bei .10 Opazität, ohne Maske |
| Chart-Theme | `.svg-*` | ECharts-Theme `duckcurve-dark`: `textStyle.fontFamily` Mono für Achsen, Grid `--grid-line`, Achse `.20`, Achsentext 12 px `--text-3` (Website 8 px ist für die Wand zu klein), Serienbreite 3 (Live) / 2 (Prognose gestrichelt `[7,7]`), Tooltip als dunkles Rechteck Radius 3 mit 1-px-Rahmen .14 und Amber-Mono-Werten |
| Energiefluss | `.storage-*`-Grafik, `.svg-line` | Knoten: Kreis 72 px, 2-px-Kontur `.17`, Icon 24 px, Wert darunter; Kanten 2–5 px, Punkte 4 px im Serienton |
| Pufferspeicher | – (neu) | Zylinder 120 × 320 px, Kontur 2 px `.17`, Füllung `linearGradient` aus `--heat-*`, Sensorwerte rechts Mono 20 px |
| Ladezustand | `.storage-soc` (Balken .26 mit Oberkante .68) | Mini-Balken für Batterie-SOC im Knoten |

### 24.4 Was bewusst anders ist als auf der Website

- Alle Schriftgrößen der Kicker/Achsen von 7–11 px auf ≥ 12 px angehoben (Leseabstand).
- Keine 3D-Neigung (`perspective … rotateY`) – Wandbetrieb braucht Ruhe.
- Nur dunkle Oberflächen; helle Abschnitte gibt es nicht.
- Eine zusätzliche Hue (Ember `#e0533d`) für Störung/negativen Preis; die Website hat keine Warnfarbe, ein Dashboard
  braucht eine. Sie wird auf Petrol-Hintergrund auf Kontrast ≥ 4,5:1 geprüft (Text nur als Pill mit dunklem Text
  oder als Linie/Fläche, nicht als Fließtext).
- Datenfarben für Serien auf Dunkel: Amber, Mist, Paper 62 %, Teal – Kontrast und CVD-Abstand werden in Phase 1 mit
  demselben Palettencheck geprüft, den valyze für seine Ableitungen verwendet; wenn Mist als Preislinie gegen Teal
  zu ähnlich ist, wird der Preis heller gesetzt (Paper 72 %), nicht bunter.

## 25. Offene technische Fragen

Vor Phase 2 zu klären (Phase 1 läuft komplett im Demo-Modus und ist davon unabhängig):

| # | Frage | Warum wichtig | Vorschlag / Annahme bis zur Klärung |
|---|---|---|---|
| 25.1 | **Shelly-Inventar:** genaue Modelle und Generation (Gen1/Gen2/Gen3) von 3EM, Relais (K1, K2, Kaffee, Terrasse, Gartenzaun) und den vier Temperatursensoren (Plus Add-on mit DS18B20? H&T?), Firmware-Stand, feste IPs vorhanden? | Adapter-Auswahl (Gen1 vs. RPC), Auto-Off-Fähigkeit, MQTT-Konfiguration | Discovery in Phase 2; Annahmen in 8.2/8.6 |
| 25.2 | **Bridge-Host:** Welcher Rechner steht dauerhaft im LAN (Raspberry Pi, NUC, vorhandener HA-Host mit Docker)? Architektur (arm64/amd64), Stromversorgung, LAN-Kabel? | Docker-Images, Zuverlässigkeit | Raspberry Pi 4/5 mit SSD oder NUC, Docker Compose |
| 25.3 | **MyEnergi:** Hub-Seriennummer und API-Key aus der App verfügbar? Welche Geräte (Zappi, Libbi, Harvi – je Seriennummer)? Liefert der Harvi die Netzleistung oder ein Zappi-CT? | Netzmessung = Pflichtgröße der Regelung | Harvi als Netzmesser |
| 25.4 | **Tibber Pulse vorhanden?** | zweite, cloud-unabhängige Netzmessung alle 2–10 s | ohne Pulse hängt die PV-Regel an der MyEnergi-Cloud |
| 25.5 | **SolarEdge:** Modbus TCP aktivierbar (SetApp/Installer-Zugang)? Wechselrichtermodell? Nutzt Home Assistant heute schon Modbus? | Live-PV mit 2 s vs. nur CT-Wert | MyEnergi-CT als Start, Modbus in Phase 2 aktivieren |
| 25.6 | **Koordinaten, kWp, Ausrichtung, Neigung, Wechselrichterleistung, Dachflächen**, evtl. Einspeisebegrenzung | PV-Forecast | Platzhalter in 19.1 |
| 25.7 | **Innentemperatur verfügbar?** (Thermostat, Shelly H&T innen) | Gebäudemodell, Komfortgrenzen | ohne: Gebäude-Vorheizen nur mit engen Grenzen oder gar nicht |
| 25.8 | **Verhalten der ELCO AERO auf K1/K2**: Was ändert K1 (Sollwertanhebung, WW-Beladung)? Zeigt K2 Frostschutz? Herstellergrenze für Sperrdauer/Tag? Klemmenbelegung dokumentiert? | Regelparameter, Freigabe von K2 | Phase 3 protokolliert Versuche; K2 bleibt aus |
| 25.9 | **Bestehende HA-Regel für die Wärmepumpe** („WP Auto“): Logik, und wann darf sie abgeschaltet werden? Soll Home Assistant überhaupt weiterlaufen? | zwei Automatiken auf denselben Relais sind ein Risiko (8.7) | HA-Regel spätestens in Phase 3 aus; HA sonst frei |
| 25.10 | **Verdrahtung K1/K2:** Schließer (NO) oder Öffner (NC)? | stromloses Relais muss „kein Eingriff“ bedeuten | NO annehmen, in Phase 3 prüfen |
| 25.11 | **Puffervolumen, Sensorhöhen, Anschlusshöhen** (WP-Vorlauf, Pelletofen, Heizkreis, WW-Entnahme) | Schichtgewichte, SOC | gleiche Volumenanteile annehmen |
| 25.12 | **Einspeisevergütung** und Tibber-Tarifdetails (Grundpreis, Netzentgelt fix/variabel) | Opportunitätskosten im Planer | 8 ct/kWh annehmen |
| 25.13 | **Pelletofen:** irgendein Indikator (Steckdosen-Leistung über Shelly Plug, Abgastemperatur, Zeitplan)? | Fremdwärme erkennen | nur Residual-Erkennung |
| 25.14 | **Außentemperatur:** eigener Sensor (Shelly H&T außen) oder nur Wetterdienst? | Regelgröße für Wärmebedarf | Open-Meteo `current` stündlich, Sensor optional |
| 25.15 | **Domains**: `home.duckcurve.de` / `api-home.duckcurve.de` gewünscht? DNS bei wem? | Railway Custom Domains | Railway-Standarddomains bis dahin |
| 25.16 | **Zugriff für weitere Personen/Handys** neben dem iPad? | Auth-Umfang | Single-User + mehrere Kiosk-Geräte |
| 25.17 | **Wallbox-Steuerung später gewünscht** (MyEnergi-API schreibend)? | Architekturreserve | nur lesen in v1 |
| 25.18 | **Historische Daten einmalig übernehmen?** (CSV-Export aus dem bisherigen System für die Kalibrierung von PV- und Wärmebedarfsmodell) | Modelle wären ab Tag 1 kalibrierbar statt nach 14+ Tagen | optionales Import-Tool, keine Laufzeitabhängigkeit |
| 25.19 | **Repository-Sichtbarkeit**: öffentlich oder privat? | CI-Secrets, Log-Hygiene | privat annehmen |

## 26. Glossar und Konventionen

| Begriff | Bedeutung |
|---|---|
| **K1 / Release-Kontakt** | potenzialfreier Kontakt „PV-Überschuss“: Anforderung an die Wärmepumpe, mehr Wärme zu erzeugen |
| **K2 / Block-Kontakt** | potenzialfreier Kontakt „Netzbetreiber-Shutdown“ (EVU-Sperre): Wärmepumpe darf nicht heizen |
| **Bridge / Device Gateway** | Geräteschicht von Duck Curve Home (Python): liest Shelly/MyEnergi/SolarEdge direkt und schaltet Shelly-Relais. Läuft im Profil A im Worker-Prozess, im Profil B als eigener Agent im Haus mit ausgehender Verbindung zu Railway |
| **Guardian** | unabhängiger Wächterprozess auf dem Haus-Rechner, der die Wärmepumpen-Kontakte zurücksetzt, wenn die Anwendung ausfällt |
| **Ringpuffer** | lokale SQLite-Ablage des Gateways mit 7 Tagen Rohwerten für die Nachlieferung nach Verbindungsabbrüchen (nur Profil B) |
| **LiveState** | letzter bekannter Wert je Sensor mit Qualität und Alter, im API-Prozess und als Spiegel in Postgres |
| **Decision** | strukturierte Regler-Entscheidung mit Reason-Codes, Inputs, TTL und Ausblick |
| **Plan / PlanInterval** | 15-min-Fahrplan über 24–36 h mit geplantem Wärmepumpenzustand und Begründung |
| **Guard** | Sicherheitsregel im Regler, die eine Entscheidung verhindert oder begrenzt |
| **Failsafe** | Regelzustand, in dem alle Wärmepumpen-Kontakte aus sind und der Regler pausiert |
| **TTL** | Gültigkeitsdauer eines Kommandos; danach fällt der Aktor auf `safe_state` |
| **Thermischer SOC** | geschätzter Ladezustand des Pufferspeichers zwischen `T_min` und `T_max` (Methode konfigurierbar) |
| **EWMA** | exponentiell gewichteter gleitender Mittelwert für geglättete Regelgrößen |

**Sprachkonvention:** Code, Bezeichner, API-Pfade, JSON-Felder, DB-Spalten, Reason-Codes, Log-Schlüssel und
ADR-Titel auf Englisch. UI-Texte, Benutzer-Doku (`README`, `CONFIGURATION`, `HEMS_CONTROL`), Commit-Messages und
Kommentare, die eine fachliche Begründung tragen, auf Deutsch. Zahlen in der UI im `de-DE`-Format (Komma, schmales
Leerzeichen vor Einheit: „6,8 kW“, „29,4 ct/kWh“).

**Zeitkonvention:** Persistenz und API in UTC (`timestamptz`, ISO 8601 mit `Z`); Intervallbeginn als Zeitstempel;
Anzeige in `Europe/Berlin`.

**Einheiten:** Leistung kW, Energie kWh, Temperatur °C, Preis ct/kWh (Speicherung mit vier Nachkommastellen),
SOC als Anteil 0–1 (Anzeige in %).

---

*Ende des Phase-0-Dokuments. Nächster Schritt nach Freigabe: Phase 1 (Monorepo-Skelett, Design-System, Demo-Modus,
Dashboard) gemäß Abschnitt 14.*

