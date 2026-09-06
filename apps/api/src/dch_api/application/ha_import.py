"""Import der Home-Assistant-Historie (Recorder-Export als CSV) in die Energiebilanz.

Zwei Exportarten:
- `statistics` / `statistics_short_term`: Spalten statistic_id, unit_of_measurement, start_ts, mean, min, max,
  state, sum – Stunden- bzw. 5-Minuten-Mittel. Das Mittel gilt als konstante Leistung im Intervall.
- `states`: Spalten entity_id, state, last_updated_ts – Rohzustände (nur die letzten Tage der Aufbewahrung);
  Sprungfunktion, Lücken bis 20 min werden fortgeschrieben.

Entitäten werden über das Mapping (config/entities.home.yaml) in Domänenschlüssel übersetzt, mit Einheit und
Vorzeichen wie in der Bridge. Ergebnis sind Stundenbilanzen (energy_hourly); eine importierte Stunde ersetzt
eine gespeicherte nur, wenn sie mehr Minuten abdeckt.
"""

from __future__ import annotations

import csv
import gzip
import io
from collections.abc import Awaitable, Callable, Iterable
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from itertools import pairwise
from pathlib import Path
from typing import Any, Literal

import structlog
import yaml
from pydantic import BaseModel, ConfigDict

from hems_core.accounting import HourlyEnergy, MinuteSample, hourly_energy
from hems_core.domain import HemsConfig, Quality
from hems_core.planning import PricePoint
from hems_core.protocol import RawReading

log = structlog.get_logger("ha_import")

UNIT_SCALE: dict[str, float] = {
    "W": 0.001,
    "kW": 1.0,
    "%": 0.01,
    "°C": 1.0,
    "EUR/kWh": 100.0,
    "€/kWh": 100.0,
    "ct/kWh": 1.0,
}
NEGATE = {"export_positive", "charge_positive"}
STATE_FILL_LIMIT = timedelta(minutes=20)
RAW_RETENTION = timedelta(days=14)
SAMPLE_KEYS = (
    "pv_power_kw",
    "grid_power_kw",
    "battery_power_kw",
    "heat_pump_power_kw",
    "ev_power_kw",
    "electricity_price_ct_kwh",
    "outdoor_temp_c",
    "battery_soc",
)
Kind = Literal["auto", "states", "statistics"]


class EntityRule(BaseModel):
    model_config = ConfigDict(frozen=True)

    key: str
    entity: str
    unit: str | None = None
    scale: float | None = None
    sign: str = "as_is"

    def convert(self, raw: float, unit_from_file: str | None) -> float:
        unit = self.unit or unit_from_file or ""
        scale = self.scale if self.scale is not None else UNIT_SCALE.get(unit, 1.0)
        v = raw * scale
        return -v if self.sign in NEGATE else v


def load_entity_rules(
    path: str | Path, extra: dict[str, dict[str, Any]] | None = None
) -> dict[str, EntityRule]:
    """Mapping entity → Regel aus dem Bridge-YAML (sensors) plus optionalen Zusatzregeln."""
    rules: dict[str, EntityRule] = {}
    p = Path(path)
    if p.exists():
        data = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
        for item in data.get("sensors") or []:
            if isinstance(item, dict) and "key" in item and "entity" in item:
                rules[str(item["entity"])] = EntityRule(
                    key=str(item["key"]),
                    entity=str(item["entity"]),
                    unit=item.get("unit"),
                    scale=item.get("scale"),
                    sign=str(item.get("sign", "as_is")),
                )
    for entity, spec in (extra or {}).items():
        rules[entity] = EntityRule(
            entity=entity, **{k: v for k, v in spec.items() if k != "entity"}
        )
    return rules


@dataclass
class ParsedDump:
    kind: str
    rows: int = 0
    entities: set[str] = field(default_factory=set)
    unmapped: set[str] = field(default_factory=set)
    # key → {minute_start: value}
    minutes: dict[str, dict[datetime, float]] = field(
        default_factory=lambda: {k: {} for k in SAMPLE_KEYS}
    )
    # Rohzustände als Messwerte (nur states)
    readings: list[RawReading] = field(default_factory=list)
    first: datetime | None = None
    last: datetime | None = None

    def span(self, ts: datetime) -> None:
        self.first = ts if self.first is None or ts < self.first else self.first
        self.last = ts if self.last is None or ts > self.last else self.last


def _open_text(payload: bytes) -> str:
    if payload[:2] == b"\x1f\x8b":
        payload = gzip.decompress(payload)
    return payload.decode("utf-8-sig", errors="replace")


def _f(v: str | None) -> float | None:
    if v is None:
        return None
    s = v.strip()
    if not s or s.lower() in ("unknown", "unavailable", "none", "null", "nan"):
        return None
    try:
        return float(s)
    except ValueError:
        return None


def _minute(ts: float) -> datetime:
    return datetime.fromtimestamp(ts, UTC).replace(second=0, microsecond=0)


