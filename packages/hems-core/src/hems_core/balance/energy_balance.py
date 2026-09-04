"""Bilanzierung der Leistungsflüsse mit unterschiedlichen Messquellen.

Regel: pv + grid + battery = house = base + heat_pump + ev.
Wenn house nicht gemessen ist, wird es aus der linken Seite abgeleitet. Verletzt die Bilanz die
Toleranz, wird das Residuum gemeldet und die Ableitung als INCONSISTENT markiert, nie
stillschweigend korrigiert.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from hems_core.domain.config import BalanceConfig, PvRuleConfig
from hems_core.domain.measurement import Measurement
from hems_core.domain.quality import Quality


@dataclass(frozen=True)
class BalanceResult:
    house_power_kw: Measurement
    base_load_kw: Measurement
    residual_kw: float
    consistent: bool


def balance(
    *,
    now: datetime,
    pv: Measurement,
    grid: Measurement,
    battery: Measurement,
    heat_pump: Measurement,
    ev: Measurement,
    house_measured: Measurement | None,
    cfg: BalanceConfig,
) -> BalanceResult:
    supply_known = pv.usable and grid.usable and battery.usable
    supply = pv.value_or(0.0) + grid.value_or(0.0) + battery.value_or(0.0)

    if house_measured is not None and house_measured.usable:
        house = house_measured
        residual = supply - house.value_or(0.0) if supply_known else 0.0
    elif supply_known:
        house = Measurement.derived(round(supply, 3), now, "balance:pv+grid+battery")
        residual = 0.0
    else:
        house = Measurement.missing(Quality.UNAVAILABLE, now, "balance")
        residual = 0.0

    consistent = abs(residual) <= cfg.tolerance_kw
    if not consistent:
        house = house.model_copy(update={"quality": Quality.INCONSISTENT})

    loads = heat_pump.value_or(0.0) + ev.value_or(0.0)
    if house.value is not None and heat_pump.usable and ev.usable:
        base_raw = house.value - loads
        base_q = Quality.DERIVED if base_raw >= -cfg.tolerance_kw else Quality.INCONSISTENT
        base = Measurement(
            value=round(max(0.0, base_raw), 3),
            observed_at=now,
            quality=base_q,
            source="balance:house-hp-ev",
        )
    else:
        base = Measurement.missing(Quality.UNAVAILABLE, now, "balance")

    return BalanceResult(
        house_power_kw=house,
        base_load_kw=base,
        residual_kw=round(residual, 3),
        consistent=consistent,
    )


def pv_surplus_kw(
    *,
    grid: Measurement,
    battery: Measurement,
    battery_soc: Measurement,
    ev: Measurement,
    heat_pump: Measurement,
    cfg: PvRuleConfig,
) -> float | None:
    """Für die Wärmepumpe verfügbarer Überschuss (kW).

    Export zählt immer. Batterieladung zählt, wenn der SOC über der Schwelle liegt (Libbi ist
    dann fast voll und würde ohnehin bald abregeln). Wallbox-Leistung zählt nur, wenn die
    Wärmepumpe Vorrang vor dem Auto haben soll. Läuft die Wärmepumpe, wird ihre Leistung
    hinzugerechnet, damit sie sich nicht selbst den Überschuss wegnimmt (Haltebedingung).
    """
    if not grid.usable:
        return None
    surplus = max(0.0, -grid.value_or(0.0))
    if battery.usable and battery_soc.usable:
        charging = max(0.0, -battery.value_or(0.0))
        if battery_soc.value_or(0.0) >= cfg.count_battery_charging_above_soc:
            surplus += charging
    if cfg.heat_pump_before_ev and ev.usable:
        surplus += max(0.0, ev.value_or(0.0))
    if heat_pump.usable:
        surplus += max(0.0, heat_pump.value_or(0.0))
    return round(surplus, 3)
