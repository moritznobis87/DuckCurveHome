from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from hems_core.domain import Quality
from hems_core.protocol import (
    AckFrame,
    CommandFrame,
    HelloFrame,
    RawReading,
    TelemetryFrame,
    parse_frame,
)


def test_frames_roundtrip() -> None:
    now = datetime(2026, 9, 4, 12, 0, tzinfo=UTC)
    t = TelemetryFrame(
        seq=7,
        sent_at=now,
        items=[
            RawReading(
                key="pv_power_kw",
                value=5.2,
                observed_at=now,
                quality=Quality.OK,
                source="ha:sensor.pv",
            )
        ],
    )
    back = parse_frame(t.model_dump_json())
    assert isinstance(back, TelemetryFrame) and back.seq == 7 and back.items[0].value == 5.2
    h = parse_frame(
        HelloFrame(
            bridge_version="0.1",
            bridge_id="haus",
            clock=now,
            entity_map_hash="abc",
            keys=["pv_power_kw"],
        ).model_dump_json()
    )
    assert isinstance(h, HelloFrame) and h.protocol == 1
    c = parse_frame(
        CommandFrame(
            command_id=uuid4(), issued_at=now, actuator_key="coffee_machine", state=True, ttl_s=60
        ).model_dump_json()
    )
    assert isinstance(c, CommandFrame) and c.ttl_s == 60
    assert isinstance(parse_frame('{"type":"ack","seq":3}'), AckFrame)


def test_unknown_type_rejected() -> None:
    import pytest
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        parse_frame('{"type":"nope"}')
