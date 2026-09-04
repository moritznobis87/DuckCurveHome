# Duck Curve Home – Projektplan (Phase 0)

**Stand:** 4. September 2026 · **Status:** Analyse und Architekturvorschlag, noch keine Implementierung
**Repository:** `moritznobis87/DuckCurveHome` · **Branch:** `claude/duck-curve-home-project-9vfe9h`

Duck Curve Home ist ein Home-Energy-Management-System (HEMS) für ein einzelnes Wohnhaus in Geilenkirchen. Es
visualisiert Energieflüsse und Zustände, bedient ausgewählte Aktoren und optimiert in späteren Phasen die
Wärmepumpe als flexible thermische Last. Der primäre Bildschirm ist ein wandmontiertes iPad im Querformat.

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
8. Integrationsstrategie Home Assistant / InfluxDB
9. Strategie für Live-Daten
10. Wärmepumpen-Steuerungsarchitektur
11. Safety-Konzept
12. Optimierungs-Roadmap
13. UI-/UX-Konzept
14. Empfohlene Projektphasen
15. Railway-Zielarchitektur
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

1. **Das Haus bleibt ohne Duck Curve Home funktionsfähig.** Home Assistant, MyEnergi-HEMS und die
   Wärmepumpen-Regelung arbeiten wie heute weiter. Duck Curve Home legt sich als Beobachter und Optimierer darüber
   und greift nur über die zwei dafür vorgesehenen potenzialfreien Kontakte ein. Jeder Eingriff ist zeitlich
   begrenzt (TTL) und fällt ohne Bestätigung von selbst zurück.
2. **Verbindung nur von innen nach außen.** Ein kleiner lokaler Agent („Bridge“) baut eine ausgehende,
   authentifizierte WSS-Verbindung zu Railway auf. Home Assistant und InfluxDB werden nicht ins Internet gestellt.
3. **Hexagonale Architektur.** Domänenmodell, Regler und Planer sind reines Python ohne I/O. Integrationen
   (Home Assistant, InfluxDB, Tibber, Open-Meteo, PV-Forecast, Shelly) sind austauschbare Adapter hinter
   Protokollen. Dadurch kann der Regler später unverändert vom Cloud-Backend auf die Bridge (Edge) wandern.
4. **Erklärbarkeit ist ein Datenmodell, kein UI-Text.** Jede Entscheidung wird als strukturierter Datensatz mit
   Reason-Codes, Eingangsgrößen und Gültigkeit persistiert. Das Dashboard rendert daraus „Was / Warum / Was kommt“.
5. **Stufenweise Intelligenz.** Regelbasiert → prognosebewusst → rollierende Optimierung; jede Stufe ist ein
   `Planner`-Adapter hinter demselben Interface, der Regler-Kern und die Safety-Schicht bleiben gleich.

### 3.2 Systemübersicht

```
┌──────────────────────────────── Haus (LAN, Geilenkirchen) ────────────────────────────────┐
│                                                                                            │
│  SolarEdge  MyEnergi (Libbi/Zappi/Harvi)  Shelly 3EM  Shelly Temp ×4  Shelly Relais       │
│      └──────────────┬─────────────────────────┴───────────────┴──────────────┘             │
│                     ▼                                                                      │
│              Home Assistant  ──────────►  InfluxDB (Rohmesswerte, Historie)                │
│                     │ WebSocket API (lokal, Long-Lived Token)      ▲ Flux/InfluxQL (lokal) │
│                     ▼                                              │                        │
│           ┌──────────────────────────────────────────────────────────────┐                 │
│           │  duckcurve-bridge (Python, Docker auf dem HA-Host)           │                 │
│           │  • abonniert Entitäten, normalisiert, puffert (SQLite-Queue) │                 │
│           │  • führt Aktor-Kommandos mit TTL aus, meldet Ist-Zustand     │                 │
│           │  • lokaler Watchdog: Kontakte fallen ohne Cloud zurück       │                 │
│           │  • Query-Proxy für InfluxDB-Backfill                         │                 │
│           └──────────────────────────────┬───────────────────────────────┘                 │
└──────────────────────────────────────────┼─────────────────────────────────────────────────┘
                                           │ ausgehend WSS + Device-Token (mTLS optional)
                                           ▼
┌──────────────────────────────────── Railway Project ───────────────────────────────────────┐
│                                                                                            │
│  ┌───────────────┐   SSE (Live-State)   ┌──────────────────────────────────────────────┐   │
│  │  web (Next.js)│◄─────────────────────│  api (FastAPI)                               │   │
│  │  iPad-Kiosk   │──── REST (Befehle) ─►│  • /ingest (Bridge-WS)  • /stream (SSE)      │   │
│  └───────────────┘                      │  • REST /api/v1/*       • Auth (Kiosk-Token) │   │
│                                         │  • LiveState (in-memory) • Persist-Batcher   │   │
│                                         └───────────────┬──────────────────────────────┘   │
│                                                         │ SQLAlchemy async                 │
│  ┌──────────────────────────────────┐                   ▼                                  │
│  │  worker (gleiches Python-Image)  │◄──────────► PostgreSQL (Railway)                     │
│  │  • Control-Loop (10 s Takt)      │              Konfiguration, Entscheidungen,           │
│  │  • Forecast-Jobs (Wetter/PV/Preis)│             Forecasts, Pläne, Events,               │
│  │  • Planner (alle 15 min)         │              Messwerte (raw 14 d, 15-min lang)        │
│  │  • Aggregation/Retention         │                                                      │
│  └──────────────┬───────────────────┘                                                      │
│                 │ ausgehend HTTPS                                                           │
└─────────────────┼──────────────────────────────────────────────────────────────────────────┘
                  ▼
   Tibber GraphQL · Open-Meteo · Forecast.Solar/Solcast (optional)
```

