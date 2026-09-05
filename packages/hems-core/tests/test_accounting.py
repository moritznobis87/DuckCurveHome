from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from hems_core.accounting import (
    MinuteSample,
    cop_at,
    heat_demand_kw,
    heat_forecast,
    hourly_energy,
    samples_from_rows,
    summarize,
)
from hems_core.domain import HeatDemandConfig, TariffConfig

H0 = datetime(2026, 9, 6, 12, 0, tzinfo=UTC)
TARIFF = TariffConfig(feed_in_ct_kwh=8.0, fallback_import_ct_kwh=30.0)


def _minutes(n: int, **kw: float | None) -> list[MinuteSample]:
    base = {
        "pv_kw": 0.0,
        "grid_kw": 0.0,
        "battery_kw": 0.0,
        "heat_pump_kw": 0.0,
        "ev_kw": 0.0,
        "price_ct_kwh": 30.0,
    }
    base.update(kw)
    return [MinuteSample(ts=H0 + timedelta(minutes=i), **base) for i in range(n)]  # type: ignore[arg-type]


def test_sunny_hour_pv_direct_battery_charge_and_export() -> None:
    # PV 6 kW, Haus 2 kW (davon WP 1 kW), Batterie lädt 2 kW, Export 2 kW
    hour = hourly_energy(
        H0, _minutes(60, pv_kw=6.0, grid_kw=-2.0, battery_kw=-2.0, heat_pump_kw=1.0), TARIFF
    )
    assert hour.minutes == 60
    assert hour.pv_kwh == pytest.approx(6.0)
    assert hour.house_kwh == pytest.approx(2.0)
    assert hour.pv_direct_kwh == pytest.approx(2.0)
    assert hour.pv_to_battery_kwh == pytest.approx(2.0)
    assert hour.export_kwh == pytest.approx(2.0)
    assert hour.grid_to_house_kwh == pytest.approx(0.0)
    assert hour.heat_pump_kwh == pytest.approx(1.0)
    assert hour.heat_pump_pv_kwh == pytest.approx(1.0)
    assert hour.heat_pump_cost_eur == pytest.approx(0.0)
    assert hour.heat_pump_opportunity_eur == pytest.approx(0.08)  # 1 kWh × 8 ct
    assert hour.export_revenue_eur == pytest.approx(0.16)
    assert hour.pv_direct_savings_eur == pytest.approx(2.0 * 0.22)
    assert hour.self_consumption_share == pytest.approx(4.0 / 6.0, abs=1e-3)
    assert hour.autarky == pytest.approx(1.0)


def test_night_hour_battery_then_grid_with_ev() -> None:
    # Nacht: Haus 4 kW (Wallbox 3 kW), Batterie entlädt 1 kW, Netz 3 kW à 40 ct
    hour = hourly_energy(
        H0,
        _minutes(60, pv_kw=0.0, grid_kw=3.0, battery_kw=1.0, ev_kw=3.0, price_ct_kwh=40.0),
        TARIFF,
    )
    assert hour.house_kwh == pytest.approx(4.0)
    assert hour.battery_to_house_kwh == pytest.approx(1.0)
    assert hour.grid_to_house_kwh == pytest.approx(3.0)
    assert hour.ev_kwh == pytest.approx(3.0)
    assert hour.ev_battery_kwh == pytest.approx(0.75)
    assert hour.ev_grid_kwh == pytest.approx(2.25)
    assert hour.ev_cost_eur == pytest.approx(2.25 * 0.40)
    assert hour.import_cost_eur == pytest.approx(1.20)
    assert hour.battery_savings_eur == pytest.approx(1.0 * 0.32)
    assert hour.avg_import_price_ct == pytest.approx(40.0)
    assert hour.autarky == pytest.approx(0.25)


def test_missing_inputs_and_fallback_price() -> None:
    rows = _minutes(30, pv_kw=1.0, grid_kw=0.5, price_ct_kwh=None) + _minutes(
        30, pv_kw=None, grid_kw=0.5
    )
    hour = hourly_energy(H0, rows, TARIFF)
    assert hour.minutes == 30 and hour.price_missing_minutes == 30
    assert hour.import_cost_eur == pytest.approx(0.25 * 0.30)  # Ersatzpreis 30 ct


def test_summarize_and_samples_from_rows() -> None:
    rows = [
        {
            "ts": "2026-09-06T12:00:00Z",
            "pv_power_kw": 2.0,
            "grid_power_kw": -1.0,
            "battery_power_kw": 0.0,
            "heat_pump_power_kw": 0.5,
            "ev_power_kw": None,
            "electricity_price_ct_kwh": 25.0,
        },
        {"ts": "2026-09-06T12:01:00Z", "pv_power_kw": 2.0, "grid_power_kw": -1.0},
    ]
    smp = samples_from_rows(rows)
    assert len(smp) == 2 and smp[1].battery_kw is None and smp[0].heat_pump_kw == 0.5
    h = hourly_energy(H0, smp, TARIFF)
    total = summarize([h, h])
    assert total.minutes == 4 and total.pv_kwh == pytest.approx(2 * h.pv_kwh)
    assert total.price_missing_minutes == 2


def test_heat_model() -> None:
    cfg = HeatDemandConfig()
    assert cop_at(-10, cfg) == 2.4 and cop_at(20, cfg) == 4.2
    assert cop_at(4.5, cfg) == pytest.approx(3.25, abs=1e-3)
    heating, dhw = heat_demand_kw(0.0, 7, cfg)
    assert heating == pytest.approx(0.22 * 21 - 0.4)
    assert dhw > heat_demand_kw(0.0, 3, cfg)[1]  # morgens mehr Warmwasser als nachts
    assert heat_demand_kw(18.0, 12, cfg)[0] == 0.0  # über Heizgrenze
    pts = heat_forecast([(H0, 5.0), (H0 + timedelta(hours=1), 16.0)], cfg)
    assert pts[0].electric_kw > 0 and pts[1].heating_kw == 0.0
