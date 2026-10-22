"""Die Einzelraumregelung auslesen - gegen die Formen, die die echte Anlage geliefert hat."""

from __future__ import annotations

import json
from datetime import UTC, datetime

import httpx
import pytest

from dch_bridge.sources.controme import (
    ContromeRooms,
    RaumInfo,
    kreiszahl,
    raeume_aus,
    ventilanteil,
)
from hems_core.domain.quality import Quality

# Abgeschrieben von der Anlage in Geilenkirchen, 21.10.2026, Haus-Kennung 2. Die Raumnamen sind
# ersetzt, das Repository ist öffentlich; Struktur, Feldnamen und Eigenheiten sind die echten -
# einschließlich der führenden Leerzeichen in den Ausgangsschlüsseln.
ROOMS = [
    {
        "etagenname": "Erdgeschoss",
        "id": 1,
        "raeume": [
            {"icon": "desk", "id": 1, "name": "Arbeiten"},
            {"icon": "feuer", "id": 2, "name": "Wohnen"},
        ],
    },
    {
        "etagenname": "Obergeschoss",
        "id": 2,
        "raeume": [{"icon": "sessel", "id": 4, "name": "Oben"}],
    },
]
TEMPS = [
    {
        "etagenname": "Erdgeschoss",
        "id": 1,
        "raeume": [
            {
                "total_offset": 0.2,
                "solltemperatur": 21.0,
                "temperatur": 20.579999923706055,
                "luftfeuchte": 47,
                "id": 1,
                "name": "Arbeiten",
                "offsets": {"Geolocation": {"raum": 0.0, "haus": 0.0}},
            },
            # Ohne Fuehler setzt Controme einen deutschen Satz an die Stelle der Zahl.
            {
                "total_offset": 0.0,
                "solltemperatur": 21.5,
                "temperatur": 21.5,
                "luftfeuchte": "kein Sensor vorhanden",
                "id": 2,
                "name": "Wohnen",
                "offsets": {},
            },
        ],
    },
    {
        "etagenname": "Obergeschoss",
        "id": 2,
        "raeume": [
            {"solltemperatur": 23.0, "temperatur": None, "id": 4, "name": "Oben", "offsets": {}},
            # Aeltere Firmware laesst Felder ganz weg. Ausser id und name ist alles freiwillig.
            {"id": 5, "name": "Knapp"},
        ],
    },
]
OUTS = [
    {
        "etagenname": "Erdgeschoss",
        "id": 1,
        "raeume": [
            {"ausgang": {" 6": 1, "5": 1}, "id": 1, "name": "Arbeiten"},
            {"ausgang": {"1": 0, " 10": 0, " 4": 0, " 3": 0}, "id": 2, "name": "Wohnen"},
        ],
    },
    {
        "etagenname": "Obergeschoss",
        "id": 2,
        "raeume": [
            {"ausgang": {"9": 1, " 8": 0}, "id": 4, "name": "Oben"},
            {"ausgang": {}, "id": 5, "name": "Knapp"},
        ],
    },
]


def _antwort(request: httpx.Request) -> httpx.Response:
    pfad = request.url.path
    if "/2/rooms/" in pfad:
        return httpx.Response(200, json=ROOMS)
    if "/2/temps/" in pfad:
        return httpx.Response(200, json=TEMPS)
    if "/2/outs/" in pfad:
        return httpx.Response(200, json=OUTS)
    # Jede andere Haus-Kennung antwortet mit einer leeren Liste statt mit einem Fehler.
    return httpx.Response(200, json=[])


def _quelle(**kw: object) -> tuple[ContromeRooms, list, list]:
    gelesen: list = []
    raeume: list = []

    async def on_readings(items: list) -> None:
        gelesen.extend(items)

    async def on_rooms(infos: dict[int, RaumInfo]) -> None:
        raeume.append(infos)

    q = ContromeRooms("192.0.2.50", on_readings, on_rooms=on_rooms, **kw)  # type: ignore[arg-type]
    return q, gelesen, raeume


async def _lauf(q: ContromeRooms) -> list:
    transport = httpx.MockTransport(_antwort)
    async with httpx.AsyncClient(transport=transport) as client:
        return await q._einmal(client)


# ------------------------------------------------------------------ Formen


def test_die_etagenschachtelung_wird_flach() -> None:
    flach = raeume_aus(TEMPS)
    assert [r["id"] for r in flach] == [1, 2, 4, 5]
    assert flach[2]["etage"] == "Obergeschoss"


