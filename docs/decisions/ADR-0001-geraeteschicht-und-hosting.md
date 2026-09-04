# ADR-0001 – Geräteschicht und Hosting (offen, Entscheidung vor Phase 2)

**Status:** vorgeschlagen · **Datum:** 2026-09-04

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

## Offene Fragen an den Betreiber

1. Nabu Casa vorhanden? (dann Variante C ohne Komponente im Haus)
2. HA OS oder HA in Docker? (bestimmt, wie eine Mini-Bridge liefe)
3. Entity-IDs aller Sensoren/Relais (Discovery-Skript in Phase 2)

## Konsequenzen

- Phase 2 implementiert `integrations/home_assistant` (WebSocket `subscribe_entities`, REST-Historie) im Worker
  und den Postgres-Unterbau; Compose bleibt für lokale Entwicklung und als Profil A erhalten.
- Die Bridge-Pakete aus Abschnitt 6 des Plans werden nur gebaut, wenn Nabu Casa fehlt.
