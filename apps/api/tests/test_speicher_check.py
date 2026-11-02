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
