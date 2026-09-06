"""API-Schemas – dort, wo sie vom Domänenmodell abweichen (Transportform)."""

from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field

from hems_core.accounting import EnergyTotals, HeatForecastPoint
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


class SystemEventOut(BaseModel):
    at: datetime
    severity: str
    code: str
    message: str
    context: dict[str, object] = Field(default_factory=dict)


class BackfillResultOut(BaseModel):
    """Ergebnis eines manuell angestoßenen myenergi-Historienabrufs."""

    ok: bool
    readings: int = 0
    start: datetime | None = None
    end: datetime | None = None
    error_de: str | None = None


class SourceStatusOut(BaseModel):
    """Zustand einer Messquelle (Bridge, myenergi, …)."""

    name: str
    online: bool
    last_ok: datetime | None = None
    detail_de: str = ""


class SystemStatusOut(BaseModel):
    mode: str
    server_time: datetime
    sim_speed: float
    bridge_online: bool
    sse_clients: int
    version: str
    connection_label_de: str
    sources: list[SourceStatusOut] = Field(default_factory=list)


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


# ----------------------------------------------------------------------------- Energiebilanz

Period = Literal["day", "week", "month", "year"]


class EnergyTotalsOut(EnergyTotals):
    """Summen plus abgeleitete Kennzahlen als normale Felder (für JSON)."""

    autarky: float | None = None
    self_consumption_share: float | None = None
    avg_import_price_ct: float | None = None

    @classmethod
    def from_totals(cls, t: EnergyTotals) -> EnergyTotalsOut:
        return cls(
            **t.model_dump(),
            autarky=t.autarky,
            self_consumption_share=t.self_consumption_share,
            avg_import_price_ct=t.avg_import_price_ct,
        )


class EnergyBucketOut(BaseModel):
    start: datetime
    end: datetime
    label: str  # z. B. "14:00", "Mo 02.09.", "Sep"
    totals: EnergyTotalsOut


class EnergyMetaOut(BaseModel):
    battery_capacity_kwh: float
    feed_in_ct_kwh: float
    data_since: datetime | None
    coverage: float | None  # bewertete Minuten / Minuten des Zeitraums (bis jetzt)
    estimated_note_de: str


class EnergySummaryOut(BaseModel):
    period: Period
    anchor: date
    start: datetime
    end: datetime
    totals: EnergyTotalsOut
    buckets: list[EnergyBucketOut]
    meta: EnergyMetaOut


class HeatReportOut(BaseModel):
    summary: EnergySummaryOut
    thermal_kwh_est: float  # gelieferte Wärme aus Strom × COP (Schätzung)
    cop_est: float
    forecast: list[HeatForecastPoint]  # nächste 48 h
    forecast_electric_kwh_24h: float
    forecast_thermal_kwh_24h: float
    buffer_series: list[
        dict[str, float | str | None]
    ]  # Puffertemperaturen des Ankertags (Minutenmittel)
    heat_loss_kw_per_k: float
    model_note_de: str


class EvSessionOut(BaseModel):
    start: datetime
    end: datetime
    kwh: float
    pv_share: float | None  # Anteil aus PV (direkt) am Ladevorgang
    grid_kwh: float
    cost_eur: float
    avg_kw: float


class EvReportOut(BaseModel):
    summary: EnergySummaryOut
    sessions: list[EvSessionOut]  # Ladevorgänge im Zeitraum (nur Tag/Woche)
