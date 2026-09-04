"""Entscheidung des Reglers – strukturiert, erklärbar, mit Gültigkeit."""

from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field


class ControllerState(StrEnum):
    OFF = "off"  # Systemmodus OFF: nur beobachten
    IDLE = "idle"
    ARMING = "arming"
    RELEASED = "released"  # K1 an, Anlauf erwartet
    RUNNING_RELEASED = "running_released"  # K1 an, Wärmepumpe läuft
    COOLDOWN = "cooldown"
    MANUAL = "manual"
    FAILSAFE = "failsafe"


class ReasonCode(StrEnum):
    # Trigger / positive Gründe
    PV_SURPLUS = "pv_surplus"
    PV_SURPLUS_FADING = "pv_surplus_fading"
    PRICE_NEGATIVE = "price_negative"
    PRICE_CHEAP_WINDOW = "price_cheap_window"
    PLANNED_WINDOW = "planned_window"
    HEAT_DEMAND_FORCED = "heat_demand_forced"
    HP_RUNNING_OWN_CONTROL = "hp_running_own_control"
    # Halte- und Wartegründe
    MIN_RUNTIME_HOLD = "min_runtime_hold"
    MIN_OFFTIME_PENDING = "min_offtime_pending"
    ON_DELAY_PENDING = "on_delay_pending"
    OFF_DELAY_PENDING = "off_delay_pending"
    # Blocker
    BUFFER_FULL = "buffer_full"
    BUFFER_NO_HEADROOM = "buffer_no_headroom"
    MAX_STARTS_REACHED = "max_starts_reached"
    NO_TRIGGER = "no_trigger"
    IMPORT_TOO_HIGH = "import_too_high"
    # Übersteuerung / Modus
    MANUAL_OVERRIDE = "manual_override"
    MODE_OFF = "mode_off"
    # Datenqualität / Sicherheit
    SENSOR_STALE = "sensor_stale"
    SENSOR_UNAVAILABLE = "sensor_unavailable"
    PRICE_DATA_STALE = "price_data_stale"
    HP_NOT_RESPONDING = "hp_not_responding"
    FAILSAFE = "failsafe"
    TOGGLE_RATE_EXCEEDED = "toggle_rate_exceeded"


class NextExpected(BaseModel):
    model_config = ConfigDict(frozen=True)

    action: str  # "start" | "stop" | "release_ends" | "window_start"
    at: datetime | None
    because: ReasonCode
    text_de: str


class DecisionInputs(BaseModel):
    model_config = ConfigDict(frozen=True)

    surplus_ewma_kw: float | None
    import_ewma_kw: float | None
    hp_running: bool
    hp_power_kw: float
    buffer_soc: float | None
    buffer_top_c: float | None
    price_ct_kwh: float | None
    price_rank: float | None  # 0 = günstigstes Intervall des Tages, 1 = teuerstes
    outdoor_temp_c: float | None
    starts_today: int
    seconds_since_stop: float | None
    seconds_since_start: float | None


class Decision(BaseModel):
    model_config = ConfigDict(frozen=True)

    id: UUID = Field(default_factory=uuid4)
    at: datetime
    controller_state: ControllerState
    k1_release: bool
    k2_block: bool
    reasons: list[ReasonCode]  # Hauptgrund zuerst
    blocked_by: list[ReasonCode]
    inputs: DecisionInputs
    valid_until: datetime
    next_expected: NextExpected | None
    explanation_de: str
    # True, wenn sich Zustand, Kontakte oder Hauptgrund gegenüber der vorigen Entscheidung änderten
    changed: bool = False
