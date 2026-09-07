"""Der MILP-Planer: rechnet er wirklich, was er verspricht?

Jeder Test stellt eine Frage, die der regelbasierte Planer nicht beantworten kann.
"""

from __future__ import annotations

from hems_core.planning import Interval, OptimizerConfig, optimize

CHEAP, PRICEY = 10.0, 45.0
KW_EL, KW_TH = 3.0, 9.0  # COP 3
BASE = dict(
    electric_kw=KW_EL,
    thermal_kw=KW_TH,
    buffer_start_kwh=10.0,
    buffer_min_kwh=6.0,
    buffer_max_kwh=25.0,
    buffer_loss_kwh_per_step=0.05,
    min_runtime_min=30.0,
    min_offtime_min=20.0,
)


def ivs(prices: list[float], demand: float = 0.4, surplus: float = 0.0) -> list[Interval]:
    return [
        Interval(price_ct_kwh=p, feed_in_ct_kwh=7.41, surplus_kw=surplus, demand_kwh=demand)
        for p in prices
    ]


def test_it_puts_the_run_into_the_cheap_hours() -> None:
    """Vier teure Stunden, dann vier günstige. Der Bedarf lässt sich verschieben."""
    prices = [PRICEY] * 16 + [CHEAP] * 16 + [PRICEY] * 64  # 24 h in Viertelstunden
    r = optimize(ivs(prices), **BASE)
    assert r.status in ("optimal", "feasible")
    cheap_on = sum(r.on[16:32])
    assert cheap_on > 0
    # Anteil der Laufzeit im günstigen Fenster liegt deutlich über dessen Zeitanteil (16/96)
    assert cheap_on / max(1, sum(r.on)) > 0.35


def test_it_respects_the_minimum_runtime() -> None:
    r = optimize(ivs([CHEAP] * 96), **BASE)
    runs, cur = [], 0
    for v in r.on:
        if v:
            cur += 1
        elif cur:
            runs.append(cur)
            cur = 0
    if cur:
        runs.append(cur)
    # 30 min Mindestlaufzeit bei 15-min-Raster = 2 Intervalle
    assert all(m >= 2 for m in runs), runs


def test_it_does_not_short_cycle_because_switching_costs() -> None:
    """Ohne Schaltstrafe wäre das Optimum ein Flattern im Viertelstundentakt."""
    prices = [CHEAP if i % 2 == 0 else PRICEY for i in range(96)]
    r = optimize(ivs(prices), **BASE)
    assert r.starts <= 8, f"{r.starts} Anläufe sind zu viele"


def test_pv_surplus_beats_a_cheap_grid_hour() -> None:
    """Überschuss kostet nur die entgangene Vergütung, also weniger als jeder Bezugspreis."""
    intervals = ivs([CHEAP] * 96)
    for t in range(40, 56):  # Mittagsfenster mit Überschuss
        intervals[t] = intervals[t].model_copy(update={"surplus_kw": KW_EL + 1.0})
    r = optimize(intervals, **BASE)
    assert sum(r.on[40:56]) > 0


def test_the_buffer_never_exceeds_its_capacity() -> None:
    r = optimize(ivs([CHEAP] * 96, demand=0.0), **BASE)
    assert max(r.buffer_kwh) <= BASE["buffer_max_kwh"] + 1e-6


def test_the_horizon_does_not_end_on_an_empty_buffer() -> None:
    """Ohne Endbedingung führe jede rollierende Optimierung den Puffer zum Schluss leer."""
    r = optimize(ivs([CHEAP] * 96, demand=0.5), **BASE)
    cfg = OptimizerConfig()
    assert r.buffer_kwh[-1] >= cfg.terminal_soc * BASE["buffer_max_kwh"] - 1e-6


def test_blocked_intervals_stay_off() -> None:
    intervals = ivs([CHEAP] * 96)
    blocked = range(0, 20)
    for t in blocked:
        intervals[t] = intervals[t].model_copy(update={"blocked": True})
    r = optimize(intervals, **BASE)
    assert not any(r.on[t] for t in blocked)


def test_an_impossible_comfort_target_is_penalised_not_refused() -> None:
    """Lieber ein Fahrplan mit ausgewiesener Komfortlücke als gar keiner."""
    args = {**BASE, "buffer_start_kwh": 6.0, "thermal_kw": 0.5}
    r = optimize(ivs([CHEAP] * 96, demand=2.0), **args)
    assert r.status in ("optimal", "feasible")
    assert r.comfort_miss_kwh > 0
    assert "Komfortminimum" in r.note_de


def test_empty_horizon_says_so() -> None:
    assert optimize([], **BASE).status == "infeasible"


def test_it_solves_a_36_hour_horizon_quickly() -> None:
    prices = [CHEAP if (i // 4) % 6 < 2 else PRICEY for i in range(144)]
    r = optimize(ivs(prices), **BASE)
    assert r.status in ("optimal", "feasible")
    assert r.solve_ms < 5000
    assert len(r.on) == 144
