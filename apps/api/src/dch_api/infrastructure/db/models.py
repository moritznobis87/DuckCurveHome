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


class MeasurementMinute(Base):
    """Minutenmittel aller Messreihen - das dauerhafte Gedächtnis der Anlage.

    Eine Zeile je Minute mit einer Spalte je Reihe, nicht eine Zeile je Messwert. Postgres schlägt pro
    Zeile rund 27 Byte Kopf auf; im schmalen Format (Schlüssel, Zeit, Wert) zahlt man den für jeden
    einzelnen Messwert, hier einmal für fünfzehn. Das ist der Unterschied zwischen ungefähr 9 GB und
    1 GB in zehn Jahren und der Grund, warum Minutenauflösung dauerhaft tragbar ist.

    Die Spalten entsprechen `infrastructure.history.SERIES`; ein Test hält beides zusammen. Reihen ohne
    eigene Spalte - weitere Aktoren, später ergänzte Sensoren - landen in `extra`, damit nichts
    stillschweigend verloren geht; sie können jederzeit zu Spalten befördert werden.

    Diese Tabelle wird nie gelöscht. Gelöscht werden nur die Rohwerte, aus denen sie entsteht.
    """

    __tablename__ = "measurements_minute"
    bucket: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True)
    pv_power_kw: Mapped[float | None] = mapped_column(Float)
    grid_power_kw: Mapped[float | None] = mapped_column(Float)
    battery_power_kw: Mapped[float | None] = mapped_column(Float)
    battery_soc: Mapped[float | None] = mapped_column(Float)
    house_power_kw: Mapped[float | None] = mapped_column(Float)
    base_load_kw: Mapped[float | None] = mapped_column(Float)
    heat_pump_power_kw: Mapped[float | None] = mapped_column(Float)
    ev_power_kw: Mapped[float | None] = mapped_column(Float)
    electricity_price_ct_kwh: Mapped[float | None] = mapped_column(Float)
    outdoor_temp_c: Mapped[float | None] = mapped_column(Float)
    buffer_temp_top_c: Mapped[float | None] = mapped_column(Float)
    buffer_temp_mid_top_c: Mapped[float | None] = mapped_column(Float)
    buffer_temp_mid_bottom_c: Mapped[float | None] = mapped_column(Float)
    buffer_temp_bottom_c: Mapped[float | None] = mapped_column(Float)
    hp_release_contact: Mapped[float | None] = mapped_column(Float)
    # Pelletofen. Eigene Spalten auch für Größen, die nicht jede Firmware füllt: eine leere
    # Spalte kostet in Postgres nur ein Bit in der NULL-Maske, eine zweite Migration mehr.
    stove_state: Mapped[float | None] = mapped_column(Float)
    stove_running: Mapped[float | None] = mapped_column(Float)
    stove_power_level: Mapped[float | None] = mapped_column(Float)
    stove_fume_temp_c: Mapped[float | None] = mapped_column(Float)
    stove_fume_fan_rpm: Mapped[float | None] = mapped_column(Float)
    stove_auger_rpm: Mapped[float | None] = mapped_column(Float)
    stove_boiler_temp_c: Mapped[float | None] = mapped_column(Float)
    stove_return_temp_c: Mapped[float | None] = mapped_column(Float)
    stove_buffer_temp_c: Mapped[float | None] = mapped_column(Float)
    stove_ambient_temp_c: Mapped[float | None] = mapped_column(Float)
    stove_pump_pct: Mapped[float | None] = mapped_column(Float)
    stove_dhw_mode: Mapped[float | None] = mapped_column(Float)
    stove_operating_hours: Mapped[float | None] = mapped_column(Float)
    stove_ignitions: Mapped[float | None] = mapped_column(Float)
    # Amtlicher Zähler (inexogy). Eigene Spalten neben `grid_power_kw`, nicht statt dessen: führend
    # bleibt der Stromwandler des Speichers, der Zähler läuft als unabhängige Beobachtung mit.
    grid_power_meter_kw: Mapped[float | None] = mapped_column(Float)
    grid_import_meter_kwh: Mapped[float | None] = mapped_column(Float)
    grid_export_meter_kwh: Mapped[float | None] = mapped_column(Float)
    # Erreichbarkeit des Türschlosses, 1 oder 0. Steht hier, weil die Verfügbarkeitskarte sie
    # zeigen soll: die Vermutung, die Strecke zum Schloss sei brüchig, wird damit nachprüfbar.
    door_lock_online: Mapped[float | None] = mapped_column(Float)
    extra: Mapped[dict[str, float] | None] = mapped_column(JsonType)


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
    """Energiebilanz je Stunde (Quellen, Verbraucher, Geld) - Grundlage der Detailseiten."""

    __tablename__ = "energy_hourly"
    hour_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True)
    minutes: Mapped[int] = mapped_column(Integer, default=0)
    # Minuten aus grober Eingangsauflösung (Stundenmittel eines Historienexports): die Summen
    # stimmen, die Aufteilung auf PV, Speicher und Netz ist dort geschätzt.
    coarse_minutes: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
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
    grid_to_battery_dark_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    battery_pv_to_house_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    battery_origin_estimated_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    # Bestand am Stundenende, kein Summand: Herkunftskonto des Speichers für die Folgestunde.
    battery_pv_stored_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    battery_grid_stored_kwh: Mapped[float] = mapped_column(Float, default=0.0)
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
    price_hours_ct: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    self_consumption_value_eur: Mapped[float] = mapped_column(Float, default=0.0)
    outdoor_temp_c: Mapped[float | None] = mapped_column(Float)  # Stundenmittel, für COP-Schätzung
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class HeatHour(Base):
    """Die Eingangsgrößen der Wärmebilanz je Stunde.

    **Eingänge, keine Ergebnisse.** Was das Modell daraus macht, entsteht beim Lesen; nur so erreicht
    eine geänderte Annahme auch die Vergangenheit. Die Tabelle ist klein: 8760 Zeilen im Jahr gegen
    525 000 Minutenzeilen, und genau das ist ihr Zweck - eine Jahresstatistik aus Minutenwerten ist
    keine Auswertung, sondern ein Ausfall.
    """

    __tablename__ = "heat_hours"
    hour_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True)
    minutes: Mapped[int] = mapped_column(Integer, default=0)
    electric_kwh: Mapped[float] = mapped_column(Float, default=0.0)
    outdoor_c: Mapped[float | None] = mapped_column(Float)
    buffer_top_c: Mapped[float | None] = mapped_column(Float)
    buffer_mean_c: Mapped[float | None] = mapped_column(Float)
    room_c: Mapped[float | None] = mapped_column(Float)
    buffer_kwh_end: Mapped[float | None] = mapped_column(Float)
    stove_minutes: Mapped[int] = mapped_column(Integer, default=0)
    stove_level_mean: Mapped[float | None] = mapped_column(Float)
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


