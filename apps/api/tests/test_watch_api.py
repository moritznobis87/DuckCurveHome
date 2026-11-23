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

from dch_api.application.live_runtime import _nach_schwere
from dch_api.main import create_app
from dch_api.schemas import WatchFindingOut
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


def aussen(seq: int, wert: float, beobachtet: datetime) -> str:
    return TelemetryFrame(
        seq=seq,
        sent_at=datetime.now(UTC),
        items=[
            RawReading(
                key="outdoor_temp_c", value=wert, observed_at=beobachtet, source="ha:wetterstation"
            )
        ],
    ).model_dump_json()


def test_eine_stehengebliebene_aussentemperatur_wird_durch_den_wetterdienst_ersetzt(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Der Fall vom 13.11.2026: 2,2 °C auf der Startseite bei 8 bis 9 Grad draußen.

    Der Wert kam frisch gestempelt aus Home Assistant und war trotzdem falsch. Die Gegenprobe
    gegen den Wetterdienst zeigt dessen Wert, sagt es im Wächter, und lässt den Messwert im
    Snapshot stehen: gespeichert wird, was gemessen wurde.
    """
    runner = client.app.state.runner  # type: ignore[attr-defined]
    monkeypatch.setattr(runner.forecasts, "outdoor_temp_c", lambda at: 8.6)
    jetzt = datetime.now(UTC)
    with client.websocket_connect("/bridge/ws", headers={"authorization": "Bearer geheim"}) as ws:
        ws.send_text(hello())
        json.loads(ws.receive_text())
        ws.send_text(aussen(1, 2.2, jetzt - timedelta(minutes=5)))
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 1}

        state = client.get("/api/v1/live/state", headers=KOPF).json()
        assert state["system"]["outdoor_shown_c"] == 8.6
        assert state["system"]["outdoor_source_de"] == "Wetterdienst"
        assert state["snapshot"]["outdoor_temp_c"]["value"] == 2.2
        befund = befunde(client)["outdoor_check"]
        assert befund["severity"] == "warn"
        assert "weicht um 6 Grad vom Wetterdienst ab" in str(befund["text_de"])

        # Ein glaubwürdiger Wert steht für sich: kein Befund, keine fremde Quelle.
        ws.send_text(aussen(2, 8.1, jetzt))
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 2}
        state = client.get("/api/v1/live/state", headers=KOPF).json()
        assert state["system"]["outdoor_shown_c"] == 8.1
        assert state["system"]["outdoor_source_de"] == ""
        assert "outdoor_check" not in befunde(client)


def saeule(seq: int, beobachtet: datetime, werte: tuple[float, float, float, float]) -> str:
    """Eine Telemetriezeile mit vier ausdrücklich verschiedenen Fühlerwerten."""
    return TelemetryFrame(
        seq=seq,
        sent_at=datetime.now(UTC),
        items=[
            RawReading(key=k, value=v, observed_at=beobachtet, source="ha:puffer")
            for k, v in zip(PUFFER, werte, strict=True)
        ],
    ).model_dump_json()


def test_ein_eingefrorener_fuehler_wird_bemerkt(client: TestClient) -> None:
    """Der Fall, den der Zeitstempel nicht sieht: ein Fühler redet und sagt nichts mehr.

    Neunzig Meldungen im **Minutentakt** - so, wie die Brücke sie wirklich schickt (MQTT alle
    dreißig Sekunden, Home Assistant jede Minute). Der oberste Fühler steht dabei unverändert auf
    58,0 °C, während die drei anderen sich bewegen. Alle vier bleiben frisch, der Ladezustand wird
    gerechnet - und genau darum ist das Bild eines gesunden Speichers von dem eines toten Fühlers
    nicht zu unterscheiden, solange nur das Alter geprüft wird.

    **Der Takt gehört zur Prüfung und ist nicht Beiwerk.** Elf Meldungen mit 36 Minuten Abstand
    ergeben dieselben sechs Stunden Stillstand und erfüllen `MELDUNGEN_MIND` auch - aber sie sind
    dem Lückenmuster gleich, das diese Mindestzahl gerade abhalten soll. Was die Prüfung belegen
    muss, ist der echte Takt: bei 58 °C liegt die Frist auf 85 Minuten (`standzeit_min`), 90
    Meldungen im Minutentakt überschreiten sie, und keine davon ist eine Lücke.
    """
    jetzt = datetime.now(UTC)
    takte = 90
    with client.websocket_connect("/bridge/ws", headers={"authorization": "Bearer geheim"}) as ws:
        ws.send_text(hello())
        json.loads(ws.receive_text())
        for i in range(takte):
            ws.send_text(
                saeule(
                    i + 1,
                    jetzt - timedelta(minutes=takte - 1 - i),
                    (58.0, 52.0 + i * 0.01, 46.0 + i * 0.01, 40.0 + i * 0.01),
                )
            )
            assert json.loads(ws.receive_text()) == {"type": "ack", "seq": i + 1}

        offen = befunde(client)
        assert "frozen:buffer_temp_top_c" in offen
        befund = offen["frozen:buffer_temp_top_c"]
        assert befund["title_de"] == "Der Pufferfühler oben"
        assert "unverändert 58,0 °C" in str(befund["text_de"])
        assert float(befund["silent_min"]) == pytest.approx(takte - 1, abs=0.1)
        # Nur dieser eine: die drei anderen bewegen sich.
        assert [n for n in offen if n.startswith("frozen:")] == ["frozen:buffer_temp_top_c"]
        # Und der Ladezustand steht weiter da. Eine Anzeige, die bei Zweifeln nichts mehr zeigt,
        # ist schlechter als eine, die die Zahl zeigt und den Zweifel daneben schreibt.
        state = client.get("/api/v1/live/state", headers=KOPF).json()
        assert state["buffer"]["soc"] is not None


def test_die_saeule_vom_foto_rechnet_und_schweigt(client: TestClient) -> None:
    """Die Säule vom Foto der Wandanzeige: `40°, 40°, 40°, 39°`, daneben „PUFFER 18 % kalt".

    Nachgerechnet ist daran nichts falsch - vier verschiedene Fühler, 18 % richtig, ein Kelvin
    Spanne bei einem entleerten Speicher physikalisch möglich. Also rechnet der Dienst, und sagt
    nichts dazu: eine Dauerwarnung an der Wand über einen gesunden Speicher kostet den einen
    Platz, auf den es ankommt, und nimmt der nächsten echten Meldung den Glauben.
    """
    with client.websocket_connect("/bridge/ws", headers={"authorization": "Bearer geheim"}) as ws:
        ws.send_text(hello())
        json.loads(ws.receive_text())
        ws.send_text(saeule(1, datetime.now(UTC), (40.0, 40.0, 40.0, 39.0)))
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 1}

        state = client.get("/api/v1/live/state", headers=KOPF).json()
        # Die Rechnung läuft: 18 % und „kalt" stehen da.
        assert state["buffer"]["soc"] == 0.1759
        assert state["buffer"]["status"] == "cold"
        namen = {b["name"] for b in state["system"]["watch"]}
        assert "buffer_flat" not in namen
        assert not any(n.startswith("frozen:") for n in namen)


def test_eine_flache_saeule_in_betrieb_wird_bemerkt(client: TestClient) -> None:
    """Oberhalb der Komforttemperatur muss eine Stufe zu sehen sein.

    Die Oberkante liefert Komfortwärme, der Speicher ist also in Betrieb, und eingespeist wie
    entnommen wird oben. Vier gleiche Werte heißen dann, dass zwei Fühler an derselben Stelle
    sitzen oder am selben Wert hängen - und der Ladezustand daneben steht auf diesen vier Zahlen.
    """
    with client.websocket_connect("/bridge/ws", headers={"authorization": "Bearer geheim"}) as ws:
        ws.send_text(hello())
        json.loads(ws.receive_text())
        ws.send_text(saeule(1, datetime.now(UTC), (44.0, 44.0, 44.0, 43.5)))
        assert json.loads(ws.receive_text()) == {"type": "ack", "seq": 1}

        state = client.get("/api/v1/live/state", headers=KOPF).json()
        assert state["buffer"]["soc"] is not None
        befund = {b["name"]: b for b in state["system"]["watch"]}["buffer_flat"]
        assert befund["severity"] == "warn"
        assert "keine Schichtung" in str(befund["text_de"])
        # Eine einzelne Meldung ist kein stehender Fühler: dafür braucht es viele gleiche.
        assert [n for n in befunde(client) if n.startswith("frozen:")] == []


def test_alarme_stehen_vor_warnungen_in_der_liste() -> None:
    """Die Reihenfolge von `system.watch` ist Inhalt, nicht Geschmack.

    Die Wandanzeige zeigt nicht alle Befunde, sondern die ersten zwei
    (`Wachbefunde.hoechstens`), das Ruhebild nur den ersten. Was hinten steht, liest niemand.
    `findings()` sortiert seine eigenen Befunde; die Prüfungen an den Pufferfühlern und an der
    Außentemperatur kommen danach dazu, also muss die zusammengelegte Liste noch einmal durch
    `_nach_schwere` - sonst steht ein eingefrorener Fühler hinter einer Preiswarnung.

    **Warum hier und nicht am Dienst:** `befunde()` oben in dieser Datei gibt ein `dict` nach
    Namen zurück, und darin ist die Reihenfolge weg. Deshalb lief diese Funktion bis zum
    22.11.2026 ungeprüft: durch `return list(befunde)` ersetzt, blieb alles grün. An ihr hängt
    zudem `Wachbefunde.zeilen` in der App, das den vorderen Lauf der Alarme vor seinen eigenen
    Befund stellt - steht dort eine Warnung vorn, fällt der Alarm bei zwei Zeilen heraus.
    """

    def f(name: str, severity: str) -> WatchFindingOut:
        return WatchFindingOut(
            name=name,
            title_de=name,
            severity=severity,  # type: ignore[arg-type]
            silent_min=1.0,
            text_de=name,
        )

    gemischt = [f("price", "warn"), f("frozen:buffer_temp_top_c", "alarm"), f("buffer_flat", "warn")]
    assert [b.name for b in _nach_schwere(gemischt)] == [
        "frozen:buffer_temp_top_c",
        "price",
        "buffer_flat",
    ]
    # Stabil: innerhalb einer Schwere bleibt die Reihenfolge, die `findings()` gesetzt hat.
    nur_warn = [f("price", "warn"), f("weather", "warn")]
    assert [b.name for b in _nach_schwere(nur_warn)] == ["price", "weather"]
