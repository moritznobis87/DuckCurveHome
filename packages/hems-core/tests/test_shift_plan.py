"""Die Automatik entscheidet nur nach jetzt und nach dem Preis - und sie hebt nur an."""

from __future__ import annotations

import re
from datetime import UTC, datetime, timedelta

from hems_core.planning.price_windows import PricePoint, PriceWindow
from hems_core.thermal.shift_plan import ShiftPolicy, next_expensive, shift_target

TAG = datetime(2026, 1, 15, tzinfo=UTC)
POLICY = ShiftPolicy()


def preise(werte: list[float]) -> list[PricePoint]:
    """24 Stundenpreise ab Mitternacht."""
    return [
        PricePoint(start=TAG + timedelta(hours=h), end=TAG + timedelta(hours=h + 1), ct_kwh=v)
        for h, v in enumerate(werte)
    ]


def teuer(von: int, bis: int, ct: float = 45.0) -> PriceWindow:
    return PriceWindow(
        start=TAG + timedelta(hours=von),
        end=TAG + timedelta(hours=bis),
        kind="expensive",
        avg_ct_kwh=ct,
    )


# Billig bis 16 Uhr, teuer von 17 bis 20 Uhr.
WERTE = [20.0] * 17 + [45.0] * 3 + [25.0] * 4
FENSTER = [teuer(17, 20)]


def test_vor_dem_preishoch_wird_vorgeladen() -> None:
    z = shift_target(TAG + timedelta(hours=15), preise(WERTE), FENSTER, POLICY)
    assert z.phase == "laden"
    assert z.offset_k == 0.5
    assert z.until == TAG + timedelta(hours=17)
    assert "Vorladen" in z.reason_de and "25 ct" in z.reason_de
    # Zahlen mit Komma: Der Satz steht in der Anzeige und im Protokoll.
    assert not re.search(r"\d\.\d", z.reason_de)


def test_waehrend_des_preishochs_steht_wieder_der_wert_des_menschen() -> None:
    z = shift_target(TAG + timedelta(hours=18), preise(WERTE), FENSTER, POLICY)
    assert z.phase == "zehren"
    # Angehoben wird nie unter den Wert, den der Mensch gesetzt hat.
    assert z.offset_k == 0.0
    assert "zehrt" in z.reason_de


def test_zu_frueh_ist_noch_nichts_zu_tun() -> None:
    z = shift_target(TAG + timedelta(hours=9), preise(WERTE), FENSTER, POLICY)
    assert z.phase == "aus"
    assert z.offset_k == 0.0
    assert "Vorladen beginnt um 14:00" in z.reason_de


def test_nach_dem_preishoch_ist_schluss() -> None:
    z = shift_target(TAG + timedelta(hours=21), preise(WERTE), FENSTER, POLICY)
    assert z.phase == "aus"
    assert "Kein Preishoch" in z.reason_de


def test_ohne_abstand_bleibt_alles_wie_es_ist() -> None:
    # Teuer, aber nur zwei Cent über dem, was vorher gilt: dafür wird keine Wohnung angefasst.
    flach = [22.0] * 24
    z = shift_target(TAG + timedelta(hours=15), preise(flach), [teuer(17, 20, ct=24.0)], POLICY)
    assert z.phase == "aus"
    assert "zu wenig" in z.reason_de
    assert z.spread_ct == 2.0


def test_ohne_preise_wird_nicht_geraten() -> None:
    z = shift_target(TAG + timedelta(hours=15), [], FENSTER, POLICY)
    assert z.phase == "aus"
    assert "fehlen die Preise" in z.reason_de


def test_ein_fernes_preishoch_zaehlt_noch_nicht() -> None:
    morgen = [teuer(40, 43)]
    assert next_expensive(morgen, TAG, horizon_h=18) is None
    assert shift_target(TAG, preise(WERTE), morgen, POLICY).phase == "aus"


def test_absenken_nur_wenn_es_jemand_einstellt() -> None:
    streng = ShiftPolicy(draw_k=0.4)
    z = shift_target(TAG + timedelta(hours=18), preise(WERTE), FENSTER, streng)
    assert z.offset_k == -0.4
    assert "abgesenkt" in z.reason_de


def test_lange_preishochs_werden_nicht_endlos_gezehrt() -> None:
    lang = [teuer(17, 24)]
    spaet = shift_target(TAG + timedelta(hours=23, minutes=30), preise(WERTE), lang, POLICY)
    # Nach sechs Stunden ist der Vorrat ohnehin weg; dann ist die Automatik aus.
    assert spaet.phase == "aus"
    frueh = shift_target(TAG + timedelta(hours=20), preise(WERTE), lang, POLICY)
    assert frueh.phase == "zehren"


def test_dieselbe_minute_ergibt_dieselbe_entscheidung() -> None:
    """Keine Zeitgeber, kein Gedächtnis: Ein Neustart ändert nichts."""
    jetzt = TAG + timedelta(hours=15, minutes=20)
    a = shift_target(jetzt, preise(WERTE), FENSTER, POLICY)
    b = shift_target(jetzt, preise(WERTE), FENSTER, POLICY)
    assert a == b