**Warum Control-Loop in der Cloud und nicht auf der Bridge?** Deployment, Beobachtbarkeit, Tests und Konfiguration
sind in der Cloud deutlich einfacher; Latenz spielt bei einem 10-Sekunden-Takt keine Rolle. Der Preis ist, dass bei
Internet-Ausfall keine Optimierung stattfindet – das ist akzeptabel, weil die Wärmepumpe dann einfach in ihre
eigene Regelung zurückfällt (siehe Safety-Konzept). Der Regler-Kern (`packages/hems-core`) ist I/O-frei und kann in
einer späteren Phase optional auf der Bridge laufen, wenn Offline-Optimierung gewünscht wird.

**Warum Worker und API getrennt?** Der Control-Loop und die Planer müssen genau einmal laufen. Railway kann die
API horizontal skalieren oder bei Deploys kurzzeitig zwei Instanzen halten. Der Worker ist ein eigener Service mit
genau einer Replika und sichert das zusätzlich per PostgreSQL-Advisory-Lock (Leader-Lock). In Phase 1 laufen API
und Worker aus demselben Docker-Image, nur mit anderem Startkommando; lokal kann beides in einem Prozess laufen
(`DCH_ROLE=all`).

### 3.3 Schichten im Backend

```
apps/api, apps/worker (FastAPI / Prozess-Hülle)
   │
   ▼
application/           Use-Cases: ingest_snapshot, switch_actuator, set_mode, run_control_tick, run_planner
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
integrations/          Adapter: home_assistant, influxdb, tibber, open_meteo, forecast_solar, pvlib, shelly,
                       bridge_protocol, demo (Simulation)
infrastructure/        Postgres-Repositories (SQLAlchemy), SSE-Broker, Settings, Logging, Scheduler
```

Die Domänenschicht kennt keine Entity-IDs von Home Assistant und keine Tibber-Felder. Adapter übersetzen in
Domänenobjekte; die Zuordnung (z. B. `sensor.solaredge_ac_power → pv_power_kw`) ist Konfiguration.

## 4. Datenfluss

### 4.1 Live-Pfad (Ziel: 1–5 s Ende-zu-Ende)

```
Shelly/MyEnergi/SolarEdge → Home Assistant (state_changed)
  → Bridge: subscribe_entities (WS) → Normalisierung (Einheit, Vorzeichen, Qualität)
  → Bridge: Telemetrie-Frame alle 1–2 s (nur geänderte Werte, Batch) → WSS → api:/ingest
  → api: LiveState.apply(frame) → EnergySnapshot (vollständig, mit Qualitätsflags)
  → api: SSE-Broker fan-out (max. 1 Frame/s pro Client, Koaleszierung)
  → web: Store aktualisiert → Energiefluss/Tank/KPIs rendern
  → api: Persist-Batcher schreibt alle 5 s in measurements_raw (Postgres)
  → worker: liest LiveState-Spiegel aus Postgres (`live_state`-Tabelle, 1 Zeile, alle 2 s) oder via
    interner HTTP-Abfrage der API; entscheidet, schreibt control_decisions, sendet Kommandos
```

Der Worker bezieht den Live-Zustand nicht über die Bridge-Verbindung (die hält die API), sondern aus einem
kleinen `live_state`-Spiegel in Postgres, den die API bei jedem Frame aktualisiert (UPSERT, eine Zeile pro
Sensor). Das hält die Verantwortung klar: Die API besitzt die Bridge-Verbindung, der Worker besitzt die Regelung.
Kommandos gehen vom Worker über eine `actuator_commands`-Tabelle plus `LISTEN/NOTIFY` an die API, die sie an die
Bridge schickt und die Bestätigung zurückschreibt.

### 4.2 Historischer Pfad

```
InfluxDB (lokal) ◄── Bridge Query-Proxy ◄── api (Backfill-Auftrag)
  → 1-min-Mittelwerte für Lücken (z. B. nach Internet-Ausfall) → measurements_1min
  → worker: Aggregation measurements_raw → measurements_15min (Energie in kWh, Mittel-/Min-/Max-Leistung)
  → 24h-Chart: measurements_1min (heute/gestern) + Forecast-Reihen + Plan-Fenster aus Postgres
```

Das Dashboard liest den Verlauf ausschließlich aus Postgres. InfluxDB bleibt hochaufgelöstes Archiv und Quelle für
Backfill/Kalibrierung, ist aber **nicht** im Live-Pfad und **nicht** für den Heizbetrieb erforderlich.

### 4.3 Steuerpfad

```
worker: ControlTick (10 s)
  Inputs: EnergySnapshot, BufferState, HeatPumpState, Preise, Plan, Modus, Override, Forecasts
  → Planner-Empfehlung (was wäre jetzt sinnvoll) → HeatPumpController (Zustandsmaschine)
  → Guards (Mindestlaufzeit, Mindestauszeit, Hysterese, max. Sperrdauer, Frostschutz, Sensorqualität)
  → Decision {k1_release, k2_block, reason_codes[], explanation, valid_until}
  → nur bei Änderung: ActuatorCommand {target, state, ttl_s, decision_id} → api → Bridge → HA → Shelly
  → Bridge meldet Ist-Zustand des Relais zurück → Command ack/failed → Event
```

### 4.4 Planungspfad

