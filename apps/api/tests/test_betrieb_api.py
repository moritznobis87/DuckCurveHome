"""Der Betrieb der Wärmepumpe über Tage als Antwort des Dienstes."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from dch_api.application import betrieb as logik
from hems_core.thermal import betrieb as kern

JETZT = datetime(2026, 11, 14, 12, 0, tzinfo=UTC)


def zeile(i: int, laeuft: bool, **werte: float | None) -> dict[str, float | str | None]:
    """Eine gespeicherte Minute, wie `minute_series` sie liefert."""
    grund: dict[str, float | str | None] = {
        "ts": (JETZT - timedelta(minutes=600 - i)).isoformat(),
        "outdoor_temp_c": 6.5,
        "flow_temp_c": 36.2 if laeuft else 30.0,
        "heat_pump_return_temp_c": 30.0,
        "heat_pump_flow_l_min": 30.1 if laeuft else 0.0,
        "heat_pump_power_kw": 3.0 if laeuft else 0.02,
        "heat_pump_mode_code": 3.0 if laeuft else 15.0,
        "heat_pump_flow_setpoint_c": 40.0,
    }
    grund.update(werte)
    return grund


def test_aus_gespeicherten_minuten_werden_laeufe_und_saetze() -> None:
    """Zwei Läufe von 60 und 8 Minuten, im ersten fünf Minuten Abtauen."""
    zeilen = [zeile(i, False) for i in range(10)]
    zeilen += [
        zeile(i, True, heat_pump_mode_code=9.0, flow_temp_c=28.0, heat_pump_return_temp_c=31.0)
        if 40 <= i < 45
        else zeile(i, True)
        for i in range(10, 70)
    ]
    zeilen += [zeile(i, False) for i in range(70, 100)]
    zeilen += [zeile(i, True) for i in range(100, 108)]
    zeilen += [zeile(i, False) for i in range(108, 120)]
    aus = logik.zusammensetzen(
        now=JETZT, tage=14, betrieb=kern.auswerten(logik.minuten(zeilen), UTC)
    )
    assert (aus.starts, aus.lauf_min, aus.abtau_min, aus.abtauungen) == (2, 68, 5, 1)
    assert [(lf.minuten, lf.abtauungen) for lf in aus.laeufe] == [(60, 1), (8, 0)]
    assert [(k.von_min, k.bis_min, k.laeufe) for k in aus.klassen] == [
        (0, 10, 1),
        (10, 20, 0),
        (20, 40, 0),
        (40, 90, 1),
        (90, None, 0),
    ]
    assert aus.lauf_median_min == 34.0
    assert aus.cop_gesamt is not None and aus.cop_heizen is not None
    assert aus.cop_gesamt < aus.cop_heizen
    assert aus.saetze_de[0] == (
        "Die Wärmepumpe lief 1 h 8 min in 2 Läufen, an Tagen mit Betrieb im Mittel 2,0 Starts. "
        "Ein Lauf dauerte im Mittel 34 Minuten; 1 von 2 waren kürzer als zehn Minuten."
    )
    assert aus.saetze_de[1] == "Abgetaut wurde einmal, zusammen 5 Minuten: 7,4 % der Laufzeit."
    # 63 Minuten Heizen mit 13,0 kW und 5 Minuten Abtauen mit -6,3 kW sind 13,2 kWh, bei 3,4 kWh
    # Strom. Im Heizbetrieb allein sind es 13,0 durch 3,0.
    assert aus.saetze_de[2] == (
        "Über alles gerechnet wurden aus 3,4 kWh Strom 13,2 kWh Wärme: Arbeitszahl 3,87. "
        "Im eingeschwungenen Heizbetrieb allein waren es 4,34."
    )
    # Zwei Stunden Heizbetrieb reichen nicht für eine Heizkurve; die Stunden selbst stehen da.
    assert aus.heizkurve is None
    assert [(s.minuten, s.soll_c) for s in aus.stunden] == [(45, 40.0), (18, 40.0)]


def test_ohne_lauf_steht_das_da_und_nichts_wird_erfunden() -> None:
    zeilen = [zeile(i, False) for i in range(120)]
    aus = logik.zusammensetzen(
        now=JETZT, tage=14, betrieb=kern.auswerten(logik.minuten(zeilen), UTC)
    )
    assert aus.starts == 0 and aus.laeufe == [] and aus.cop_gesamt is None
    assert aus.saetze_de == [
        "In diesem Zeitraum ist nach den gespeicherten Werten kein Lauf der Wärmepumpe."
    ]
    leer = logik.zusammensetzen(now=JETZT, tage=14, betrieb=kern.auswerten([], UTC))
    assert leer.tage == [] and leer.lauf_median_min is None


def test_die_formel_der_heizkurve_liest_sich() -> None:
    g = kern.Gerade(a=44.0, b=-0.7, n=24, r2=0.98, aussen_von_c=-2.0, aussen_bis_c=11.0)
    assert logik.formel(g) == "Sollwert = 44,0 - 0,70 × Außentemperatur"


def test_die_vorfuehrung_zeigt_takten_abtauen_und_die_heizkurve(client: TestClient) -> None:
    r = client.get("/api/v1/waermepumpe/betrieb", params={"tage": 14})
    assert r.status_code == 200
    d = r.json()
    assert d["zeitraum_tage"] == 14 and len(d["tage"]) >= 14
    assert d["starts"] > 30 and d["abtauungen"] > 0 and d["zusatz_min"] > 0
    # Die erzeugte Maschine folgt 35,7 - 0,7 * außen; die Auszählung findet das.
    assert abs(d["heizkurve"]["a"] - 35.7) < 0.5 and abs(d["heizkurve"]["b"] + 0.7) < 0.05
    # Anlauf, Abtauen und Heizstab kosten: über alles liegt die Arbeitszahl unter der im
    # eingeschwungenen Heizbetrieb.
    assert 3.0 < d["cop_gesamt"] < d["cop_heizen"] < 6.0
    assert d["hinweise_de"][0].startswith("Vorführung")
    # Die Teile passen zusammen: die Summen sind die der Tage.
    assert d["starts"] == sum(t["starts"] for t in d["tage"])
    assert d["lauf_min"] == sum(t["lauf_min"] for t in d["tage"])
    assert client.get("/api/v1/waermepumpe/betrieb", params={"tage": 0}).status_code == 422
