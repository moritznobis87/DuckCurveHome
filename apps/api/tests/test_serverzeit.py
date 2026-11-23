"""`system.server_time` ist die Uhr des Dienstes - nicht das Alter seiner jüngsten Messung.

**Der Fall vom 22.11.2026.** Ein Foto der Wandanzeige zeigt in der großen Uhr 22:04, während die
Statusleiste desselben iPads 22:07 zeigt; oben rechts stand LIVE. Die App stellt ihre Uhr auf
`system.server_time` (`Hauszustand.setzeVersatz`), also trägt jede Minute, die dieses Feld daneben
liegt, die Wandanzeige um dieselbe Minute mit - bei sonst unauffälligen Zahlen.

Im Live-Betrieb war das Feld schon richtig: `live_state()` schrieb `snap.timestamp`, und
`LiveState.snapshot(now)` setzt `timestamp=now` aus derselben Uhr - wertgleich (gemessen 0,0 s bei
einer 600 s alten jüngsten Messung), aber nur, solange niemand die Momentaufnahme in ein Feld legt.
Der Vorführbetrieb tut das (`demo_runner.snapshot`); dort geht es gut, weil seine Uhr nur im
Schritt weiterläuft und die Aufnahme im gleichen Schritt erneuert wird (gemessen 0,0 s bei
`sim_speed=60`). Diese Prüfung hält die Richtung fest, in der die Kopplung im Live-Betrieb nicht
entstehen darf: Die Uhr darf an keinem Messzeitpunkt hängen - weder am ältesten Fühlerwert noch an
einer vorgehaltenen Aufnahme.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from dch_api.infrastructure.live_state import LiveState
from dch_api.main import create_app
from dch_api.settings import Settings
from hems_core.domain import EnergySnapshot
from hems_core.protocol import HelloFrame, RawReading, TelemetryFrame

KOPF = {"authorization": "Bearer api-geheim"}


@pytest.fixture
def client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'zeit.sqlite'}",
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
        keys=["grid_power_kw"],
    ).model_dump_json()


def telemetrie(seq: int, beobachtet: datetime) -> str:
    return TelemetryFrame(
        seq=seq,
        sent_at=datetime.now(UTC),
        items=[
            RawReading(
                key="grid_power_kw", value=0.4, observed_at=beobachtet, source="ha:hausanschluss"
            )
        ],
    ).model_dump_json()


def zeit(roh: str) -> datetime:
    return datetime.fromisoformat(roh)


def test_eine_zehn_minuten_alte_messung_laesst_die_uhr_nicht_nachgehen(
    client: TestClient,
) -> None:
    """Der Bestand schweigt seit zehn Minuten; die Uhr ist trotzdem jetzt.

    Die Altersangaben stehen woanders: `observed_at` am Messwert (das die App über
    `Messwert.alter` liest) und `snapshot.timestamp`. Diese Prüfung hält beide Rollen
    auseinander - sonst zeigt die Wandanzeige das Alter der Messung als Uhrzeit.
    """
    messung = datetime.now(UTC) - timedelta(minutes=10)
    with client.websocket_connect("/bridge/ws", headers={"authorization": "Bearer geheim"}) as ws:
        ws.send_text(hello())
        json.loads(ws.receive_text())
        ws.send_text(telemetrie(1, messung))
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 1}

        vorher = datetime.now(UTC)
        zustand = client.get("/api/v1/live/state", headers=KOPF).json()
        nachher = datetime.now(UTC)

    serverzeit = zeit(zustand["system"]["server_time"])
    assert vorher <= serverzeit <= nachher, (
        f"server_time {serverzeit.isoformat()} liegt nicht in der Dauer der Anfrage "
        f"({vorher.isoformat()} bis {nachher.isoformat()})"
    )

    # Die Aufnahme trägt dieselbe Uhr: Im Live-Betrieb baut `_states` sie aus eben diesem `now`.
    # Damit ist festgehalten, worauf sich der Vorführbetrieb nicht verlassen darf.
    assert zeit(zustand["snapshot"]["timestamp"]) == serverzeit

    # Das Alter der Messung geht dabei nicht verloren - es steht, wo es hingehört.
    netz = zustand["snapshot"]["grid_power_kw"]
    assert abs((zeit(netz["observed_at"]) - messung).total_seconds()) < 1.0
    assert netz["quality"] == "stale"
    assert (serverzeit - zeit(netz["observed_at"])).total_seconds() > 590.0


def test_eine_gepufferte_momentaufnahme_zieht_die_uhr_nicht_mit(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Die Uhr darf nicht an der Aufnahme hängen, auch wenn die beiden heute gleich sind.

    Hier hinkt `snapshot.timestamp` absichtlich drei Minuten nach: genau der Abstand vom Foto
    (22:04 in der großen Uhr gegen 22:07 in der Statusleiste). Vor dem 22.11.2026 las
    `live_state()` seine Uhr aus eben diesem Feld; die Prüfung fällt, sobald das wieder geschieht.
    """
    live: LiveState = client.app.state.runner.live  # type: ignore[attr-defined]
    echte_aufnahme = live.snapshot

    def nachhinkend(now: datetime | None = None) -> EnergySnapshot:
        snap = echte_aufnahme(now)
        return snap.model_copy(update={"timestamp": snap.timestamp - timedelta(minutes=3)})

    monkeypatch.setattr(live, "snapshot", nachhinkend)

    vorher = datetime.now(UTC)
    zustand = client.get("/api/v1/live/state", headers=KOPF).json()
    nachher = datetime.now(UTC)

    serverzeit = zeit(zustand["system"]["server_time"])
    aufnahme = zeit(zustand["snapshot"]["timestamp"])
    assert vorher <= serverzeit <= nachher, (
        f"server_time {serverzeit.isoformat()} folgt der gepufferten Aufnahme "
        f"({aufnahme.isoformat()}) statt der Uhr"
    )
    assert (serverzeit - aufnahme).total_seconds() > 179.0
