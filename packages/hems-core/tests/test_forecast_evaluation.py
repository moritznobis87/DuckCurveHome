from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

import pytest

from hems_core.forecasting.evaluation import (
    BiasCorrector,
    CorrectorState,
    ForecastSample,
    aggregate_15min,
    elevation_bin,
    explain_corrections_de,
    score,
    score_by_horizon,
)

T0 = datetime(2026, 9, 5, 4, 0, tzinfo=UTC)


def _day(forecast_factor: float, elev: float = 25.0, n: int = 40) -> list[ForecastSample]:
    """Ein Tag mit konstanter Sonnenhöhe: Prognose = Ist × forecast_factor."""
    out = []
    for i in range(n):
        actual = 3.0
        out.append(
            ForecastSample(
                ts=T0 + timedelta(minutes=15 * i),
                forecast_kw=actual * forecast_factor,
                actual_kw=actual,
                elevation_deg=elev,
                horizon_h=6 + i * 0.25,
            )
        )
    return out


def test_elevation_bins() -> None:
    assert elevation_bin(-3) is None
    assert elevation_bin(0.5) == 0
    assert elevation_bin(10) == 1
    assert elevation_bin(44.9) == 3
    assert elevation_bin(70) == 4


def test_score_basic() -> None:
    s = score(_day(1.2))
    assert s.n == 40
    assert s.bias_kw == pytest.approx(0.6, abs=1e-6)
    assert s.mae_kw == pytest.approx(0.6, abs=1e-6)
    assert s.energy_actual_kwh == pytest.approx(30.0)
    assert s.energy_error_pct == pytest.approx(20.0)


def test_score_empty_and_horizon_classes() -> None:
    assert score([]).n == 0 and score([]).energy_error_pct is None
    by = score_by_horizon(_day(1.0))
    assert by["0-3h"].n == 0
    assert by["3-12h"].n == 24  # Horizonte 6 … 11,75 h
    assert by["12-36h"].n == 16


def test_aggregate_15min_skips_gaps() -> None:
    rows = [(T0 + timedelta(minutes=m), (2.0 if m % 2 == 0 else None)) for m in range(30)]
    agg = aggregate_15min(rows)
    assert [a[0] for a in agg] == [T0, T0 + timedelta(minutes=15)]
    assert agg[0][1] == 2.0


def test_corrector_learns_towards_ratio_with_damping_and_activation() -> None:
    c = BiasCorrector(min_days=3, half_life_days=1)
    # Prognose 20 % zu hoch → Verhältnis 0,833; alpha 0,5 → Schritt auf höchstens −0,05 gedämpft
    u1 = c.update_day(date(2026, 9, 1), _day(1.2))
    assert u1.changes[0].ratio == pytest.approx(0.8333, abs=1e-3)
    assert u1.changes[0].new == pytest.approx(0.95, abs=1e-6)
    assert not c.state.active
    assert c.apply(3.0, 25.0) == 3.0  # noch nicht aktiv → unverändert
    c.update_day(date(2026, 9, 2), _day(1.2))
    u3 = c.update_day(date(2026, 9, 3), _day(1.2))
    assert u3.active_after and c.state.active
    b = c.state.bins[2]
    assert 0.83 < b.factor < 0.95 and b.days == 3
    assert c.apply(3.0, 25.0) == pytest.approx(3.0 * b.factor, abs=1e-3)
    assert c.apply(3.0, -5.0) == 3.0  # nachts kein Faktor
    # andere Klassen haben nichts gelernt
    assert c.state.bins[0].days == 0 and c.state.bins[0].factor == 1.0


def test_corrector_ignores_bins_without_energy_and_clamps() -> None:
    c = BiasCorrector(min_days=1, half_life_days=1, max_step=1.0)
    u = c.update_day(date(2026, 9, 1), _day(10.0))  # Verhältnis 0,1, alpha 0,5 → 0,55
    assert u.changes[0].new == pytest.approx(0.55)
    u2 = c.update_day(date(2026, 9, 2), _day(10.0))  # 0,325 → auf 0,5 begrenzt
    assert u2.changes[0].new == 0.5
    u3 = c.update_day(date(2026, 9, 3), [])
    assert u3.changes == [] and u3.days_learned == 2


def test_state_roundtrip_and_explanation() -> None:
    c = BiasCorrector(min_days=1)
    c.update_day(date(2026, 9, 1), _day(1.2))
    dumped = c.state.model_dump(mode="json")
    restored = CorrectorState.model_validate(dumped)
    assert restored == c.state
    lines = explain_corrections_de(restored)
    assert any("20–30°" in ln and "gesenkt" in ln for ln in lines)
    assert any("Tagesenergie" in ln for ln in lines)
    inactive = explain_corrections_de(CorrectorState())
    assert inactive[0].startswith("Korrektur noch nicht aktiv")
