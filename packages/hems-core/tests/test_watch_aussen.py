"""Die Gegenprobe der Außentemperatur gegen den Wetterdienst."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

from hems_core.domain.config import SensorTimeouts
from hems_core.watch.aussen import ABWEICHUNG_K, ALT_MIN, pruefe
from hems_core.watch.silence import RULES

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


#: Der Melde-Takt der Wetterstation über Home Assistant (docs/SENSORIK.md, „Die Außentemperatur":
#: die Station meldet stündlich). Sie ist die langsamste der beiden Quellen - über den eBUS der
#: Wärmepumpe kommt der Wert alle 5 bis 55 Sekunden - und setzt damit die Untergrenze.
MELDETAKT_STATION_S = 3600.0


def test_die_altersgrenze_der_aufnahme_ist_die_der_gegenprobe() -> None:
    """Dieselbe Frist in zwei Einheiten: 90 Minuten hier, 5400 Sekunden in der Aufnahme.

    Diese Prüfung ist die Herleitung der Zahl. Unten liegt der Melde-Takt der Station: eine
    Grenze auf dem Takt selbst verfällt genau dann, wenn die nächste Meldung fällig ist, und
    erzeugt bei jeder Verzögerung eine Lücke. Oben liegt diese Gegenprobe: ab `ALT_MIN` zeigt die
    Startseite nicht mehr den Messwert, sondern den Wetterdienst. Eine Aufnahme, die den Wert
    danach weiter `ok` nennt - bis zum 23.11.2026 drei Stunden lang - gibt ihn der Anlagenseite
    als brauchbar heraus und nennt ihn auf der Regelkreis-Karte gemessen, während die Anzeige der
    Startseite ihn schon aufgegeben hat.
    """
    frist_s = SensorTimeouts().outdoor_temp_s
    assert frist_s > MELDETAKT_STATION_S
    assert frist_s == ALT_MIN * 60.0


def test_der_waechter_bleibt_laenger_als_die_aufnahme() -> None:
    """180 Minuten gegen 90 - und das ist Absicht, nicht eine vergessene Zahl.

    Die beiden fragen Verschiedenes. Die Aufnahme fragt, ob der Wert noch die Luft draußen
    beschreibt; sie wird still `stale`, die Anzeige fällt auf den Wetterdienst zurück, und das
    kostet niemanden etwas. Der Wächter fragt, ob die Quelle verstummt ist, und seine Antwort
    geht einem Menschen aufs Telefon - dafür toleriert er eine ausgefallene Meldung mehr.

    Die Prüfung steht hier, weil die Zahl bis zum 23.11.2026 nur als Kommentar begründet war:
    die Produktionsregeln aus `hems_core.watch.silence.RULES` behauptete im ganzen Baum keine
    Prüfung, während die drei anderen Stellen dieser Größe je eine haben.
    """
    regel = next(r for r in RULES if r.name == "weather")
    assert regel.keys == ("outdoor_temp_c",)
    assert regel.silence_min == 180
    assert regel.silence_min * 60.0 > SensorTimeouts().outdoor_temp_s
    assert regel.severity == "warn", "eine fehlende Außentemperatur ist kein Alarm"
