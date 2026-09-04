"""Anbieterneutrale Forecast-Modelle und Provider-Protokolle (Plan Abschnitte 18–19)."""

from __future__ import annotations

from datetime import date, datetime
from typing import Protocol

from pydantic import BaseModel, ConfigDict, Field

from hems_core.planning.price_windows import PricePoint


class GeoPoint(BaseModel):
    model_config = ConfigDict(frozen=True)

    latitude: float
    longitude: float
    elevation_m: float = 0.0


class SiteConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    name: str = "Geilenkirchen"
    location: GeoPoint = GeoPoint(latitude=50.97, longitude=6.12, elevation_m=80.0)
    timezone: str = "Europe/Berlin"


class PvArrayConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    name: str = "main_roof"
    capacity_kwp: float = 9.9
    azimuth_deg: float = 180.0  # 0 = Nord, 90 = Ost, 180 = Süd, 270 = West
    tilt_deg: float = 35.0


class PvSystemConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    arrays: list[PvArrayConfig] = Field(default_factory=lambda: [PvArrayConfig()])
    inverter_ac_kw: float = 8.25
    loss_factor: float = 0.14
    calibration_factor: float = 1.0  # aus Kalibrierung (19.4), 1.0 = neutral

    @property
    def total_kwp(self) -> float:
        return sum(a.capacity_kwp for a in self.arrays)


class WeatherPoint(BaseModel):
    model_config = ConfigDict(frozen=True)

    ts: datetime
    temp_c: float | None
    apparent_temp_c: float | None = None
    ghi_w_m2: float | None = None
    dni_w_m2: float | None = None
    dhi_w_m2: float | None = None
    cloud_cover: float | None = None  # 0–1
    precipitation_mm: float | None = None
    wind_speed_m_s: float | None = None
    humidity: float | None = None


class SunEvent(BaseModel):
    model_config = ConfigDict(frozen=True)

    day: date
    sunrise: datetime
    sunset: datetime


class WeatherForecast(BaseModel):
    model_config = ConfigDict(frozen=True)

    provider: str
    issued_at: datetime
    location: GeoPoint
    resolution_min: int
    points: list[WeatherPoint]
    sun_events: list[SunEvent] = Field(default_factory=list)


class PvPoint(BaseModel):
    model_config = ConfigDict(frozen=True)

    ts: datetime
    ac_kw: float
    ac_kw_lo: float | None = None
    ac_kw_hi: float | None = None


class PvForecast(BaseModel):
    model_config = ConfigDict(frozen=True)

    provider: str
    issued_at: datetime
    resolution_min: int
    points: list[PvPoint]

    def energy_kwh(self, day: date, tz: str) -> float:
        from zoneinfo import ZoneInfo

        z = ZoneInfo(tz)
        step_h = self.resolution_min / 60.0
        return round(
            sum(p.ac_kw * step_h for p in self.points if p.ts.astimezone(z).date() == day), 2
        )


class WeatherProvider(Protocol):
    name: str

    async def fetch(self, location: GeoPoint, horizon_h: int) -> WeatherForecast: ...


class PvForecastProvider(Protocol):
    name: str

    async def forecast(
        self,
        system: PvSystemConfig,
        site: SiteConfig,
        weather: WeatherForecast | None,
        horizon_h: int,
    ) -> PvForecast: ...


class PriceProvider(Protocol):
    name: str

    async def fetch(self) -> list[PricePoint]: ...