def test_ein_raum_ohne_kennung_faellt_heraus() -> None:
    """Ohne `id` ist ein Raum nicht zuzuordnen, und eine erfundene Zuordnung wäre schlimmer."""
    assert raeume_aus([{"etagenname": "X", "raeume": [{"name": "namenlos"}]}]) == []


def test_unsinn_statt_json_ergibt_keine_raeume() -> None:
    """Der Mini-Server antwortet bei Fehlern gern mit HTML. Das darf nichts umwerfen."""
    assert raeume_aus("<html>Fehler</html>") == []
    assert raeume_aus(None) == []


# ------------------------------------------------------------------ Ventile


def test_ventile_sind_auf_oder_zu_und_der_anteil_zaehlt_kreise() -> None:
    """Die Antriebe kennen keine Zwischenstellung. 0,5 heißt „einer von zwei"."""
    assert ventilanteil({" 6": 1, "5": 1}) == 1.0
    assert ventilanteil({"1": 0, " 10": 0, " 4": 0, " 3": 0}) == 0.0
    assert ventilanteil({"9": 1, " 8": 0}) == 0.5


def test_ohne_ausgaenge_kein_wert() -> None:
    assert ventilanteil({}) is None
    assert ventilanteil(None) is None


# ------------------------------------------------------------------ Ein Lauf


@pytest.mark.anyio
async def test_ein_lauf_liefert_ist_soll_und_ventil_je_raum() -> None:
    q, _, _ = _quelle()
    werte = {r.key: r.value for r in await _lauf(q)}
    assert werte["room_1_temp_c"] == pytest.approx(20.58, abs=0.01)
    assert werte["room_1_setpoint_c"] == 21.0
    assert werte["room_1_valve"] == 1.0
    assert werte["room_2_valve"] == 0.0
    assert werte["room_4_valve"] == 0.5


@pytest.mark.anyio
async def test_die_haus_kennung_wird_gesucht_und_nicht_vorausgesetzt() -> None:
    """Haus 1 liefert auf dieser Anlage eine leere Liste. Wer 1 voraussetzt, sieht nichts."""
    q, _, _ = _quelle()
    assert q.house_id == 0
    await _lauf(q)
    assert q.house_id == 2


@pytest.mark.anyio
async def test_ein_stummer_fuehler_wird_nicht_zu_null_grad() -> None:
    """Der wichtigste Fall: kein Messwert ist etwas anderes als 0 °C."""
    q, _, _ = _quelle()
    werte = {r.key: r for r in await _lauf(q)}
    stumm = werte["room_4_temp_c"]
    assert stumm.value is None
    assert stumm.quality is Quality.UNKNOWN
    # Der Sollwert dieses Raums ist bekannt, nur die Messung fehlt.
    assert werte["room_4_setpoint_c"].value == 23.0
    assert werte["room_4_setpoint_c"].quality is Quality.OK


@pytest.mark.anyio
async def test_die_raumnamen_gehen_einmal_hinaus_und_nicht_bei_jedem_lauf() -> None:
    """Namen sind keine Messwerte. Sie kommen als Ereignis, und nur wenn sie sich ändern."""
    q, _, raeume = _quelle()
    await _lauf(q)
    assert raeume == [
        {
            1: RaumInfo(name="Arbeiten", etage="Erdgeschoss", kreise=2, rang=0),
            2: RaumInfo(name="Wohnen", etage="Erdgeschoss", kreise=4, rang=1),
            4: RaumInfo(name="Oben", etage="Obergeschoss", kreise=2, rang=2),
            # Dieser Raum hat keinen Ausgang am Verteiler, also auch keinen Heizkreis.
            5: RaumInfo(name="Knapp", etage="Obergeschoss", kreise=0, rang=3),
        }
    ]
    await _lauf(q)
    assert len(raeume) == 1, "unveränderte Namen erzeugen kein zweites Ereignis"


def test_die_kreiszahl_zaehlt_die_ausgaenge_nicht_die_offenen() -> None:
    """Sie beschreibt den Verteiler, nicht den Augenblick: ein zugedrehter Kreis ist einer."""
    assert kreiszahl({"1": 0, " 10": 0, " 4": 0, " 3": 0}) == 4
    assert kreiszahl({"9": 1, " 8": 0}) == 2
    assert kreiszahl({}) == 0
    assert kreiszahl(None) == 0


@pytest.mark.anyio
async def test_die_etage_bleibt_wenn_nur_die_ausgaenge_antworten() -> None:
    """`temps` und `outs` sind zwei Abrufe, und einer kann ausfallen.

    Der zweite Durchgang über `outs` ergänzt den Raum, er ersetzt ihn nicht - sonst verlöre die
    Anzeige bei einem halb geglückten Lauf die Geschossgruppierung.
    """
    q, _, raeume = _quelle()
    await _lauf(q)
    assert raeume[0][1].etage == "Erdgeschoss"
    assert raeume[0][1].kreise == 2


