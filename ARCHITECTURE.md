# Architektur (Kurzfassung)

Ausführlich: [`docs/PROJECT_PLAN.md`](docs/PROJECT_PLAN.md). Dieses Dokument beschreibt den **umgesetzten Stand**.

## Schichten

```
apps/web  (Next.js)  ── SSE + REST über /api/dch/* (Rewrite) ──►  apps/api (FastAPI)
                                                                     │
                     application/  DemoRunner, PlanService           │  Use-Cases
                     routers/      health, live, history, plan,      │  HTTP
                                   control, config, demo             │
                     infrastructure/  SseBroker, HistoryStore (RAM)  │  Technik
                                                                     ▼
                     packages/hems-core  (reines Python, keine I/O, mypy --strict)
                       domain/      Quality, Measurement, EnergySnapshot, BufferState, HeatPumpState,
                                    Decision + ReasonCode, OperatingMode/Override, HemsConfig
                       balance/     Bilanzierung, PV-Überschuss
                       thermal/     thermischer SOC (layered_energy_v1, weighted_mean_v1)
                       control/     HeatPumpTracker, HeatPumpController (Zustandsmaschine), Ewma, explain
                       planning/    Preisfenster (Rang, günstig/teuer/negativ)
                       simulation/  DemoHouse (PV, Last, Wetter, Wärmepumpe, Puffer, Batterie, Wallbox, Preise)
```

Die Importgrenze wird mit `import-linter` erzwungen: `hems_core` darf weder `dch_api` noch FastAPI, SQLAlchemy,
httpx oder MQTT importieren; Router importieren keine Integrationen direkt.

## Datenfluss im Demo-Modus

1. `DemoRunner` rückt die Simulation jede Echtzeitsekunde um `DCH_DEMO_SPEED` Sekunden vor (Teilschritte ≤ 10 s).
2. Nach jedem Teilschritt: Snapshot → `HistoryStore` (1-min-Bins) → `HeatPumpTracker` (Laufzustand aus Leistung)
   → thermischer SOC. Alle `DCH_TICK_S` Simulationssekunden ein Regler-Tick.
3. Der Regler liefert eine `Decision` (K1/K2, Reason-Codes, Erklärung, TTL). Der Runner setzt K1 in der
   Simulation mit Hardware-Auto-Off-TTL, genau wie später am Shelly.
4. Alle 15 Simulationsminuten berechnet `PlanService` Preis- und PV-Überschussfenster und ein 15-min-Raster.
5. Der `SseBroker` verteilt `snapshot`, `decision`, `plan` an alle Dashboards (Koaleszierung bei Rückstau).

Im Live-Betrieb (Phase 2) bleiben Regler, Planung und Dashboard unverändert; die Simulation wird durch die
Geräteschicht ersetzt (Home Assistant und/oder direkte Adapter), die In-Memory-Historie durch PostgreSQL.

## Vorzeichenkonvention

Aus Sicht des Hauses: Erzeuger und Verbraucher positiv; `grid_power_kw` > 0 Bezug, < 0 Einspeisung;
`battery_power_kw` > 0 Entladen, < 0 Laden. Bilanz `pv + grid + battery = house = base + heat_pump + ev`.
Jeder Wert trägt `observed_at`, `quality` (ok, stale, unavailable, unknown, derived, inconsistent) und `source`.

## Frontend

- Tokens in `apps/web/src/styles/tokens.css` (einzige Quelle), Tailwind 4 bindet sie per `@theme`.
- Live-Daten: `EventSource` mit Reconnect/Backoff, Watchdog (15 s ohne Frame → Reconnect), Erstladung von
  Zustand/Historie/Plan, keine Polling-Schleife. Store: Zustand (`lib/live/store.ts`), Minutenraster wird
  clientseitig fortgeschrieben.
- Chart: ein ECharts-Wrapper (`components/charts/EChart.tsx`, `setOption` auf lebender Instanz), zwei gekoppelte
  Panels (Leistung, Strompreis) mit gemeinsamer Zeitachse, Jetzt-Linie, Prognose gestrichelt, Planfenster als
  Bänder.
- Energiefluss und Pufferspeicher sind eigene SVG-Komponenten.

## Entscheidungen (ADR-Kurzliste)

| # | Entscheidung | Begründung |
|---|---|---|
| 1 | Regler-Kern I/O-frei in `hems-core` | testbar, später auf Edge verschiebbar |
| 2 | SSE statt WebSocket für das Dashboard | unidirektional, Auto-Reconnect, proxyfreundlich |
| 3 | ECharts mit gekoppelten Panels statt Doppelachse | lesbarer, entspricht Website-Stil, Doppelachse bleibt Option |
| 4 | Ist-Zustand der Wärmepumpe aus Leistung | K1 ist nur eine Anforderung, keine Garantie |
| 5 | Hardware-Auto-Off in jedem Schaltbefehl | sicherer Grundzustand ohne Mitwirkung der Software |
| 6 | In-Memory-Historie in Phase 1 | keine Datenbank nötig, PostgreSQL folgt mit Alembic in Phase 2 |
