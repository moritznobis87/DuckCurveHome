"""Bridge gegen einen simulierten Home-Assistant-WebSocket und einen simulierten API-Uplink."""

from __future__ import annotations

import asyncio
import json
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
import websockets
from websockets.asyncio.server import ServerConnection, serve

from dch_bridge.home_assistant.ws_client import HaWsClient
from dch_bridge.outbox import Outbox
from dch_bridge.uplink.client import UplinkClient
from hems_core.protocol import (
    AckFrame,
    CommandFrame,
    CommandResultFrame,
    RawReading,
    WelcomeFrame,
    parse_frame,
)


async def fake_ha(ws: ServerConnection) -> None:
    await ws.send(json.dumps({"type": "auth_required", "ha_version": "2026.9"}))
    auth = json.loads(await ws.recv())
    if auth.get("access_token") != "llat":
        await ws.send(json.dumps({"type": "auth_invalid", "message": "falsch"}))
        return
    await ws.send(json.dumps({"type": "auth_ok", "ha_version": "2026.9"}))
    async for raw in ws:
        msg = json.loads(raw)
        if msg["type"] == "get_states":
            await ws.send(
                json.dumps(
                    {
                        "id": msg["id"],
                        "type": "result",
                        "success": True,
                        "result": [
                            {
                                "entity_id": "sensor.pv",
                                "state": "5200",
                                "attributes": {"unit_of_measurement": "W"},
                                "last_updated": "2026-09-04T12:00:00+00:00",
                            },
                            {
                                "entity_id": "switch.coffee",
                                "state": "off",
                                "attributes": {},
                                "last_updated": "2026-09-04T12:00:00+00:00",
                            },
                        ],
                    }
                )
            )
        elif msg["type"] == "subscribe_events":
            await ws.send(
                json.dumps({"id": msg["id"], "type": "result", "success": True, "result": None})
            )
            await ws.send(
                json.dumps(
                    {
                        "id": msg["id"],
                        "type": "event",
                        "event": {
                            "event_type": "state_changed",
                            "data": {
                                "entity_id": "sensor.pv",
                                "new_state": {
                                    "entity_id": "sensor.pv",
                                    "state": "6100",
                                    "attributes": {},
                                    "last_updated": "2026-09-04T12:00:05+00:00",
                                },
                            },
                        },
                    }
                )
            )
        elif msg["type"] == "call_service":
            assert msg["service"] == "turn_on" and msg["target"]["entity_id"] == "switch.coffee"
            await ws.send(
                json.dumps({"id": msg["id"], "type": "result", "success": True, "result": {}})
            )
            await ws.send(
                json.dumps(
                    {
                        "id": 999,
                        "type": "event",
                        "event": {
                            "event_type": "state_changed",
                            "data": {
                                "entity_id": "switch.coffee",
                                "new_state": {
                                    "entity_id": "switch.coffee",
                                    "state": "on",
                                    "attributes": {},
                                    "last_updated": "2026-09-04T12:00:06+00:00",
                                },
                            },
                        },
                    }
                )
            )


async def test_ha_client_auth_states_events_and_service() -> None:
    async with serve(fake_ha, "127.0.0.1", 0) as server:
        port = server.sockets[0].getsockname()[1]  # type: ignore[index]
        client = HaWsClient(f"ws://127.0.0.1:{port}", "llat", {"sensor.pv", "switch.coffee"})
        await client.connect()
        states = await client.get_states()
        assert {s.entity_id for s in states} == {"sensor.pv", "switch.coffee"}
        await client.subscribe_state_changes()
        events = client.events()
        first = await asyncio.wait_for(anext(events), 5)
        assert first.entity_id == "sensor.pv" and first.state == "6100"
        await client.call_service("switch", "turn_on", "switch.coffee")
        second = await asyncio.wait_for(anext(events), 5)
        assert second.entity_id == "switch.coffee" and second.state == "on"
        await client.close()


async def test_ha_client_rejects_bad_token() -> None:
    async with serve(fake_ha, "127.0.0.1", 0) as server:
        port = server.sockets[0].getsockname()[1]  # type: ignore[index]
        client = HaWsClient(f"ws://127.0.0.1:{port}", "falsch")
        with pytest.raises(RuntimeError):
            await client.connect()


async def test_uplink_hello_telemetry_ack_and_command(tmp_path: Path) -> None:
    received: dict[str, Any] = {"telemetry": [], "results": [], "hello": None}
    done = asyncio.Event()

    async def fake_api(ws: ServerConnection) -> None:
        assert ws.request is not None and ws.request.headers.get("authorization") == "Bearer geheim"
        hello = parse_frame(await ws.recv())
        received["hello"] = hello
        await ws.send(
            WelcomeFrame(
                server_time=datetime.now(UTC), server_version="t", resume_from_seq=1
            ).model_dump_json()
        )
        async for raw in ws:
            frame = parse_frame(raw)
            if frame.type in ("telemetry", "backlog"):
                received["telemetry"].append(frame)
                await ws.send(AckFrame(seq=frame.seq).model_dump_json())  # type: ignore[union-attr]
                if len(received["telemetry"]) == 2:
                    await ws.send(
                        CommandFrame(
                            command_id=__import__("uuid").uuid4(),
                            issued_at=datetime.now(UTC),
                            actuator_key="coffee_machine",
                            state=True,
                            ttl_s=60,
                        ).model_dump_json()
                    )
            elif frame.type == "command_result":
                received["results"].append(frame)
                done.set()

    async def on_command(cmd: CommandFrame) -> CommandResultFrame:
        return CommandResultFrame(
            command_id=cmd.command_id, ok=True, observed_state=True, at=datetime.now(UTC)
        )

    outbox = Outbox(tmp_path / "o.sqlite", timedelta(hours=1))
    # Vorab ein Frame im Backlog (Verbindung war weg)
    outbox.put(
        1,
        {
            "seq": 1,
            "items": [
                {
                    "key": "pv_power_kw",
                    "value": 1.0,
                    "observed_at": "2026-09-04T12:00:00Z",
                    "quality": "ok",
                    "source": "t",
                }
            ],
        },
    )
    async with serve(fake_api, "127.0.0.1", 0) as server:
        port = server.sockets[0].getsockname()[1]  # type: ignore[index]
        up = UplinkClient(
            f"ws://127.0.0.1:{port}",
            "geheim",
            "haus",
            "t",
            "hash",
            ["pv_power_kw"],
            outbox,
            on_command,
        )
        task = asyncio.create_task(up.run())
        for _ in range(50):
            if up.connected:
                break
            await asyncio.sleep(0.1)
        assert up.connected
        await asyncio.sleep(0.3)  # Backlog wird gesendet
        await up.publish(
            [RawReading(key="pv_power_kw", value=2.0, observed_at=datetime.now(UTC), source="t")]
        )
        await asyncio.wait_for(done.wait(), 5)
        up.stop()
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task
    assert received["hello"] is not None and received["hello"].bridge_id == "haus"
    kinds = [f.type for f in received["telemetry"]]
    assert kinds == ["backlog", "telemetry"]
    assert received["results"][0].ok is True
    assert outbox.count() == 0  # alles bestätigt
    outbox.close()
    assert websockets  # verwendet
