"""Open-Meteo: stündliche Prognose (Temperatur, Strahlung, Bewölkung, Wind, Niederschlag) und Sonnenzeiten."""

from __future__ import annotations

from datetime import UTC, date, datetime

import httpx
import structlog

from hems_core.forecasting import GeoPoint, SunEvent, WeatherForecast, WeatherPoint

log = structlog.get_logger("open_meteo")
URL = "https://api.open-meteo.com/v1/forecast"
HOURLY = [
    "temperature_2m",
    "apparent_temperature",
    "shortwave_radiation",
    "direct_normal_irradiance",
    "diffuse_radiation",
    "cloud_cover",
    "precipitation",
    "wind_speed_10m",
    "relative_humidity_2m",
]


def _ts(s: str) -> datetime:
    return datetime.fromisoformat(s).replace(tzinfo=UTC)


class OpenMeteoWeatherProvider:
    name = "open_meteo"

    def __init__(self, timeout_s: float = 20.0) -> None:
        self.timeout_s = timeout_s

    async def fetch(self, location: GeoPoint, horizon_h: int) -> WeatherForecast:
        days = max(1, min(16, (horizon_h + 23) // 24))
        params: dict[str, str | float | int] = {
            "latitude": location.latitude,
            "longitude": location.longitude,
            "elevation": location.elevation_m,
            "hourly": ",".join(HOURLY),
            "daily": "sunrise,sunset",
            "forecast_days": days,
            "timezone": "UTC",
            "wind_speed_unit": "ms",
        }
        async with httpx.AsyncClient(timeout=self.timeout_s) as client:
            r = await client.get(URL, params=params)
            r.raise_for_status()
            data = r.json()
        h = data["hourly"]
        n = len(h["time"])

        def col(name: str, i: int, scale: float = 1.0) -> float | None:
            v = h.get(name, [None] * n)[i]
            return None if v is None else float(v) * scale

        points = [
            WeatherPoint(
                ts=_ts(h["time"][i]),
                temp_c=col("temperature_2m", i),
                apparent_temp_c=col("apparent_temperature", i),
                ghi_w_m2=col("shortwave_radiation", i),
                dni_w_m2=col("direct_normal_irradiance", i),
                dhi_w_m2=col("diffuse_radiation", i),
                cloud_cover=col("cloud_cover", i, 0.01),
                precipitation_mm=col("precipitation", i),
                wind_speed_m_s=col("wind_speed_10m", i),
                humidity=col("relative_humidity_2m", i, 0.01),
            )
            for i in range(n)
        ]
        d = data.get("daily", {})
        sun = [
            SunEvent(day=date.fromisoformat(t), sunrise=_ts(sr), sunset=_ts(ss))
            for t, sr, ss in zip(
                d.get("time", []), d.get("sunrise", []), d.get("sunset", []), strict=False
            )
        ]
        log.info("weather fetched", points=len(points), days=days)
        return WeatherForecast(
            provider=self.name,
            issued_at=datetime.now(UTC),
            location=location,
            resolution_min=60,
            points=points,
            sun_events=sun,
        )
