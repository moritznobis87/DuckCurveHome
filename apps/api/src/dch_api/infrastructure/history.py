"""In-Memory-Historie in 1-Minuten-Bins (Phase 1). Phase 2 ersetzt dies durch PostgreSQL."""

from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass, field
from datetime import datetime, timedelta

from hems_core.domain import EnergySnapshot

SERIES = (
    "pv_power_kw",
    "grid_power_kw",
    "battery_power_kw",
    "battery_soc",
    "house_power_kw",
    "base_load_kw",
    "heat_pump_power_kw",
    "ev_power_kw",
    "electricity_price_ct_kwh",
    "outdoor_temp_c",
    "buffer_temp_top_c",
    "buffer_temp_mid_top_c",
    "buffer_temp_mid_bottom_c",
    "buffer_temp_bottom_c",
    "hp_release_contact",
)


@dataclass
class Bin:
    sums: dict[str, float] = field(default_factory=dict)
    counts: dict[str, int] = field(default_factory=dict)

    def add(self, key: str, value: float | None) -> None:
        if value is None:
            return
        self.sums[key] = self.sums.get(key, 0.0) + value
        self.counts[key] = self.counts.get(key, 0) + 1

    def mean(self, key: str) -> float | None:
        n = self.counts.get(key, 0)
        return round(self.sums[key] / n, 3) if n else None


class HistoryStore:
    def __init__(self, retention: timedelta) -> None:
        self.retention = retention
        self._bins: OrderedDict[datetime, Bin] = OrderedDict()

    @staticmethod
    def _values(s: EnergySnapshot) -> dict[str, float | None]:
        t = s.buffer_temps_c
        return {
            "pv_power_kw": s.pv_power_kw.value,
            "grid_power_kw": s.grid_power_kw.value,
            "battery_power_kw": s.battery_power_kw.value,
            "battery_soc": s.battery_soc.value,
            "house_power_kw": s.house_power_kw.value,
            "base_load_kw": s.base_load_kw.value,
            "heat_pump_power_kw": s.heat_pump_power_kw.value,
            "ev_power_kw": s.ev_power_kw.value,
            "electricity_price_ct_kwh": s.electricity_price_ct_kwh.value,
            "outdoor_temp_c": s.outdoor_temp_c.value,
            "buffer_temp_top_c": t.top.value,
            "buffer_temp_mid_top_c": t.mid_top.value,
            "buffer_temp_mid_bottom_c": t.mid_bottom.value,
            "buffer_temp_bottom_c": t.bottom.value,
            "hp_release_contact": s.hp_release_contact.value,
        }

    def add(self, s: EnergySnapshot) -> None:
        minute = s.timestamp.replace(second=0, microsecond=0)
        b = self._bins.get(minute)
        if b is None:
            b = Bin()
            self._bins[minute] = b
            self._prune(minute)
        for k, v in self._values(s).items():
            b.add(k, v)

    def _prune(self, now_minute: datetime) -> None:
        cutoff = now_minute - self.retention
        while self._bins and next(iter(self._bins)) < cutoff:
            self._bins.popitem(last=False)

    def series(self, start: datetime, end: datetime) -> list[dict[str, float | str | None]]:
        rows: list[dict[str, float | str | None]] = []
        for minute, b in self._bins.items():
            if start <= minute < end:
                row: dict[str, float | str | None] = {"ts": minute.isoformat()}
                for k in SERIES:
                    row[k] = b.mean(k)
                rows.append(row)
        return rows

    def energy_kwh(
        self, key: str, start: datetime, end: datetime, positive_only: bool = True
    ) -> float:
        total = 0.0
        for minute, b in self._bins.items():
            if start <= minute < end:
                v = b.mean(key)
                if v is None:
                    continue
                if positive_only:
                    v = max(0.0, v)
                total += v / 60.0
        return round(total, 3)
