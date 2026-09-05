"""API-Schemas – dort, wo sie vom Domänenmodell abweichen (Transportform)."""

from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field

from hems_core.domain import (
    AutoProfile,
    BufferState,
    Decision,
    EnergySnapshot,
    HeatPumpState,
    OperatingMode,
    SystemMode,
)
from hems_core.forecasting import CorrectorState, ForecastScore


class PriceWindowOut(BaseModel):
    start: datetime
    end: datetime
    kind: Literal["cheap", "expensive", "negative", "pv_surplus"]
    avg_ct_kwh: float | None = None
    label_de: str


class PlanIntervalOut(BaseModel):
    ts: datetime
    expected_pv_kw: float
    price_ct_kwh: float | None
    planned_hp_state: Literal["off", "release", "free", "avoid"]
    reason_code: str
    note_de: str | None = None


class PlanOut(BaseModel):
    created_at: datetime
    planner: str
    horizon_start: datetime
    horizon_end: datetime
    windows: list[PriceWindowOut]
    intervals: list[PlanIntervalOut]
    pv_forecast_today_kwh: float
    next_cheap_window: PriceWindowOut | None


class SystemStatusOut(BaseModel):
    mode: str
    server_time: datetime
    sim_speed: float
    bridge_online: bool
    sse_clients: int
    version: str
    connection_label_de: str


class LiveStateOut(BaseModel):
    snapshot: EnergySnapshot
    buffer: BufferState
    heat_pump: HeatPumpState
    decision: Decision | None
    operating_mode: OperatingMode
    price_rank: float | None
    today_kwh: dict[str, float]
    system: SystemStatusOut


class HistoryOut(BaseModel):
    start: datetime
    end: datetime
    resolution_s: int = 60
    rows: list[dict[str, float | str | None]]


class ActuatorCommandIn(BaseModel):
    state: bool
    duration_min: int | None = Field(default=None, ge=1, le=24 * 60)


class ActuatorCommandOut(BaseModel):
    key: str
    requested: bool
    observed: bool | None
    ok: bool
    message_de: str


class HeatPumpModeIn(BaseModel):
    system_mode: SystemMode
    auto_profile: AutoProfile | None = None
    manual_state: Literal["on", "off"] | None = None
    duration_min: int = Field(default=120, ge=5, le=12 * 60)


class DemoControlIn(BaseModel):
    speed: float | None = Field(default=None, ge=0.0, le=3600.0)
    fault_key: str | None = None
    fault_quality: Literal["stale", "unavailable", "unknown"] | None = None
    fault_duration_s: int | None = Field(default=None, ge=1, le=86400)
    scenario: (
        Literal["reset", "sunny_surplus", "cold_evening", "buffer_full", "sensor_outage"] | None
    ) = None


class ErrorOut(BaseModel):
    error: dict[str, object]


# ----------------------------------------------------------------------------- Prognose-Auswertung


class ForecastPointOut(BaseModel):
    ts: datetime
    actual_kw: float | None
    day_ahead_kw: float | None  # Prognose, die um 06:00 für den Tag vorlag
    latest_kw: float | None  # jüngster Lauf, unkorrigiert
    corrected_kw: float | None  # jüngster Lauf mit den heutigen Korrekturfaktoren


class ForecastDayOut(BaseModel):
    day: date
    issued_at: datetime | None
    score: ForecastScore | None  # Day-ahead gegen Ist, bis jetzt
    points: list[ForecastPointOut]


class DailyScoreOut(BaseModel):
    day: date
    energy_forecast_kwh: float
    energy_actual_kwh: float
    energy_error_pct: float | None
    mae_kw: float
    bias_kw: float
    k_global_after: float
    issued_at: datetime | None = None


class HorizonScoreOut(BaseModel):
    key: str
    label_de: str
    score: ForecastScore


class SourceOut(BaseModel):
    name: str
    label_de: str
    weight: float
    mae_7d_kw: float | None
    active: bool


class ForecastEvaluationOut(BaseModel):
    generated_at: datetime
    stage_de: str
    sources: list[SourceOut]
    today: ForecastDayOut
    yesterday: ForecastDayOut
    daily: list[DailyScoreOut]
    horizons: list[HorizonScoreOut]
    corrector: CorrectorState
    correction_active: bool
    next_changes_de: list[str]
    runs_kept: int
    notes_de: list[str]
