"""Der Wächter am lebenden Dienst: Eine alte Meldung wird zu einem Befund im Zustand.

Der Fall vom 23.10.2026 in klein: Die Brücke hängt, die Verbindung steht, aber die Werte sind von
vorgestern. Genau diese Lage soll der Zustand benennen und nicht nur „bridge_online: true".
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from dch_api.main import create_app
from dch_api.settings import Settings
from hems_core.protocol import HelloFrame, RawReading, TelemetryFrame

KOPF = {"authorization": "Bearer api-geheim"}
PUFFER = (
    "buffer_temp_top_c",
    "buffer_temp_mid_top_c",
    "buffer_temp_mid_bottom_c",
    "buffer_temp_bottom_c",
)


@pytest.fixture
def client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'watch.sqlite'}",
        db_create_all=True,
        bridge_tokens=["geheim"],
        api_token="api-geheim",
        weather_refresh_min=0,
        role="api",
    )
    with TestClient(create_app(settings)) as c:
        yield c


def hello() -> str:
    return HelloFrame(
        bridge_version="t",
        bridge_id="haus",
        clock=datetime.now(UTC),
        entity_map_hash="x",
        keys=list(PUFFER),
    ).model_dump_json()


def telemetrie(seq: int, beobachtet: datetime) -> str:
    return TelemetryFrame(
        seq=seq,
        sent_at=datetime.now(UTC),
        items=[
            RawReading(key=k, value=50.0, observed_at=beobachtet, source="ha:puffer")
            for k in PUFFER
        ],
    ).model_dump_json()


def befunde(client: TestClient) -> dict[str, dict[str, object]]:
    state = client.get("/api/v1/live/state", headers=KOPF).json()
    return {b["name"]: b for b in state["system"]["watch"]}


def test_alte_puffertemperaturen_werden_gemeldet(client: TestClient) -> None:
    jetzt = datetime.now(UTC)
    with client.websocket_connect("/bridge/ws", headers={"authorization": "Bearer geheim"}) as ws:
        ws.send_text(hello())
        json.loads(ws.receive_text())
        ws.send_text(telemetrie(1, jetzt - timedelta(hours=3)))
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 1}

        offen = befunde(client)
        assert "buffer" in offen
        assert "Ladezustand" in str(offen["buffer"]["text_de"])
        assert offen["buffer"]["severity"] == "alarm"
        # Die Verbindung steht: Genau darum reicht „bridge_online" als Auskunft nicht.
        state = client.get("/api/v1/live/state", headers=KOPF).json()
        assert state["system"]["bridge_online"] is True

        # Frische Werte, und der Befund ist weg.
        ws.send_text(telemetrie(2, datetime.now(UTC)))
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 2}
        assert "buffer" not in befunde(client)


def test_eine_quelle_die_es_nie_gab_wird_nicht_gemeldet(client: TestClient) -> None:
    """Kein Strompreis eingerichtet heißt nicht: Strompreis ausgefallen."""
    with client.websocket_connect("/bridge/ws", headers={"authorization": "Bearer geheim"}) as ws:
        ws.send_text(hello())
        json.loads(ws.receive_text())
        ws.send_text(telemetrie(1, datetime.now(UTC)))
        json.loads(ws.receive_text())
        assert "price" not in befunde(client)