class PushKey(Base):
    """Das VAPID-Schlüsselpaar des Dienstes. Genau eine Zeile.

    **Warum in der Datenbank und nicht in der Umgebung.** Ein privater Schlüssel ist ein Geheimnis;
    er darf weder ins Repository noch durch einen Chat. Der Dienst erzeugt ihn deshalb beim ersten
    Mal selbst und behält ihn hier. Niemand muss ihn jemals sehen, und es gibt keinen Weg, auf dem
    er versehentlich irgendwo landet.

    Geht die Zeile verloren, werden die bestehenden Abonnements ungültig: Ein Push-Dienst verknüpft
    sie mit dem öffentlichen Schlüssel, der sie angelegt hat. Das ist kein Schaden, der bleibt - die
    Geräte melden sich beim nächsten Besuch der Seite neu an.
    """

    __tablename__ = "push_keys"
    id: Mapped[int] = mapped_column(primary_key=True)
    private_key: Mapped[str] = mapped_column(String(128))  # base64url des rohen Skalars
    public_key: Mapped[str] = mapped_column(String(255))  # base64url des unkomprimierten Punktes
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class PushSubscription(Base):
    """Ein Gerät, das Mitteilungen bekommen möchte.

    Der Endpunkt ist die Adresse beim Push-Dienst des Browsers und zugleich der Schlüssel: Dasselbe
    Gerät, das sich zweimal anmeldet, soll nicht zweimal klingeln. `failures` zählt die Versuche
    seit der letzten Zustellung; ein Endpunkt, den der Dienst mit 404 oder 410 beantwortet, wird
    sofort gelöscht - dann gibt es das Gerät nicht mehr.
    """

    __tablename__ = "push_subscriptions"
    endpoint: Mapped[str] = mapped_column(String(512), primary_key=True)
    p256dh: Mapped[str] = mapped_column(String(255))
    auth: Mapped[str] = mapped_column(String(64))
    label: Mapped[str] = mapped_column(String(64), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    last_ok_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    failures: Mapped[int] = mapped_column(Integer, default=0)


class RoomShiftState(Base):
    """Was die Automatik in einem Raum angestellt hat - und worauf sie ihn zurückstellen muss.

    **Diese Zeile ist die Rückfahrkarte.** Hebt die Automatik einen Sollwert von 22,2 auf 22,7 an
    und geht der Dienst dabei unter, dann weiß ohne sie niemand mehr, dass 22,2 der Wert des
    Menschen war - und der Raum bliebe für immer einen halben Grad zu warm. Darum wird sie
    **vor** dem Stellen geschrieben, nicht danach.

    `written_setpoint_c` ist, was die Automatik zuletzt gestellt hat. Weicht der gemeldete Sollwert
    davon ab, hat jemand anders gedreht - in Controme, an der Wand, egal. Dann zieht sich die
    Automatik für diesen Raum zurück, statt dagegenzuhalten.
    """

    __tablename__ = "room_shift_states"
    room_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    base_setpoint_c: Mapped[float] = mapped_column(Float)
    offset_k: Mapped[float] = mapped_column(Float, default=0.0)
    written_setpoint_c: Mapped[float] = mapped_column(Float)
    written_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    phase: Mapped[str] = mapped_column(String(16), default="aus")
    until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    paused_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
