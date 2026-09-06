"""Neuberechnung darf Verbraucher nicht verlieren, die nur eine andere Quelle kennt."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from dch_api.application.energy_accounting import EnergyAccounting, merge_hour
from hems_core.accounting import HourlyEnergy
from hems_core.domain import HemsConfig
from hems_core.simulation import BERLIN

HOUR = datetime(2026, 4, 15, 12, 0, tzinfo=UTC)


def test_merge_keeps_consumer_the_new_calculation_cannot_see() -> None:
    old = HourlyEnergy(
        hour_start=HOUR,
        minutes=60,
        house_kwh=3.0,
        heat_pump_kwh=2.0,
        heat_pump_grid_kwh=2.0,
        heat_pump_cost_eur=0.6,
        base_kwh=1.0,
    )
    new = HourlyEnergy(hour_start=HOUR, minutes=60, house_kwh=5.0, base_kwh=5.0)
    merged = merge_hour(new, old)
    assert merged.heat_pump_kwh == pytest.approx(2.0)  # aus der gespeicherten Stunde übernommen
    assert merged.heat_pump_cost_eur == pytest.approx(0.6)
    assert merged.house_kwh == pytest.approx(5.0)  # bessere Bilanz der neuen Messung bleibt
    assert merged.base_kwh == pytest.approx(3.0)  # Rest um die Wärmepumpe verkleinert


def test_merge_does_not_override_a_measured_consumer() -> None:
    old = HourlyEnergy(hour_start=HOUR, minutes=60, heat_pump_kwh=2.0, house_kwh=3.0)
    new = HourlyEnergy(hour_start=HOUR, minutes=60, heat_pump_kwh=1.5, house_kwh=4.0, base_kwh=2.5)
    assert merge_hour(new, old).heat_pump_kwh == pytest.approx(1.5)
    assert merge_hour(new, None) is new


@pytest.mark.asyncio
async def test_recompute_carries_heat_pump_forward() -> None:
    """myenergi-Backfill (nur PV, Netz, Batterie, Wallbox) darf die Wärmepumpe der Stunde nicht löschen."""
    written: list[HourlyEnergy] = []
    stored = HourlyEnergy(
        hour_start=HOUR,
        minutes=60,
        house_kwh=3.0,
        heat_pump_kwh=2.0,
        heat_pump_grid_kwh=2.0,
        base_kwh=1.0,
    )

    async def minute_rows(s: datetime, e: datetime) -> list[dict[str, float | str | None]]:
        return [
            {
                "ts": (HOUR + timedelta(minutes=i)).isoformat().replace("+00:00", "Z"),
                "pv_power_kw": 4.0,
                "grid_power_kw": 1.0,
            }
            for i in range(60)
        ]

    async def read(s: datetime, e: datetime) -> list[tuple[HourlyEnergy, float | None]]:
        return [(stored, 12.5)]

    async def write(hours: list[HourlyEnergy], temps: dict[datetime, float | None]) -> None:
        written.extend(hours)

    async def last() -> datetime | None:
        return None

    acc = EnergyAccounting(HemsConfig(), BERLIN, minute_rows, store=(read, write, last))
    n = await acc.recompute(HOUR, HOUR + timedelta(hours=1))
    assert n == 1 and len(written) == 1
    h = written[0]
    assert h.house_kwh == pytest.approx(5.0)  # PV 4 + Netz 1, aus den Minutenwerten
    assert h.heat_pump_kwh == pytest.approx(2.0)  # erhalten geblieben
    assert h.base_kwh == pytest.approx(3.0)
