"""Die Einzelraumregelung: aus Reihennamen und einem Ereignis wird eine Raumliste.

Die Raumnamen hier sind erfunden. Das Repository ist öffentlich, und wie die Zimmer eines
bewohnten Hauses heißen, gehört nicht hinein.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from dch_api.application import rooms
from dch_api.main import create_app
from dch_api.settings import Settings
from hems_core.protocol import EventFrame, HelloFrame, RawReading, TelemetryFrame

KOPF = {"authorization": "Bearer api-geheim"}


# ------------------------------------------------------------------ reine Logik


def test_reihennamen_werden_zerlegt() -> None:
    assert rooms.parse_key("room_12_temp_c") == (12, "temp_c")
    assert rooms.parse_key("room_3_valve") == (3, "valve")
    assert rooms.parse_key("room_3_unbekannt") is None
    assert rooms.parse_key("pv_power_kw") is None
    # Kein Treffer auf halbem Weg: der Name muss ganz passen.
    assert rooms.parse_key("x_room_3_valve") is None


def test_kennungen_aus_einem_gemischten_schluesselbund() -> None:
    assert rooms.ids_from_keys(
        ["pv_power_kw", "room_4_temp_c", "room_4_valve", "room_1_temp_c"]
    ) == [1, 4]


def test_die_raumliste_kommt_aus_dem_ereignis() -> None:
    meta = rooms.meta_from_context(
        {
            "raum.1.name": "Arbeiten",
            "raum.1.etage": "Erdgeschoss",
            "raum.1.kreise": "2",
            "raum.1.rang": "0",
            "raum.9.name": "Baden",
            "raum.9.etage": "Obergeschoss",
            "raum.9.rang": "5",
        }
    )
    assert meta[1] == rooms.RoomMeta(id=1, name="Arbeiten", floor="Erdgeschoss", circuits=2, rank=0)
    # Ohne Kreisangabe bleibt die Zahl 0, nicht 1: geraten wird nichts.
    assert meta[9].circuits == 0


def test_das_alte_ereignisformat_wird_noch_gelesen() -> None:
    """Die erste Fassung der Brücke schickte nur `{"5": "Name"}`. Die Namen sollen trotzdem da sein."""
    meta = rooms.meta_from_context({"5": "Oben", "7": "Knapp"})
    assert meta[5].name == "Oben"
    assert meta[5].floor == ""
    # Ohne Rangangabe ordnet die Kennung, damit die Reihenfolge wenigstens stabil ist.
    assert [m.id for m in sorted(meta.values(), key=rooms.sort_key)] == [5, 7]


def test_raeume_ohne_etage_stehen_hinten() -> None:
    """Sie gehören in keine Geschossgruppe, und eine erfundene wäre schlimmer als keine."""
    ohne = rooms.RoomMeta(id=1, name="Irgendwo", floor="", rank=0)
    mit = rooms.RoomMeta(id=2, name="Oben", floor="Obergeschoss", rank=9)
    assert sorted([ohne, mit], key=rooms.sort_key) == [mit, ohne]


def test_die_reihenfolge_ist_contromes_und_nicht_das_alphabet() -> None:
    """Alphabetisch läge das Dachgeschoss vor dem Erdgeschoss und der Keller mitten drin."""
    meta = rooms.meta_from_context(
        {
            "raum.1.name": "A",
            "raum.1.etage": "Keller",
            "raum.1.rang": "2",
            "raum.2.name": "B",
            "raum.2.etage": "Erdgeschoss",
            "raum.2.rang": "0",
            "raum.3.name": "C",
            "raum.3.etage": "Dachgeschoss",
            "raum.3.rang": "4",
        }
    )
    assert [m.floor for m in sorted(meta.values(), key=rooms.sort_key)] == [
        "Erdgeschoss",
        "Keller",
        "Dachgeschoss",
    ]


# ------------------------------------------------------------------ Verdichtung


def _zeile(minute: int, **werte: float) -> dict[str, float | str | None]:
    t = datetime(2026, 10, 22, tzinfo=UTC) + timedelta(minutes=minute)
    return {"ts": t.isoformat().replace("+00:00", "Z"), **werte}


def test_fenster_werden_gemittelt_und_luecken_bleiben_luecken() -> None:
    start = datetime(2026, 10, 22, 0, 0, tzinfo=UTC)
    zeilen = [
        _zeile(0, room_1_temp_c=20.0),
        _zeile(1, room_1_temp_c=21.0),
        # Minute 2 fehlt; das dritte Fenster (10 bis 15) hat überhaupt keinen Wert.
        _zeile(7, room_1_temp_c=22.0),
    ]
    ts, reihen = rooms.condense(zeilen, [1], start, start + timedelta(minutes=20), 5)
    assert len(ts) == 4 and ts[0] == start
    assert reihen[0].values["temp_c"] == [20.5, 22.0, None, None]


def test_die_ventilstellung_wird_zur_einschaltdauer() -> None:
    """Das einzelne Ventil kennt nur auf und zu. Über ein Fenster ist der Mittelwert die Dauer."""
    start = datetime(2026, 10, 22, 0, 0, tzinfo=UTC)
    zeilen = [_zeile(i, room_1_valve=1.0 if i < 3 else 0.0) for i in range(5)]
    _, reihen = rooms.condense(zeilen, [1], start, start + timedelta(minutes=5), 5)
    assert reihen[0].values["valve"] == [0.6]


def test_werte_ausserhalb_des_zeitraums_fallen_heraus() -> None:
    start = datetime(2026, 10, 22, 1, 0, tzinfo=UTC)
    zeilen = [_zeile(0, room_1_temp_c=99.0), _zeile(70, room_1_temp_c=20.0)]
    _, reihen = rooms.condense(zeilen, [1], start, start + timedelta(minutes=15), 15)
    assert reihen[0].values["temp_c"] == [20.0]


def test_ein_unbekannter_raum_in_den_zeilen_stoert_nicht() -> None:
    """Gefragt wird nach bekannten Räumen; was sonst in der Zeile steht, wird nicht gezählt."""
    start = datetime(2026, 10, 22, 0, 0, tzinfo=UTC)
    zeilen = [_zeile(0, room_1_temp_c=20.0, room_77_temp_c=5.0)]
    _, reihen = rooms.condense(zeilen, [1], start, start + timedelta(minutes=5), 5)
    assert [r.id for r in reihen] == [1]
    assert reihen[0].values["temp_c"] == [20.0]


# ------------------------------------------------------------------ Ende zu Ende


@pytest.fixture
def live_client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'rooms.sqlite'}",
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


def _telemetrie(seq: int, now: datetime, werte: dict[str, float | None]) -> str:
    return TelemetryFrame(
        seq=seq,
        sent_at=now,
        items=[
            RawReading(key=k, value=v, observed_at=now, source="controme") for k, v in werte.items()
        ],
    ).model_dump_json()


def test_raeume_kommen_von_der_bruecke_bis_in_die_anzeige(live_client: TestClient) -> None:
    now = datetime.now(UTC)
    with live_client.websocket_connect(
        "/bridge/ws", headers={"authorization": "Bearer geheim"}
    ) as ws:
        ws.send_text(_hello())
        assert json.loads(ws.receive_text())["type"] == "welcome"
        ws.send_text(
            EventFrame(
                at=now,
                severity="info",
                code="rooms.list",
                message="2 Räume der Einzelraumregelung",
                context={
                    "raum.1.name": "Arbeiten",
                    "raum.1.etage": "Erdgeschoss",
                    "raum.1.kreise": "2",
                    "raum.1.rang": "0",
                    "raum.4.name": "Oben",
                    "raum.4.etage": "Obergeschoss",
                    "raum.4.kreise": "2",
                    "raum.4.rang": "1",
                },
            ).model_dump_json()
        )
        ws.send_text(
            _telemetrie(
                1,
                now,
                {
                    "room_1_temp_c": 20.6,
                    "room_1_setpoint_c": 21.0,
                    "room_1_offset_k": 0.2,
                    "room_1_valve": 1.0,
                    # Dieser Raum meldet keine Temperatur - ein stummer Funkfühler.
                    "room_4_temp_c": None,
                    "room_4_setpoint_c": 23.0,
                    "room_4_valve": 0.5,
                },
            )
        )
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 1}

        antwort = live_client.get("/api/v1/rooms", headers=KOPF).json()
        assert antwort["named"] is True
        assert [r["id"] for r in antwort["rooms"]] == [1, 4]

        erster = antwort["rooms"][0]
        assert erster["name"] == "Arbeiten" and erster["floor"] == "Erdgeschoss"
        assert erster["circuits"] == 2 and erster["valve"] == 1.0
        # Die Abweichung bezieht sich auf den gemeldeten Sollwert, nicht auf Soll plus Offset:
        # dass der Regler auf die Summe regelt, ist nicht belegt. Beide Zahlen stehen daneben.
        assert erster["temp_c"] == 20.6 and erster["setpoint_c"] == 21.0
        assert erster["offset_k"] == 0.2
        assert erster["deviation_k"] == -0.4

        stumm = antwort["rooms"][1]
        assert stumm["name"] == "Oben"
        # Kein Messwert heißt kein Messwert, nicht 0 °C - und keine ausgerechnete Abweichung.
        assert stumm["temp_c"] is None and stumm["deviation_k"] is None
        assert stumm["setpoint_c"] == 23.0, "der Sollwert ist bekannt, nur die Messung fehlt"
        assert stumm["observed_at"] is None

    verlauf = live_client.get(
        "/api/v1/rooms/history", params={"range": "24h", "step_min": 15}, headers=KOPF
    ).json()
    # 96 Viertelstunden, und eine mehr, wenn das gerasterte Anfangsfenster vorne übersteht.
    assert verlauf["step_min"] == 15 and len(verlauf["ts"]) in (96, 97)
    assert [r["id"] for r in verlauf["rooms"]] == [1, 4]
    for r in verlauf["rooms"]:
        assert len(r["temp_c"]) == len(verlauf["ts"])
        assert len(r["valve"]) == len(verlauf["ts"])
    # Der eben gemeldete Wert steht im letzten, noch laufenden Fenster. Ein abgerundetes Ende
    # hätte ihn verschwiegen.
    assert verlauf["rooms"][0]["temp_c"][-1] == 20.6


def test_ohne_ereignis_heissen_die_raeume_nach_ihrer_kennung(live_client: TestClient) -> None:
    """Messwerte kommen vielleicht vor der Namensliste. Dann zeigt die Seite Ersatznamen - und
    `named` sagt, dass es Ersatznamen sind."""
    now = datetime.now(UTC)
    with live_client.websocket_connect(
        "/bridge/ws", headers={"authorization": "Bearer geheim"}
    ) as ws:
        ws.send_text(_hello())
        ws.receive_text()
        ws.send_text(_telemetrie(1, now, {"room_7_temp_c": 19.0}))
        ws.receive_text()
        antwort = live_client.get("/api/v1/rooms", headers=KOPF).json()
    assert antwort["named"] is False
    assert antwort["rooms"][0]["name"] == "Raum 7"
    assert antwort["rooms"][0]["floor"] == ""


def test_eine_unzulaessige_fensterbreite_wird_abgewiesen(live_client: TestClient) -> None:
    r = live_client.get("/api/v1/rooms/history", params={"step_min": 7}, headers=KOPF)
    assert r.status_code == 422


def test_ein_kalendertag_wird_in_ortszeit_abgegrenzt(live_client: TestClient) -> None:
    """Ein Heiztag beginnt um Mitternacht in Geilenkirchen, nicht in UTC - sonst läge die
    Nachtabsenkung halb im Vortag."""
    r = live_client.get(
        "/api/v1/rooms/history", params={"day": "2026-07-01", "step_min": 60}, headers=KOPF
    )
    assert r.status_code == 200
    d = r.json()
    assert d["start"].startswith("2026-06-30T22:00")  # Sommerzeit: UTC+2
    assert len(d["ts"]) == 24


def test_die_vorfuehrung_zeigt_erfundene_raeume(client: TestClient) -> None:
    """Im Demo-Modus soll die Seite nicht leer sein, und die Namen sind keine echten."""
    antwort = client.get("/api/v1/rooms").json()
    assert len(antwort["rooms"]) == 9
    assert {r["floor"] for r in antwort["rooms"]} == {"Erdgeschoss", "Obergeschoss"}
    bad = next(r for r in antwort["rooms"] if r["name"] == "Baden")
    assert bad["setpoint_c"] == 23.0
    # Jeder Kreis ist auf oder zu: der Anteil ist ein Bruch mit der Kreiszahl als Nenner.
    for r in antwort["rooms"]:
        assert r["valve"] is not None
        assert abs(r["valve"] * r["circuits"] - round(r["valve"] * r["circuits"])) < 1e-6

    verlauf = client.get("/api/v1/rooms/history", params={"step_min": 60}).json()
    assert len(verlauf["ts"]) == 24
    assert len(verlauf["rooms"][0]["temp_c"]) == 24
    # Die Werte sind eine Formel und ließen sich für jede Uhrzeit ausrechnen. Trotzdem endet die
    # Reihe jetzt: eine Vorführung darf erfundene Werte zeigen, aber nicht so tun, als wüsste sie
    # mehr als die echte Anlage.
    jetzt = datetime.fromisoformat(antwort["at"].replace("Z", "+00:00"))
    reihe = verlauf["rooms"][0]["temp_c"]
    for i, zeit in enumerate(verlauf["ts"]):
        kuenftig = datetime.fromisoformat(zeit.replace("Z", "+00:00")) > jetzt
        assert (reihe[i] is None) == kuenftig, f"Fenster {zeit}"
    assert any(v is not None for v in reihe), "der angebrochene Tag ist nicht leer"
