"""Die Einstellungen des Reglers: gelesen über den Bus, als Liste für die Seite „Regler“."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import yaml
from fastapi.testclient import TestClient

from dch_api.application import regler as logik
from hems_core.domain.measurement import Measurement, Quality

JETZT = datetime(2026, 11, 15, 10, 0, tzinfo=UTC)


def mess_aus(werte: dict[str, float], alter_s: float = 60.0):  # type: ignore[no-untyped-def]
    def mess(key: str) -> Measurement:
        if key not in werte:
            return Measurement.missing(Quality.UNAVAILABLE, JETZT, key)
        m = Measurement.ok(werte[key], JETZT - timedelta(seconds=alter_s), "mqtt:ebusd")
        return m.aged(JETZT, logik.STALE_S)

    return mess


def test_gelesene_einstellungen_stehen_mit_wert_und_lesart_da() -> None:
    aus = logik.zusammensetzen(now=JETZT, mess=mess_aus(logik.vorfuehrung()))
    assert aus.gelesen == 12 and len(aus.werte) == 12
    assert aus.satz_de == "Alle 12 Einstellungen gelesen. Bitte mit dem Bediengerät vergleichen."
    nach = {w.schluessel: w for w in aus.werte}
    steil = nach["heat_pump_set_slope"]
    assert (steil.wert.value, steil.stellen, steil.gruppe_de, steil.kennung) == (
        0.7,
        2,
        "Heizkurve",
        "6a71",
    )
    # Eine Kennzahl bleibt eine Zahl; was die Busbeschreibung dazu sagt, steht daneben.
    art = nach["heat_pump_set_curve_type"]
    assert art.wert.value == 2.0 and art.lesart_de == "nach Außentemperatur"
    assert nach["heat_pump_set_flow_max_c"].lesart_de is None
    assert [w.gruppe_de for w in aus.werte].count("Warmwasser") == 3


def test_fehlende_und_alte_einstellungen_werden_nicht_als_gelesen_gezaehlt() -> None:
    leer = logik.zusammensetzen(now=JETZT, mess=mess_aus({}))
    assert leer.gelesen == 0 and leer.satz_de.startswith("Noch keine Einstellung gelesen.")
    teil = logik.zusammensetzen(
        now=JETZT, mess=mess_aus({"heat_pump_set_slope": 1.2, "heat_pump_set_dhw_mode": 7.0})
    )
    assert teil.gelesen == 2 and teil.satz_de.startswith("2 von 12 Einstellungen gelesen.")
    # Eine Zahl, die die Busbeschreibung nicht kennt, bekommt keine Lesart.
    assert {w.schluessel: w for w in teil.werte}["heat_pump_set_dhw_mode"].lesart_de is None
    # Älter als eine halbe Stunde gilt nicht mehr als gelesen.
    alt = logik.zusammensetzen(now=JETZT, mess=mess_aus(logik.vorfuehrung(), alter_s=3600.0))
    assert alt.gelesen == 0


def test_jede_einstellung_ist_in_der_zuordnung_des_hauses_und_im_add_on(client: TestClient) -> None:
    """Drei Stellen müssen dieselben zwölf kennen: die Zeilen zum Abfragen im Add-on, die
    Zuordnung der Bridge und diese Liste. Fehlt eine, bleibt der Wert still leer."""
    from pathlib import Path

    wurzel = Path(__file__).resolve().parents[3]
    karte = yaml.safe_load((wurzel / "config" / "entities.home.yaml").read_text(encoding="utf-8"))
    ebus = next(m for m in karte["mqtt"] if m.get("kind") == "ebusd")
    zugeordnet = {
        v["wert"]: thema
        for thema, v in ebus["components"].items()
        if thema.startswith("energymgr/e_")
    }
    zeilen = {
        z.split(",")[2]: z.split(",")[7]
        for z in (wurzel / "addons" / "duckcurve_ebusd" / "aerotop_abfragen.csv")
        .read_text(encoding="utf-8")
        .splitlines()
        if z.startswith("r9,")
    }
    for e in logik.EINSTELLUNGEN:
        assert e.key in zugeordnet, e.key
        assert zeilen[zugeordnet[e.key].split("/")[1]] == e.kennung, e.key
    assert len(zeilen) == len(logik.EINSTELLUNGEN) == 12

    d = client.get("/api/v1/waermepumpe/einstellungen").json()
    assert d["gelesen"] == 12 and d["hinweise_de"][0].startswith("Vorführung")
