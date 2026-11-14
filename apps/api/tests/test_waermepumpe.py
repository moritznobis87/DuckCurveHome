"""Die Technikseite der Wärmepumpe: Zusammensetzung, Abschätzung und die Vorführung."""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi.testclient import TestClient

from dch_api.application import waermepumpe as wp
from hems_core.domain import EnergySnapshot, Measurement, Quality

JETZT = datetime(2026, 11, 13, 22, 30, 54, tzinfo=UTC)

#: Das zweite Protokoll des Hauses, 13.11.2026 23:30 Ortszeit, bei laufender Maschine.
HAUS_LAEUFT = {
    "heat_pump_mode_code": 3.0,
    "heat_pump_flow_l_min": 29.8,
    "flow_temp_c": 39.9,
    "heat_pump_return_temp_c": 36.5,
    "heat_pump_bus_power_kw": 1.448,
    "heat_pump_flow_setpoint_c": 45.0,
    "heat_pump_evaporator_temp_c": 2.3,
    "heat_pump_liquid_temp_c": 36.6,
    "heat_pump_suction_temp_c": 3.3,
    "heat_pump_discharge_temp_c": 46.4,
    "heat_pump_tank_temp_c": 47.6,
}


def schnappschuss(client: TestClient, zaehler_kw: float | None) -> EnergySnapshot:
    """Ein Schnappschuss der Vorführung, mit dem Zählerwert, den die Prüfung braucht."""
    snap = EnergySnapshot.model_validate(client.get("/api/v1/live/state").json()["snapshot"])
    zaehler = (
        Measurement.ok(zaehler_kw, JETZT, "test")
        if zaehler_kw is not None
        else Measurement.missing(Quality.UNAVAILABLE, JETZT, "test")
    )
    return snap.model_copy(update={"heat_pump_power_kw": zaehler})


def mess_aus(werte: dict[str, float]):  # type: ignore[no-untyped-def]
    def mess(key: str) -> Measurement:
        if key in werte:
            return Measurement.ok(werte[key], JETZT, "mqtt:ebusd")
        return Measurement.missing(Quality.UNAVAILABLE, JETZT, key)

    return mess


def test_die_zahlen_des_hauses_ergeben_die_abschaetzung_aus_den_unterlagen(
    client: TestClient,
) -> None:
    """30 l/min mal 3,4 K sind rund 7,1 kW; bei 1,448 kW Aufnahme eine Arbeitszahl um 4,9.

    So steht es in docs/SENSORIK.md, von Hand gerechnet. Hier rechnet der Dienst dasselbe.
    """
    aus = wp.zusammensetzen(
        now=JETZT,
        snap=schnappschuss(client, 1.448),
        laeuft_laut_zaehler=True,
        mess=mess_aus(HAUS_LAEUFT),
    )
    assert aus.laeuft and aus.pumpe_laeuft
    assert aus.zustand_de == "heizt"
    assert aus.spreizung_k == 3.4
    assert aus.waermeleistung_kw == 7.07
    assert aus.arbeitszahl == 4.9
    assert aus.vorlauf_c.value == 39.9 and aus.heissgas_c.value == 46.4
    assert any("Abschätzungen" in h for h in aus.hinweise_de)


def test_im_stillstand_gibt_es_keine_waermeleistung_und_das_wort_heisst_steht(
    client: TestClient,
) -> None:
    """Zustand 15 heißt in der fremden Liste „Soft_fail"; an dieser Anlage ist es der Stillstand.

    Nach dem Lauf liegen Vorlauf und Rücklauf noch auseinander (46,8 gegen 39,6 °C). Ohne
    Durchfluss ist das keine Wärmeleistung.
    """
    steht = HAUS_LAEUFT | {
        "heat_pump_mode_code": 15.0,
        "heat_pump_flow_l_min": 0.0,
        "flow_temp_c": 46.8,
        "heat_pump_return_temp_c": 39.6,
        "heat_pump_bus_power_kw": 0.0,
    }
    aus = wp.zusammensetzen(
        now=JETZT, snap=schnappschuss(client, 0.02), laeuft_laut_zaehler=False, mess=mess_aus(steht)
    )
    assert not aus.laeuft and not aus.pumpe_laeuft
    assert aus.zustand_de == "steht"
    assert aus.spreizung_k == 7.2
    assert aus.waermeleistung_kw is None and aus.arbeitszahl is None


def test_ohne_zaehler_gilt_die_auskunft_der_maschine_und_ohne_bus_steht_es_da(
    client: TestClient,
) -> None:
    ohne_zaehler = wp.zusammensetzen(
        now=JETZT,
        snap=schnappschuss(client, None),
        laeuft_laut_zaehler=True,
        mess=mess_aus(HAUS_LAEUFT),
    )
    assert ohne_zaehler.arbeitszahl == 4.9
    stumm = wp.zusammensetzen(
        now=JETZT, snap=schnappschuss(client, 1.2), laeuft_laut_zaehler=True, mess=mess_aus({})
    )
    # Ohne Bus entscheidet der Zähler, ob sie läuft, und es wird nichts gerechnet.
    assert stumm.laeuft and stumm.zustand_de == "läuft"
    assert stumm.waermeleistung_kw is None and stumm.vorlauf_c.value is None
    assert "Vom Bus der Wärmepumpe kommt gerade nichts" in (stumm.bus_stumm_de or "")


