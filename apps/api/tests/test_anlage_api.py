"""Der Endpunkt `/anlage`: das Schema im Augenblick, aus der Vorführung und aus der Brücke."""

from __future__ import annotations

import json
from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta
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


def test_der_vorlauf_bleibt_leer_bis_jemand_ihn_liefert(client: TestClient) -> None:
    """Die Reihe ist eingerichtet, der Wert fehlt. Das Schema sagt das, statt eine Zahl zu setzen.

    Die Oberflaeche schreibt dafuer „Vorlauf ?". Ein NaN in der Spalte waere die naheliegende
    Alternative und waere falsch: es ist in JSON nicht darstellbar und ginge in jedes Minutenmittel
    ein, in das es einmal faellt.
    """
    wp = client.get("/api/v1/anlage", headers=KOPF).json()["waermepumpe"]
    assert wp["flow_c"] is None
    # Und der COP bleibt leer, auch wenn der Vorlauf eines Tages da ist: er waere dann gerechnet
    # und nicht gemessen, und die Kachel verspricht eine Messung.
    assert wp["cop"] is None
    assert wp["thermal_kw"] is None


def test_der_vorlauf_erscheint_sobald_die_bruecke_ihn_schickt(live_client: TestClient) -> None:
    """Der eigentliche Zweck der Einrichtung: der erste Wert braucht keine Codeaenderung mehr."""
    now = datetime.now(UTC).replace(second=0, microsecond=0)
    with live_client.websocket_connect(
        "/bridge/ws", headers={"authorization": "Bearer geheim"}
    ) as ws:
        ws.send_text(_hello())
        assert json.loads(ws.receive_text())["type"] == "welcome"
        ws.send_text(_telemetrie(1, now - timedelta(minutes=1), {logik.WP_VORLAUF: 38.5}))
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 1}

        a = live_client.get("/api/v1/anlage", headers=KOPF).json()

    assert a["waermepumpe"]["flow_c"] == 38.5


# ------------------------------------------------------------------ Die Wiedergabe


def test_die_wiedergabe_liefert_bilder_desselben_schemas(client: TestClient) -> None:
    """Der Endpunkt gibt dieselbe Form wie `GET /anlage`, nur viele davon.

    Geprüft wird die Form und nicht der Inhalt: ob der Tag in der Vorführung schon erlebt wurde,
    hängt an ihrer Laufzeit, und ein Prüflauf soll nicht davon abhängen, wie lange er dauert.
    """
    heute = date.today().isoformat()
    r = client.get(f"/api/v1/anlage/wiedergabe?day={heute}&step_min=15", headers=KOPF)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["day"] == heute
    assert body["step_min"] == 15
    assert body["erwartet"] in (92, 96, 100), "24 Stunden, am Umstellungstag 23 oder 25"
    assert isinstance(body["frames"], list)
    assert body["hinweise_de"], "eine Wiedergabe sagt immer, was sie nicht zeigen kann"
    for bild in body["frames"]:
        assert set(bild) >= {"at", "strom", "waermepumpe", "ofen", "speicher", "heizkreis"}


def test_eine_unsinnige_schrittweite_wird_abgelehnt(client: TestClient) -> None:
    r = client.get(
        f"/api/v1/anlage/wiedergabe?day={date.today().isoformat()}&step_min=7", headers=KOPF
    )
    assert r.status_code == 422
    assert "Schrittweite" in r.text


def test_ein_tag_ohne_erfassung_ist_leer_und_sagt_es(client: TestClient) -> None:
    """Leer heißt „nichts erfasst", nicht „nichts geschah". Der Unterschied gehört in den Text."""
    r = client.get("/api/v1/anlage/wiedergabe?day=2020-01-01&step_min=15", headers=KOPF)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["frames"] == []
    assert "keine Minutenwerte" in body["hinweise_de"][0]


# ------------------------------------------------------------------ Was K1 auslöst


def test_die_kontaktwirkung_liefert_form_und_urteil(client: TestClient) -> None:
    """Geprüft wird die Form: wie viele Ereignisse die Vorführung erlebt hat, hängt an ihrer Zeit."""
    r = client.get("/api/v1/anlage/kontaktwirkung?days=7", headers=KOPF)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["days"] == 7
    assert body["urteil"] in ("offen", "wirkt", "kein_unterschied", "seltener")
    assert body["urteil_de"]
    faecher = body["faecher"]
    assert faecher["minuten"][0] == -body["vor_min"]
    assert faecher["minuten"][-1] == body["nach_min"]
    assert len(faecher["median_kw"]) == len(faecher["minuten"])
    assert body["schwelle_kw"] == 0.5, "dieselbe Schwelle wie im Taktzähler der Anlage"
    for e in body["ereignisse"]:
        assert len(e["kw"]) == len(faecher["minuten"])
    # Die Vorführung reicht keine sieben Tage zurück, und das steht da.
    assert "Vorführung" in body["hinweise_de"][0]
    assert any("keine Ursache" in h for h in body["hinweise_de"])


def test_ein_unbekannter_zeitraum_wird_abgelehnt(client: TestClient) -> None:
    r = client.get("/api/v1/anlage/kontaktwirkung?days=12", headers=KOPF)
    assert r.status_code == 422
    assert "Zeitraum" in r.text


def test_die_kontaktwirkung_liest_im_echten_betrieb_den_minutenbestand(
    live_client: TestClient,
) -> None:
    """Ohne eine einzige Minute im Bestand: kein Fehler, kein Urteil, und der Satz sagt warum."""
    r = live_client.get("/api/v1/anlage/kontaktwirkung?days=30", headers=KOPF)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["n"] == 0
    assert body["urteil"] == "offen"
    assert "kein einziges Mal" in body["urteil_de"]
