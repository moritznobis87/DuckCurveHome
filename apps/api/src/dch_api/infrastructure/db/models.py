"""Tabellen (Plan Abschnitt 16, Phase-2-Teilmenge). Spalten für Abfragen, JSONB für Payloads.

Portabel (SQLite in Tests, PostgreSQL im Betrieb): JSON im Modell, JSONB über `with_variant` für
Postgres. Partitionierung von measurements_raw folgt als eigene Migration, sobald das Volumen es
verlangt (Plan 16.5).
"""

from __future__ import annotations

from datetime import date, datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    JSON,
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    SmallInteger,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

JsonType = JSON().with_variant(JSONB(), "postgresql")


class Base(DeclarativeBase):
    pass


class MeasurementRaw(Base):
    __tablename__ = "measurements_raw"
    sensor_key: Mapped[str] = mapped_column(String(64), primary_key=True)
    observed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True)
    value: Mapped[float | None] = mapped_column(Float)
    quality: Mapped[int] = mapped_column(
        SmallInteger, default=0
    )  # 0 ok,1 stale,2 unavailable,3 unknown,4 derived,5 inconsistent

    __table_args__ = (Index("ix_measurements_raw_observed_at", "observed_at"),)


class Measurement1min(Base):
    __tablename__ = "measurements_1min"
    sensor_key: Mapped[str] = mapped_column(String(64), primary_key=True)
    bucket: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True)
    avg: Mapped[float | None] = mapped_column(Float)
    min: Mapped[float | None] = mapped_column(Float)
    max: Mapped[float | None] = mapped_column(Float)
    samples: Mapped[int] = mapped_column(Integer, default=0)


class LiveStateRow(Base):
    __tablename__ = "live_state"
    sensor_key: Mapped[str] = mapped_column(String(64), primary_key=True)
    value: Mapped[float | None] = mapped_column(Float)
    observed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    quality: Mapped[str] = mapped_column(String(16))
    source: Mapped[str] = mapped_column(String(128), default="")
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class ControlDecision(Base):
    __tablename__ = "control_decisions"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    controller_state: Mapped[str] = mapped_column(String(32))
    k1_release: Mapped[bool] = mapped_column(Boolean)
    k2_block: Mapped[bool] = mapped_column(Boolean)
    reasons: Mapped[list[str]] = mapped_column(JsonType)
    blocked_by: Mapped[list[str]] = mapped_column(JsonType)
    inputs: Mapped[dict[str, object]] = mapped_column(JsonType)
    valid_until: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    next_expected: Mapped[dict[str, object] | None] = mapped_column(JsonType, nullable=True)
    explanation_de: Mapped[str] = mapped_column(Text)


class ActuatorCommand(Base):
    __tablename__ = "actuator_commands"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    actuator_key: Mapped[str] = mapped_column(String(64))
    desired_state: Mapped[bool] = mapped_column(Boolean)
    ttl_s: Mapped[int | None] = mapped_column(Integer)
    decision_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("control_decisions.id"), nullable=True
    )
    status: Mapped[str] = mapped_column(
        String(16), default="queued"
    )  # queued, sent, acked, failed, expired
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    acked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    observed_state: Mapped[bool | None] = mapped_column(Boolean)
    error: Mapped[str | None] = mapped_column(Text)


class SystemEvent(Base):
    __tablename__ = "system_events"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    severity: Mapped[str] = mapped_column(String(8))
    code: Mapped[str] = mapped_column(String(64), index=True)
    message: Mapped[str] = mapped_column(Text)
    context: Mapped[dict[str, object]] = mapped_column(JsonType, default=dict)
    acknowledged_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class ConfigVersion(Base):
    __tablename__ = "config_versions"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_by: Mapped[str] = mapped_column(String(64), default="system")
    kind: Mapped[str] = mapped_column(
        String(16), index=True
    )  # site, control, comfort, dashboard, entities
    payload: Mapped[dict[str, object]] = mapped_column(JsonType)
    comment: Mapped[str | None] = mapped_column(Text)
    active: Mapped[bool] = mapped_column(Boolean, default=False, index=True)


class OperatingModeRow(Base):
    __tablename__ = "system_modes"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    system_mode: Mapped[str] = mapped_column(String(8))
    auto_profile: Mapped[str] = mapped_column(String(8))
    override: Mapped[dict[str, object] | None] = mapped_column(JsonType, nullable=True)
    set_by: Mapped[str] = mapped_column(String(64), default="dashboard")


