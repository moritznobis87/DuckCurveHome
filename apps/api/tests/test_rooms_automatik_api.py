"""Die Raumautomatik über die API: aus, bis jemand sie einschaltet - und zurück beim Ausschalten."""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from dch_api.main import create_app
from dch_api.settings import Settings


@pytest.fixture
def client() -> Iterator[TestClient]:
    with TestClient(create_app(Settings(mode="demo", demo_autostart=False))) as c:
        yield c


def zustand(c: TestClient) -> dict:
    return c.get("/api/v1/rooms/automatik").json()


def test_sie_ist_aus_bis_jemand_sie_einschaltet(client: TestClient) -> None:
    d = zustand(client)
    assert d["enabled"] is False
    assert d["rooms"] == []
    assert d["phase"] == "aus"
    assert d["offset_k"] == 0.0
    assert "ausgeschaltet" in d["reason_de"]


def test_einschalten_braucht_raeume_die_es_gibt(client: TestClient) -> None:
    raeume = [r["id"] for r in client.get("/api/v1/rooms").json()["rooms"]]
    r = client.post("/api/v1/rooms/automatik", json={"enabled": True, "rooms": [raeume[0]]})
    assert r.status_code == 200
    d = r.json()
    assert d["enabled"] is True and d["rooms"] == [raeume[0]]

    schlecht = client.post("/api/v1/rooms/automatik", json={"rooms": [9999]})
    assert schlecht.status_code == 422
    assert "Unbekannte" in schlecht.json()["error"]["message"]


def test_die_grenzen_gelten_auch_ueber_die_api(client: TestClient) -> None:
    d = client.post("/api/v1/rooms/automatik", json={"delta_k": 5.0, "draw_k": 3.0}).json()
    assert d["delta_k"] == 1.5
    assert d["draw_k"] == 1.0


def test_was_fehlt_bleibt_wie_es_war(client: TestClient) -> None:
    raeume = [r["id"] for r in client.get("/api/v1/rooms").json()["rooms"]]
    client.post("/api/v1/rooms/automatik", json={"enabled": True, "rooms": raeume[:2]})
    d = client.post("/api/v1/rooms/automatik", json={"delta_k": 0.8}).json()
    assert d["enabled"] is True
    assert d["rooms"] == raeume[:2]
    assert d["delta_k"] == 0.8


def test_ausschalten_laesst_keinen_raum_angehoben_zurueck(client: TestClient) -> None:
    raeume = [r["id"] for r in client.get("/api/v1/rooms").json()["rooms"]]
    client.post("/api/v1/rooms/automatik", json={"enabled": True, "rooms": raeume})
    aus = client.post("/api/v1/rooms/automatik", json={"enabled": False}).json()
    assert aus["enabled"] is False
    # Kein Raum bleibt mit einer Anhebung stehen.
    assert [r for r in aus["active"] if r["offset_k"] != 0.0] == []
