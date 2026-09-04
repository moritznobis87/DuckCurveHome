# Wärmepumpen-Regelung (Stand Phase 1)

Der Regler in `hems_core.control.heat_pump_controller` ist reines Python, wird im Demo-Modus gegen die
Simulation betrieben und ab Phase 4 gegen die echten Shelly-Kontakte. Er steuert **nur** zwei Kontakte:

| Kontakt | Bedeutung | Regler-Ausgang |
|---|---|---|
| K1 „PV-Überschuss“ | Anforderung an die Wärmepumpe, mehr Wärme zu erzeugen | `k1_release` |
| K2 „Netzbetreiber-Shutdown“ | Sperre | `k2_block` – in Phase 1–4 immer `false` |

Ob die Wärmepumpe läuft, wird aus der elektrischen Leistung (Shelly 3EM) abgeleitet (`HeatPumpTracker`,
Schwelle 0,5 kW, Entprellung 60 s). Mindestlaufzeit und Mindestauszeit beziehen sich auf diesen Ist-Zustand.

## Zustandsmaschine

```
OFF ── Modus OFF: nur beobachten
MANUAL ── Übersteuerung aktiv (zeitlich begrenzt): K1 folgt dem Menschen, außer Puffer voll
FAILSAFE ── Sicherheitsmodus: K1/K2 aus, Pause failsafe_hold_min

IDLE ──(Trigger ∧ keine Blocker)──► ARMING ──(on_delay gehalten)──► RELEASED ──(läuft)──► RUNNING_RELEASED
  ▲                                    │(Bedingung weg)               │(start_timeout)        │
  │                                    ▼                              ▼                       ▼
  └──────────────────────────────── IDLE ◄──── COOLDOWN ◄──── (Haltebedingung off_delay verletzt ∧ min_runtime erreicht)
                                                                       oder Puffer voll oder Sensorausfall > Karenz
```

**Trigger:** `PV_SURPLUS` (geglätteter Überschuss ≥ `on_surplus_kw`), `PRICE_NEGATIVE`, `PRICE_CHEAP_WINDOW`
(Rang ≤ `cheap_quantile`, Profile PRICE/SMART), `PLANNED_WINDOW` (Profil SMART, ab Phase 5).

**Blocker vor einem Start:** Sensor `stale`/`unavailable`, Puffer voll (`T_top ≥ max` oder `soc ≥ soc_full`),
zu wenig Ladehub, Mindestauszeit, maximale Starts pro Tag, Wärmepumpe reagierte zuletzt nicht.

**Haltebedingung im Lauf:** geglätteter Netzbezug ≤ `off_import_kw` **oder** Preisgrund aktiv. Verletzt sie
länger als `off_delay_min` und ist die Mindestlaufzeit erreicht, endet die Freigabe. Vorher hält
`MIN_RUNTIME_HOLD`. Immer sofort beenden: Puffer voll, Sensorausfall länger als `sensor_grace_min`.

**Überschussbegriff:** Einspeisung + Batterieladung (nur wenn SOC ≥ 80 %) + optional Wallbox + Leistung der
laufenden Wärmepumpe (damit sie sich nicht selbst den Überschuss wegnimmt).

## Guards (immer)

1. Nie K1 und K2 gleichzeitig.
2. Mehr als `max_toggles_per_hour` K1-Wechsel → FAILSAFE.
3. Jede Entscheidung hat `valid_until`; jeder Schaltbefehl trägt den Shelly-Auto-Off-Timer
   (`hw_auto_off_release_s`), der Regler frischt spätestens alle 10 min auf.
4. Manuelle Freigabe überhitzt den Puffer nicht (Puffer voll blockt auch MANUAL).
5. Fehlende Preise pausieren nur Preisregeln; PV-Regel und Heizbetrieb sind nie betroffen.

## Erklärbarkeit

`Decision` enthält `reasons` (Hauptgrund zuerst), `blocked_by`, `inputs` (Überschuss-, Bezugs-EWMA, SOC,
Preis, Rang, Zeiten), `next_expected` (Start/Ende/Fenster mit Uhrzeit) und `explanation_de`. Die Codes sind eine
geschlossene Enum (`ReasonCode`), jeder Code hat einen Test und einen deutschen Satz (`control/explain.py`).

## Tests (`packages/hems-core/tests/test_heat_pump_controller.py`)

Hysterese, Einschaltverzögerung bei kurzen Spitzen, Mindestlaufzeit trotz Bezug, Ende nach Ausschaltverzögerung,
Mindestauszeit, negative Preise, günstiges Preisfenster, PV-Profil ignoriert Preise, Puffer voll (Start und Lauf),
geringer Ladehub, manuelle Freigabe/Sperre inkl. Ablauf, Modus OFF, Sensor nicht verfügbar / veraltet mit Karenz,
Tibber-Ausfall, Wärmepumpe reagiert nicht, nie beide Kontakte, Schaltrate → FAILSAFE, Erklärungstext für jeden Code.

## Ausblick

Phase 4 verbindet den Regler mit echten Kontakten (TTL, Ack, Guardian). Phase 5 liefert `planned_release` aus dem
Forecast-Aware-Planner; Phase 6 den Optimierer. K2 wird erst nach dokumentiertem Freigabetest aktiviert.