```
worker: alle 15 min + bei neuen Preisen/Forecasts/Modus-Wechsel
  → Forecast-Refresh (Wetter 1 h, PV 1 h, Preise 13:00–15:00 für morgen, danach stündlich)
  → HeatDemandModel (48 h, 15 min) → BufferModel-Simulation
  → Planner erzeugt Plan[96 Intervalle] mit reason je Intervall → plans/plan_intervals
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
| Datenbank | **PostgreSQL 16 (Railway)**, native Partitionierung für Messwerte, Retention-Job | TimescaleDB ist auf Railways Standard-Postgres nicht als Extension verfügbar; bei ~1 Wert/s × 15 Sensoren ≈ 1,3 Mio. Zeilen/Tag ist natives Partitioning mit 14-Tage-Retention für Rohwerte ausreichend. Bewertung Timescale in 16.5 |
| Historische Rohdaten | **InfluxDB bleibt** (lokal), Zugriff nur über Bridge-Proxy für Backfill | keine Migration in v1 |
| Auth | **Single-Tenant**: Admin-Passwort (Argon2id) + Kiosk-Pairing-Code → langlebiges Geräte-Session-Cookie (HttpOnly) über Next-BFF; Bridge mit eigenem Device-Token (rotierbar) | kein OAuth-Provider nötig; valyze-Muster (iron-session, Bearer bleibt serverseitig) wird übernommen |
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
│   ├── bridge/                      # lokaler Agent im Haus
│   │   ├── Dockerfile
│   │   └── src/dch_bridge/
│   │       ├── main.py
│   │       ├── settings.py          # DCH_BRIDGE_*
│   │       ├── home_assistant/      # ws_client.py (subscribe_entities), rest_client.py, entity_map.py
│   │       ├── influxdb/            # query_proxy.py (v1 InfluxQL / v2 Flux)
│   │       ├── uplink/              # ws_uplink.py, queue.py (SQLite), protocol.py
│   │       ├── actuators/           # executor.py (TTL, Ack), watchdog.py
│   │       └── discovery.py         # listet HA-Entitäten für die Konfiguration
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
    source: str                # z. B. "ha:sensor.shelly_3em_total_power"

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
    # Stellgrößen-Ist (aus HA gelesen, nicht was wir gesendet haben):
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

## 8. Integrationsstrategie Home Assistant / InfluxDB

### 8.1 Grundsatz

Home Assistant bleibt die Geräteschicht. Alle Sensoren (SolarEdge, MyEnergi, Shelly 3EM, Shelly-Temperaturen,
Tibber-Preis, Wetter) und alle Aktoren (Shelly-Relais) sind bereits in HA integriert. Duck Curve Home spricht in v1
deshalb **nur mit Home Assistant**, nicht direkt mit MyEnergi-Cloud, SolarEdge-API oder Shelly-Geräten. Das spart
fünf Integrationen, vermeidet doppelte Polling-Lasten auf den Geräten und nutzt HA-Entitäten als stabile
Abstraktion. Die Adapter-Ordner `integrations/myenergi`, `solaredge`, `shelly` werden angelegt, bleiben aber
Platzhalter mit dokumentiertem Zweck (Direktzugriff nur, falls HA-Daten zu grob oder zu langsam sind – z. B. Shelly
3EM liefert lokal 1-Hz-Werte, HA-Standard-Polling ggf. nur alle 10–30 s).

### 8.2 Home Assistant: Lesen

- **Transport:** HA WebSocket API (`ws://<ha>:8123/api/websocket`), Authentifizierung mit Long-Lived Access Token,
  Kommando `subscribe_entities` mit expliziter `entity_ids`-Liste. Das liefert nur Änderungen (push), keine Polling-
  Last, mit `last_changed`/`last_updated` je Entität.
- **Backfill:** REST `GET /api/history/period/<start>?filter_entity_id=…&minimal_response` für die letzten Stunden
  nach einem Bridge-Neustart; für längere Zeiträume InfluxDB (8.4).
- **Entity-Mapping** als YAML in der Bridge (Beispiel, echte IDs sind offene Frage 25.1):

```yaml
home_assistant:
  url: http://homeassistant.local:8123
  token_env: DCH_BRIDGE_HA_TOKEN
entities:
  pv_power_kw:            { entity: sensor.solaredge_ac_power,              unit: W,  scale: 0.001 }
  grid_power_kw:          { entity: sensor.myenergi_harvi_grid_power,        unit: W,  scale: 0.001, sign: import_positive }
  battery_power_kw:       { entity: sensor.myenergi_libbi_power,            unit: W,  scale: 0.001, sign: discharge_positive }
  battery_soc:            { entity: sensor.myenergi_libbi_soc,              unit: "%", scale: 0.01 }
  ev_power_kw:            { entity: sensor.myenergi_zappi_power,            unit: W,  scale: 0.001 }
  heat_pump_power_kw:     { entity: sensor.shelly_3em_wp_total_power,       unit: W,  scale: 0.001, stale_after_s: 60 }
  buffer_temp_top_c:      { entity: sensor.shelly_temp_puffer_oben,         unit: "°C", stale_after_s: 900 }
  buffer_temp_mid_top_c:  { entity: sensor.shelly_temp_puffer_mitte_oben }
  buffer_temp_mid_bottom_c: { entity: sensor.shelly_temp_puffer_mitte_unten }
  buffer_temp_bottom_c:   { entity: sensor.shelly_temp_puffer_unten }
  electricity_price_ct_kwh: { entity: sensor.tibber_electricity_price,      unit: EUR/kWh, scale: 100 }
  outdoor_temp_c:         { entity: sensor.outdoor_temperature }
  hp_release_contact:     { entity: switch.shelly_wp_pv_freigabe,  kind: binary }
  hp_block_contact:       { entity: switch.shelly_wp_evu_sperre,   kind: binary }
actuators:
  coffee_machine:         { entity: switch.shelly_kaffeemaschine, label: Kaffee }
  terrace_light:          { entity: light.terrassenlicht,          label: Terrassenlicht }
  garden_fence_light:     { entity: light.gartenzaun,              label: Gartenzaun }
  hp_release_contact:     { entity: switch.shelly_wp_pv_freigabe,  label: WP PV-Freigabe, safety_class: heat_pump }
  hp_block_contact:       { entity: switch.shelly_wp_evu_sperre,   label: WP Sperre,      safety_class: heat_pump }
```

