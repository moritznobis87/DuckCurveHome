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


# --------------------------------------------------------------------- Zwei Wärmequellen
#
# Der Ofen liefert 10 kW ins Wasser und kostet rund 1,22 EUR je Betriebsstunde. Bei 15 kg im
# Behälter und 2,67 kg/h reicht die Füllung für 5,6 Stunden. Das macht aus dem Preisvergleich ein
# Rucksackproblem, und genau das prüfen die folgenden Tests.
STOVE = dict(
    stove_thermal_kw=10.0,
    stove_kg_per_h=2.666,
    stove_min_runtime_min=120.0,
    stove_min_offtime_min=60.0,
)
STOVE_EUR_H = 1.22


def ivs_with_stove(
    prices: list[float],
    demand: float = 0.4,
    stove_eur_per_h: float = STOVE_EUR_H,
    window_of=None,
) -> list[Interval]:
    return [
        Interval(
            price_ct_kwh=p,
            feed_in_ct_kwh=7.41,
            demand_kwh=demand,
            stove_eur_per_h=stove_eur_per_h,
            budget_window=window_of(t) if window_of else 0,
        )
        for t, p in enumerate(prices)
    ]


def test_ohne_ofen_bleibt_das_problem_so_gross_wie_vorher() -> None:
    """Ein Haus ohne Ofen darf für dessen Modellierung nichts zahlen."""
    r = optimize(ivs([CHEAP] * 96), **BASE)
    assert r.stove_on == []
    assert r.stove_starts == 0
    assert r.stove_pellet_kg == 0.0


def test_bei_billigem_strom_bleibt_der_ofen_aus() -> None:
    """10 ct und COP 3 heißen 3,3 ct/kWh Wärme. Dagegen hat der Ofen mit 12 ct keine Chance."""
    r = optimize(ivs_with_stove([CHEAP] * 96), **BASE, **STOVE, fuel_budget_kg=[15.0])
    assert r.status in ("optimal", "feasible")
    assert not any(r.stove_on), "der Ofen darf hier nicht anspringen"
    assert "Ofen bleibt aus" in r.note_de


def test_bei_teurem_strom_uebernimmt_der_ofen() -> None:
    """80 ct und COP 3 sind 26,7 ct/kWh Wärme. Der Ofen liefert dieselbe Wärme für gut 12."""
    r = optimize(ivs_with_stove([80.0] * 96), **BASE, **STOVE, fuel_budget_kg=[15.0])
    assert r.status in ("optimal", "feasible")
    assert any(r.stove_on), "der Ofen ist hier die günstigere Quelle"
    assert r.stove_runtime_min >= 120, "und läuft dann mindestens seine Mindestlaufzeit"


def test_der_brennstoff_begrenzt_die_ofenlaufzeit() -> None:
    """Auch wenn der Ofen durchgehend günstiger wäre: mehr als eine Füllung gibt es nicht.

    Das ist die Bedingung, die eine Regel nicht abbilden kann. Sie zwingt den Planer, die Füllung
    zu verteilen statt sie zu verbrauchen, sobald sie sich lohnt.
    """
    r = optimize(ivs_with_stove([200.0] * 96, demand=1.0), **BASE, **STOVE, fuel_budget_kg=[15.0])
    assert r.status in ("optimal", "feasible")
    assert r.stove_pellet_kg <= 15.05, f"Budget überschritten: {r.stove_pellet_kg} kg"
    assert r.stove_runtime_min <= 6 * 60, "15 kg tragen keine sechs Stunden Volllast"
    assert r.stove_runtime_min > 0