@pytest.mark.anyio
async def test_die_schluessel_werden_erst_nach_dem_ersten_lauf_gemeldet() -> None:
    """Die Räume stehen nicht in einer Konfiguration, sondern in der Heizungsregelung."""
    q, _, _ = _quelle()
    assert q.keys == []
    await _lauf(q)
    assert "room_1_temp_c" in q.keys
    assert "room_4_valve" in q.keys


@pytest.mark.anyio
async def test_ein_nicht_erreichbarer_server_wirft_nicht() -> None:
    q, _, _ = _quelle()

    def kaputt(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("kein Netz")

    async with httpx.AsyncClient(transport=httpx.MockTransport(kaputt)) as client:
        assert await q._einmal(client) == []


@pytest.mark.anyio
async def test_html_statt_json_wirft_nicht() -> None:
    q, _, _ = _quelle()

    def html(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text="<html>Interner Fehler</html>")

    async with httpx.AsyncClient(transport=httpx.MockTransport(html)) as client:
        assert await q._einmal(client) == []


def test_der_zustand_sagt_was_die_quelle_gerade_tut() -> None:
    q, _, _ = _quelle()
    s = q.status()
    assert s["name"] == "controme"
    assert s["online"] is False
    assert json.dumps(s)  # muss sich ins Protokoll schreiben lassen


@pytest.mark.anyio
async def test_die_beobachtungszeit_ist_gesetzt() -> None:
    q, _, _ = _quelle()
    werte = await _lauf(q)
    assert all(isinstance(r.observed_at, datetime) for r in werte)
    assert all(r.observed_at.tzinfo is UTC for r in werte)
    assert all(r.source == "controme" for r in werte)


# ------------------------------------------------------------------ Was die Quellenlage ergab


def test_der_einzelraum_abruf_hat_eine_andere_form() -> None:
    """Dort liegen die Raumfelder flach, ohne Etagenhuelle. Wird heute nicht abgefragt."""
    assert raeume_aus([{"id": 1, "name": "Arbeiten", "temperatur": 20.5}]) == []


@pytest.mark.anyio
async def test_sollwert_und_offset_stehen_getrennt() -> None:
    """Ob der Offset im Sollwert steckt, ist nicht belegt. Also beides mitschreiben.

    Contromes FPS-Dokumentation definiert `ziel = soll + offsets`, und die Anlage meldet
    `solltemperatur: 21.0` neben `total_offset: 0.2` - ein glatter Planwert neben einem krummen
    Offset. Wer nur den Sollwert nimmt, rechnet moeglicherweise systematisch um den Offset
    daneben; wer beide hat, kann es aus den eigenen Daten entscheiden.
    """
    q, _, _ = _quelle()
    werte = {r.key: r.value for r in await _lauf(q)}
    assert werte["room_1_setpoint_c"] == 21.0
    assert werte["room_1_offset_k"] == 0.2
    assert werte["room_2_offset_k"] == 0.0


@pytest.mark.anyio
async def test_eine_luftfeuchte_als_satz_wird_nicht_zu_einer_zahl() -> None:
    """Controme setzt bei fehlendem Fuehler "kein Sensor vorhanden" an die Stelle der Zahl."""
    q, _, _ = _quelle()
    werte = {r.key: r for r in await _lauf(q)}
    assert werte["room_1_humidity_pct"].value == 47.0
    assert werte["room_2_humidity_pct"].value is None
    assert werte["room_2_humidity_pct"].quality is Quality.UNKNOWN


@pytest.mark.anyio
async def test_fehlende_felder_aelterer_firmware_werfen_nicht() -> None:
    """Ausser `id` und `name` ist jedes Feld freiwillig."""
    q, _, _ = _quelle()
    werte = {r.key: r.value for r in await _lauf(q)}
    assert werte["room_5_temp_c"] is None
    assert werte["room_5_setpoint_c"] is None
    assert werte["room_5_valve"] is None


def test_ein_schema_im_hostfeld_wird_abgeschnitten() -> None:
    """Der haeufigste Eingabefehler: wer das Schema mittippt, bekaeme sonst http://http://..."""
    q, _, _ = _quelle()
    assert ContromeRooms("http://192.0.2.50/", q.on_readings).host == "192.0.2.50"
    assert ContromeRooms("https://192.0.2.50", q.on_readings).host == "192.0.2.50"
