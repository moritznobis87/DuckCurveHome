"""Der Endpunkt `/energy/speicher-check`: die Speicherbilanz gegen ihre beiden Zeugen.

Die Urteilslogik selbst steht in `packages/hems-core/tests/test_battery_check.py`; hier geht es
nur darum, dass die Kette steht: Minutenreihen lesen, in Wochenstuecken pruefen, als Text setzen.
"""

from __future__ import annotations

from fastapi.testclient import TestClient


def test_die_vorfuehrung_liefert_einen_bericht(client: TestClient) -> None:
    antwort = client.get("/api/v1/energy/speicher-check?period=day&anchor=2026-09-04")
    assert antwort.status_code == 200
    text = antwort.text

    # Die drei Messungen stehen nebeneinander, und jede sagt, woher sie kommt.
    assert "Gemessen (battery_power_kw)" in text
    assert "Gegenprobe 1: der Ladestand" in text
    assert "Gegenprobe 2: die Leistungsbilanz" in text
    assert "Urteil" in text
    # Der Vorfuehrungsspeicher ist gesund: 95 % Ladewirkungsgrad, kein Nullpunktfehler.
    assert "Unauffällig" in text
    # Und die Tabelle steht da, mit mindestens einer Zeile.
    assert "Zeitraum     Minuten" in text


def test_ein_leerer_zeitraum_bricht_nicht(client: TestClient) -> None:
    # Weit vor dem Beginn der Vorfuehrung: keine Zeile, aber auch kein Fehler.
    antwort = client.get("/api/v1/energy/speicher-check?period=day&anchor=2020-01-01")
    assert antwort.status_code == 200
    assert "Kein Ladestand" in antwort.text


def test_der_zeitraum_laesst_sich_waehlen(client: TestClient) -> None:
    antwort = client.get("/api/v1/energy/speicher-check?period=week&anchor=2026-09-04")
    assert antwort.status_code == 200
    assert "(week, Ortszeit" in antwort.text


def test_die_zerlegung_des_verlusts_steht_im_bericht() -> None:
    """Der Textteil der Zerlegung, ohne eine Datenbank: gebaut wird der Befund von Hand.

    Die Rechnung selbst steht in `test_battery_check.py`; hier geht es um die Zeilen, die daraus
    entstehen - sie laufen nur in Zeitraeumen mit genug Tagen und wuerden sonst nie geprueft.
    """
    from datetime import UTC, datetime, timedelta

    from dch_api.application.energy_accounting import _speicher_text
    from hems_core.accounting import (
        Abschnitt,
        RuheBefund,
        SpeicherBefund,
        TiefBefund,
        Wirkungsgrade,
        aufteilung,
        summe_abschnitte,
    )
    from hems_core.simulation import BERLIN

    t0 = datetime(2026, 10, 1, tzinfo=UTC)
    tage = []
    for i, (aktiv, kw) in enumerate(
        [(600, 0.5), (700, 1.2), (400, 2.0), (800, 0.4), (500, 1.5), (900, 0.8), (300, 2.4)]
    ):
        laden = kw * aktiv / 60.0
        verlust = 0.12 * aktiv / 60.0 + 0.05 * 2 * laden
        tage.append(
            Abschnitt(
                von=t0 + timedelta(days=i),
                bis=t0 + timedelta(days=i, hours=23, minutes=59),
                minuten=1440,
                laden_kwh=round(laden, 3),
                entladen_kwh=round(laden, 3),
                laden_dunkel_kwh=0.0,
                soc_von=0.5,
                soc_bis=round(0.5 - verlust / 5.1, 4),
                delta_speicher_kwh=round(-verlust, 4),
                restglied_kw=None,
                restglied_minuten=0,
                aktiv_minuten=aktiv,
            )
        )
    befund = SpeicherBefund(
        kapazitaet_kwh=5.1,
        gesamt=summe_abschnitte(tage),
        tage=tage,
        ruhe=RuheBefund(0, 0, 0.0, 0.0),
        ruhe_voll_minuten=0,
        wirkungsgrade=Wirkungsgrade(),
        tief=TiefBefund(),
        verlustquelle=aufteilung(tage),
    )
    text = "\n".join(_speicher_text(befund, t0, t0 + timedelta(days=7), BERLIN, "week"))
    assert "Woran der Verlust haengt" in text
    # 120 W Grundlast und 5 % vom Durchsatz, so wie die Tage gebaut sind.
    assert "120 W" in text
    assert "5.0% des Durchsatzes" in text
    # Und die Tabelle hat jetzt die Spalte mit den aktiven Minuten.
    assert "aktiv" in text