def parse_dump(payload: bytes, rules: dict[str, EntityRule], kind: Kind = "auto") -> ParsedDump:
    text = _open_text(payload)
    reader = csv.DictReader(io.StringIO(text))
    header = [h.strip().lower() for h in (reader.fieldnames or [])]
    if kind == "auto":
        if "start_ts" in header and "mean" in header:
            kind = "statistics"
        elif "last_updated_ts" in header and "state" in header:
            kind = "states"
        else:
            raise ValueError(
                "Unbekanntes Format: erwartet Spalten statistic_id,unit_of_measurement,start_ts,mean,… "
                "oder entity_id,state,last_updated_ts"
            )
    out = ParsedDump(kind=kind)
    if kind == "statistics":
        _parse_statistics(reader, rules, out)
    else:
        _parse_states(reader, rules, out)
    return out


def _parse_statistics(
    reader: csv.DictReader[str], rules: dict[str, EntityRule], out: ParsedDump
) -> None:
    per_entity: dict[str, list[tuple[float, float]]] = {}
    units: dict[str, str | None] = {}
    for row in reader:
        row = {(k or "").strip().lower(): v for k, v in row.items()}
        ent = (row.get("statistic_id") or row.get("entity_id") or "").strip()
        if not ent:
            continue
        out.rows += 1
        out.entities.add(ent)
        if ent not in rules:
            out.unmapped.add(ent)
            continue
        ts = _f(row.get("start_ts"))
        mean = _f(row.get("mean"))
        if ts is None or mean is None:
            continue
        per_entity.setdefault(ent, []).append((ts, mean))
        units.setdefault(ent, (row.get("unit_of_measurement") or "").strip() or None)
    for ent, pts in per_entity.items():
        rule = rules[ent]
        if rule.key not in out.minutes:
            continue
        pts.sort()
        # Intervallbreite aus dem typischen Abstand (300 s Kurzzeit, 3600 s Langzeit)
        deltas = sorted(b - a for (a, _), (b, _) in pairwise(pts) if b > a)
        step = deltas[len(deltas) // 2] if deltas else 3600.0
        step_min = 5 if step <= 600 else 60
        target = out.minutes[rule.key]
        for ts, mean in pts:
            start = _minute(ts)
            value = round(rule.convert(mean, units.get(ent)), 4)
            for i in range(step_min):
                target[start + timedelta(minutes=i)] = value
            out.span(start)
            out.span(start + timedelta(minutes=step_min - 1))


def _parse_states(
    reader: csv.DictReader[str], rules: dict[str, EntityRule], out: ParsedDump
) -> None:
    per_entity: dict[str, list[tuple[float, float]]] = {}
    units: dict[str, str | None] = {}
    now = datetime.now(UTC)
    for row in reader:
        row = {(k or "").strip().lower(): v for k, v in row.items()}
        ent = (row.get("entity_id") or "").strip()
        if not ent:
            continue
        out.rows += 1
        out.entities.add(ent)
        if ent not in rules:
            out.unmapped.add(ent)
            continue
        ts = _f(row.get("last_updated_ts"))
        val = _f(row.get("state"))
        if ts is None or val is None:
            continue
        per_entity.setdefault(ent, []).append((ts, val))
        units.setdefault(ent, (row.get("unit_of_measurement") or "").strip() or None)
    for ent, pts in per_entity.items():
        rule = rules[ent]
        pts.sort()
        target = out.minutes.get(rule.key)
        for ts, raw in pts:
            at = datetime.fromtimestamp(ts, UTC)
            value = round(rule.convert(raw, units.get(ent)), 4)
            if now - at <= RAW_RETENTION:
                out.readings.append(
                    RawReading(
                        key=rule.key,
                        value=value,
                        observed_at=at,
                        quality=Quality.OK,
                        source=f"ha-import:{ent}",
                    )
                )
            out.span(at.replace(second=0, microsecond=0))
        if target is None:
            continue
        # Sprungfunktion: Wert gilt bis zum nächsten Zustand, höchstens STATE_FILL_LIMIT
        for (ts, raw), nxt in zip(pts, [*pts[1:], (None, None)], strict=False):
            start = _minute(ts)
            value = round(rule.convert(raw, units.get(ent)), 4)
            end_ts = nxt[0] if nxt[0] is not None else ts + 60
            stop = min(_minute(end_ts), start + STATE_FILL_LIMIT)
            m = start
            while m <= stop:
                target[m] = value
                m += timedelta(minutes=1)


def _samples(minutes: dict[str, dict[datetime, float]], hour: datetime) -> list[MinuteSample]:
    out: list[MinuteSample] = []
    for i in range(60):
        m = hour + timedelta(minutes=i)
        pv = minutes["pv_power_kw"].get(m)
        grid = minutes["grid_power_kw"].get(m)
        if pv is None or grid is None:
            continue
        out.append(
            MinuteSample(
                ts=m,
                pv_kw=pv,
                grid_kw=grid,
                battery_kw=minutes["battery_power_kw"].get(m),
                heat_pump_kw=minutes["heat_pump_power_kw"].get(m),
                ev_kw=minutes["ev_power_kw"].get(m),
                price_ct_kwh=minutes["electricity_price_ct_kwh"].get(m),
            )
        )
    return out


def apply_prices(dump: ParsedDump, prices: Iterable[PricePoint]) -> int:
    """Stundenpreise (Tibber-Historie) in Minuten übertragen, wo der Export keinen Preis hat."""
    target = dump.minutes["electricity_price_ct_kwh"]
    n = 0
    for p in prices:
        m = p.start.astimezone(UTC).replace(second=0, microsecond=0)
        while m < p.end.astimezone(UTC):
            if m not in target:
                target[m] = round(p.ct_kwh, 3)
                n += 1
            m += timedelta(minutes=1)
    return n


def compute_hours(dump: ParsedDump, hems: HemsConfig) -> list[tuple[HourlyEnergy, float | None]]:
    if dump.first is None or dump.last is None:
        return []
    hour = dump.first.replace(minute=0, second=0, microsecond=0)
    end = dump.last.replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)
    out: list[tuple[HourlyEnergy, float | None]] = []
    temps = dump.minutes["outdoor_temp_c"]
    while hour < end:
        samples = _samples(dump.minutes, hour)
        if samples:
            ts = [temps.get(hour + timedelta(minutes=i)) for i in range(60)]
            vals = [t for t in ts if t is not None]
            out.append(
                (
                    hourly_energy(hour, samples, hems.tariff),
                    round(sum(vals) / len(vals), 2) if vals else None,
                )
            )
        hour += timedelta(hours=1)
    return out


