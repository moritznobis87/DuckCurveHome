"""Reine Übersetzung inexogy → Domänenschlüssel (testbar ohne Netz).

Vorzeichen der Domäne: `grid > 0` ist Bezug. Der Zähler meldet seine Momentanleistung mit derselben
Bedeutung, Einspeisung also negativ; eine Umkehr ist nicht nötig.

**Die Einheiten sind der heikle Teil.** Die Beschreibung der API nennt sie nicht. Alle Clients des
Ökosystems - die Home-Assistant-Integration, evcc, pydiscovergy - rechnen `power` in Milliwatt und
die Zählerstände in Zehnmilliardstel Kilowattstunden. Das ist gut belegt, aber es bleibt ein Schluss
aus fremdem Quelltext und nicht aus einer Zusage des Herstellers.

Deshalb steht hier nicht nur der Faktor, sondern auch eine Plausibilitätsgrenze. Ein Hausanschluss
führt keine 100 kW. Stimmt der Faktor nicht, liegt das Ergebnis um Zehnerpotenzen daneben und fällt
durch diese Grenze: die Reihe bleibt dann leer und im Protokoll steht, was ankam. Das ist die
richtige Reaktion - eine Messreihe, die aussieht wie eine Messreihe und um den Faktor tausend falsch
ist, wäre der teuerste Fehler, den diese Anbindung machen kann.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

import structlog

from hems_core.domain import Quality
from hems_core.protocol import RawReading

log = structlog.get_logger("inexogy")

# Momentanleistung in Milliwatt, Zählerstände in 1e-10 kWh.
MW_TO_KW = 1e-6
COUNTER_TO_KWH = 1e-10
# Hausanschluss in Geilenkirchen: 3 x 63 A sind gut 43 kW. 100 kW ist reichlich Luft nach oben und
# trotzdem drei Zehnerpotenzen von dem entfernt, was ein falscher Faktor erzeugen würde.
MAX_PLAUSIBLE_KW = 100.0
# Ein Zählerstand über 100 GWh wäre selbst nach hundert Jahren nicht erreicht.
MAX_PLAUSIBLE_KWH = 1e8

POWER_KEY = "grid_power_meter_kw"
IMPORT_KEY = "grid_import_meter_kwh"
EXPORT_KEY = "grid_export_meter_kwh"


def _num(v: Any) -> float | None:
    return float(v) if isinstance(v, int | float) and not isinstance(v, bool) else None


def reading_time(measurement: dict[str, Any], fallback: datetime) -> datetime:
    ms = _num(measurement.get("time"))
    if ms is None:
        return fallback
    return datetime.fromtimestamp(ms / 1000.0, tz=UTC)


def _scaled(
    values: dict[str, Any], field: str, factor: float, limit: float, *, signed: bool
) -> float | None:
    raw = _num(values.get(field))
    if raw is None:
        return None
    out = raw * factor
    if abs(out) > limit or (not signed and out < 0):
        log.warning("inexogy value implausible", field=field, raw=raw, scaled=out)
        return None
    return round(out, 4)


def readings_from_measurement(
    measurement: dict[str, Any], now: datetime, source: str
) -> list[RawReading]:
    """Ein Messwert des Zählers als Messreihen der Domäne.

    Der Netzwert läuft bewusst **nicht** auf `grid_power_kw`. Führend bleibt der Stromwandler des
    Speichers; der Zähler läuft als zweite, unabhängige Beobachtung mit. Erst wenn feststeht, wie
    stabil er überträgt und wie weit die beiden auseinanderliegen, ist die Frage zu stellen, wer
    die Bilanz tragen soll - und bis dahin darf diese Anbindung an keiner Zahl etwas ändern, die
    heute schon jemand liest.
    """
    values = measurement.get("values")
    if not isinstance(values, dict):
        return []
    at = reading_time(measurement, now)
    out: list[RawReading] = []
    pairs = (
        (POWER_KEY, "power", MW_TO_KW, MAX_PLAUSIBLE_KW, True),
        (IMPORT_KEY, "energy", COUNTER_TO_KWH, MAX_PLAUSIBLE_KWH, False),
        (EXPORT_KEY, "energyOut", COUNTER_TO_KWH, MAX_PLAUSIBLE_KWH, False),
    )
    for key, field, factor, limit, signed in pairs:
        value = _scaled(values, field, factor, limit, signed=signed)
        if value is not None:
            out.append(
                RawReading(
                    key=key,
                    value=value,
                    observed_at=at,
                    quality=Quality.OK,
                    source=source,
                )
            )
    return out


def readings_from_history(
    measurements: list[dict[str, Any]], now: datetime, source: str
) -> list[RawReading]:
    out: list[RawReading] = []
    for m in measurements:
        out.extend(readings_from_measurement(m, now, source))
    return out


def pick_meter(meters: list[dict[str, Any]], wanted: str = "") -> dict[str, Any] | None:
    """Den Zähler auswählen, dessen Werte gelesen werden sollen.

    Mit `wanted` wird ausdrücklich einer benannt - `meterId`, Seriennummer oder die aufgedruckte
    lange Seriennummer, weil an der Wand nur letztere steht. Ohne Angabe gewinnt der Zähler, der
    zuletzt gemeldet hat: in einem Konto mit einem einzigen Zähler ist das der richtige, und in
    einem mit mehreren ist „der, der lebt" die einzige Wahl, die ohne Nachfrage auskommt.
    """
    if wanted:
        w = wanted.strip().lower()
        for m in meters:
            candidates = {
                str(m.get(k, "")).lower()
                for k in ("meterId", "serialNumber", "fullSerialNumber", "printedFullSerialNumber")
            }
            if w in candidates - {""}:
                return m
        return None
    alive = [m for m in meters if _num(m.get("lastMeasurementTime")) not in (None, -1)]
    if not alive:
        return meters[0] if meters else None
    return max(alive, key=lambda m: _num(m.get("lastMeasurementTime")) or 0.0)
