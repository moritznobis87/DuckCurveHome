"""Der Endpunkt `/anlage`: das Schema im Augenblick, aus der Vorführung und aus der Brücke."""

from __future__ import annotations

import json
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from dch_api.application import anlage as logik
from dch_api.application import demo_rooms
from dch_api.main import create_app
from dch_api.settings import Settings
from hems_core.protocol import HelloFrame, RawReading, TelemetryFrame

KOPF = {"authorization": "Bearer api-geheim"}


@pytest.fixture
def live_client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'anlage.sqlite'}",
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
        keys=["buffer_temp_top_c"],
    ).model_dump_json()


def _telemetrie(seq: int, beobachtet: datetime, werte: dict[str, float]) -> str:
    return TelemetryFrame(
        seq=seq,
        sent_at=datetime.now(UTC),
        items=[
            RawReading(key=k, value=v, observed_at=beobachtet, source="test")
            for k, v in werte.items()
        ],
    ).model_dump_json()


# ------------------------------------------------------------------ Vorführung


def test_die_vorfuehrung_liefert_das_ganze_schema(client: TestClient) -> None:
    antwort = client.get("/api/v1/anlage")
    assert antwort.status_code == 200
    a = antwort.json()

    assert len(a["speicher"]["temps_c"]) == 4
    assert all(t is not None for t in a["speicher"]["temps_c"])
    # Die Vorführung hat 26 Stunden Geschichte: die Nettoleistung lässt sich bilden.
    assert a["speicher"]["net_kw"] is not None
    assert a["speicher"]["net_word"] in ("lädt", "entlädt", "hält")
    assert a["speicher"]["return_c"] == a["speicher"]["temps_c"][3]

    assert a["heizkreis"]["rooms_total"] == len(demo_rooms.ROOMS)
    assert 0 <= a["heizkreis"]["rooms_open"] <= a["heizkreis"]["rooms_total"]

    # Was die Vorführung nicht hat, sagt sie auch nicht.
    assert a["ofen"]["present"] is False
    assert a["warmwasser"]["present"] is False and a["warmwasser"]["tapping"] is None
    assert a["waermepumpe"]["thermal_kw"] is None and a["waermepumpe"]["cop"] is None

    anteile = a["strom"]["share_pv"] + a["strom"]["share_grid"] + a["strom"]["share_battery"]
    assert anteile == pytest.approx(1.0, abs=0.01) or anteile == 0.0


# ------------------------------------------------------------------ Brücke


def test_nettoleistung_und_zapfung_aus_der_minutenreihe(live_client: TestClient) -> None:
    now = datetime.now(UTC).replace(second=0, microsecond=0)
    with live_client.websocket_connect(
        "/bridge/ws", headers={"authorization": "Bearer geheim"}
    ) as ws:
        ws.send_text(_hello())
        assert json.loads(ws.receive_text())["type"] == "welcome"
        # Der Speicher wird über 16 Minuten in allen Schichten um zwei Kelvin wärmer: er lädt.
        # Der Auslass ruht bei 22 °C und springt vor drei Minuten auf: eine Zapfung.
        verlauf = [
            (16, 40.0, None),
            (10, 40.8, None),
            (5, 41.4, 22.0),
            (4, 41.5, 22.0),
            (3, 41.6, 22.0),
            (2, 41.8, 44.0),
            (1, 42.0, 46.0),
        ]
        for seq, (vor, puffer, auslass) in enumerate(verlauf, start=1):
            werte = {k: puffer for k in logik.BUFFER_KEYS}
            if auslass is not None:
                werte[logik.DHW_OUTLET] = auslass
            ws.send_text(_telemetrie(seq, now - timedelta(minutes=vor), werte))
            assert json.loads(ws.receive_text()) == {"type": "ack", "seq": seq}

        a = live_client.get("/api/v1/anlage", headers=KOPF).json()

    assert a["speicher"]["net_kw"] is not None and a["speicher"]["net_kw"] > 0
    assert a["speicher"]["net_word"] == "lädt"
    assert a["speicher"]["temps_c"] == [42.0] * 4

    ww = a["warmwasser"]
    assert ww["present"] is True and ww["outlet_c"] == 46.0
    assert ww["tapping"] is True
    seit = datetime.fromisoformat(ww["tapping_since"].replace("Z", "+00:00"))
    assert seit == now - timedelta(minutes=3)

    # Kein Raum gemeldet, kein Ofen angebunden: beides steht so da, nicht als Null.
    assert a["heizkreis"]["rooms_total"] == 0 and a["heizkreis"]["running"] is False
    assert a["ofen"]["present"] is True and a["ofen"]["running"] is None


def test_ohne_geschichte_keine_nettoleistung(live_client: TestClient) -> None:
    now = datetime.now(UTC)
    with live_client.websocket_connect(
        "/bridge/ws", headers={"authorization": "Bearer geheim"}
    ) as ws:
        ws.send_text(_hello())
        ws.receive_text()
        ws.send_text(_telemetrie(1, now, {k: 45.0 for k in logik.BUFFER_KEYS}))
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 1}
        a = live_client.get("/api/v1/anlage", headers=KOPF).json()
    # Eine einzige Minute ist keine Änderung. Null wäre eine Behauptung, also steht hier nichts.
    assert a["speicher"]["net_kw"] is None and a["speicher"]["net_word"] == ""