class BridgeCredential(Base):
    __tablename__ = "bridge_credentials"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(String(64))
    token_hash: Mapped[str] = mapped_column(String(128), unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class BridgeSession(Base):
    __tablename__ = "bridge_sessions"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    bridge_id: Mapped[str] = mapped_column(String(64))
    connected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    disconnected_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    remote_version: Mapped[str] = mapped_column(String(32), default="")
    clock_offset_ms: Mapped[int] = mapped_column(Integer, default=0)
    frames_in: Mapped[int] = mapped_column(Integer, default=0)


class ForecastRun(Base):
    __tablename__ = "forecast_runs"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    kind: Mapped[str] = mapped_column(String(16), index=True)  # weather, pv, price
    provider: Mapped[str] = mapped_column(String(32))
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    horizon_start: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    horizon_end: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    resolution_min: Mapped[int] = mapped_column(Integer)
    params: Mapped[dict[str, object]] = mapped_column(JsonType, default=dict)


class ForecastPoint(Base):
    __tablename__ = "forecast_points"
    run_id: Mapped[UUID] = mapped_column(
        ForeignKey("forecast_runs.id", ondelete="CASCADE"), primary_key=True
    )
    ts: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True)
    variable: Mapped[str] = mapped_column(String(24), primary_key=True, default="value")
    value: Mapped[float | None] = mapped_column(Float)
    value_lo: Mapped[float | None] = mapped_column(Float)
    value_hi: Mapped[float | None] = mapped_column(Float)


class ModelCalibration(Base):
    """Gelernter Zustand eines Modells (z. B. PV-Bias-Korrektor) als ein JSON-Dokument je Modell."""

    __tablename__ = "model_calibrations"
    model: Mapped[str] = mapped_column(String(32), primary_key=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    state: Mapped[dict[str, object]] = mapped_column(JsonType, default=dict)


class EnergyHour(Base):
    """Energiebilanz je Stunde (Quellen, Verbraucher, Geld) – Grundlage der Detailseiten."""

    __tablename__ = "energy_hourly"
    hour_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True)
    minutes: Mapped[int] = mapped_column(Integer, default=0)
    price_missing_minutes: Mapped[int] = mapped_column(Integer, default=0)
    pv_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    import_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    export_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    battery_charge_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    battery_discharge_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    house_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    heat_pump_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    ev_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    base_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    pv_direct_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    battery_to_house_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    grid_to_house_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    pv_to_battery_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    grid_to_battery_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    heat_pump_pv_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    heat_pump_battery_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    heat_pump_grid_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    ev_pv_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    ev_battery_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    ev_grid_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    import_cost_eur: Mapped[float] = mapped_column(Float, default=0.0)
    export_revenue_eur: Mapped[float] = mapped_column(Float, default=0.0)
    heat_pump_cost_eur: Mapped[float] = mapped_column(Float, default=0.0)
    heat_pump_opportunity_eur: Mapped[float] = mapped_column(Float, default=0.0)
    ev_cost_eur: Mapped[float] = mapped_column(Float, default=0.0)
    ev_opportunity_eur: Mapped[float] = mapped_column(Float, default=0.0)
    battery_savings_eur: Mapped[float] = mapped_column(Float, default=0.0)
    pv_direct_savings_eur: Mapped[float] = mapped_column(Float, default=0.0)
    price_weighted_ct: Mapped[float] = mapped_column(Float, default=0.0)
    outdoor_temp_c: Mapped[float | None] = mapped_column(Float)  # Stundenmittel, für COP-Schätzung
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class TibberInvoice(Base):
    """Geprüfte Tibber-Rechnung. Die Rechnung selbst wird nicht gespeichert, nur die gelesenen Werte,
    die Befunde der Prüfung und eine Prüfsumme, damit dieselbe Datei nicht doppelt ausgewertet wird."""

    __tablename__ = "tibber_invoices"
    number: Mapped[str] = mapped_column(String(32), primary_key=True)
    issued_on: Mapped[date] = mapped_column(Date)
    period_start: Mapped[date] = mapped_column(Date)
    period_end: Mapped[date] = mapped_column(Date)
    period_label: Mapped[str] = mapped_column(String(32))
    kwh: Mapped[float] = mapped_column(Float)
    total_net_eur: Mapped[float] = mapped_column(Float)
    total_gross_eur: Mapped[float] = mapped_column(Float)
    avg_ct_kwh_gross: Mapped[float] = mapped_column(Float)
    verdict: Mapped[str] = mapped_column(String(16))  # ok | info | warning | error
    invoice: Mapped[dict[str, object]] = mapped_column(JsonType, default=dict)
    findings: Mapped[list[dict[str, object]]] = mapped_column(JsonType, default=list)
    file_sha256: Mapped[str] = mapped_column(String(64))
    file_name: Mapped[str | None] = mapped_column(String(255))
    uploaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    checked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    __table_args__ = (Index("ix_tibber_invoices_period_start", "period_start"),)


class KioskDevice(Base):
    __tablename__ = "kiosk_devices"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(String(64))
    paired_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    session_token_hash: Mapped[str] = mapped_column(String(128), unique=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
