from __future__ import annotations

from datetime import UTC, datetime

from hems_core.domain import (
    BufferTemperatures,
    EnergySnapshot,
    Measurement,
    Quality,
)

T0 = datetime(2026, 9, 4, 11, 0, tzinfo=UTC)


def m(value: float | None, at: datetime = T0, quality: Quality = Quality.OK) -> Measurement:
    if value is None:
        return Measurement.missing(quality, at, "test")
    return Measurement(value=value, observed_at=at, quality=quality, source="test")


def make_snapshot(
    *,
    at: datetime = T0,
    pv: float = 6.0,
    grid: float = -3.0,
    battery: float = 0.0,
    soc: float = 1.0,
    hp: float = 0.0,
    ev: float = 0.0,
    price: float | None = 25.0,
    temps: tuple[float, float, float, float] = (50.0, 48.0, 42.0, 36.0),
    grid_quality: Quality = Quality.OK,
    hp_quality: Quality = Quality.OK,
    release: bool = False,
) -> EnergySnapshot:
    house = pv + grid + battery
    return EnergySnapshot(
        timestamp=at,
        pv_power_kw=m(pv, at),
        grid_power_kw=m(grid if grid_quality.usable else None, at, grid_quality),
        battery_power_kw=m(battery, at),
        battery_soc=m(soc, at),
        house_power_kw=Measurement.derived(house, at),
        base_load_kw=Measurement.derived(max(0.0, house - hp - ev), at),
        heat_pump_power_kw=m(hp if hp_quality.usable else None, at, hp_quality),
        ev_power_kw=m(ev, at),
        electricity_price_ct_kwh=m(price, at)
        if price is not None
        else m(None, at, Quality.UNAVAILABLE),
        outdoor_temp_c=m(14.0, at),
        buffer_temps_c=BufferTemperatures(
            top=m(temps[0], at),
            mid_top=m(temps[1], at),
            mid_bottom=m(temps[2], at),
            bottom=m(temps[3], at),
        ),
        hp_release_contact=m(1.0 if release else 0.0, at),
        hp_block_contact=m(0.0, at),
    )
