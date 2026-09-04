from __future__ import annotations

from datetime import timedelta

from hc_helpers import T0

from hems_core.planning import (
    PricePoint,
    cheap_windows,
    expensive_windows,
    negative_windows,
    price_rank,
)

PRICES = [
    18.5,
    18.3,
    18.1,
    18.5,
    19.2,
    22.0,
    27.5,
    31.2,
    38.3,
    34.1,
    29.4,
    25.0,
    22.0,
    19.6,
    17.2,
    18.9,
    21.4,
    30.0,
    42.0,
    40.5,
    38.0,
    33.2,
    29.9,
    26.4,
]


def series(values: list[float]) -> list[PricePoint]:
    day = T0.replace(hour=0, minute=0)
    return [
        PricePoint(day + timedelta(hours=i), day + timedelta(hours=i + 1), v)
        for i, v in enumerate(values)
    ]


def test_rank_is_zero_for_cheapest_and_one_for_most_expensive() -> None:
    s = series(PRICES)
    day = T0.replace(hour=0, minute=0)
    assert price_rank(s, day + timedelta(hours=14, minutes=30)) == 0.0
    assert price_rank(s, day + timedelta(hours=18, minutes=10)) == 1.0


def test_cheap_windows_merge_adjacent_hours() -> None:
    w = cheap_windows(series(PRICES), quantile=0.15, min_window_min=60)
    assert w, "mindestens ein Fenster"
    assert all(x.kind == "cheap" for x in w)
    assert any(x.start.hour <= 3 and x.end.hour >= 3 for x in w)


def test_expensive_and_negative() -> None:
    s = series(PRICES)
    e = expensive_windows(s, quantile=0.85, min_window_min=60)
    assert any(x.start.hour == 18 for x in e)
    assert negative_windows(s) == []
    neg = negative_windows(series([1.0, -0.5, -1.0, 2.0]))
    assert len(neg) == 1 and neg[0].start.hour == 1 and neg[0].end.hour == 3
