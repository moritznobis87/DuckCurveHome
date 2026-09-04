"""Stufe 1 der Planung: Preisfenster und erwartete PV-Überschussfenster (Chart, Energy Plan)."""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from dch_api.schemas import PlanIntervalOut, PlanOut, PriceWindowOut
from hems_core.domain import HemsConfig
from hems_core.planning import (
    PricePoint,
    PriceWindow,
    cheap_windows,
    expensive_windows,
    negative_windows,
    next_window_after,
)
from hems_core.simulation import BERLIN

LABELS = {
    "cheap": "günstiges Preisfenster",
    "expensive": "Wärmepumpe vermeiden, wenn thermisch möglich",
    "negative": "negativer Strompreis",
    "pv_surplus": "PV-Überschuss nutzen",
}


def _out(w: PriceWindow | tuple[datetime, datetime, str]) -> PriceWindowOut:
    if isinstance(w, PriceWindow):
        return PriceWindowOut(
            start=w.start, end=w.end, kind=w.kind, avg_ct_kwh=w.avg_ct_kwh, label_de=LABELS[w.kind]
        )
    s, e, kind = w
    return PriceWindowOut(start=s, end=e, kind=kind, label_de=LABELS[kind])


PvExpected = Callable[[datetime], float]


def pv_surplus_windows(
    pv_expected: PvExpected, day_start: datetime, cfg: HemsConfig
) -> list[tuple[datetime, datetime, str]]:
    """Erwartete PV-Überschussfenster (Prognose minus Grundlast ≥ Schwelle, mind. 30 min)."""
    windows: list[tuple[datetime, datetime, str]] = []
    run_start: datetime | None = None
    t = day_start
    step = timedelta(minutes=15)
    while t < day_start + timedelta(hours=24):
        exp = pv_expected(t) - 0.6
        if exp >= cfg.control.pv.on_surplus_kw:
            run_start = run_start or t
        elif run_start is not None:
            if t - run_start >= timedelta(minutes=30):
                windows.append((run_start, t, "pv_surplus"))
            run_start = None
        t += step
    if run_start is not None and t - run_start >= timedelta(minutes=30):
        windows.append((run_start, t, "pv_surplus"))
    return windows


def build_plan(
    pv_expected: PvExpected, prices: list[PricePoint], now: datetime, cfg: HemsConfig
) -> PlanOut:
    local_day = now.astimezone(BERLIN).replace(hour=0, minute=0, second=0, microsecond=0)
    day_start = local_day.astimezone(UTC)
    horizon_end = (local_day + timedelta(days=2)).astimezone(UTC)
    price_cfg = cfg.control.price
    cheap = cheap_windows(prices, price_cfg.cheap_quantile, price_cfg.min_window_min)
    expensive = expensive_windows(prices, price_cfg.expensive_quantile, 60)
    negative = negative_windows(prices)
    pv_win = pv_surplus_windows(pv_expected, day_start, cfg) + pv_surplus_windows(
        pv_expected, day_start + timedelta(days=1), cfg
    )
    if len(prices) <= 24:  # ohne Morgenpreise keine PV-Fenster für morgen ausweisen
        pv_win = [w for w in pv_win if w[0] < day_start + timedelta(days=1)]
    windows = [_out(w) for w in (*negative, *cheap, *expensive)] + [_out(w) for w in pv_win]
    windows.sort(key=lambda w: w.start)

    def in_windows(t: datetime, kinds: set[str]) -> PriceWindowOut | None:
        for w in windows:
            if w.kind in kinds and w.start <= t < w.end:
                return w
        return None

    price_by_hour = {p.start: p.ct_kwh for p in prices}
    intervals: list[PlanIntervalOut] = []
    t = day_start
    end_plan = day_start + timedelta(hours=48 if len(prices) > 24 else 24)
    while t < end_plan:
        hour_key = t.replace(minute=0, second=0, microsecond=0)
        price = price_by_hour.get(hour_key)
        w = in_windows(t, {"negative", "pv_surplus", "cheap"})
        avoid = in_windows(t, {"expensive"})
        if w is not None:
            state, code, note = "release", f"planned_{w.kind}", w.label_de
        elif avoid is not None:
            state, code, note = "avoid", "planned_avoid_peak", avoid.label_de
        else:
            state, code, note = "free", "none", None
        intervals.append(
            PlanIntervalOut(
                ts=t,
                expected_pv_kw=round(pv_expected(t), 3),
                price_ct_kwh=price,
                planned_hp_state=state,
                reason_code=code,
                note_de=note,
            )
        )
        t += timedelta(minutes=15)

    pv_kwh = sum(i.expected_pv_kw for i in intervals if i.ts < day_start + timedelta(days=1)) / 4
    nxt = next_window_after([*cheap, *negative], now)
    return PlanOut(
        created_at=now,
        planner="rule_based_v1",
        horizon_start=day_start,
        horizon_end=horizon_end,
        windows=windows,
        intervals=intervals,
        pv_forecast_today_kwh=round(pv_kwh, 1),
        next_cheap_window=_out(nxt) if nxt else None,
    )
