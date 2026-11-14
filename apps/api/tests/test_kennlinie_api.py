"""Die gemessene Kennlinie als Antwort des Dienstes."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from dch_api.application import kennlinie as logik
from hems_core.domain.config import BufferConfig, HeatDemandConfig
from hems_core.thermal import kennlinie as kern

JETZT = datetime(2026, 11, 14, 10, 0, tzinfo=UTC)


def zeile(i: int, **werte: float | None) -> dict[str, float | str | None]:
    """Eine gespeicherte Minute, wie `minute_series` sie liefert: Zahlen des Hauses."""
    grund: dict[str, float | str | None] = {
        "ts": (JETZT - timedelta(minutes=60 - i)).isoformat(),
        "outdoor_temp_c": 6.5,
        "flow_temp_c": 36.2,
        "heat_pump_return_temp_c": 30.0,
        "heat_pump_flow_l_min": 30.1,
        "heat_pump_power_kw": 3.16,
        "heat_pump_mode_code": 3.0,
        "heat_pump_compressor_hz": 65.0,
    }
    grund.update(werte)
    return grund


def test_aus_gespeicherten_minuten_werden_messpunkte() -> None:
    zeilen = [zeile(i) for i in range(40)]
    # Eine Zeile ohne Zeitpunkt und eine mit einem Wort statt einer Zahl stören nicht.
    zeilen.append({"outdoor_temp_c": 5.0})
    zeilen[5] = zeile(5, heat_pump_flow_l_min=None)
    punkte = kern.messpunkte(logik.minuten(zeilen))
    assert len(punkte) >= 2
    assert all(abs(p.cop - 4.12) < 0.02 and p.aussen_c == 6.5 for p in punkte)


def test_die_antwort_sagt_was_dem_ausgleich_fehlt() -> None:
    def antwort(punkte: list[kern.Messpunkt]) -> object:
        return logik.zusammensetzen(
            now=JETZT, tage=30, punkte=punkte, heat=HeatDemandConfig(), buffer=BufferConfig()
        )

    def punkt(i: int, aussen: float, vorlauf: float, cop: float) -> kern.Messpunkt:
        return kern.Messpunkt(
            at=JETZT - timedelta(hours=i),
            minuten=10,
            aussen_c=aussen,
            vorlauf_c=vorlauf,
            cop=cop,
            waerme_kw=cop * 2,
            strom_kw=2.0,
        )

    leer = antwort([])
    assert leer.fit is None and "Noch kein Messpunkt" in (leer.fehlt_de or "")  # type: ignore[attr-defined]
    # Die Kennlinie des Fahrplans steht immer dabei, mit der Vorlauftemperatur, bei der sie gilt.
    assert [a.aussen_c for a in leer.annahme] == [-7.0, 2.0, 7.0, 15.0]  # type: ignore[attr-defined]
    assert leer.annahme_vorlauf_c == BufferConfig().target_temperature_c  # type: ignore[attr-defined]

    wenige = antwort([punkt(i, 6.0, 36.0, 4.0) for i in range(5)])
    assert wenige.fit is None and f"5 von {kern.MIN_PUNKTE}" in (wenige.fehlt_de or "")  # type: ignore[attr-defined]

    # Ein Vormittag: nur der Vorlauf streut. Die Formel nennt nur diesen Term.
    vormittag = antwort(
        [punkt(i, 6.0 + (i % 2), 34.0 + i, 6.2 - 0.05 * (34.0 + i)) for i in range(13)]
    )
    assert vormittag.fit is not None and vormittag.fit.art == "vorlauf"  # type: ignore[attr-defined]
    assert vormittag.fit.formel_de == "COP = 6,20 - 0,050 × Vorlauf"  # type: ignore[attr-defined]
    assert "Außentemperatur ist deshalb noch nicht bestimmt" in (vormittag.fehlt_de or "")  # type: ignore[attr-defined]
    assert "zwischen 34,0 und 46,0 °C Vorlauf" in vormittag.fit.geltung_de  # type: ignore[attr-defined]

    # Beide Temperaturen streuen unabhängig: die ganze Ebene, und es fehlt nichts.
    ebene = antwort(
        [
            punkt(i, ta, tv, 6.0 + 0.1 * ta - 0.06 * tv)
            for i, (ta, tv) in enumerate(
                (a, v) for a in (-5.0, 0.0, 5.0, 10.0) for v in (32.0, 40.0, 48.0)
            )
        ]
    )
    assert ebene.fit is not None and ebene.fit.art == "ebene" and ebene.fehlt_de is None  # type: ignore[attr-defined]
    assert ebene.fit.formel_de == "COP = 6,00 + 0,100 × Außentemperatur - 0,060 × Vorlauf"  # type: ignore[attr-defined]


def test_die_vorfuehrung_zeigt_eine_kennlinie_mit_ausgleich(client: TestClient) -> None:
    r = client.get("/api/v1/waermepumpe/kennlinie", params={"tage": 30})
    assert r.status_code == 200
    d = r.json()
    assert len(d["punkte"]) == 120 and d["tage"] == 30
    assert d["fit"]["art"] == "ebene"
    # Die erzeugten Punkte folgen 6,4 + 0,09 * außen - 0,065 * Vorlauf; der Ausgleich findet das.
    assert abs(d["fit"]["b_aussen"] - 0.09) < 0.02 and abs(d["fit"]["c_vorlauf"] + 0.065) < 0.01
    assert d["hinweise_de"][0].startswith("Vorführung")
    # Zweimal gefragt, zweimal dasselbe: die Streuung ist kein Zufall.
    assert (
        client.get("/api/v1/waermepumpe/kennlinie", params={"tage": 30}).json()["fit"] == d["fit"]
    )
    assert client.get("/api/v1/waermepumpe/kennlinie", params={"tage": 0}).status_code == 422
    # Die Technikseite der Vorführung nennt die Betriebsart.
    wp = client.get("/api/v1/waermepumpe").json()
    assert wp["kreis_de"] in ("Heizen", "Bereitschaft")
