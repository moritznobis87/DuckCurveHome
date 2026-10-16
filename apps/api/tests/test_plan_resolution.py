"""Der Planer rechnet auf einem 15-Minuten-Raster. Er muss deshalb auch Preise auflösen können, die
feiner sind als eine Stunde - die Strombörse rechnet seit Oktober 2025 in Viertelstunden."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from dch_api.application.plan_service import build_plan
from hems_core.domain import HemsConfig
from hems_core.planning import PricePoint
from hems_core.simulation import BERLIN

NOW = datetime(2026, 9, 7, 10, 0, tzinfo=UTC)
DAY_START = (
    NOW.astimezone(BERLIN).replace(hour=0, minute=0, second=0, microsecond=0).astimezone(UTC)
)


def _quarter_prices(hours: int) -> list[PricePoint]:
    """Viertelstundenpreise, die innerhalb jeder Stunde deutlich schwanken."""
    out: list[PricePoint] = []
    for i in range(hours * 4):
        t = DAY_START + timedelta(minutes=15 * i)
        out.append(PricePoint(start=t, end=t + timedelta(minutes=15), ct_kwh=10.0 + (i % 4) * 10.0))
    return out


def _hourly_prices(hours: int) -> list[PricePoint]:
    return [
        PricePoint(
            start=DAY_START + timedelta(hours=i),
            end=DAY_START + timedelta(hours=i + 1),
            ct_kwh=20.0 + i,
        )
        for i in range(hours)
    ]


def _pv(_t: datetime) -> float:
    return 0.0


def test_quarter_hourly_prices_reach_every_interval() -> None:
    plan = build_plan(_pv, _quarter_prices(24), NOW, HemsConfig())
    first_hour = [i for i in plan.intervals if i.ts < DAY_START + timedelta(hours=1)]
    assert len(first_hour) == 4
    # Vier verschiedene Preise in einer Stunde: ein Nachschlagen über den Stundenschlüssel gäbe
    # allen vier denselben.
    assert [i.price_ct_kwh for i in first_hour] == [10.0, 20.0, 30.0, 40.0]


def test_hourly_prices_are_unchanged() -> None:
    plan = build_plan(_pv, _hourly_prices(24), NOW, HemsConfig())
    first_hour = [i for i in plan.intervals if i.ts < DAY_START + timedelta(hours=1)]
    assert [i.price_ct_kwh for i in first_hour] == [20.0] * 4


def test_horizon_follows_price_coverage_not_point_count() -> None:
    """96 Viertelstundenpreise sind ein Tag, nicht vier. Eine Zählung verwechselte das."""
    one_day = build_plan(_pv, _quarter_prices(24), NOW, HemsConfig())
    assert one_day.intervals[-1].ts < DAY_START + timedelta(days=1)
    two_days = build_plan(_pv, _quarter_prices(48), NOW, HemsConfig())
    assert two_days.intervals[-1].ts >= DAY_START + timedelta(days=1)
    # Stundenpreise verhalten sich weiterhin gleich
    assert build_plan(_pv, _hourly_prices(24), NOW, HemsConfig()).intervals[
        -1
    ].ts < DAY_START + timedelta(days=1)
    assert build_plan(_pv, _hourly_prices(48), NOW, HemsConfig()).intervals[
        -1
    ].ts >= DAY_START + timedelta(days=1)


def test_der_ofen_steht_im_plan_oder_gar_nichts() -> None:
    """Der Fahrplan des Ofens wird mitgeführt, nicht hier gerechnet.

    `None` heißt „kein Ofenfahrplan" und ist etwas anderes als `False`: ohne diesen Unterschied
    zeigte die Zeitleiste einen Ofen, der durchgehend aus ist, wo in Wahrheit niemand geplant hat.
    """
    from datetime import UTC, datetime, timedelta

    from dch_api.application.plan_service import build_plan
    from hems_core.domain import HemsConfig

    now = datetime(2026, 10, 13, 10, 0, tzinfo=UTC)
    brennt_bis = now + timedelta(hours=2)

    ohne = build_plan(lambda t: 0.0, [], now, HemsConfig())
    assert all(iv.planned_stove_on is None for iv in ohne.intervals)

    mit = build_plan(lambda t: 0.0, [], now, HemsConfig(), stove_on=lambda t: now <= t < brennt_bis)
    an = [iv for iv in mit.intervals if iv.planned_stove_on]
    aus = [iv for iv in mit.intervals if iv.planned_stove_on is False]
    assert len(an) == 8, "zwei Stunden sind acht Viertelstunden"
    assert aus, "ausserhalb der Brennphase steht ausdrücklich „aus“"
