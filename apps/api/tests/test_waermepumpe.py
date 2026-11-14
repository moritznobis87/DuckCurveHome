"""Die Technikseite der Wärmepumpe: Zusammensetzung, Abschätzung und die Vorführung."""

from __future__ import annotations

from datetime import UTC, datetime

import pytest
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
    # Am 14.11.2026 stand im Haus genau dieser Satz: Version 0.14.2, Zuordnung ohne Bus. Das
    # Protokoll zeigte dann die eigene Datei in /config; der Satz nennt sie und das Update.
    assert "/config/duckcurve/entities.yaml" in alt and "Update genügt" in alt
    # Ab 0.14.3 ergänzt die Datei das Repository, und die Bridge sagt, woher ihre Zuordnung
    # stammt. Fehlt der Bus dann noch, hat es einen dieser Gründe.
    ohne = {"bridge_online": True, "bridge_version": "0.14.3", "angekuendigt": frozenset({"x"})}
    datei = {"herkunft": "datei", "ort": "/config/duckcurve/entities.yaml"}
    verboten = satz(**ohne, zuordnung=datei)
    assert "allein die Datei /config/duckcurve/entities.yaml" in verboten
    assert "ersetzt_repository" in verboten
    kein_netz = satz(**ohne, zuordnung={**datei, "grund": "timed out"})
    assert "nicht zu erreichen (timed out)" in kein_netz and "ersetzt_repository" not in kein_netz
    lager = satz(
        **ohne,
        zuordnung={"herkunft": "zwischenspeicher", "ort": "/data/x", "grund": "timed out"},
    )
    assert "letzten Abruf" in lager and "(timed out)" in lager
    for art in ("repository", "datei+repository", "datei+zwischenspeicher"):
        assert "entities_url" in satz(**ohne, zuordnung={"herkunft": art, "ort": "x"})
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