Die Vorzeichen-Übersetzung (`sign:`) passiert **ausschließlich** in der Bridge. Ab dem Uplink gilt die Konvention
aus Abschnitt 7. Ein Discovery-Kommando (`dch-bridge discover --match "shelly|myenergi|solaredge|tibber"`) listet
Entitäten mit Einheit und letztem Wert, um das Mapping zu erstellen.

**Zustände `unavailable`/`unknown`** werden nicht als 0 interpretiert, sondern als `Measurement(value=None,
quality=UNAVAILABLE|UNKNOWN)` weitergegeben. Der letzte gute Wert wird nur für die Anzeige (ausgegraut, mit Alter)
verwendet, nie für die Regelung.

### 8.3 Home Assistant: Schreiben (ab Phase 3)

- `call_service` über WebSocket (`switch.turn_on/turn_off`, `light.turn_on/turn_off`) mit anschließender
  Zustandsverifikation (Erwartung: Entität wechselt innerhalb `ack_timeout_s`, Default 5 s). Kein „fire and forget“.
- Jedes Kommando trägt `command_id`, `decision_id`, `ttl_s`. Die Bridge führt eine lokale TTL-Tabelle: Läuft eine
  TTL ohne Verlängerung ab, setzt die Bridge den Aktor auf seinen `safe_state` (Wärmepumpen-Kontakte: aus =
  „kein Eingriff“; Licht/Kaffee: kein safe_state, TTL optional).

### 8.4 InfluxDB

- **Version klären** (25.2): InfluxDB 1.x (InfluxQL, HA-Integration mit `database`) oder 2.x (Flux, `bucket`/`org`).
  Der Bridge-Proxy kapselt beide hinter `InfluxQueryProxy.range(entity, start, end, every="1m", agg="mean")`.
- **Nutzung:** (a) Backfill von `measurements_1min` in Postgres nach Ausfällen, (b) initiale Historie beim
  Erstbetrieb (z. B. letzte 12 Monate PV, Wärmepumpe, Außentemperatur für Kalibrierung von PV- und Wärmebedarfs-
  Modell), (c) Ad-hoc-Analysen. **Nicht** im Live-Pfad, **nicht** für die Regelung.
- **Zugriff:** Die Cloud stellt einen `history.backfill`-Auftrag in die Bridge-Queue; die Bridge fragt InfluxDB lokal
  ab und liefert komprimierte Batches (max. 10.000 Punkte/Frame) zurück. Es gibt keinen freien Query-Durchgriff aus
  der Cloud (kein beliebiges Flux/InfluxQL), sondern nur parametrisierte Abfragen auf gemappte Entitäten.

### 8.5 Tibber

- Direkt aus dem Backend per GraphQL (`viewer.homes[].currentSubscription.priceInfo { today tomorrow }` plus, sobald
  verfügbar, 15-Minuten-Auflösung über `priceInfo(resolution: QUARTER_HOURLY)` – Feldname bei Umsetzung prüfen).
  Abruf um 13:00, 13:30, 14:00, 15:00 UTC-lokal (Preise für morgen erscheinen meist zwischen 13 und 14 Uhr), sonst
  stündlich als Kontrolle. Persistiert als `forecasts(kind="price")`.
- Der HA-Preis-Sensor wird zusätzlich als Live-Wert übernommen (Plausibilitätsabgleich).
- Fällt Tibber aus: letzte bekannte Preise gelten weiter (mit Kennzeichnung `stale`), preisbasierte Regeln pausieren
  nach `price_max_age_h` (Default 30 h), PV-Regeln laufen weiter, Heizbetrieb ist nie betroffen (Abschnitt 11).

## 9. Strategie für Live-Daten

### 9.1 Ziel und Budget

| Strecke | Ziel |
|---|---|
| Gerät → HA | geräteabhängig (Shelly lokal ≈ 1 s, MyEnergi-Cloud 10–30 s, SolarEdge-Cloud bis 5 min – siehe 25.3) |
| HA → Bridge | < 100 ms (WebSocket-Push) |
| Bridge → API | Frame alle 1 s (koalesziert), < 300 ms Laufzeit |
| API → Dashboard | SSE, max. 1 Frame/s, < 200 ms |
| **Ende-zu-Ende (Shelly-Werte)** | **≈ 1–2 s**; MyEnergi/SolarEdge-Werte tragen ihr eigenes `observed_at` und werden mit Alter angezeigt |

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

