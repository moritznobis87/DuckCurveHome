# ADR-0001 – Geräteschicht und Hosting (offen, Entscheidung vor Phase 2)

**Status:** angenommen und bestätigt (2026-09-04: Railway als Hosting, kein Nabu Casa, Home Assistant OS) · **Datum:** 2026-09-04

## Kontext

Alle Sensoren und Aktoren stehen im Haus; Home Assistant (HA) läuft dort bereits mit allen Integrationen. Der
Betreiber möchte ein eigenständiges System mit eigener Datenbank, scheut aber den Betrieb eigener Infrastruktur.
Der bisher gebaute Code (Domäne, Regler, API, Dashboard) ist von beiden Fragen unabhängig: Geräte sind
`DeviceSource`/`Actuator`-Adapter, Persistenz ist Repository-Schicht.

## Optionen

| | A – lokal, direkte Adapter | B – Railway + eigene Bridge | **C – Railway + HA als Geräteschicht** |
|---|---|---|---|
| Geräte | Shelly MQTT/RPC, MyEnergi-Cloud, SolarEdge Modbus selbst implementiert | wie A, in der Bridge | HA WebSocket-API liefert alle Entitäten; Schalten über HA-Dienste |
| Datenbank | Postgres im Compose auf dem Pi | Railway-Postgres | Railway-Postgres |
| Komponenten im Haus | alles | Bridge + Mosquitto + Guardian | **nichts** (Nabu Casa) oder Mini-Bridge auf dem HA-Host |
| Eigener Code für Geräte | hoch (3 Protokolle) | hoch | **gering** (ein HA-Adapter) |
| Abhängigkeit | keine | keine | HA muss laufen (tut es ohnehin); Nabu Casa optional |
| Regelung bei Internetausfall | läuft | pausiert, Rückfall sicher | pausiert, Rückfall sicher |
| Betriebsaufwand | Hardware, Backups, Updates selbst | Railway managed, Bridge-Host | **am geringsten** |
| Datenrate | Shelly 1 s, MyEnergi 10 s | wie A | wie HA pollt (Shelly lokal ≈ 1 s, MyEnergi/SolarEdge je Integration) |

## Empfehlung

**Option C**, mit direkten Adaptern als späterer Ergänzung, falls HA-Daten zu grob sind. Safety bleibt
unverändert: Shelly-Auto-Off als Geräteeinstellung (E0), HA-Automation als Wächter (E1), TTL im Regler (E2/E3).
Für Schaltbefehle setzt der HA-Adapter `switch.turn_on`; da HA den Shelly-Timer nicht mitgeben kann, muss der
Auto-Off **im Shelly** konfiguriert sein (Phase 3 prüft das).

## Entscheidung

**Option C mit Bridge als Home-Assistant-Add-on.** Antworten des Betreibers: kein Nabu Casa, Home Assistant OS.
Ein Add-on ist ein vom Supervisor verwalteter Container: Es erhält den Zugang zur HA-API über den Supervisor-Proxy
(`ws://supervisor/core/websocket`, `SUPERVISOR_TOKEN`), braucht keinen eigenen Docker-Host und darf ausgehende
Verbindungen öffnen. Die Bridge liest Entitäten per WebSocket (`subscribe_entities`), schaltet über HA-Dienste und
spricht ausgehend per WSS mit der API auf Railway (Protokoll: Plan Abschnitt 17.2). Wird später Nabu Casa
abonniert, kann der Worker direkt auf die HA-WebSocket-API zugreifen; der Adapter ist identisch.

## Konsequenzen

- Phase 2 baut: PostgreSQL mit Alembic auf Railway, `integrations/home_assistant` (Adapter, Entity-Mapping),
  `apps/bridge` als HA-Add-on (Repository-Struktur für lokale Add-ons), Bridge-Ingest in der API mit
  Device-Token, Tibber- und Wetter-Provider, PV-Forecast v1, Railway-Konfiguration.
- Die Rückfallebenen bleiben: Shelly-Auto-Off als Geräteeinstellung (E0), HA-Automation als Wächter (E1) – sie
  läuft auf demselben Host wie das Add-on und überwacht dessen Heartbeat-Entität –, TTL im Regler (E2/E3).
- Docker Compose bleibt für Entwicklung und Demo; Profil A (alles lokal) bleibt technisch möglich.