def test_die_kennzahl_des_reglers_bekommt_nur_ein_wort_das_im_haus_bestaetigt_ist(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Am 14.11.2026 stand im Haus „Puffer kühlen" an einer Maschine, die im November den
    Puffer heizt: das Wort der fremden Liste zur Kennzahl 20. Seitdem steht die Zahl da, und ein
    Wort nur für die 0, die in drei Protokollen bei stehender Maschine stand."""

    def mit(code: float | None, **werte: float) -> object:
        bus = {**HAUS_LAEUFT, **werte}
        if code is not None:
            bus["heat_pump_cycle_code"] = code
        return wp.zusammensetzen(
            now=JETZT,
            snap=schnappschuss(client, 1.448),
            laeuft_laut_zaehler=True,
            mess=mess_aus(bus),
        )

    zwanzig = mit(20.0)
    assert (zwanzig.kreis_code, zwanzig.kreis_de) == (20, "Kennzahl 20")  # type: ignore[attr-defined]
    # Keine Zuordnung, keine Behauptung: die Zeichnung zeigt nicht, wohin eingespeist wird.
    assert zwanzig.einspeisung is None  # type: ignore[attr-defined]
    assert any("Kennzahl 20" in h and "nicht entschlüsselt" in h for h in zwanzig.hinweise_de)  # type: ignore[attr-defined]
    assert "kühlen" not in " ".join(zwanzig.hinweise_de)  # type: ignore[attr-defined]
    assert mit(0.0, heat_pump_flow_l_min=0.0).kreis_de == "Bereitschaft"  # type: ignore[attr-defined]
    ohne = mit(None)
    assert (ohne.kreis_code, ohne.kreis_de, ohne.einspeisung) == (None, None, None)  # type: ignore[attr-defined]
    # Kein Wort der fremden Liste ist übrig; was dazukommt, kommt aus der Auszählung im Haus.
    assert wp.KREIS_DE == {0: "Bereitschaft"} and wp.EINSPEISUNG == {}

    # Ist eine Kennzahl einmal zugeordnet, führt die Zeichnung den Vorlauf danach, aber nur,
    # solange die Pumpe läuft.
    monkeypatch.setattr(wp, "EINSPEISUNG", {20: "tiefer", 16: "oben"})
    assert mit(20.0).einspeisung == "tiefer"  # type: ignore[attr-defined]
    assert mit(16.0).einspeisung == "oben"  # type: ignore[attr-defined]
    assert mit(20.0, heat_pump_flow_l_min=0.0).einspeisung is None  # type: ignore[attr-defined]
    assert not any("nicht entschlüsselt" in h for h in mit(20.0).hinweise_de)  # type: ignore[attr-defined]


def test_die_auszaehlung_zeigt_was_die_maschine_unter_jeder_kennzahl_tat(
    client: TestClient,
) -> None:
    from datetime import timedelta

    from dch_api.application import reglerkennzahl as rk

    def zeile(i: int, code: float, **werte: float | None) -> dict[str, float | str | None]:
        return {
            "ts": (JETZT + timedelta(minutes=i)).isoformat(),
            "heat_pump_cycle_code": code,
            **werte,
        }

    zeilen: list[dict[str, float | str | None]] = []
    # 30 Minuten Stillstand unter der 0.
    zeilen += [zeile(i, 0.0, heat_pump_mode_code=15.0, hp_release_contact=0.0) for i in range(30)]
    # 40 Minuten Lauf unter der 20: Vorlauf 38, Sollwert 45, der Speicher wird unten wärmer
    # (0,1 K je Minute), oben nicht. Angefordert von Duck Curve Home.
    zeilen += [
        zeile(
            30 + i,
            20.0,
            heat_pump_mode_code=3.0,
            flow_temp_c=38.0,
            heat_pump_flow_setpoint_c=45.0,
            buffer_temp_top_c=50.0,
            buffer_temp_mid_bottom_c=34.0 + 0.1 * i,
            hp_release_contact=1.0,
        )
        for i in range(40)
    ]
    # Eine Minute, in der die Kennzahl wechselte (Mittel 10), und eine ohne Kennzahl: zählen nicht.
    zeilen.append(zeile(70, 10.0 + 0.4, heat_pump_mode_code=3.0))
    zeilen.append({"ts": (JETZT + timedelta(minutes=71)).isoformat()})
    # Zehn Minuten Lauf unter der 16: zu kurz für eine Erwärmungsrate.
    zeilen += [
        zeile(
            72 + i,
            16.0,
            heat_pump_mode_code=3.0,
            flow_temp_c=55.0,
            buffer_temp_top_c=50.0 + i,
            buffer_temp_mid_bottom_c=40.0,
        )
        for i in range(10)
    ]

    aus = {z.code: z for z in rk.auswerten(zeilen)}
    assert set(aus) == {0, 20, 16}
    assert (aus[0].minuten, aus[0].lauf_min, aus[0].vorlauf_c, aus[0].angefordert_anteil) == (
        30,
        0,
        None,
        0.0,
    )
    z = aus[20]
    assert (z.minuten, z.lauf_min, z.vorlauf_c, z.vorlauf_soll_c, z.angefordert_anteil) == (
        40,
        40,
        38.0,
        45.0,
        1.0,
    )
    assert z.oben_k_h == 0.0 and z.unten_k_h == 6.0
    assert (aus[16].lauf_min, aus[16].oben_k_h, aus[16].unten_k_h) == (10, None, None)
    # Die häufigste Kennzahl steht zuerst.
    assert [x.code for x in rk.auswerten(zeilen)] == [20, 0, 16]

    r = client.get("/api/v1/waermepumpe/kennzahlen")
    assert r.status_code == 200
    vor = {x["code"]: x for x in r.json()["zeilen"]}
    # In der Vorführung wird der Speicher unter der 2 unten wärmer und unter der 3 oben.
    assert vor[2]["unten_k_h"] > 3 and vor[2]["oben_k_h"] == 0
    assert vor[3]["oben_k_h"] > 3 and vor[3]["unten_k_h"] == 0
    assert vor[0]["lauf_min"] == 0


def test_nimmt_der_zaehler_viel_mehr_auf_als_die_maschine_steht_es_da(client: TestClient) -> None:
    """14.11.2026, 11:18 im Haus: 8,84 kW am Zähler bei 64 Hz, Arbeitszahl 1,6, und die Seite
    sagte nichts dazu. Der Hausherr vermutete ein Abtauen; es war etwas, das neben dem
    Verdichter Strom nahm."""
    bus = {**HAUS_LAEUFT, "heat_pump_bus_power_kw": 3.1, "heat_pump_flow_l_min": 30.2}
    aus = wp.zusammensetzen(
        now=JETZT, snap=schnappschuss(client, 8.84), laeuft_laut_zaehler=True, mess=mess_aus(bus)
    )
    assert aus.zusatz_kw == 5.74
    satz = next(h for h in aus.hinweise_de if "Heizstab" in h)
    assert "8,84 kW" in satz and "3,10 kW" in satz and "Rund 5,7 kW" in satz
    # Im gewöhnlichen Lauf weichen Zähler und Maschine um Lüfter und Pumpe ab: kein Zusatz.
    normal = wp.zusammensetzen(
        now=JETZT, snap=schnappschuss(client, 3.3), laeuft_laut_zaehler=True, mess=mess_aus(bus)
    )
    assert normal.zusatz_kw is None and not any("Heizstab" in h for h in normal.hinweise_de)
