"""Reine Übersetzung myenergi → Domänenschlüssel (testbar ohne Netz).

Vorzeichen der Domäne: grid > 0 Bezug, battery > 0 Entladen, alle Leistungen in kW.
myenergi liefert Watt; der interne Last-CT der Libbi ist beim Laden positiv, daher wird er negiert.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from hems_core.domain import Quality
from hems_core.protocol import RawReading

DEVICE_KINDS = ("zappi", "eddi", "harvi", "libbi")
PREFIX = {"zappi": "Z", "eddi": "E", "libbi": "L", "harvi": "H"}
W_TO_KW = 0.001


def _num(v: Any) -> float | None:
    return float(v) if isinstance(v, int | float) and not isinstance(v, bool) else None


def observed_at(device: dict[str, Any], fallback: datetime) -> datetime:
    """`dat` (TT-MM-JJJJ) und `tim` (HH:MM:SS) sind UTC; ohne beides gilt der Abrufzeitpunkt."""
    dat, tim = device.get("dat"), device.get("tim")
    if isinstance(dat, str) and isinstance(tim, str):
        try:
            return datetime.strptime(f"{dat} {tim}", "%d-%m-%Y %H:%M:%S").replace(tzinfo=UTC)
        except ValueError:
            pass
    return fallback


def _cts(device: dict[str, Any], count: int) -> list[tuple[str, float]]:
    out: list[tuple[str, float]] = []
    for i in range(1, count + 1):
        name = str(device.get(f"ectt{i}", "None"))
        power = _num(device.get(f"ectp{i}"))
        if name.lower() != "none" and power is not None:
            out.append((name.lower(), power))
    return out


def readings_from_status(groups: list[dict[str, Any]], now: datetime) -> list[RawReading]:
    """Aktuelle Leistungen aus `/cgi-jstatus-*`.

    - pv_power_kw: Summe aller „Generation“-CTs (bei Bedarf `gen` eines Geräts)
    - grid_power_kw: Summe aller „Grid“-CTs (bei Bedarf `grd`), Bezug positiv
    - battery_power_kw / battery_soc: Libbi (interner Last-CT negiert, soc in %)
    - ev_power_kw: Zappi, Summe der internen Last-CTs aller Phasen (bei Bedarf `div`)
    """
    devices: list[tuple[str, dict[str, Any]]] = []
    for grp in groups:
        for kind in DEVICE_KINDS:
            items = grp.get(kind)
            if isinstance(items, list):
                devices.extend((kind, d) for d in items if isinstance(d, dict))

    gen_w = 0.0
    gen_seen = False
    grid_w = 0.0
    grid_seen = False
    gen_fallback: float | None = None
    grid_fallback: float | None = None
    gen_at = grid_at = now
    out: list[RawReading] = []

    for kind, d in devices:
        at = observed_at(d, now)
        sno = d.get("sno", "?")
        src = f"myenergi:{kind}:{sno}"
        cts = _cts(d, 6 if kind in ("zappi", "libbi") else 3)
        for name, power in cts:
            if "generation" in name:
                gen_w += power
                gen_seen = True
                gen_at = at
            elif "grid" in name:
                grid_w += power
                grid_seen = True
                grid_at = at
        if kind in ("zappi", "eddi", "libbi"):
            if gen_fallback is None and _num(d.get("gen")) is not None:
                gen_fallback = _num(d.get("gen"))
            if grid_fallback is None and _num(d.get("grd")) is not None:
                grid_fallback = _num(d.get("grd"))
        if kind == "libbi":
            loads = [p for n, p in cts if "internal load" in n] or [
                p for n, p in cts if "battery" in n
            ]
            load = sum(loads) if loads else None
            if load is not None:
                out.append(
                    RawReading(
                        key="battery_power_kw",
                        value=round(-load * W_TO_KW, 3),
                        observed_at=at,
                        quality=Quality.OK,
                        source=src,
                    )
                )
            soc = _num(d.get("soc"))
            if soc is not None:
                out.append(
                    RawReading(
                        key="battery_soc",
                        value=round(max(0.0, min(1.0, soc / 100.0)), 3),
                        observed_at=at,
                        quality=Quality.OK,
                        source=src,
                    )
                )
        if kind == "zappi":
            # dreiphasige Zappi: ein „Internal Load“-CT je Phase → Ladeleistung ist die Summe
            loads = [p for n, p in cts if "internal load" in n]
            load = sum(loads) if loads else _num(d.get("div"))
            if load is not None:
                out.append(
                    RawReading(
                        key="ev_power_kw",
                        value=round(max(0.0, load) * W_TO_KW, 3),
                        observed_at=at,
                        quality=Quality.OK,
                        source=src,
                    )
                )

    if gen_seen or gen_fallback is not None:
        pv = gen_w if gen_seen else float(gen_fallback or 0.0)
        out.append(
            RawReading(
                key="pv_power_kw",
                value=round(max(0.0, pv) * W_TO_KW, 3),
                observed_at=gen_at,
                quality=Quality.OK,
                source="myenergi:generation",
            )
        )
    if grid_seen or grid_fallback is not None:
        grid = grid_w if grid_seen else float(grid_fallback or 0.0)
        out.append(
            RawReading(
                key="grid_power_kw",
                value=round(grid * W_TO_KW, 3),
                observed_at=grid_at,
                quality=Quality.OK,
                source="myenergi:grid",
            )
        )
    return out


def devices_for_history(groups: list[dict[str, Any]]) -> list[tuple[str, str, int]]:
    """(kind, prefix, serial) aller Geräte mit Historie (Harvi hat keine)."""
    out: list[tuple[str, str, int]] = []
    for grp in groups:
        for kind in ("libbi", "zappi", "eddi"):
            for d in grp.get(kind) or []:
                sno = d.get("sno") if isinstance(d, dict) else None
                if isinstance(sno, int):
                    out.append((kind, PREFIX[kind], sno))
    return out


@dataclass
class HistoryMinute:
    """Mittlere Leistungen einer Minute aus der myenergi-Historie (kW, Domänenvorzeichen)."""

    ts: datetime
    pv_kw: float | None = None
    grid_kw: float | None = None
    battery_kw: float | None = None
    ev_kw: float | None = None


def _minute_ts(row: dict[str, Any]) -> datetime | None:
    try:
        return datetime(
            int(row["yr"]),
            int(row["mon"]),
            int(row["dom"]),
            int(row.get("hr", 0)),
            int(row.get("min", 0)),
            tzinfo=UTC,
        )
    except (KeyError, TypeError, ValueError):
        return None


def _j_to_kw(joule: Any) -> float:
    v = _num(joule) or 0.0
    return v / 60.0 * W_TO_KW  # Joule je Minute → mittlere Watt → kW


def history_minutes(rows_by_device: dict[str, list[dict[str, Any]]]) -> list[HistoryMinute]:
    """Minutenzeilen mehrerer Geräte zu einer Reihe je Minute zusammenführen.

    Netz (`imp`/`exp`) und Erzeugung (`gep`) meldet jedes Gerät für den Standort – es zählt der größte Wert
    statt der Summe. Wallbox: `h1d`+`h1b` der Zappi(s). Batterie: `bdp1`−`bcp1` der Libbi (Entladen positiv).
    Fehlende Felder einer vorhandenen Minutenzeile bedeuten 0 (myenergi überträgt Nullen nicht).
    """
    by_ts: dict[datetime, HistoryMinute] = {}
    for kind, rows in rows_by_device.items():
        for row in rows:
            ts = _minute_ts(row)
            if ts is None:
                continue
            hm = by_ts.setdefault(ts, HistoryMinute(ts=ts))
            # myenergi lässt Felder mit 0 weg: eine vorhandene Zeile ohne gep/imp/exp bedeutet 0 kW
            pv = _j_to_kw(row.get("gep"))
            hm.pv_kw = pv if hm.pv_kw is None else max(hm.pv_kw, pv)
            grid = _j_to_kw(row.get("imp")) - _j_to_kw(row.get("exp"))
            hm.grid_kw = grid if hm.grid_kw is None or abs(grid) > abs(hm.grid_kw) else hm.grid_kw
            if kind == "zappi":
                ev = _j_to_kw(row.get("h1d")) + _j_to_kw(row.get("h1b"))
                hm.ev_kw = (hm.ev_kw or 0.0) + ev
            if kind == "libbi":
                hm.battery_kw = _j_to_kw(row.get("bdp1")) - _j_to_kw(row.get("bcp1"))
    out = sorted(by_ts.values(), key=lambda h: h.ts)
    for h in out:
        for f in ("pv_kw", "grid_kw", "battery_kw", "ev_kw"):
            v = getattr(h, f)
            if v is not None:
                setattr(h, f, round(v, 4))
    return out


HISTORY_KEYS = {
    "pv_kw": "pv_power_kw",
    "grid_kw": "grid_power_kw",
    "battery_kw": "battery_power_kw",
    "ev_kw": "ev_power_kw",
}


def readings_from_history(
    minutes: list[HistoryMinute], missing: set[tuple[datetime, str]] | None
) -> list[RawReading]:
    """Minutenwerte als Messwerte (Zeitstempel Minute + 30 s). `missing` begrenzt auf fehlende (Minute, Schlüssel)."""
    out: list[RawReading] = []
    for h in minutes:
        for field, key in HISTORY_KEYS.items():
            v = getattr(h, field)
            if v is None:
                continue
            if missing is not None and (h.ts, key) not in missing:
                continue
            out.append(
                RawReading(
                    key=key,
                    value=v,
                    observed_at=h.ts.replace(second=30),
                    quality=Quality.OK,
                    source="myenergi:history",
                )
            )
    return out
