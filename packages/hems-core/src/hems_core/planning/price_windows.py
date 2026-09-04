"""Preisfenster aus einer Tagespreisreihe (Tibber-ähnlich, stündlich oder viertelstündlich)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta


@dataclass(frozen=True)
class PricePoint:
    start: datetime
    end: datetime
    ct_kwh: float


@dataclass(frozen=True)
class PriceWindow:
    start: datetime
    end: datetime
    kind: str  # "cheap" | "expensive" | "negative"
    avg_ct_kwh: float


def current_price(prices: list[PricePoint], now: datetime) -> PricePoint | None:
    for p in prices:
        if p.start <= now < p.end:
            return p
    return None


def price_rank(prices: list[PricePoint], now: datetime) -> float | None:
    """Rang des aktuellen Preises innerhalb der Reihe: 0 = günstigst, 1 = teuerst."""
    cur = current_price(prices, now)
    if cur is None or len(prices) < 2:
        return None
    cheaper = sum(1 for p in prices if p.ct_kwh < cur.ct_kwh)
    return cheaper / (len(prices) - 1)


def _merge(points: list[PricePoint], kind: str, min_len: timedelta) -> list[PriceWindow]:
    windows: list[PriceWindow] = []
    run: list[PricePoint] = []

    def flush() -> None:
        if run and (run[-1].end - run[0].start) >= min_len:
            avg = sum(p.ct_kwh for p in run) / len(run)
            windows.append(PriceWindow(run[0].start, run[-1].end, kind, round(avg, 2)))

    for p in points:
        if run and p.start == run[-1].end:
            run.append(p)
        else:
            flush()
            run = [p]
    flush()
    return windows


def cheap_windows(
    prices: list[PricePoint], quantile: float, min_window_min: int
) -> list[PriceWindow]:
    if not prices:
        return []
    ordered = sorted(p.ct_kwh for p in prices)
    idx = max(0, min(len(ordered) - 1, round(quantile * (len(ordered) - 1))))
    threshold = ordered[idx]
    selected = [p for p in prices if p.ct_kwh <= threshold]
    return _merge(selected, "cheap", timedelta(minutes=min_window_min))


def expensive_windows(
    prices: list[PricePoint], quantile: float, min_window_min: int
) -> list[PriceWindow]:
    if not prices:
        return []
    ordered = sorted(p.ct_kwh for p in prices)
    idx = max(0, min(len(ordered) - 1, round(quantile * (len(ordered) - 1))))
    threshold = ordered[idx]
    selected = [p for p in prices if p.ct_kwh >= threshold]
    return _merge(selected, "expensive", timedelta(minutes=min_window_min))


def negative_windows(prices: list[PricePoint]) -> list[PriceWindow]:
    return _merge([p for p in prices if p.ct_kwh < 0], "negative", timedelta(0))


def next_window_after(windows: list[PriceWindow], now: datetime) -> PriceWindow | None:
    upcoming = [w for w in windows if w.start > now]
    return min(upcoming, key=lambda w: w.start) if upcoming else None
