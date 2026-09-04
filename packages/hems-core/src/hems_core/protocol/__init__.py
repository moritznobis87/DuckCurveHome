"""Bridge-Protokoll: Frames zwischen Bridge (Haus) und API (Cloud). Reines Pydantic, keine I/O."""

from hems_core.protocol.frames import (
    AckFrame,
    BacklogFrame,
    CommandFrame,
    CommandResultFrame,
    DeviceHealthFrame,
    EventFrame,
    Frame,
    HeartbeatFrame,
    HelloFrame,
    RawReading,
    TelemetryFrame,
    WelcomeFrame,
    parse_frame,
)

__all__ = [
    "AckFrame",
    "BacklogFrame",
    "CommandFrame",
    "CommandResultFrame",
    "DeviceHealthFrame",
    "EventFrame",
    "Frame",
    "HeartbeatFrame",
    "HelloFrame",
    "RawReading",
    "TelemetryFrame",
    "WelcomeFrame",
    "parse_frame",
]