- **OFF:** Duck Curve Home beobachtet nur. Beide Kontakte aus. Bestehende HA-Automation darf laufen.
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
| **E0 Hardware** | Shelly-Relais | Shelly Gen2/Gen3 „Auto-Off-Timer“ pro Relais (Geräteeinstellung): K2-Relais `auto_off: 1200 s`, K1-Relais `auto_off: 1800 s`. Ein gesetzter Kontakt fällt also auch dann, wenn HA, Bridge, Netz und Cloud gleichzeitig ausfallen | alles oberhalb tot |
| **E1 Home Assistant** | HA-Automation (vom Betreiber angelegt, von DCH dokumentiert) | Watchdog: Wenn `input_datetime.dch_heartbeat` älter als 30 min → beide Kontakte aus, Benachrichtigung. Die Bridge setzt den Heartbeat alle 60 s | Bridge tot oder abgeklemmt |
| **E2 Bridge** | lokaler Agent | TTL-Tabelle je Aktor; ohne Verlängerung durch die Cloud → `safe_state`. Zusätzlich: Cloud-Verbindung > `offline_release_s` (Default 180 s) weg → alle Wärmepumpen-Kontakte sofort auf `safe_state`, Event lokal gepuffert | Cloud/Internet tot |
| **E3 Cloud-Regler** | Worker | Guards (Mindestzeiten, Max-Sperrdauer, Max-Starts, Plausibilität), Sensorqualitäts-Gate, Preisdaten-Alter, `FAILSAFE`-Zustand mit Auto-Recovery, Leader-Lock gegen doppelte Regler | Logikfehler, Datenfehler |

Ebene E0 ist die wichtigste und kostet nichts. Sie erzwingt, dass der Regler K1/K2 regelmäßig „nachsetzt“ (Bridge
sendet bei Bedarf alle 10 min ein Refresh-`turn_on`); das ist gewollt: Ein Zustand, der aktiv gehalten werden muss,
kann nicht versehentlich ewig bleiben.

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
| InfluxDB | keine | kein Backfill; Live und Regelung unberührt |
| Postgres (Railway) | keine (E2 räumt auf) | API liefert 503, Worker geht in FAILSAFE, Dashboard zeigt Störung |
| Railway komplett | keine (E2 nach 180 s) | Dashboard zeigt Störung, letzte Werte |
| Bridge / HA-Host | keine (E0 nach ≤ 30 min) | wie oben |
| Duck Curve Home vollständig entfernt | keine | – |

### 11.5 Watchdog-Konzept zusammengefasst

