"""Der Hausplan: von der Datei der Bruecke bis in die Modellansicht.

Das Haus in diesen Pruefungen ist das erfundene der Vorfuehrung. Das Repository ist oeffentlich.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
import yaml
from fastapi.testclient import TestClient

from dch_api.application import demo_house, demo_rooms, house
from dch_api.main import create_app
from dch_api.settings import Settings
from hems_core.domain import Measurement, Quality
from hems_core.house import HousePlan
from hems_core.protocol import EventFrame, HelloFrame, RawReading, TelemetryFrame

KOPF = {"authorization": "Bearer api-geheim"}
WURZEL = Path(__file__).resolve().parents[3]


# ------------------------------------------------------------------ reine Logik


def test_der_plan_kommt_aus_dem_ereignis() -> None:
    plan, fehler = house.plan_from_context({house.CTX_PLAN: demo_house.PLAN.model_dump_json()})
    assert fehler == "" and plan == demo_house.PLAN


def test_ein_fehler_der_bruecke_wird_durchgereicht() -> None:
    plan, fehler = house.plan_from_context({house.CTX_ERROR: "Zeile 7: kein Rechteck"})
    assert plan is None and fehler == "Zeile 7: kein Rechteck"


def test_ohne_plan_im_zusammenhang_gibt_es_einen_grund() -> None:
    plan, fehler = house.plan_from_context({})
    assert plan is None and "keinen Plan" in fehler
    plan, fehler = house.plan_from_context({house.CTX_PLAN: json.dumps({"decks": []})})
    assert plan is None and "Schema" in fehler


def test_ein_kontakt_ist_nur_mit_frischem_wert_offen_oder_zu() -> None:
    now = datetime(2026, 10, 30, 8, 0, tzinfo=UTC)
    assert house.contact_open(Measurement.ok(1.0, now, "ha")) is True
    assert house.contact_open(Measurement.ok(0.0, now, "ha")) is False
    assert house.contact_open(Measurement.missing(Quality.UNAVAILABLE, now, "ha")) is None
    alt = Measurement.ok(1.0, now, "ha").aged(now.replace(hour=12), house.STALE_S)
    assert alt.quality == Quality.STALE
    assert house.contact_open(alt) is None, "ein alter Wert sagt nicht, ob die Tuer offen ist"


def test_das_beispiel_im_repository_ist_das_haus_der_vorfuehrung() -> None:
    """Die YAML-Datei ist die Vorlage fuer die eigene; sie soll genau das zeigen, was die
    Vorfuehrung zeigt - und jede Art von Eintrag einmal enthalten."""
    daten = yaml.safe_load((WURZEL / "config" / "haus.example.yaml").read_text(encoding="utf-8"))
    plan = HousePlan.model_validate(daten)
    assert plan == demo_house.PLAN
    arten = {i.kind for d in plan.decks for i in d.items}
    assert {"box", "bed", "stove", "buffer", "heat_pump", "car", "wallbox", "flight"} <= arten


def test_die_raeume_der_vorfuehrung_stehen_im_plan() -> None:
    assert set(demo_house.PLAN.room_ids) == {r.id for r in demo_rooms.ROOMS}


# ------------------------------------------------------------------ Vorfuehrung


def test_die_vorfuehrung_zeigt_das_erfundene_haus(client: TestClient) -> None:
    antwort = client.get("/api/v1/haus").json()
    assert antwort["present"] is True
    assert [d["key"] for d in antwort["plan"]["decks"]] == ["eg", "og"]
    kontakte = {k["key"]: k for k in antwort["contacts"]}
    assert set(kontakte) == {k.key for k in demo_house.PLAN.contacts}
    # Ein Kontakt ohne Meldung bleibt unbekannt, nicht zu.
    assert kontakte["kontakt_haustuer"]["open"] is None
    assert kontakte["kontakt_haustuer"]["quality"] == "unavailable"
    assert kontakte["kontakt_wohnen_fenster"]["open"] in (True, False)


# ------------------------------------------------------------------ Ende zu Ende


@pytest.fixture
def live_client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'haus.sqlite'}",
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
        keys=["kontakt_terrassentuer"],
    ).model_dump_json()


def _plan_ereignis(now: datetime) -> str:
    return EventFrame(
        at=now,
        severity="info",
        code="house.plan",
        message="Hausplan mit 2 Decks",
        context={
            house.CTX_PLAN: demo_house.PLAN.model_dump_json(),
            house.CTX_HASH: "abc",
            house.CTX_FILE: "/config/duckcurve/haus.yaml",
        },
    ).model_dump_json()


def test_ohne_bruecke_sagt_die_antwort_warum(live_client: TestClient) -> None:
    antwort = live_client.get("/api/v1/haus", headers=KOPF).json()
    assert antwort["present"] is False and antwort["plan"] is None
    assert "haus.yaml" in antwort["error_de"]


def test_der_plan_kommt_von_der_bruecke_bis_in_die_anzeige(live_client: TestClient) -> None:
    now = datetime.now(UTC)
    with live_client.websocket_connect(
        "/bridge/ws", headers={"authorization": "Bearer geheim"}
    ) as ws:
        ws.send_text(_hello())
        assert json.loads(ws.receive_text())["type"] == "welcome"
        ws.send_text(_plan_ereignis(now))
        ws.send_text(
            TelemetryFrame(
                seq=1,
                sent_at=now,
                items=[
                    RawReading(
                        key="kontakt_terrassentuer", value=1.0, observed_at=now, source="ha"
                    ),
                    RawReading(
                        key="kontakt_kochen_fenster", value=0.0, observed_at=now, source="ha"
                    ),
                ],
            ).model_dump_json()
        )
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 1}

        antwort = live_client.get("/api/v1/haus", headers=KOPF).json()
        assert antwort["present"] is True and antwort["error_de"] == ""
        assert antwort["plan"]["name"] == "Beispielhaus"
        assert "haus.yaml" in antwort["source_de"]
        kontakte = {k["key"]: k for k in antwort["contacts"]}
        assert kontakte["kontakt_terrassentuer"]["open"] is True
        assert kontakte["kontakt_kochen_fenster"]["open"] is False
        # Nicht gemeldet heisst nicht zu, sondern unbekannt.
        assert kontakte["kontakt_haustuer"]["open"] is None

        # Eine kaputte Datei verdraengt den Plan: Der juengste Stand zaehlt, und der ist ein Fehler.
        ws.send_text(
            EventFrame(
                at=now + timedelta(seconds=1),
                severity="warning",
                code="house.plan",
                message="Hausplan nicht lesbar",
                context={house.CTX_ERROR: "decks.0.rooms.2: x1 > x0 und z1 > z0 noetig"},
            ).model_dump_json()
        )
        # Das Ereignis hat keine Bestaetigung; ein zweiter Telemetrierahmen ordnet die Reihenfolge.
        ws.send_text(TelemetryFrame(seq=2, sent_at=now, items=[]).model_dump_json())
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 2}
        antwort = live_client.get("/api/v1/haus", headers=KOPF).json()
        assert antwort["present"] is False
        assert "x1 > x0" in antwort["error_de"]
