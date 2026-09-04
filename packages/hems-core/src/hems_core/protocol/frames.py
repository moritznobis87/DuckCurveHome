"""Frames des Bridge-Protokolls (Plan Abschnitt 17.2).

Richtung Bridge → API: hello, telemetry, backlog, command_result, heartbeat, device_health, event
Richtung API → Bridge: welcome, ack, command, heartbeat
Alle Zeitstempel UTC. Werte sind bereits in der Domänenkonvention (kW, °C, ct/kWh, 0–1, 0/1).
"""

from __future__ import annotations

from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, TypeAdapter

from hems_core.domain.quality import Quality

PROTOCOL_VERSION = 1


class RawReading(BaseModel):
    model_config = ConfigDict(frozen=True)

    key: str  # Domänenschlüssel, z. B. pv_power_kw, buffer_temp_top_c, actuator:coffee_machine
    value: float | None
    observed_at: datetime
    quality: Quality = Quality.OK
    source: str = ""


class HelloFrame(BaseModel):
    type: Literal["hello"] = "hello"
    protocol: int = PROTOCOL_VERSION
    bridge_version: str
    bridge_id: str
    clock: datetime
    entity_map_hash: str
    keys: list[str]  # gelieferte Schlüssel (Sensoren und Aktoren)
    last_acked_seq: int = 0


class WelcomeFrame(BaseModel):
    type: Literal["welcome"] = "welcome"
    protocol: int = PROTOCOL_VERSION
    server_time: datetime
    server_version: str
    resume_from_seq: int  # ab dieser Sequenz erwartet der Server Telemetrie
    heartbeat_s: int = 15


class TelemetryFrame(BaseModel):
    type: Literal["telemetry"] = "telemetry"
    seq: int
    sent_at: datetime
    items: list[RawReading]


class BacklogFrame(BaseModel):
    type: Literal["backlog"] = "backlog"
    seq: int
    items: list[RawReading]
    remaining: int  # noch nicht gesendete Backlog-Frames


class AckFrame(BaseModel):
    type: Literal["ack"] = "ack"
    seq: int


class CommandFrame(BaseModel):
    type: Literal["command"] = "command"
    command_id: UUID
    issued_at: datetime
    actuator_key: str
    state: bool
    ttl_s: int | None = None
    decision_id: UUID | None = None


class CommandResultFrame(BaseModel):
    type: Literal["command_result"] = "command_result"
    command_id: UUID
    ok: bool
    observed_state: bool | None
    error: str | None = None
    at: datetime


class HeartbeatFrame(BaseModel):
    type: Literal["heartbeat"] = "heartbeat"
    at: datetime


class DeviceHealthFrame(BaseModel):
    type: Literal["device_health"] = "device_health"
    at: datetime
    source: str  # z. B. home_assistant
    status: Literal["ok", "degraded", "down"]
    details: dict[str, str] = Field(default_factory=dict)


class EventFrame(BaseModel):
    type: Literal["event"] = "event"
    at: datetime
    severity: Literal["info", "warning", "error"]
    code: str
    message: str
    context: dict[str, str] = Field(default_factory=dict)


Frame = Annotated[
    HelloFrame
    | WelcomeFrame
    | TelemetryFrame
    | BacklogFrame
    | AckFrame
    | CommandFrame
    | CommandResultFrame
    | HeartbeatFrame
    | DeviceHealthFrame
    | EventFrame,
    Field(discriminator="type"),
]

_adapter: TypeAdapter[Frame] = TypeAdapter(Frame)


def parse_frame(raw: str | bytes) -> Frame:
    return _adapter.validate_json(raw)
