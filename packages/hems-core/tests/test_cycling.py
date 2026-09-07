"""Taktung: die Zerlegung einer Leistungsreihe in Verdichterläufe."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from hems_core.domain import BufferConfig
from hems_core.thermal import compressor_runs, cycling_stats, usable_energy_kwh

T0 = datetime(2026, 9, 7, 0, 0, tzinfo=UTC)
ON = 1.0


def series(pattern: list[float | None]) -> list[tuple[datetime, float | None]]:
    return [(T0 + timedelta(minutes=i), v) for i, v in enumerate(pattern)]


def test_a_run_is_consecutive_minutes_above_the_threshold() -> None:
    runs = compressor_runs(series([0.0, 3.0, 3.0, 3.0, 0.0, 0.0, 2.0, 2.0]), ON)
    assert [r.minutes for r in runs] == [3, 2]
    assert runs[0].start == T0 + timedelta(minutes=1)
    assert runs[0].end == T0 + timedelta(minutes=4)


def test_standby_power_does_not_count_as_a_run() -> None:
    """Umwälzpumpe und Elektronik laufen weiter - ohne Schwelle wäre alles ein Dauerlauf."""
    assert compressor_runs(series([0.2, 0.3, 0.25, 0.2]), ON) == []


def test_energy_of_a_run_is_summed() -> None:
    runs = compressor_runs(series([0.0, 3.0, 3.0, 0.0]), ON)
    assert runs[0].kwh == pytest.approx(2 * 3.0 / 60.0, abs=1e-3)


def test_a_gap_in_the_data_ends_the_run_instead_of_bridging_it() -> None:
    """Über eine Lücke weiterzuzählen erfände Laufzeit, sie zu ignorieren einen zweiten Start."""
    samples = [
        (T0, 3.0),
        (T0 + timedelta(minutes=1), 3.0),
        # zehn Minuten fehlen
        (T0 + timedelta(minutes=11), 3.0),
        (T0 + timedelta(minutes=12), 3.0),
    ]
    runs = compressor_runs(samples, ON)
    assert len(runs) == 2 and [r.minutes for r in runs] == [2, 2]


def test_stats_count_starts_per_day_against_the_covered_time() -> None:
    # 6 h bewertet, darin 3 Läufe → 12 Starts je Tag
    runs = compressor_runs(series(([3.0] * 20 + [0.0] * 100) * 3), ON)
    s = cycling_stats(runs, covered_minutes=360, min_runtime_min=30)
    assert s.runs == 3
    assert s.starts_per_day == pytest.approx(12.0)
    assert s.running_minutes == 60
    assert s.duty_cycle == pytest.approx(60 / 360, abs=1e-3)
    assert s.short_runs == 3  # 20 min < 30 min Mindestlaufzeit
    # Unter 12 h bewertet gibt es bewusst kein Urteil
    assert s.verdict == "unknown" and "zu wenig" in s.note_de


def test_frequent_short_runs_are_called_out() -> None:
    runs = compressor_runs(series(([3.0] * 10 + [0.0] * 20) * 48), ON)  # 24 h, 48 Läufe à 10 min
    s = cycling_stats(runs, covered_minutes=1440, min_runtime_min=30)
    assert s.verdict == "short_cycling"
    assert s.starts_per_day == pytest.approx(48.0)
    assert s.short_share == pytest.approx(1.0)


def test_long_calm_runs_are_unremarkable() -> None:
    runs = compressor_runs(series(([3.0] * 120 + [0.0] * 240) * 4), ON)  # 24 h, 4 Läufe à 2 h
    s = cycling_stats(runs, covered_minutes=1440, min_runtime_min=30)
    assert s.verdict == "ok" and s.short_runs == 0
    assert s.mean_run_min == pytest.approx(120.0)


def test_empty_period_says_so_instead_of_pretending() -> None:
    s = cycling_stats([], covered_minutes=0, min_runtime_min=30)
    assert s.verdict == "unknown" and s.starts_per_day is None


def test_buffer_energy_rises_with_temperature_and_is_capped() -> None:
    cfg = BufferConfig()  # 1000 l, T_min 35, T_max 62
    cold = usable_energy_kwh([35.0, 35.0, 35.0, 35.0], cfg)
    warm = usable_energy_kwh([55.0, 50.0, 45.0, 40.0], cfg)
    assert cold == pytest.approx(0.0)
    assert warm > cold
    # Überhöhungen über T_min: 20/15/10/5 K, im Mittel 12,5 K
    # 1000 l × 1,163 Wh/(l·K) × 12,5 K ≈ 14,5 kWh
    assert warm == pytest.approx(14.5, abs=0.2)
    # Schichten unter T_min zählen nicht negativ
    assert usable_energy_kwh([50.0, 20.0, 20.0, 20.0], cfg) == pytest.approx(
        usable_energy_kwh([50.0, 35.0, 35.0, 35.0], cfg)
    )
