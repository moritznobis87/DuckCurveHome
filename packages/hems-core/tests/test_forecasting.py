from __future__ import annotations

from datetime import UTC, datetime, timedelta

from hems_core.forecasting import (
    GeoPoint,
    PvSystemConfig,
    SiteConfig,
    WeatherForecast,
    WeatherPoint,
    simple_pv_forecast,
)


def test_simple_pv_forecast_shape() -> None:
    start = datetime(2026, 6, 20, 0, 0, tzinfo=UTC)
    fc = simple_pv_forecast(
        system=PvSystemConfig(), site=SiteConfig(), weather=None, start=start, horizon_h=24
    )
    assert len(fc.points) == 96
    peak = max(p.ac_kw for p in fc.points)
    assert 5.0 < peak <= 8.25
    night = [p.ac_kw for p in fc.points if p.ts.hour in (0, 1, 2, 22, 23)]
    assert all(v == 0 for v in night)
    assert fc.energy_kwh(start.date(), "Europe/Berlin") > 30


def test_cloud_cover_reduces_output() -> None:
    start = datetime(2026, 6, 20, 0, 0, tzinfo=UTC)
    cloudy = WeatherForecast(
        provider="t",
        issued_at=start,
        location=GeoPoint(latitude=50.97, longitude=6.12),
        resolution_min=60,
        points=[
            WeatherPoint(ts=start + timedelta(hours=h), temp_c=15.0, cloud_cover=1.0)
            for h in range(48)
        ],
    )
    clear = simple_pv_forecast(
        system=PvSystemConfig(), site=SiteConfig(), weather=None, start=start, horizon_h=24
    )
    dull = simple_pv_forecast(
        system=PvSystemConfig(), site=SiteConfig(), weather=cloudy, start=start, horizon_h=24
    )
    assert dull.energy_kwh(start.date(), "Europe/Berlin") < 0.4 * clear.energy_kwh(
        start.date(), "Europe/Berlin"
    )
    assert all(p.ac_kw_lo is not None for p in dull.points)
