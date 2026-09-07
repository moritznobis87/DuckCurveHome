"""Die Jahreskarte muss zwei Dinge richtig machen, sonst zeigt sie Unsinn: die Stundenachse ist
Ortszeit, und eine Lücke in der Aufzeichnung ist keine Null."""

from __future__ import annotations

from datetime import UTC, date, datetime
from zoneinfo import ZoneInfo

import pytest

from dch_api.application.energy_accounting import EnergyAccounting
from hems_core.accounting import HourlyEnergy
from hems_core.domain import HemsConfig

BERLIN = ZoneInfo("Europe/Berlin")
NOW = datetime(2026, 7, 1, 12, 0, tzinfo=UTC)


def _accounting(hours: list[HourlyEnergy]) -> EnergyAccounting:
    async def no_rows(_s: datetime, _e: datetime) -> list[dict[str, float | str | None]]:
        return []

    async def read(s: datetime, e: datetime) -> list[tuple[HourlyEnergy, float | None]]:
        return [(h, None) for h in hours if s <= h.hour_start < e]

    async def write(_h: list[HourlyEnergy], _t: dict[datetime, float | None]) -> None:
        return None

    async def last() -> datetime | None:
        return hours[-1].hour_start if hours else None

    return EnergyAccounting(HemsConfig(), BERLIN, no_rows, (read, write, last))


def _hour(ts: datetime, **kw: float) -> HourlyEnergy:
    return HourlyEnergy(hour_start=ts, minutes=60, **kw)


async def test_hour_axis_is_local_time_not_utc() -> None:
    """Im Sommer liegt 10:00 UTC auf 12:00 Ortszeit. Sonst wanderte die Sonne im Bild."""
    acc = _accounting([_hour(datetime(2026, 7, 1, 10, 0, tzinfo=UTC), pv_kwh=5.0)])
    m = await acc.year_map(2026, NOW)
    row = m.days.index(date(2026, 7, 1))
    assert m.metrics["pv_kwh"][row][12] == pytest.approx(5.0)
    assert m.metrics["pv_kwh"][row][10] is None


async def test_missing_hours_stay_none_and_are_not_zero() -> None:
    acc = _accounting([_hour(datetime(2026, 7, 1, 10, 0, tzinfo=UTC), pv_kwh=5.0)])
    m = await acc.year_map(2026, NOW)
    assert m.hours_with_data == 1
    jan = m.metrics["pv_kwh"][m.days.index(date(2026, 1, 1))]
    assert all(v is None for v in jan)  # nie „0 kWh" für eine Lücke


async def test_year_has_every_calendar_day_and_24_hours() -> None:
    acc = _accounting([])
    m = await acc.year_map(2026, NOW)
    assert len(m.days) == 365 and m.days[0] == date(2026, 1, 1) and m.days[-1] == date(2026, 12, 31)
    assert all(len(day) == 24 for day in m.metrics["pv_kwh"])
    leap = await _accounting([]).year_map(2028, NOW)
    assert len(leap.days) == 366


async def test_grid_net_is_import_minus_export() -> None:
    acc = _accounting(
        [_hour(datetime(2026, 7, 1, 10, 0, tzinfo=UTC), import_kwh=0.4, export_kwh=3.0)]
    )
    m = await acc.year_map(2026, NOW)
    row = m.days.index(date(2026, 7, 1))
    assert m.metrics["grid_net_kwh"][row][12] == pytest.approx(-2.6)


async def test_autumn_dst_hour_sums_energies_and_averages_prices() -> None:
    """Am Rückstelltag fallen zwei UTC-Stunden auf dieselbe Ortsstunde 02:00."""
    acc = _accounting(
        [
            _hour(
                datetime(2026, 10, 25, 0, 0, tzinfo=UTC),
                pv_kwh=1.0,
                price_weighted_ct=30.0,
                import_kwh=1.0,
            ),
            _hour(
                datetime(2026, 10, 25, 1, 0, tzinfo=UTC),
                pv_kwh=2.0,
                price_weighted_ct=50.0,
                import_kwh=1.0,
            ),
        ]
    )
    m = await acc.year_map(2026, NOW)
    row = m.days.index(date(2026, 10, 25))
    assert m.metrics["pv_kwh"][row][2] == pytest.approx(3.0)  # addiert
    assert m.metrics["price_ct_kwh"][row][2] == pytest.approx(40.0)  # gemittelt


async def test_spring_dst_leaves_the_skipped_hour_empty() -> None:
    acc = _accounting(
        [_hour(datetime(2026, 3, 29, h, 0, tzinfo=UTC), pv_kwh=1.0) for h in range(0, 6)]
    )
    m = await acc.year_map(2026, NOW)
    row = m.days.index(date(2026, 3, 29))
    assert m.metrics["pv_kwh"][row][2] is None  # 02:00 gibt es an diesem Tag nicht
    assert m.metrics["pv_kwh"][row][3] is not None
