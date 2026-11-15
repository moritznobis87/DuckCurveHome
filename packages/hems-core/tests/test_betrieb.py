"""Der Betrieb über Tage: Läufe, Abtauen, Takten und die Heizkurve des Reglers."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from hems_core.thermal import betrieb as b
from hems_core.thermal import kennlinie as k

T0 = datetime(2026, 11, 14, 0, 0, tzinfo=UTC)


def minute(i: int, **kw: float | None) -> k.Minute:
    """Eine Minute im Heizbetrieb mit den Zahlen des Hauses vom 14.11.2026, 10:20."""
    werte: dict[str, float | None] = {
        "aussen_c": 6.5,
        "vorlauf_c": 36.2,
        "ruecklauf_c": 30.0,
        "durchfluss_l_min": 30.1,
        "strom_kw": 3.0,
        "modus": 3.0,
        "vorlauf_soll_c": 40.0,
    }
    werte.update(kw)
    return k.Minute(ts=T0 + timedelta(minutes=i), **werte)  # type: ignore[arg-type]


def steht(i: int, **kw: float | None) -> k.Minute:
    return minute(i, modus=15.0, strom_kw=0.02, durchfluss_l_min=0.0, **kw)


def test_ein_lauf_reicht_vom_anlaufen_bis_zum_halt_und_abtauen_beendet_ihn_nicht() -> None:
    """60 Minuten Lauf, darin zweimal Abtauen (fünf und drei Minuten), dann Stillstand, dann ein
    kurzer Lauf von acht Minuten. Zwei Läufe, zwei Starts, acht Minuten Abtauen."""
    reihe = [steht(i) for i in range(10)]
    for i in range(10, 70):
        taut = 30 <= i < 35 or 50 <= i < 53
        reihe.append(minute(i, modus=9.0, vorlauf_c=28.0, ruecklauf_c=31.0) if taut else minute(i))
    reihe += [steht(i) for i in range(70, 100)]
    reihe += [minute(i) for i in range(100, 108)]
    reihe += [steht(i) for i in range(108, 120)]
    aus = b.auswerten(reihe, UTC)
    assert [(lf.minuten, lf.abtau_min, lf.abtauungen, lf.angeschnitten) for lf in aus.laeufe] == [
        (60, 8, 2, False),
        (8, 0, 0, False),
    ]
    tag = aus.tage[0]
    assert (tag.starts, tag.lauf_min, tag.abtau_min, tag.abtauungen) == (2, 68, 8, 2)
    assert tag.lauf_median_min == 34.0
    # Die Klassen der Lauflängen: einer unter zehn Minuten, einer zwischen 40 und 90.
    assert aus.klassen == [1, 0, 0, 1, 0]
    assert b.klasse(9) == 0 and b.klasse(10) == 1 and b.klasse(500) == 4


def test_die_arbeitszahl_des_tages_enthaelt_das_abtauen_die_im_heizbetrieb_nicht() -> None:
    """Im Heizen 13,0 kW Wärme aus 3,0 kW Strom. Beim Abtauen fließt Wärme zurück: der Vorlauf
    liegt drei Grad unter dem Rücklauf, das sind 6,3 kW mit negativem Vorzeichen. Über den Tag
    liegt die Arbeitszahl deshalb unter der im reinen Heizbetrieb."""
    reihe = [steht(0)]
    for i in range(1, 121):
        taut = 60 <= i < 70
        reihe.append(
            minute(i, modus=9.0, vorlauf_c=28.0, ruecklauf_c=31.0, strom_kw=2.0)
            if taut
            else minute(i)
        )
    reihe.append(steht(121))
    aus = b.auswerten(reihe, UTC)
    tag = aus.tage[0]
    heizen = 30.1 * 6.2 * k.KW_JE_L_MIN_K
    abtauen = 30.1 * -3.0 * k.KW_JE_L_MIN_K
    waerme = (110 * heizen + 10 * abtauen) / 60
    strom = (110 * 3.0 + 10 * 2.0) / 60
    assert tag.waerme_kwh == pytest.approx(waerme, abs=0.01)
    assert tag.cop_tag == pytest.approx(waerme / strom, abs=0.01)
    assert tag.cop_heizen == pytest.approx(heizen / 3.0, abs=0.01)
    assert tag.cop_tag < tag.cop_heizen
    assert b.waerme_kw(minute(0, vorlauf_c=28.0, ruecklauf_c=31.0)) == pytest.approx(abtauen)
    # Ohne Durchfluss fließt nichts; ohne Wert ist die Wärme unbekannt, nicht null.
    assert b.waerme_kw(minute(0, durchfluss_l_min=0.0)) == 0.0
    assert b.waerme_kw(minute(0, ruecklauf_c=None)) is None


def test_ein_lauf_am_rand_der_daten_oder_an_einer_luecke_ist_angeschnitten() -> None:
    # Die Daten beginnen mitten im Lauf und enden mitten im nächsten.
    reihe = [minute(i) for i in range(20)] + [steht(i) for i in range(20, 40)]
    reihe += [minute(i) for i in range(40, 60)]
    aus = b.auswerten(reihe, UTC)
    assert [lf.angeschnitten for lf in aus.laeufe] == [True, True]
    assert aus.klassen == [0, 0, 0, 0, 0] and aus.tage[0].lauf_median_min is None
    # Eine Lücke von zehn Minuten mitten im Lauf: zwei angeschnittene Stücke, kein langer Lauf.
    luecke = [steht(0)] + [minute(i) for i in range(1, 60) if not 20 <= i < 30] + [steht(60)]
    aus = b.auswerten(luecke, UTC)
    assert [(lf.minuten, lf.angeschnitten) for lf in aus.laeufe] == [(19, True), (30, True)]


def test_der_tag_beginnt_nach_der_uhr_am_ort() -> None:
    from zoneinfo import ZoneInfo

    berlin = ZoneInfo("Europe/Berlin")
    # 22:30 bis 23:30 UTC ist in Berlin 23:30 bis 00:30: der Lauf beginnt am 14. und reicht in
    # den 15. Der Start zählt am 14., die Minuten an dem Tag, an dem sie liegen.
    reihe = [steht(22 * 60 + 29)] + [minute(22 * 60 + 30 + i) for i in range(60)]
    reihe.append(steht(23 * 60 + 30))
    aus = b.auswerten(reihe, berlin)
    assert [(t.tag.day, t.starts, t.lauf_min) for t in aus.tage] == [(14, 1, 30), (15, 0, 30)]


def test_die_heizkurve_des_reglers_entsteht_aus_dem_sollwert_ueber_der_aussentemperatur() -> None:
    """Der Regler gibt bei null Grad 45 Grad Vorlauf vor und je Grad wärmer 0,8 Grad weniger.
    Acht Stunden Heizbetrieb bei acht Außentemperaturen finden diese Gerade wieder."""
    reihe = []
    for stunde in range(8):
        aussen = -4.0 + 2.0 * stunde
        for i in range(60):
            reihe.append(
                minute(stunde * 60 + i, aussen_c=aussen, vorlauf_soll_c=45.0 - 0.8 * aussen)
            )
    aus = b.auswerten(reihe, UTC)
    assert len(aus.stunden) == 8 and aus.stunden[0].minuten == 60
    g = aus.heizkurve
    assert g is not None and g.n == 8
    assert g.a == pytest.approx(45.0, abs=0.01) and g.b == pytest.approx(-0.8, abs=0.001)
    assert g.r2 == pytest.approx(1.0) and (g.aussen_von_c, g.aussen_bis_c) == (-4.0, 10.0)
    assert g.soll(5.0) == pytest.approx(41.0, abs=0.01)
    # Bei fast gleichem Wetter gibt es keine Gerade, nur die Punkte.
    flach = [minute(i, aussen_c=6.0 + (i // 60) * 0.2) for i in range(8 * 60)]
    aus = b.auswerten(flach, UTC)
    assert len(aus.stunden) == 8 and aus.heizkurve is None
    # Eine Stunde mit weniger als zehn Minuten Heizbetrieb zählt nicht.
    kurz = [minute(i) for i in range(8)] + [steht(i) for i in range(8, 60)]
    assert b.auswerten(kurz, UTC).stunden == []


def test_heizstab_minuten_werden_je_tag_gezaehlt() -> None:
    reihe = [steht(0)] + [minute(i, strom_kw=8.8 if 30 <= i < 40 else 3.0) for i in range(1, 61)]
    reihe.append(steht(61))
    aus = b.auswerten(reihe, UTC)
    assert aus.tage[0].zusatz_min == 10 and aus.laeufe[0].zusatz_min == 10
