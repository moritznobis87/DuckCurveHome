"""Die Gegenprobe der Außentemperatur gegen den Wetterdienst."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

from hems_core.watch.aussen import ABWEICHUNG_K, ALT_MIN, pruefe

BERLIN = ZoneInfo("Europe/Berlin")
#: 12:49 im Haus, der Augenblick des Bildschirmfotos vom 13.11.2026.
JETZT = datetime(2026, 11, 13, 11, 49, tzinfo=UTC)


def test_der_fall_vom_13_11_ein_stehengebliebener_wert_mit_frischem_zeitstempel() -> None:
    """2,2 °C gemeldet, 8,6 °C laut Wetterdienst: angezeigt wird der Wetterdienst, mit Grund."""
    p = pruefe(2.2, JETZT - timedelta(minutes=5), 8.6, JETZT, BERLIN)
    assert p.angezeigt_c == 8.6
    assert p.quelle_de == "Wetterdienst"
    assert p.text_de == (
        "Der Messwert der Außentemperatur (2,2 °C) weicht um 6 Grad vom Wetterdienst ab "
        "(8,6 °C) und ist vermutlich stehengeblieben. Angezeigt wird der Wert des Wetterdienstes."
    )


def test_ein_alter_wert_wird_ersetzt_und_der_satz_nennt_seine_uhrzeit() -> None:
    p = pruefe(7.9, JETZT - timedelta(minutes=ALT_MIN + 30), 8.6, JETZT, BERLIN)
    assert p.angezeigt_c == 8.6 and p.quelle_de == "Wetterdienst"
    assert p.text_de == (
        "Der Messwert der Außentemperatur ist von 10:49 Uhr (7,9 °C). Angezeigt wird der Wert "
        "des Wetterdienstes (8,6 °C)."
    )
    assert p.alter_min == ALT_MIN + 30


def test_ein_frischer_wert_in_der_naehe_des_wetterdienstes_bleibt_stehen() -> None:
    # Eine gewöhnliche Abweichung zwischen Vorhersage und Wirklichkeit löst nichts aus.
    for gemessen in (8.6 - ABWEICHUNG_K, 8.6, 8.6 + ABWEICHUNG_K):
        p = pruefe(gemessen, JETZT - timedelta(minutes=20), 8.6, JETZT, BERLIN)
        assert (p.angezeigt_c, p.quelle_de, p.text_de) == (gemessen, "", "")


def test_ohne_wetterdienst_gibt_es_keine_gegenprobe_und_nichts_wird_ersetzt() -> None:
    frisch = pruefe(2.2, JETZT - timedelta(minutes=5), None, JETZT, BERLIN)
    assert (frisch.angezeigt_c, frisch.quelle_de, frisch.text_de) == (2.2, "", "")
    alt = pruefe(2.2, JETZT - timedelta(hours=3), None, JETZT, BERLIN)
    assert alt.angezeigt_c == 2.2 and alt.quelle_de == ""
    assert alt.text_de == "Die Außentemperatur (2,2 °C) ist von 09:49 Uhr."


def test_ohne_messwert_steht_der_wetterdienst_da_ohne_befund() -> None:
    """Dass die Quelle schweigt, meldet der Wächter selbst; hier gibt es keinen zweiten Satz."""
    p = pruefe(None, None, 8.6, JETZT, BERLIN)
    assert (p.angezeigt_c, p.quelle_de, p.text_de) == (8.6, "Wetterdienst", "")
    leer = pruefe(None, None, None, JETZT, BERLIN)
    assert (leer.angezeigt_c, leer.quelle_de, leer.text_de) == (None, "", "")
