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
                       regelkreis/  Struktur der Kaskade, Parameterregister mit Herkunft, Entwurf
                                    nach SIMC, Schätzer und Übernahmeprüfung, Karte
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

## Datenfluss im Live-Modus (Phase 2)

1. Die Bridge (HA-Add-on, `apps/bridge`) liest Entitäten über die HA-WebSocket-API, normalisiert sie nach
   `entities.yaml` (Einheit, Skalierung, Vorzeichen) und sendet `telemetry`-Frames über eine ausgehende
   WSS-Verbindung an `/bridge/ws` (Bearer-Token). Eine SQLite-Outbox puffert bis zum `ack`.
2. `BridgeHub` nimmt die Frames an, `LiveRuntime` schreibt Rohwerte und den Spiegel `live_state` in
   PostgreSQL (`SqlRepositories`) und aktualisiert den `LiveState` im Prozess; SSE wie im Demo-Modus.
3. Der Regler-Tick läuft alle 10 s auf dem Snapshot des `LiveState`; Entscheidungen werden in
   `control_decisions` gespeichert. Schaltbefehle gehen erst mit `DCH_ACTUATION_ENABLED=true` als `command`
   an die Bridge, die sie über HA-Dienste ausführt und den Zustand zurückmeldet.
4. `ForecastService` holt Tibber-Preise und Open-Meteo-Wetter, `simple_pv_forecast` rechnet die PV-Erwartung;
   daraus baut `PlanService` alle 15 min den Plan.
5. Die Historie für das Chart kommt aus Minutenmitteln der Rohwerte (`minute_series`); Rohwerte werden nach
   14 Tagen gelöscht.

Regler, Planung und Dashboard sind in beiden Modi identisch; Router sprechen nur das `Runtime`-Protokoll.

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
| 7 | Home Assistant als Geräteschicht, Bridge als HA-Add-on, Railway als Hosting | ADR-0001: geringster Aufwand, HA bleibt geschlossen, Datenbank managed |
| 8 | BFF-Route mit signiertem Kiosk-Cookie statt Auth in der API | Bearer bleibt serverseitig (valyze-Muster), Pairing per Link |
| 9 | Regler aus gelernten Streckenparametern rechnen (SIMC) statt von Hand einstellen | indirekter selbsteinstellender Regler; die Einstellregel ist prüfbar, die Handeinstellung war es nie |
| 10 | Übernahme einer Schätzung nur über fünf Hürden (Daten, Grenzen, Unsicherheit, Wartezeit, Gütegewinn) | das Modell kann nie schlechter werden als sein Startwert; jede Ablehnung hat einen Satz |
| 11 | Lernzustand des Regelkreises in `model_calibrations` (`regelkreis_v1`) statt eigener Tabelle | ein Zustand je Modell, genau wofür die Tabelle da ist |
| 12 | Der Regelkreis in der App als Liste nach Ebenen statt als Blockschaltbild | die einzige Seite, die bewusst anders aussieht als die Vorlage: eine Zeichnung von 1400 Punkten Breite ist am Telefon ein Ausschnitt, durch den man schiebt - dieselben Zahlen, dieselben Instrumente, andere Gestalt |


**Nummer 8 ist seit dem 23.11.2026 umgekehrt:** die Anmeldung steht mit Personen und Passkeys in
der API, das BFF hält nur noch ein opakes Sitzungstoken, und die Rechte liegen in
`dch_api/auth/rechte.py` statt im Proxy ([docs/ZUGANG.md](docs/ZUGANG.md))
([`docs/decisions/ADR-0002-identitaet-und-berechtigung.md`](docs/decisions/ADR-0002-identitaet-und-berechtigung.md)).
**ADR-0003** beschreibt, wie eine Box im Kundenrollout ohne Home Assistant erreichbar wird - Beitritt,
Verzeichnis, Relais und Flotte
([`docs/decisions/ADR-0003-erreichbarkeit-und-flotte.md`](docs/decisions/ADR-0003-erreichbarkeit-und-flotte.md)),
mit dem Ausfallvertrag in [`docs/ZENTRALE.md`](docs/ZENTRALE.md).
