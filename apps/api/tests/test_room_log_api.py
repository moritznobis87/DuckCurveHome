"""Der Endpunkt `/rooms/{id}/log`: Zeitreihe und Zeitleiste eines Raums.

Die Raumnamen hier sind erfunden. Das Repository ist öffentlich.
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
from hems_core.protocol import EventFrame, HelloFrame, RawReading, TelemetryFrame

KOPF = {"authorization": "Bearer api-geheim"}


@pytest.fixture
def live_client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'roomlog.sqlite'}",
        db_create_all=True,
        bridge_tokens=["geheim"],
        api_token="api-geheim",
        weather_refresh_min=0,
        role="api",
    )
    with TestClient(create_app(settings)) as c:
        yield c


def _hello() -> str:
    return HelloFrame(
        bridge_version="t",
        bridge_id="haus",
        clock=datetime.now(UTC),
        entity_map_hash="x",
        keys=["room_1_temp_c"],
    ).model_dump_json()


def _telemetrie(seq: int, beobachtet: datetime, werte: dict[str, float | None]) -> str:
    return TelemetryFrame(
        seq=seq,
        sent_at=datetime.now(UTC),
        items=[
            RawReading(key=k, value=v, observed_at=beobachtet, source="controme")
            for k, v in werte.items()
        ],
    ).model_dump_json()


def _raumliste() -> str:
    return EventFrame(
        at=datetime.now(UTC),
        severity="info",
        code="rooms.list",
        message="1 Raum",
        context={
            "raum.1.name": "Nordzimmer",
            "raum.1.etage": "Obergeschoss",
            "raum.1.kreise": "2",
            "raum.1.rang": "0",
        },
    ).model_dump_json()


def test_ein_sollwertsprung_ohne_ereignis_steht_als_extern_im_protokoll(
    live_client: TestClient,
) -> None:
    now = datetime.now(UTC)
    with live_client.websocket_connect(
        "/bridge/ws", headers={"authorization": "Bearer geheim"}
    ) as ws:
        ws.send_text(_hello())
        assert json.loads(ws.receive_text())["type"] == "welcome"
        ws.send_text(_raumliste())
        # Zwei verschiedene Minuten: in derselben Minute wären beide Werte ein Mittel, und ein
        # Mittel aus 21 und 22 wäre ein Sollwert, auf dem die Anlage nie stand.
        ws.send_text(
            _telemetrie(
                1,
                now - timedelta(minutes=4),
                {"room_1_temp_c": 20.5, "room_1_setpoint_c": 21.0, "room_1_valve": 1.0},
            )
        )
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 1}
        ws.send_text(
            _telemetrie(
                2,
                now - timedelta(minutes=1),
                {"room_1_temp_c": 20.9, "room_1_setpoint_c": 22.5, "room_1_valve": 1.0},
            )
        )
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 2}

        antwort = live_client.get(
            "/api/v1/rooms/1/log?hours=2&step_min=5", headers=KOPF
        ).json()

    assert antwort["room"]["name"] == "Nordzimmer"
    assert antwort["step_min"] == 5
    assert len(antwort["ts"]) == len(antwort["room"]["temp_c"]) == len(antwort["target_c"])

    eintraege = antwort["entries"]
    assert len(eintraege) == 1
    assert eintraege[0]["quelle"] == "extern"
    assert eintraege[0]["art"] == "sollwert"
    assert eintraege[0]["from_c"] == 21.0
    assert eintraege[0]["to_c"] == 22.5
    # Keine Begründung, und das ist die Aussage: Dieses Werkzeug war es nicht.
    assert eintraege[0]["text"] == ""


def test_der_zielwert_steht_neben_der_kurve(live_client: TestClient) -> None:
    now = datetime.now(UTC)
    with live_client.websocket_connect(
        "/bridge/ws", headers={"authorization": "Bearer geheim"}
    ) as ws:
        ws.send_text(_hello())
        ws.receive_text()
        ws.send_text(_raumliste())
        ws.send_text(
            _telemetrie(
                1,
                now - timedelta(minutes=2),
                {"room_1_setpoint_c": 21.0, "room_1_offset_k": -0.3},
            )
        )
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 1}
        antwort = live_client.get("/api/v1/rooms/1/log?hours=1&step_min=5", headers=KOPF).json()

    # Geregelt wird auf Soll plus Offset. 21,0 - 0,3 = 20,7.
    assert 20.7 in [w for w in antwort["target_c"] if w is not None]


def test_ein_unbekannter_raum_hat_kein_protokoll(live_client: TestClient) -> None:
    assert live_client.get("/api/v1/rooms/99/log", headers=KOPF).status_code == 404


def test_eine_unzulaessige_fensterbreite_wird_abgewiesen(live_client: TestClient) -> None:
    assert live_client.get("/api/v1/rooms/1/log?step_min=7", headers=KOPF).status_code == 422


def test_mehr_als_achtundvierzig_stunden_gibt_es_nicht(live_client: TestClient) -> None:
    assert live_client.get("/api/v1/rooms/1/log?hours=72", headers=KOPF).status_code == 422


def test_die_vorfuehrung_schreibt_mit_wer_gestellt_hat(client: TestClient) -> None:
    raeume = client.get("/api/v1/rooms", headers=KOPF).json()["rooms"]
    rid = raeume[0]["id"]
    client.post(f"/api/v1/rooms/{rid}/setpoint", json={"setpoint_c": 22.0}, headers=KOPF)
    antwort = client.get(f"/api/v1/rooms/{rid}/log?hours=2&step_min=5", headers=KOPF).json()
    eigene = [e for e in antwort["entries"] if e["quelle"] == "app"]
    assert len(eigene) == 1
    assert eigene[0]["to_c"] == 22.0
    assert eigene[0]["art"] == "sollwert"
