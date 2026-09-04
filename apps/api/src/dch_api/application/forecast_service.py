"""Hält Wetter-, PV- und Preisprognosen aktuell (Live-Modus) und stellt eine PV-Erwartungsfunktion bereit."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import structlog

from hems_core.forecasting import (
    PvForecast,
    PvSystemConfig,
    SiteConfig,
    WeatherForecast,
    simple_pv_forecast,
)
from hems_core.forecasting.models import PriceProvider, WeatherProvider
from hems_core.planning import PricePoint

log = structlog.get_logger("forecast")


class ForecastService:
    def __init__(
        self,
        site: SiteConfig,
        pv: PvSystemConfig,
        weather: WeatherProvider | None,
        prices: PriceProvider | None,
    ) -> None:
        self.site = site
        self.pv_cfg = pv
        self.weather_provider = weather
        self.price_provider = prices
        self.weather: WeatherForecast | None = None
        self.pv: PvForecast | None = None
        self.prices: list[PricePoint] = []
        self.prices_fetched_at: datetime | None = None
        self.weather_fetched_at: datetime | None = None
        self.last_error: str | None = None

    async def refresh_weather(self, now: datetime) -> None:
        if self.weather_provider is not None:
            try:
                self.weather = await self.weather_provider.fetch(self.site.location, horizon_h=72)
                self.weather_fetched_at = now
                self.last_error = None
            except Exception as exc:
                self.last_error = f"weather: {exc}"
                log.warning("weather refresh failed", error=str(exc)[:200])
        self.pv = simple_pv_forecast(
            system=self.pv_cfg,
            site=self.site,
            weather=self.weather,
            start=now - timedelta(hours=1),
            horizon_h=49,
            issued_at=now,
        )

    async def refresh_prices(self, now: datetime) -> None:
        if self.price_provider is None:
            return
        try:
            self.prices = await self.price_provider.fetch()
            self.prices_fetched_at = now
        except Exception as exc:
            self.last_error = f"prices: {exc}"
            log.warning("price refresh failed", error=str(exc)[:200])

    def price_age_s(self, now: datetime) -> float | None:
        return (
            None
            if self.prices_fetched_at is None
            else (now - self.prices_fetched_at).total_seconds()
        )

    def pv_expected_kw(self, at: datetime) -> float:
        if self.pv is None or not self.pv.points:
            return 0.0
        best = min(self.pv.points, key=lambda p: abs((p.ts - at).total_seconds()))
        return best.ac_kw if abs((best.ts - at).total_seconds()) <= 15 * 60 else 0.0

    def outdoor_temp_c(self, at: datetime) -> float | None:
        if self.weather is None or not self.weather.points:
            return None
        best = min(self.weather.points, key=lambda p: abs((p.ts - at).total_seconds()))
        return best.temp_c if abs((best.ts - at).total_seconds()) <= 3600 else None

    @staticmethod
    def now() -> datetime:
        return datetime.now(UTC)