def test_die_fuellung_landet_in_den_teuersten_stunden() -> None:
    """Der Kern des Rucksackproblems: knapper Brennstoff geht dorthin, wo Strom am teuersten ist.

    Die teure Phase muss dafür länger sein, als der Puffer sie überbrücken kann. Sonst lädt die
    Wärmepumpe vorher billig voll und fährt durch, und dann ist es richtig, den Ofen aus zu lassen.
    Das ist genau der Fall, den die bisherige Handregel falsch macht: sie wirft den Ofen um 17 Uhr
    an, auch wenn der Puffer die Spitze getragen hätte.
    """
    # 16 h: vier billige Stunden, acht teure, vier billige, bei 4 kW Bedarf. Acht Stunden Spitze
    # sind 32 kWh; der Puffer trägt über dem Minimum nur 19 kWh.
    prices = [CHEAP] * 16 + [150.0] * 32 + [CHEAP] * 16
    r = optimize(ivs_with_stove(prices, demand=1.0), **BASE, **STOVE, fuel_budget_kg=[15.0])
    assert any(r.stove_on), "hier trägt der Puffer die Spitze nicht allein"
    in_peak = sum(r.stove_on[16:48])
    assert in_peak / max(1, sum(r.stove_on)) > 0.7, (
        "die Füllung gehört in die teure Spitze, nicht gleichmäßig über den Tag"
    )


def test_zwei_budgetfenster_werden_getrennt_begrenzt() -> None:
    """Über einen 48-h-Horizont gibt es zwei Füllungen, und keine darf die andere ausleihen."""
    prices = [200.0] * 192  # 48 h in Viertelstunden
    r = optimize(
        ivs_with_stove(prices, demand=1.0, window_of=lambda t: 0 if t < 96 else 1),
        **BASE,
        **STOVE,
        fuel_budget_kg=[15.0, 15.0],
    )
    assert r.status in ("optimal", "feasible")
    kg_per_step = STOVE["stove_kg_per_h"] * 0.25
    first = sum(r.stove_on[:96]) * kg_per_step
    second = sum(r.stove_on[96:]) * kg_per_step
    assert first <= 15.05 and second <= 15.05
    assert r.stove_pellet_kg <= 30.1


def test_ein_fast_leerer_behaelter_begrenzt_sofort() -> None:
    """Abends sind vielleicht nur noch 3 kg drin. Dann ist eine Stunde Ofen alles, was geht."""
    r = optimize(ivs_with_stove([200.0] * 96, demand=1.0), **BASE, **STOVE, fuel_budget_kg=[3.0])
    assert r.stove_pellet_kg <= 3.05
    assert r.stove_runtime_min <= 75


def test_der_ofen_taktet_nicht() -> None:
    """Zündkosten und zwei Stunden Mindestlaufzeit halten ihn von kurzen Phasen ab."""
    prices = [CHEAP if (t // 4) % 2 == 0 else 150.0 for t in range(96)]  # stündlicher Wechsel
    r = optimize(ivs_with_stove(prices, demand=0.8), **BASE, **STOVE, fuel_budget_kg=[15.0])
    if any(r.stove_on):
        assert r.stove_starts <= 2, f"{r.stove_starts} Zündungen sind zu viele"


def test_gesperrter_ofen_bleibt_aus() -> None:
    """Nachtruhe, Wartung, oder schlicht: der Hausherr will nicht."""
    intervals = [
        Interval(
            price_ct_kwh=200.0,
            feed_in_ct_kwh=7.41,
            demand_kwh=0.8,
            stove_eur_per_h=STOVE_EUR_H,
            stove_blocked=True,
        )
        for _ in range(96)
    ]
    r = optimize(intervals, **BASE, **STOVE, fuel_budget_kg=[15.0])
    assert not any(r.stove_on)


def test_beide_quellen_zusammen_decken_mehr_als_eine_allein() -> None:
    """Bei sehr hohem Bedarf ist die Wärmepumpe allein zu klein. Dann muss der Ofen mittragen.

    2,6 kWh je Viertelstunde sind 10,4 kW Dauerbedarf, die Wärmepumpe liefert 9. Die Lücke kann nur
    der Ofen schließen, und auch er nur, solange die Füllung reicht.
    """
    prices = [60.0] * 96
    allein = optimize(ivs(prices, demand=2.6), **BASE)
    zusammen = optimize(ivs_with_stove(prices, demand=2.6), **BASE, **STOVE, fuel_budget_kg=[15.0])
    assert allein.unmet_demand_kwh > 0, "die Wärmepumpe allein schafft das nicht"
    assert zusammen.unmet_demand_kwh < allein.unmet_demand_kwh
    assert any(zusammen.stove_on)
