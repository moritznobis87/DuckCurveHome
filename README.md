# Duck Curve Home

Home-Energy-Management-System (HEMS) für ein Wohnhaus in Geilenkirchen: Energieflüsse, Pufferspeicher,
Strompreis und der Wärmepumpen-Plan auf einen Blick – auf einem iPad an der Wand. Ab Phase 4 optimiert
Duck Curve Home die Wärmepumpe als flexible Last nach PV-Überschuss, Strompreis und Wärmebedarf, ohne die
Anlage selbst zu verändern: gesteuert werden ausschließlich die beiden dafür vorgesehenen Kontakte.

**Status: Phase 2 – Read-only Live.** Demo-Modus (Simulation) und Live-Modus (Home Assistant über die Bridge
als HA-Add-on, PostgreSQL auf Railway, Tibber, Open-Meteo). Der Regler entscheidet und erklärt, schaltet aber
noch nichts (`DCH_ACTUATION_ENABLED=false`). Plan: [`docs/PROJECT_PLAN.md`](docs/PROJECT_PLAN.md),
Betrieb: [DEPLOYMENT.md](DEPLOYMENT.md).

## Schnellstart

```bash
# Voraussetzungen: Docker (oder: uv ≥ 0.8, Node 22, pnpm 10)
docker compose up --build          # Dashboard: http://localhost:3000, API: http://localhost:8000/docs
DCH_DEMO_SPEED=288 docker compose up   # Zeitraffer: 24 Stunden in 5 Minuten
```

Ohne Docker:

```bash
uv sync --all-packages && (cd apps/web && pnpm install)
tools/demo.sh                      # API mit Reload + Next.js Dev-Server
```

## Aufbau

| Pfad | Inhalt |
|---|---|
| `packages/hems-core` | reine Domäne: Modelle, Vorzeichenkonvention, Bilanz, thermischer SOC, Regler-Zustandsmaschine, Preisfenster, Simulation |
| `apps/api` | FastAPI: Live-Zustand, SSE-Stream, Historie, Plan, Steuerung, Bridge-Ingest, PostgreSQL (Alembic) |
| `apps/bridge` + `addons/duckcurve_bridge` | Bridge als Home-Assistant-Add-on: liest Entitäten, schaltet mit TTL, ausgehende WSS-Verbindung |
| `apps/web` | Next.js-Dashboard (iPad-Querformat, Dark Mode, Duck-Curve-Design-System) mit Detailseiten `/pv`, `/haus`, `/batterie`, `/wallbox`, `/waerme` (Energiebilanz Tag/Woche/Monat/Jahr) und `/prognose` |
| `docs/` | Projektplan, OpenAPI-Schema, Architekturentscheidungen |

Weitere Dokumente: [ARCHITECTURE.md](ARCHITECTURE.md) · [CONFIGURATION.md](CONFIGURATION.md) ·
[HEMS_CONTROL.md](HEMS_CONTROL.md)

## Entwicklung

```bash
uv run pytest -q                         # Python-Tests (Kern + API)
uv run ruff check apps packages && uv run mypy apps/api/src packages/hems-core/src && uv run lint-imports
cd apps/web && pnpm lint && pnpm typecheck && pnpm test && pnpm build
tools/gen-types.sh                       # OpenAPI → docs/openapi.json → apps/web/src/lib/api/types.ts
```

Demo steuern (Zeitraffer, Störungen, Szenarien):

```bash
curl -X POST localhost:8000/api/v1/demo -H 'content-type: application/json' -d '{"speed": 120}'
curl -X POST localhost:8000/api/v1/demo -H 'content-type: application/json' -d '{"scenario": "sunny_surplus"}'
curl -X POST localhost:8000/api/v1/demo -H 'content-type: application/json' -d '{"fault_key": "grid_power_kw", "fault_quality": "unavailable", "fault_duration_s": 300}'
```

## Phasen

0 Analyse ✔ · 1 Demo-Modus ✔ · **2 Read-only Live (dieser Stand)** · 3 Manuelle Steuerung · 4 Rule-Based HEMS ·
5 Smart Scheduler · 6 Optimizer – Details und Definition of Done in Abschnitt 14 des Projektplans.

## Weitere Dokumente

- [docs/OPEN_QUESTIONS.md](docs/OPEN_QUESTIONS.md) – offene Rückfragen mit Annahmen
- [docs/design/prognose-und-waermemodell.md](docs/design/prognose-und-waermemodell.md) – Prognoselernen, Einspeiseprognose, Wärmemodell