class ImportResult(BaseModel):
    kind: str
    rows: int
    entities: list[str]
    unmapped: list[str]
    first: datetime | None
    last: datetime | None
    hours_computed: int
    hours_written: int
    hours_kept_existing: int
    raw_readings_stored: int
    price_minutes_from_tibber: int
    minutes_without_price: int
    dry_run: bool
    note_de: str


class HaImporter:
    def __init__(
        self,
        hems: HemsConfig,
        rules: dict[str, EntityRule],
        read_hours: Callable[
            [datetime, datetime], Awaitable[list[tuple[HourlyEnergy, float | None]]]
        ],
        write_hours: Callable[[list[HourlyEnergy], dict[datetime, float | None]], Awaitable[None]],
        add_readings: Callable[[list[RawReading]], Awaitable[None]],
        price_history: Callable[[datetime, datetime], Awaitable[list[PricePoint]]] | None = None,
    ) -> None:
        self.hems = hems
        self.rules = rules
        self.read_hours = read_hours
        self.write_hours = write_hours
        self.add_readings = add_readings
        self.price_history = price_history

    async def run(self, payload: bytes, kind: Kind = "auto", dry_run: bool = False) -> ImportResult:
        dump = parse_dump(payload, self.rules, kind)
        tibber_minutes = 0
        if dump.first and dump.last and self.price_history is not None:
            try:
                prices = await self.price_history(dump.first, dump.last + timedelta(hours=1))
                tibber_minutes = apply_prices(dump, prices)
            except Exception as exc:
                log.warning("tibber history unavailable", error=repr(exc)[:200])
        hours = compute_hours(dump, self.hems)
        written = kept = 0
        if hours and not dry_run:
            existing = {
                h.hour_start: h
                for h, _ in await self.read_hours(
                    hours[0][0].hour_start, hours[-1][0].hour_start + timedelta(hours=1)
                )
            }
            to_write = [
                (h, t)
                for h, t in hours
                if h.minutes
                > existing.get(h.hour_start, HourlyEnergy(hour_start=h.hour_start)).minutes
            ]
            kept = len(hours) - len(to_write)
            for i in range(0, len(to_write), 500):
                chunk = to_write[i : i + 500]
                await self.write_hours([h for h, _ in chunk], {h.hour_start: t for h, t in chunk})
            written = len(to_write)
        stored = 0
        if dump.readings and not dry_run:
            for i in range(0, len(dump.readings), 2000):
                await self.add_readings(dump.readings[i : i + 2000])
            stored = len(dump.readings)
        missing_price = sum(h.price_missing_minutes for h, _ in hours)
        note = (
            "Statistik-Mittel gelten als konstante Leistung im Intervall; Quellenzuordnung deshalb näherungsweise."
            if dump.kind == "statistics"
            else "Rohzustände als Sprungfunktion (Lücken bis 20 min fortgeschrieben)."
        )
        if dump.unmapped:
            note += f" {len(dump.unmapped)} Entitäten ohne Zuordnung übersprungen."
        return ImportResult(
            kind=dump.kind,
            rows=dump.rows,
            entities=sorted(dump.entities),
            unmapped=sorted(dump.unmapped),
            first=dump.first,
            last=dump.last,
            hours_computed=len(hours),
            hours_written=written,
            hours_kept_existing=kept,
            raw_readings_stored=stored,
            price_minutes_from_tibber=tibber_minutes,
            minutes_without_price=missing_price,
            dry_run=dry_run,
            note_de=note,
        )
