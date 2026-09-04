"""Live-Modus Ende-zu-Ende: Bridge verbindet sich per WebSocket, sendet Telemetrie, Dashboard sieht sie."""

from __future__ import annotations

import json
from collections.abc import Iterator
from datetime import UTC, datetime
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from dch_api.main import create_app
from dch_api.settings import Settings
from hems_core.protocol import HelloFrame, RawReading, TelemetryFrame


@pytest.fixture
def live_client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'live.sqlite'}",
        db_create_all=True,
        bridge_tokens=["geheim"],
        api_token="api-geheim",
        weather_refresh_min=0,
        role="api",
    )
    app = create_app(settings)
    with TestClient(app) as c:
        yield c


def hello() -> str:
    return HelloFrame(
        bridge_version="t",
        bridge_id="haus",
        clock=datetime.now(UTC),
        entity_map_hash="x",
        keys=["pv_power_kw"],
    ).model_dump_json()


def test_bridge_requires_token(live_client: TestClient) -> None:
    from starlette.websockets import WebSocketDisconnect

    with pytest.raises(WebSocketDisconnect), live_client.websocket_connect("/bridge/ws"):
        pass


def test_api_requires_token(live_client: TestClient) -> None:
    assert live_client.get("/api/v1/live/state").status_code == 401
    assert (
        live_client.get(
            "/api/v1/live/state", headers={"authorization": "Bearer api-geheim"}
        ).status_code
        == 200
    )
    assert live_client.get("/health").status_code == 200


def test_bridge_telemetry_reaches_live_state(live_client: TestClient) -> None:
    now = datetime.now(UTC)
    with live_client.websocket_connect(
        "/bridge/ws", headers={"authorization": "Bearer geheim"}
    ) as ws:
        ws.send_text(hello())
        welcome = json.loads(ws.receive_text())
        assert welcome["type"] == "welcome" and welcome["resume_from_seq"] == 1
        frame = TelemetryFrame(
            seq=1,
            sent_at=now,
            items=[
                RawReading(key="pv_power_kw", value=5.5, observed_at=now, source="ha:pv"),
                RawReading(key="grid_power_kw", value=-2.0, observed_at=now, source="ha:grid"),
                RawReading(key="battery_power_kw", value=0.0, observed_at=now, source="ha:bat"),
                RawReading(key="heat_pump_power_kw", value=0.0, observed_at=now, source="ha:hp"),
                RawReading(key="ev_power_kw", value=0.0, observed_at=now, source="ha:ev"),
                RawReading(
                    key="actuator:coffee_machine", value=1.0, observed_at=now, source="ha:c"
                ),
            ],
        )
        ws.send_text(frame.model_dump_json())
        ack = json.loads(ws.receive_text())
        assert ack == {"type": "ack", "seq": 1}
        state = live_client.get(
            "/api/v1/live/state", headers={"authorization": "Bearer api-geheim"}
        ).json()
        assert state["snapshot"]["pv_power_kw"]["value"] == 5.5
        assert state["snapshot"]["house_power_kw"]["value"] == 3.5
        assert state["snapshot"]["actuators"]["coffee_machine"]["value"] == 1.0
        assert state["system"]["mode"] == "live" and state["system"]["bridge_online"] is True
        # Steuerung ist in Phase 2 deaktiviert
        r = live_client.post(
            "/api/v1/control/actuators/coffee_machine",
            json={"state": False},
            headers={"authorization": "Bearer api-geheim"},
        )
        assert (
            r.status_code == 200
            and r.json()["ok"] is False
            and "deaktiviert" in r.json()["message_de"]
        )
    hist = live_client.get(
        "/api/v1/history", params={"range": "24h"}, headers={"authorization": "Bearer api-geheim"}
    ).json()
    assert any(row["pv_power_kw"] == 5.5 for row in hist["rows"])
