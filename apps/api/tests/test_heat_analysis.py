"""Preisgüte und Puffer-Energiebilanz: zwei Auswertungen ohne neue Hardware."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from dch_api.application.energy_accounting import _buffer_balance, _price_quality
from dch_api.schemas import EnergyTotalsOut
from hems_core.accounting import HourlyEnergy
from hems_core.domain import BufferConfig

H0 = datetime(2026, 9, 7, 0, 0, tzinfo=UTC)


def _hour(i: int, *, price_ct: float, import_kwh: float, hp_kwh: float, hp_grid: float):
    """Eine Stunde mit stimmigem Preis: price_weighted_ct = Bezug × Preis."""
    return (
        HourlyEnergy(
            hour_start=H0 + timedelta(hours=i),
            minutes=60,
            import_kwh=import_kwh,
            price_weighted_ct=import_kwh * price_ct,
            heat_pump_kwh=hp_kwh,
            heat_pump_grid_kwh=hp_grid,
            heat_pump_cost_eur=hp_grid * price_ct / 100.0,
        ),
        None,
    )


def _totals(hours) -> EnergyTotalsOut:
    from hems_core.accounting import summarize

    return EnergyTotalsOut.from_totals(summarize(h for h, _ in hours))


def test_heat_pump_running_in_cheap_hours_shows_an_advantage() -> None:
    # 18 teure Stunden ohne WP, 6 günstige mit WP — das günstigste Viertel von 24 Stunden sind 6
    hours = [_hour(i, price_ct=45.0, import_kwh=2.0, hp_kwh=0.0, hp_grid=0.0) for i in range(18)]
    hours += [
        _hour(i, price_ct=15.0, import_kwh=3.0, hp_kwh=3.0, hp_grid=3.0) for i in range(18, 24)
    ]
    q = _price_quality(hours, _totals(hours))
    assert q.hp_grid_price_ct == pytest.approx(15.0, abs=0.1)
    assert q.house_grid_price_ct is not None and q.house_grid_price_ct > 20
    assert q.advantage_ct is not None and q.advantage_ct > 5
    assert "günstiger" in q.note_de
    assert q.cheap_share == pytest.approx(1.0)  # alle WP-Energie im günstigsten Viertel


def test_heat_pump_running_in_expensive_hours_is_called_out() -> None:
    hours = [_hour(i, price_ct=15.0, import_kwh=3.0, hp_kwh=0.0, hp_grid=0.0) for i in range(12)]
    hours += [
        _hour(i, price_ct=45.0, import_kwh=3.0, hp_kwh=3.0, hp_grid=3.0) for i in range(12, 24)
    ]
    q = _price_quality(hours, _totals(hours))
    assert q.advantage_ct is not None and q.advantage_ct < -5
    assert "teurer" in q.note_de
    assert q.cheap_share == pytest.approx(0.0)


def test_price_quality_without_heat_pump_grid_use_says_so() -> None:
    hours = [_hour(i, price_ct=30.0, import_kwh=1.0, hp_kwh=0.0, hp_grid=0.0) for i in range(24)]
    q = _price_quality(hours, _totals(hours))
    assert q.hp_grid_price_ct is None and q.advantage_ct is None
    assert "Zu wenig" in q.note_de


def _row(t: float, hp: float) -> dict[str, float | str | None]:
    return {
        "buffer_temp_top_c": t,
        "buffer_temp_mid_top_c": t,
        "buffer_temp_mid_bottom_c": t,
        "buffer_temp_bottom_c": t,
        "heat_pump_power_kw": hp,
    }


def test_buffer_gain_without_the_heat_pump_is_flagged_as_foreign_heat() -> None:
    """Der Puffer wird wärmer, obwohl die Wärmepumpe steht — beim Kombipuffer der Pelletofen."""
    cfg = BufferConfig()
    series = [_row(40.0, 0.0), _row(45.0, 0.0), _row(50.0, 0.0)]
    b = _buffer_balance(series, cfg)
    assert b.samples == 3
    assert b.gain_kwh > 0 and b.gain_with_hp_kwh == 0.0
    assert b.gain_without_hp_kwh == pytest.approx(b.gain_kwh)
    assert "Pelletofen" in b.note_de


def test_buffer_gain_while_the_heat_pump_runs_is_not_foreign_heat() -> None:
    cfg = BufferConfig()
    series = [_row(40.0, 3.0), _row(45.0, 3.0), _row(50.0, 3.0)]
    b = _buffer_balance(series, cfg)
    assert b.gain_without_hp_kwh == 0.0
    assert b.gain_with_hp_kwh == pytest.approx(b.gain_kwh)
    assert "Keine nennenswerte" in b.note_de


def test_buffer_drop_is_counted_separately() -> None:
    cfg = BufferConfig()
    b = _buffer_balance([_row(55.0, 0.0), _row(45.0, 0.0)], cfg)
    assert b.drop_kwh > 0 and b.gain_kwh == 0.0
    assert b.energy_start_kwh is not None and b.energy_end_kwh is not None
    assert b.energy_start_kwh > b.energy_end_kwh


def test_incomplete_buffer_readings_are_skipped_not_guessed() -> None:
    cfg = BufferConfig()
    broken = {**_row(45.0, 0.0), "buffer_temp_bottom_c": None}
    b = _buffer_balance([broken, broken], cfg)
    assert b.samples == 0 and "Zu wenige" in b.note_de