```
Cloud-Regler ──10 s──► Decision (valid_until = now + TTL)
      │
      ▼ Kommando/Refresh nur bei Änderung oder alle 10 min
Bridge ──60 s──► HA heartbeat entity      ──► HA-Automation räumt nach 30 min auf
      │
      ▼ turn_on (Shelly auto_off läuft)  ──► Relais fällt nach 20–30 min selbst
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
| **1 UI-Prototyp / Demo-Modus** | Monorepo-Skelett, Tokens/Design-System, `hems-core` mit Domänenmodell, Thermal-SOC, Bilanzierer, Simulation (`demo_house`), API mit In-Memory-Repositories und SSE, Dashboard mit Energiefluss, Tageschart, Puffer, Steuerkacheln (gegen Simulation), Intelligence Card mit simulierten Entscheidungen, Zeitraffer (24 h in 5 min), CI (Web + Python), Docker-Compose, README/ARCHITECTURE/CONFIGURATION/HEMS_CONTROL Erstfassung | `docker compose up` startet Demo ohne Haus; Playwright-Smoke grün; Tests für SOC, Bilanz, Simulation; Dashboard läuft 24 h stabil im Browser-Kiosk | 2–3 Wochen |
| **2 Read-only Live** | Bridge (HA-WS, Entity-Map, Queue, Uplink), API-Ingest, Postgres + Alembic (Messwerte, Events, Konfiguration), Tibber-Preise, Wetter (Open-Meteo), PV-Forecast v1, History-API, Zeitraumwahl, Railway-Deploy (web, api, worker, postgres), Kiosk-Pairing | echte Werte auf dem iPad; Ausfallszenarien (WLAN, Bridge-Neustart, Backend-Deploy) getestet; Backfill aus InfluxDB für 24 h nachgewiesen | 3–4 Wochen |
| **3 Manuelle Steuerung** | Aktor-Kommandos mit TTL/Ack über Bridge, Kacheln aktiv, Wärmepumpe MANUAL mit Dauer, Shelly-Auto-Off-Setup dokumentiert, HA-Watchdog-Automation dokumentiert, Verhalten der ELCO auf K1/K2 protokolliert | Kaffee/Licht/K1 schaltbar; Rückfall-Tests E0–E2 durchgeführt und dokumentiert | 2 Wochen |
| **4 Rule-Based HEMS** | Controller-Zustandsmaschine, Guards, PV-/Preisregeln, Reason-Codes, Decision-Persistenz, Intelligence Card mit echten Begründungen, vollständige Unit-Tests der geforderten Fälle (Hysterese, Mindestzeiten, PV, negative Preise, Puffer voll, Override, Sensorausfall, Tibber-Ausfall) | mindestens 2 Wochen Betrieb AUTO/PV ohne Eingriff; Events zeigen keine Guard-Verletzung | 3 Wochen |
| **5 Smart Scheduler** | Wärmebedarfsmodell, Puffermodell, Forecast-Aware-Planner, Plan-Persistenz, Plan-Bänder im Chart, Kalibrierungsjobs, optional K2 nach Validierung | Plan erklärt jedes Intervall; PV-Forecast-Fehler < 20 % Tages-kWh nach Kalibrierung; K2 nur mit dokumentiertem Freigabetest | 3–4 Wochen |
| **6 Optimizer** | MILP-Planer (HiGHS), Gebäude-RC-Modell, Komfortgrenzen, Vergleich Regel vs. Optimum im Dashboard | Optimum-Plan im Schattenbetrieb 4 Wochen mit Kostenvergleich, dann aktiv | 4+ Wochen |

Jede Phase beginnt mit einer kurzen Standortbestimmung (Was ist da, was hat sich geändert, Plan in 10 Zeilen), endet
mit Tests, Doku-Update und einer ADR pro wesentlicher Entscheidung.

## 15. Railway-Zielarchitektur

```
Railway Project „duckcurve-home“  (Region: EU-West, gleiche Region für alle Services)
│
├── web        Next.js (Dockerfile apps/web)        Root Directory: apps/web
│              PORT von Railway, öffentlich: home.duckcurve.de (Custom Domain, TLS von Railway)
│              Env: DCH_API_URL=http://api.railway.internal:8000, DCH_SESSION_SECRET
│              Healthcheck: GET /api/health (BFF prüft API-Erreichbarkeit)
│
├── api        FastAPI (Dockerfile apps/api, CMD uvicorn)   Root Directory: apps/api  (Build-Kontext Repo-Root*)
│              öffentlich NUR für den Bridge-Endpunkt wss://api-home.duckcurve.de/bridge/ws
│              intern für web über *.railway.internal (IPv6 → uvicorn --host ::)
│              Env: DATABASE_URL, DCH_ROLE=api, DCH_BRIDGE_TOKEN_PEPPER, DCH_TIBBER_TOKEN, …
│              Healthcheck: GET /health  (DB-Ping, Bridge-Status, Version)
│              Replicas: 1 (SSE-Broker und Bridge-Verbindung sind prozesslokal; siehe 15.2)
│
├── worker     gleiches Image wie api, CMD python -m dch_api.worker
│              Env: DATABASE_URL, DCH_ROLE=worker, externe API-Keys
│              Healthcheck: GET /health auf Port 8001 (Tick-Alter, Leader-Status)
│              Replicas: genau 1 + Advisory-Lock
│
├── postgres   Railway PostgreSQL 16, tägliches Backup (Railway) + wöchentlicher pg_dump nach R2/S3 (Job)
│
└── (optional) cron  Railway Cron-Service für Retention/Backups, falls nicht im Worker
```

\* Weil `apps/api` und `apps/worker` das Workspace-Paket `packages/hems-core` brauchen, wird das Python-Image vom
Repo-Root gebaut (`RAILWAY_DOCKERFILE_PATH=apps/api/Dockerfile`, Root Directory leer, Watch Paths
`apps/api/**`, `packages/**`). valyze löst das gleiche Problem für `locales/` identisch.

### 15.1 Konfiguration je Service (`railway.json`)

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

`preDeployCommand` läuft einmal pro Deploy vor dem Start der neuen Instanz; scheitert die Migration, wird nicht
deployt und die alte Instanz läuft weiter. Nur additive Migrationen dürfen so laufen (23.4).

### 15.2 Skalierung und Zustand

- Die API hält zwei prozesslokale Dinge: die Bridge-WebSocket-Verbindung und die SSE-Verbindungen. Mit einer
  Replika ist das unkritisch. Sollte je eine zweite Replika nötig sein, wird der Live-State über Postgres
  `LISTEN/NOTIFY` (oder Redis) verteilt – die Abstraktion `LiveStateBus` ist dafür vorgesehen.
- Deploy-Rollover: Railway startet die neue Instanz, wartet auf Healthcheck, dann Traffic-Wechsel. Die Bridge
  verliert kurz die Verbindung (Reconnect < 5 s, Queue puffert), das Dashboard reconnectet.
- Kosten: vier kleine Services; API/Worker mit 512 MB RAM ausreichend; Postgres wächst mit ~1 GB/Monat Rohdaten
  bei 14-Tage-Retention nicht, 15-min-Aggregate ≈ 5 MB/Jahr.

### 15.3 Domains und Zugriff

- `home.duckcurve.de` → web (Kiosk, Login/Pairing).
- `api-home.duckcurve.de` → api; alle Pfade außer `/health` und `/bridge/ws` verlangen Bearer (vom BFF) oder werden
  gar nicht öffentlich benötigt. Alternative ohne zweite öffentliche Domain: Der BFF proxyt alles, und die Bridge
  verbindet sich über `home.duckcurve.de/bridge/ws` (Next-Route mit WebSocket-Upgrade ist umständlich) – deshalb
  die eigene API-Domain.

## 16. PostgreSQL-Datenmodell

Schema `dch` (nicht `public`), Zeitstempel `timestamptz`, IDs `uuid` (v7 wenn verfügbar, sonst v4), Konfigurationen
und variable Strukturen als `jsonb` mit Pydantic-Validierung im Backend. Zeilen, die abgefragt oder gefiltert werden,
bekommen Spalten; alles andere bleibt Payload (valyze-Regel).

### 16.1 Tabellen

**Stammdaten und Konfiguration**

| Tabelle | Zweck | Wichtige Spalten |
|---|---|---|
| `devices` | Geräte (PV, Batterie, Wallbox, Wärmepumpe, Puffer, Relais, Sensoren) | `id, kind, name, vendor, model, location, meta jsonb` |
| `sensors` | Messpunkte mit Quelle und Mapping | `id, device_id, key` (z. B. `pv_power_kw`), `source` (`ha`, `derived`, `bridge`), `source_ref` (Entity-ID), `unit, stale_after_s, sign_convention, enabled` |
| `actuators` | steuerbare Ausgänge | `id, device_id, key, source_ref, label, safety_class` (`none`, `heat_pump`), `safe_state, default_ttl_s, auto_off_s_hardware` |
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
| `measurements_raw` | Rohwerte 1–10 s | `(sensor_key, observed_at) pk, value real, quality smallint`; **partitioniert nach Tag** (`PARTITION BY RANGE (observed_at)`), Retention 14 Tage (Partition droppen, nicht `DELETE`) |
| `measurements_1min` | Minutenmittel (aus raw oder Backfill Influx) | `(sensor_key, bucket) pk, avg, min, max, samples, source` (`raw`, `influx`), Partition monatlich, Retention 400 Tage |
| `measurements_15min` | Planungsraster | `(sensor_key, bucket) pk, avg_kw, energy_kwh, min, max, samples`; unbegrenzt |
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

Worker-Job stündlich: `raw → 1min` (für die letzte volle Stunde), `1min → 15min`, `15min → daily`, dann Partitionen
älter als Retention droppen. Aggregation ist idempotent (`INSERT … ON CONFLICT DO UPDATE`), damit Backfill aus Influx
dieselben Wege nutzt.

### 16.4 Trennung InfluxDB / PostgreSQL

| | InfluxDB (lokal) | PostgreSQL (Railway) |
|---|---|---|
| Rohmesswerte aller HA-Entitäten | ✔ Quelle der Wahrheit, lange Historie | ✘ (nur gemappte Sensoren, 14 Tage) |
| Minuten-/15-min-Aggregate | – | ✔ |
| Konfiguration, Modi, Overrides | – | ✔ |
| Entscheidungen, Begründungen, Kommandos | – | ✔ |
| Forecasts, Pläne, Kalibrierungen | – | ✔ |
| Events, Fehler | – | ✔ |

### 16.5 TimescaleDB-Bewertung

Timescale brächte automatische Chunking/Compression/Continuous Aggregates und würde 16.3 vereinfachen. Gegen v1:
Railways Standard-Postgres-Template hat die Extension nicht; ein eigenes Timescale-Image ist möglich, aber dann
liegt Backup/Upgrade in eigener Hand. Bei unserem Volumen (≈ 15 Sensoren × 0,2–1 Hz) reichen native Partitionen.
**Entscheidung:** Postgres nativ; Repository-Schicht so schneiden, dass ein Wechsel zu Hypertables nur Migrationen
und den Aggregationsjob betrifft. Re-Evaluation, wenn mehr als ~50 Sensoren oder > 1 Hz dauerhaft anfallen.

## 17. Sichere Verbindung Railway ↔ Haus

### 17.1 Bewertete Optionen

| Option | Richtung | Bewertung |
|---|---|---|
| HA per Port-Forwarding/Reverse-Proxy öffentlich | Cloud → Haus | **abgelehnt** (ausdrücklich unerwünscht; Angriffsfläche HA) |
| HA über Nabu-Casa-Cloud-URL | Cloud → Haus | funktioniert, aber HA-Vollzugriff über Dritt-Cloud, Latenz, kein InfluxDB-Zugriff; höchstens Notfall-Fallback |
| VPN/Tailscale zwischen Railway und Haus | beidseitig | Railway hat keinen nativen Tailscale-Sidecar; Userspace-Tailscale im Container ist möglich, aber fragil bei Deploys; HA bliebe „im Netz“ der Cloud erreichbar – mehr Zugriff als nötig |
| MQTT-Broker in der Cloud, HA publisht/subscribed | Haus → Cloud | solide, Standard; zusätzlicher Dienst mit Auth/TLS-Pflege; HA-MQTT-Integration müsste jeden Sensor publizieren (Konfigurationsaufwand in HA) |
| **Lokaler Agent (Bridge) mit ausgehender WSS-Verbindung** | **Haus → Cloud** | **gewählt**: minimale Angriffsfläche (kein offener Port im Haus), volle Kontrolle über Protokoll, Queue und Failsafe, InfluxDB-Proxy möglich, HA-Konfiguration bleibt unangetastet |

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
  `heartbeat` beidseitig alle 15 s; `history.request {job_id, key, start, end, every}` → `history.chunk` …;
  `event {code, message, context}`.
- Sequenznummern und Ack: Die Bridge hält eine SQLite-Queue (`queue.db`, WAL). Frames werden erst nach `ack`
  gelöscht. Nach Reconnect sendet sie ab der letzten nicht bestätigten Sequenz (Backlog komprimiert auf 1-min-Bins,
  wenn > 1 h Rückstand, Rohdaten bleiben in InfluxDB). Maximale Queue 7 Tage, danach älteste verwerfen.
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
| HA Long-Lived Token | nur auf der Bridge (`DCH_BRIDGE_HA_TOKEN`), nie in der Cloud | in HA erzeugen, in Bridge-Env tauschen |
| InfluxDB Token/Passwort | nur Bridge | – |
| Tibber-Token, Solcast-Key | Railway-Variablen (worker) | Anbieter |
| Kiosk-Session | HttpOnly-Cookie (iron-session-Muster), 180 Tage, widerrufbar | in UI |

Regeln: keine Secrets im Repo (`.env.example` enthält nur Namen), `gitleaks` in CI, Secrets erscheinen nie in Logs
(structlog-Processor maskiert bekannte Schlüssel), `/health` gibt keine Verbindungsdaten preis.

### 17.4 Offline-Betrieb der Bridge

Ohne Cloud: Bridge sammelt weiter in die Queue, hält den HA-Heartbeat, setzt nach `offline_release_s` alle
Wärmepumpen-Kontakte auf `safe_state` und schreibt einen lokalen Event. Es gibt in v1 **keine** lokale Regelung –
die Wärmepumpe läuft dann so, wie sie es auch ohne Duck Curve Home täte. Ein lokales Mini-Dashboard der Bridge
(`http://bridge:8080/status`, nur LAN) zeigt Queue-Stand, Verbindung, Uhrzeitversatz, letzte Kommandos.

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
├── docker.yml      PR: docker build beider Images (ohne Push), Trivy-Scan (Warnstufe)
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
  --kicker: 400 13px/1.2 var(--font-mono);   /* + letter-spacing .13em, uppercase; Website: 11 px */
  --kpi-xl: 400 64px/1 var(--font-mono);     /* letter-spacing -.03em */
  --kpi-l:  400 40px/1 var(--font-mono);     /* letter-spacing -.03em */
  --kpi-m:  400 28px/1 var(--font-mono);     /* letter-spacing -.02em */
  --title:  600 22px/1.2 var(--font-sans);   /* letter-spacing -.02em */
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
| 25.1 | **Entity-IDs in Home Assistant** für alle Sensoren und Relais (SolarEdge, Harvi, Libbi, Zappi, Shelly 3EM, 4× Shelly-Temp, Tibber, K1/K2, Kaffee, Terrasse, Gartenzaun) und deren Einheiten/Vorzeichen | Entity-Map der Bridge | Discovery-Kommando in Phase 2 liefert Liste; Annahme in 8.2 |
| 25.2 | **InfluxDB-Version** (1.x InfluxQL oder 2.x Flux), Datenbank-/Bucket-Name, Retention, Zugangsdaten, läuft sie auf dem HA-Host? | Query-Proxy, Backfill | Adapter für beide vorbereiten |
| 25.3 | **Aktualisierungsraten der Quellen in HA**: MyEnergi-Integration (Cloud-Polling, typ. 10–30 s?), SolarEdge (Cloud 5–15 min oder Modbus/TCP lokal?), Shelly (lokal, ≈ 1 s) | „Live“-Anspruch; Bilanz mit unterschiedlich alten Werten | Alter je Wert anzeigen; ggf. SolarEdge-Modbus lokal aktivieren |
| 25.4 | **Gibt es Tibber Pulse** (Echtzeit-Zählerwerte in HA)? Wenn ja, ist das die beste Netzmessung neben Harvi | Netzleistung 1 s, Abgleich mit Harvi | Harvi als primär |
| 25.5 | **HA-Host für die Bridge**: HA OS (dann Bridge als Add-on/Container über Portainer/SSH) oder Docker-Host? Docker verfügbar? | Deployment der Bridge | Docker-Compose annehmen; Add-on-Verpackung später |
| 25.6 | **Exakte Koordinaten, kWp, Ausrichtung, Neigung, Wechselrichterleistung, Anzahl Dachflächen**, evtl. Einspeisebegrenzung | PV-Forecast | Platzhalter in 19.1 |
| 25.7 | **Innentemperatur verfügbar?** (Thermostat, Sensor) | Gebäudemodell, Komfortgrenzen, Kalibrierung τ | ohne: Gebäude-Vorheizen nur „blind“ mit engen Grenzen oder gar nicht (Phase 6 abhängig) |
| 25.8 | **Verhalten der ELCO AERO auf K1/K2**: Was genau ändert K1 (Sollwertanhebung, WW-Beladung)? Zeigt K2 Frostschutz? Herstellerangabe zur max. Sperrdauer/Tag? Klemmenbelegung dokumentiert? | Regelparameter, Freigabe von K2 | Phase 3 protokolliert Versuche; K2 bleibt aus |
| 25.9 | **Wie ist die bestehende HA-Regel für die Wärmepumpe** aufgebaut, und soll sie in Phase 4 abgeschaltet werden? („WP Auto“ auf dem heutigen Dashboard) | Doppelsteuerung vermeiden | in Phase 4 deaktivieren, Logik übernehmen |
| 25.10 | **Shelly-Modelle der Relais** (Gen1/Gen2/Gen3, Plus 1/Pro) – unterstützen sie Auto-Off-Timer? | Rückfallebene E0 | E0 mit HA-Automation E1 kompensieren, falls nicht |
| 25.11 | **Puffervolumen, Sensorhöhen, Anschlusshöhen** (WP-Vorlauf, Pelletofen, Heizkreis, WW-Entnahme) | Schichtgewichte, SOC | gleiche Volumenanteile annehmen |
| 25.12 | **Einspeisevergütung** (ct/kWh) und Tibber-Tarifdetails (Grundpreis, Netzentgelt fix/variabel) | Opportunitätskosten im Planer | 8 ct/kWh annehmen |
| 25.13 | **Pelletofen**: gibt es irgendeinen Indikator (Steckdosen-Leistung, Abgastemperatur, Zeitplan)? | Fremdwärme erkennen | nur Residual-Erkennung |
| 25.14 | **Domains**: `home.duckcurve.de` / `api-home.duckcurve.de` gewünscht? DNS bei wem? | Railway Custom Domains | Railway-Standarddomains bis dahin |
| 25.15 | **Zugriff für weitere Personen/Handys** neben dem iPad? | Auth-Umfang | Single-User + mehrere Kiosk-Geräte |
| 25.16 | **Wallbox-Steuerung später gewünscht** (MyEnergi-API schreibend)? | Architekturreserve | nur lesen in v1 |
| 25.17 | **Wetter-Provider**: Open-Meteo genügt? DWD gewünscht? | 18.2 | Open-Meteo |
| 25.18 | **Repository-Sichtbarkeit**: öffentlich (dann Log-Hygiene wie valyze) oder privat? | CI-Secrets, Doku | privat annehmen |

## 26. Glossar und Konventionen

| Begriff | Bedeutung |
|---|---|
| **K1 / Release-Kontakt** | potenzialfreier Kontakt „PV-Überschuss“: Anforderung an die Wärmepumpe, mehr Wärme zu erzeugen |
| **K2 / Block-Kontakt** | potenzialfreier Kontakt „Netzbetreiber-Shutdown“ (EVU-Sperre): Wärmepumpe darf nicht heizen |
| **Bridge** | lokaler Duck-Curve-Home-Agent im Haus (Python), verbindet HA/InfluxDB ausgehend mit Railway |
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

