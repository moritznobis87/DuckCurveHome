"""PV-Forecast v1 ohne pvlib: Klarhimmel aus Sonnenstand × Bewölkungsfaktor aus der Wetterprognose.

Bewusst einfach (Plan 19.2 Strategie B, Stufe 1). Ersetzt später durch pvlib mit GHI/DNI/DHI-Transposition.
"""

from __future__ import annotations

import math
from datetime import UTC, datetime, timedelta

from hems_core.forecasting.models import (
    PvForecast,
    PvPoint,
    PvSystemConfig,
    SiteConfig,
    WeatherForecast,
)


def solar_elevation_deg(at: datetime, latitude: float, longitude: float) -> float:
    ut = at.astimezone(UTC)
    n = ut.timetuple().tm_yday
    decl = math.radians(23.44) * math.sin(2 * math.pi * (284 + n) / 365)
    solar_hour = ut.hour + ut.minute / 60 + ut.second / 3600 + longitude / 15
    hour_angle = math.radians(15 * (solar_hour - 12))
    lat = math.radians(latitude)
    s = math.sin(lat) * math.sin(decl) + math.cos(lat) * math.cos(decl) * math.cos(hour_angle)
    return math.degrees(math.asin(max(-1.0, min(1.0, s))))


def clear_sky_ac_kw(at: datetime, system: PvSystemConfig, site: SiteConfig) -> float:
    el = solar_elevation_deg(at, site.location.latitude, site.location.longitude)
    if el <= 0:
        return 0.0
    s = math.sin(math.radians(el))
    air = 1.0 - 0.18 * (1.0 - s)
    dc = system.total_kwp * 0.92 * s * air * (1.0 - system.loss_factor)
    return min(system.inverter_ac_kw, dc)


def _cloud_at(weather: WeatherForecast | None, at: datetime) -> float | None:
    if weather is None or not weather.points:
        return None
    best = min(weather.points, key=lambda p: abs((p.ts - at).total_seconds()))
    if abs((best.ts - at).total_seconds()) > 2 * 3600:
        return None
    return best.cloud_cover


def simple_pv_forecast(
    *,
    system: PvSystemConfig,
    site: SiteConfig,
    weather: WeatherForecast | None,
    start: datetime,
    horizon_h: int,
    resolution_min: int = 15,
    issued_at: datetime | None = None,
) -> PvForecast:
    points: list[PvPoint] = []
    t = start.replace(second=0, microsecond=0)
    t -= timedelta(minutes=t.minute % resolution_min)
    end = start + timedelta(hours=horizon_h)
    while t < end:
        clear = clear_sky_ac_kw(t, system, site)
        cloud = _cloud_at(weather, t)
        factor = 1.0 if cloud is None else max(0.12, 1.0 - 0.75 * cloud)
        ac = clear * factor * system.calibration_factor
        lo = ac * 0.7 if cloud is not None else None
        hi = min(system.inverter_ac_kw, ac * 1.25) if cloud is not None else None
        points.append(
            PvPoint(
                ts=t,
                ac_kw=round(ac, 3),
                ac_kw_lo=None if lo is None else round(lo, 3),
                ac_kw_hi=None if hi is None else round(hi, 3),
            )
        )
        t += timedelta(minutes=resolution_min)
    return PvForecast(
        provider="simple_clear_sky_v1",
        issued_at=issued_at or datetime.now(UTC),
        resolution_min=resolution_min,
        points=points,
    )