def test_abtauen_und_unbekannte_zustaende_haben_ein_wort() -> None:
    assert wp.zustand_wort(9, True) == "taut ab"
    assert wp.zustand_wort(42, False) == "Zustand 42"
    assert 9 in wp.ARBEITET and 15 not in wp.ARBEITET


def test_die_vorfuehrung_zeigt_eine_stimmige_waermepumpe(client: TestClient) -> None:
    """Die Vorführung hat keinen Bus. Die Seite soll dort trotzdem zu sehen sein, mit Zahlen,
    die zueinander passen: läuft sie, gibt es Durchfluss, eine Spreizung und eine Arbeitszahl."""
    aus = client.get("/api/v1/waermepumpe").json()
    assert aus["zustand_de"] in {"heizt", "steht"}
    assert aus["vorlauf_c"]["value"] is not None
    assert len(aus["puffer_c"]) == 4
    if aus["laeuft"]:
        assert aus["durchfluss_l_min"]["value"] == 29.5
        assert 3.0 <= aus["arbeitszahl"] <= 5.5
    else:
        assert aus["waermeleistung_kw"] is None
    laeuft = wp.vorfuehrung(
        laeuft=True, aussen_c=5.0, leistung_kw=1.5, puffer_oben_c=46.0, puffer_unten_c=33.0
    )
    assert laeuft["flow_temp_c"] > laeuft["heat_pump_return_temp_c"]
    assert set(laeuft) >= set(wp.KEYS.values()) - {"flow_temp_c"} | {wp.ZUSTAND_KEY}


def test_schweigt_der_bus_nennt_die_seite_die_stelle_an_der_es_haengt(client: TestClient) -> None:
    """Am 14.11.2026 stand im Haus an jedem Buswert ein Fragezeichen und nirgends ein Grund."""
    aus = wp.zusammensetzen(
        now=JETZT,
        snap=schnappschuss(client, 3.3),
        laeuft_laut_zaehler=True,
        mess=mess_aus({}),
        bus_stumm_de="Der Grund.",
    )
    assert aus.bus_stumm_de == "Der Grund."
    # Kommt auch nur ein Wert, ist der Bus nicht stumm.
    aus = wp.zusammensetzen(
        now=JETZT,
        snap=schnappschuss(client, 3.3),
        laeuft_laut_zaehler=True,
        mess=mess_aus({"heat_pump_flow_l_min": 29.8}),
        bus_stumm_de="Der Grund.",
    )
    assert aus.bus_stumm_de is None


def test_die_auskunft_folgt_dem_weg_der_werte() -> None:
    from zoneinfo import ZoneInfo

    tz = ZoneInfo("Europe/Berlin")
    bus = frozenset({"pv_power_kw", wp.BUS_KENNZEICHEN})

    def satz(**kw: object) -> str:
        return wp.bus_auskunft(wp.BusStand(**kw), tz)  # type: ignore[arg-type]

    assert "nicht verbunden" in satz(bridge_online=False)
    # Die Bridge läuft, aber mit einer Zuordnung ohne den Bus (alter Stand im Zwischenspeicher).
    alt = satz(bridge_online=True, bridge_version="0.13.1", angekuendigt=frozenset({"pv_power_kw"}))
    assert "Version 0.13.1" in alt and "Zuordnung" in alt
    # Eine Bridge vor 0.14.2 kann die Stelle nicht nennen; der Satz sagt, wo sie steht.
    vor = satz(bridge_online=True, bridge_version="0.14.1", angekuendigt=bus)
    assert "ab Version 0.14.2" in vor and "Protokoll" in vor
    # Ab 0.14.2 kommt das Wort der Bridge, und jedes hat seinen Satz.
    einzel = {"thema": "ebusd", "nachrichten": "412", "namen": "23", "source_mode": "compare"}
    for lage, wort in [
        ("broker_getrennt", "Mosquitto"),
        ("kein_wort", "unter „ebusd“"),
        ("verstummt", "nichts mehr"),
        ("kein_signal", "Signal"),
        ("nicht_zugeordnet", "412 bisher, 23 verschiedene"),
        ("nur_mitlesen", "„compare“"),
        ("abgeschaltet", "„compare“"),
    ]:
        text = satz(
            bridge_online=True,
            bridge_version="0.14.2",
            angekuendigt=bus,
            lage=lage,
            einzelheiten=einzel,
        )
        assert wort in text, (lage, text)
        assert "{" not in text
    # Ohne Meldung der Bridge: sie kommt noch.
    assert "fünf Minuten" in satz(bridge_online=True, bridge_version="0.14.2", angekuendigt=bus)
    # Wann zuletzt etwas kam, steht in Ortszeit dabei (22:30 UTC ist 23:30 in Berlin).
    mit = satz(bridge_online=False, zuletzt=JETZT)
    assert mit.endswith("Der letzte Wert vom Bus kam am 13.11. um 23:30 Uhr.")
    # Ein unbekanntes Wort einer neueren Bridge wirft nichts um.
    assert satz(bridge_online=True, bridge_version="0.15.0", angekuendigt=bus, lage="neu")
