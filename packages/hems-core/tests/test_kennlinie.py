"""Die gemessene Kennlinie: Messpunkte aus Minuten, Ausgleich nach kleinsten Quadraten."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from hems_core.thermal import kennlinie as k

T0 = datetime(2026, 11, 14, 9, 0, tzinfo=UTC)


def minute(i: int, **kw: float | None) -> k.Minute:
    """Eine Minute im Heizbetrieb mit den Zahlen des Hauses vom 14.11.2026, 10:20."""
    werte: dict[str, float | None] = {
        "aussen_c": 6.5,
        "vorlauf_c": 36.2,
        "ruecklauf_c": 30.0,
        "durchfluss_l_min": 30.1,
        "strom_kw": 3.16,
        "modus": 3.0,
        "hz": 65.0,
    }
    werte.update(kw)
    return k.Minute(ts=T0 + timedelta(minutes=i), **werte)  # type: ignore[arg-type]


def test_ein_fenster_im_heizbetrieb_ergibt_die_arbeitszahl_des_hauses() -> None:
    """30,1 l/min mal 6,2 K mal 4,186/60 sind 13,0 kW; durch 3,16 kW eine Arbeitszahl von 4,1.

    So stand es am 14.11.2026 um 10:20 auf der Seite der Wärmepumpe. Die ersten zehn Minuten
    nach dem Start zählen nicht, das Fenster danach schon.
    """
    punkte = k.messpunkte([minute(i) for i in range(30)])
    assert [p.at for p in punkte] == [T0 + timedelta(minutes=10), T0 + timedelta(minutes=20)]
    p = punkte[0]
    assert p.minuten == 10 and p.aussen_c == 6.5 and p.vorlauf_c == 36.2
    assert p.waerme_kw == pytest.approx(13.02, abs=0.01)
    assert p.cop == pytest.approx(4.12, abs=0.01)


def test_anlauf_abtauen_luecken_und_fehlende_werte_ergeben_keinen_punkt() -> None:
    # Abtauen mitten im Fenster: der Zustand 9 unterbricht den Lauf, danach beginnt der Anlauf neu.
    abtauen = [minute(i, modus=9.0 if i == 14 else 3.0) for i in range(30)]
    assert k.messpunkte(abtauen) == []
    # Eine Lücke von fünf Minuten in den Daten zählt wie ein Halt.
    luecke = [minute(i) for i in range(30) if not 12 <= i < 17]
    assert k.messpunkte(luecke) == []
    # Schweigt der Rücklauf länger, als sich überbrücken lässt, fällt das Fenster heraus.
    ohne = [minute(i, ruecklauf_c=None if 11 <= i < 19 else 30.0) for i in range(30)]
    assert [p.at for p in k.messpunkte(ohne)] == [T0 + timedelta(minutes=20)]
    # Stehende Pumpe, keine Spreizung, keine Aufnahme: keine Wärme, kein Punkt.
    for kw in ({"durchfluss_l_min": 0.0}, {"ruecklauf_c": 36.0}, {"strom_kw": 0.1}):
        assert k.messpunkte([minute(i, **kw) for i in range(30)]) == []
    # Eine Arbeitszahl von 20 ist ein Messfehler, kein Betriebspunkt.
    assert k.messpunkte([minute(i, strom_kw=0.6) for i in range(30)]) == []


def test_ohne_zustand_der_maschine_entscheidet_die_frequenz_dann_der_strom() -> None:
    assert len(k.messpunkte([minute(i, modus=None) for i in range(30)])) == 2
    assert k.messpunkte([minute(i, modus=None, hz=0.0) for i in range(30)]) == []
    assert len(k.messpunkte([minute(i, modus=None, hz=None) for i in range(30)])) == 2


def punkt(aussen: float, vorlauf: float, cop: float, i: int = 0) -> k.Messpunkt:
    return k.Messpunkt(
        at=T0 + timedelta(minutes=10 * i),
        minuten=10,
        aussen_c=aussen,
        vorlauf_c=vorlauf,
        cop=cop,
        waerme_kw=cop * 2.0,
        strom_kw=2.0,
    )


def test_der_ausgleich_findet_eine_ebene_wieder() -> None:
    """Punkte, die genau auf COP = 6 + 0,1 * außen - 0,06 * Vorlauf liegen, ergeben diese Zahlen."""
    punkte = [
        punkt(ta, tv, 6.0 + 0.1 * ta - 0.06 * tv, i)
        for i, (ta, tv) in enumerate(
            (a, v) for a in (-5.0, 0.0, 5.0, 10.0) for v in (32.0, 40.0, 48.0)
        )
    ]
    f = k.ausgleich(punkte)
    assert f is not None and f.art == "ebene" and f.n == 12
    assert (f.a, f.b_aussen, f.c_vorlauf) == pytest.approx((6.0, 0.1, -0.06), abs=1e-3)
    assert f.rmse == pytest.approx(0.0, abs=1e-3) and f.r2 == pytest.approx(1.0, abs=1e-3)
    assert f.cop(7.0, 35.0) == pytest.approx(4.6, abs=1e-2)
    assert (f.aussen_von_c, f.aussen_bis_c, f.vorlauf_von_c, f.vorlauf_bis_c) == (-5, 10, 32, 48)


def test_was_die_punkte_nicht_hergeben_wird_nicht_erfunden() -> None:
    # Zu wenige Punkte: kein Ausgleich.
    assert k.ausgleich([punkt(5.0, 35.0, 4.0, i) for i in range(k.MIN_PUNKTE - 1)]) is None
    # Ein Vormittag: draußen 5 bis 7 Grad, Vorlauf 34 bis 46. Der Einfluss der Außentemperatur
    # lässt sich daraus nicht bestimmen; der Term fällt weg.
    vormittag = [punkt(5.0 + (i % 3), 34.0 + i, 6.2 - 0.05 * (34.0 + i), i) for i in range(13)]
    f = k.ausgleich(vormittag)
    assert f is not None and f.art == "vorlauf" and f.b_aussen == 0.0
    assert f.c_vorlauf == pytest.approx(-0.05, abs=1e-3)
    # Umgekehrt: fester Vorlauf, wechselndes Wetter.
    wetter = [punkt(-6.0 + i, 35.0, 3.5 + 0.08 * (-6.0 + i), i) for i in range(13)]
    f = k.ausgleich(wetter)
    assert f is not None and f.art == "aussen" and f.c_vorlauf == 0.0
    assert f.b_aussen == pytest.approx(0.08, abs=1e-3)
    # Weder noch: es bleibt der Mittelwert.
    eng = [punkt(6.0 + 0.1 * i, 36.0, 4.0 + 0.01 * (i % 2), i) for i in range(13)]
    f = k.ausgleich(eng)
    assert f is not None and f.art == "mittel" and (f.b_aussen, f.c_vorlauf) == (0.0, 0.0)
    assert f.a == pytest.approx(4.005, abs=1e-2)
    # Witterungsgeführt: kälter draußen heißt genau entsprechend wärmerer Vorlauf. Beide streuen
    # weit genug, aber auf einer Geraden; getrennt bestimmen lassen sie sich nicht.
    gefuehrt = [punkt(-6.0 + i, 50.0 - 1.2 * i, 3.0 + 0.15 * i, i) for i in range(13)]
    f = k.ausgleich(gefuehrt)
    assert f is not None and f.art == "aussen" and f.c_vorlauf == 0.0


def test_werte_die_nicht_jede_minute_kommen_kosten_kein_fenster() -> None:
    """14.11.2026: die Wärmepumpe lief Stunden, und die Kennlinie hatte keinen einzigen Punkt.

    Der Bus sendet Vorlauf, Rücklauf und die Leistung der Maschine etwa alle halbe Minute bis
    Minute, den Rücklauf in einer Liste, deren Zusammensetzung wechselt. Die erste Fassung
    verlangte jeden Wert in jeder der zehn Minuten eines Fensters.
    """
    haus = [
        minute(
            i,
            # Der Rücklauf nur jede dritte Minute, der Vorlauf jede zweite, der Zustand selten.
            ruecklauf_c=30.0 + i * 0.02 if i % 3 == 0 else None,
            vorlauf_c=36.2 + i * 0.02 if i % 2 == 0 else None,
            modus=3.0 if i % 4 == 0 else None,
            hz=None,
        )
        for i in range(60)
    ]
    punkte, b = k.auswerten(haus)
    assert [p.at for p in punkte] == [T0 + timedelta(minutes=m) for m in (10, 20, 30, 40, 50)]
    assert all(p.minuten == 10 and p.cop == pytest.approx(4.12, abs=0.02) for p in punkte)
    assert b.heizen == 60 and b.anlauf == 10 and b.gueltig == 50 and b.ohne_wert == 0
    # Zwischen zwei Werten liegt die Gerade, nicht der alte Wert: Minute 1 und 2 zwischen 0 und 3.
    voll = k.auffuellen(haus)
    assert voll[1].ruecklauf_c == pytest.approx(30.02) and voll[2].ruecklauf_c == pytest.approx(
        30.04
    )
    # Am Ende der Reihe gilt der letzte Wert weiter (Minute 57 hatte den letzten Rücklauf).
    assert voll[59].ruecklauf_c == pytest.approx(31.14)


def test_eine_reihe_die_laenger_schweigt_bleibt_leer_und_die_bilanz_sagt_welche() -> None:
    # Sechs Minuten ohne Wert sind eine zu viel: nichts wird überbrückt.
    sechs = k.auffuellen([minute(i, vorlauf_c=None if 1 <= i <= 6 else 36.2) for i in range(10)])
    assert [m.vorlauf_c for m in sechs[1:7]] == [None] * 6
    fuenf = k.auffuellen([minute(i, vorlauf_c=None if 1 <= i <= 5 else 36.2) for i in range(10)])
    assert [m.vorlauf_c for m in fuenf] == [36.2] * 10
    # Der Zustand ist keine Größe: zwischen "heizt" (3) und "taut ab" (9) liegt kein Zustand 6.
    zustand = k.auffuellen([minute(i, modus={0: 3.0, 3: 9.0}.get(i), hz=None) for i in range(4)])
    assert [m.modus for m in zustand] == [3.0, 3.0, 3.0, 9.0]
    # Der Rücklauf kommt gar nicht: kein Punkt, und die Bilanz nennt ihn.
    punkte, b = k.auswerten([minute(i, ruecklauf_c=None) for i in range(60)])
    assert punkte == [] and b.punkte == 0
    assert b.heizen == 60 and b.anlauf == 10 and b.ohne_wert == 50 and b.gueltig == 0
    assert b.fehlt == {"Rücklauf": 50}
    # Die Teile der Bilanz ergeben zusammen die Minuten im Heizbetrieb.
    gemischt = [
        minute(
            i,
            ruecklauf_c=None if 40 <= i < 50 else 30.0,
            durchfluss_l_min=0.0 if 52 <= i < 55 else 30.1,
            strom_kw=8.8 if 30 <= i < 34 else 3.16,
            modus=15.0 if i >= 70 else 3.0,
        )
        for i in range(80)
    ]
    punkte, b = k.auswerten(gemischt)
    assert b.minuten == 80 and b.heizen == 70
    assert (b.anlauf, b.zusatz, b.ohne_wert, b.ohne_waerme, b.gueltig) == (10, 4, 10, 3, 43)
    assert b.heizen == b.anlauf + b.zusatz + b.ohne_wert + b.ohne_waerme + b.gueltig
    # Fenster 10 und 20 sind voll, 30 hat sechs brauchbare Minuten, 50 sieben, 60 zehn.
    assert [p.at.minute + 60 * (p.at.hour - 9) for p in punkte] == [10, 20, 60]
    assert b.fenster == 5 and b.punkte == 3


def test_ein_fenster_zaehlt_mit_acht_von_zehn_minuten() -> None:
    acht = [minute(i, durchfluss_l_min=0.0 if i in (12, 17) else 30.1) for i in range(20)]
    assert [p.minuten for p in k.messpunkte(acht)] == [8]
    sieben = [minute(i, durchfluss_l_min=0.0 if i in (12, 15, 17) else 30.1) for i in range(20)]
    assert k.messpunkte(sieben) == []


def test_ein_punkt_nennt_die_stellung_des_umschaltventils_wenn_sie_einheitlich_war() -> None:
    """Die Stellung fragt das eBUS-Add-on ab 0.3.0 ab, etwa alle halbe Minute. Mit ihr lassen
    sich Heizen und Warmwasser später trennen; ein Fenster, in dem umgeschaltet wurde, gehört zu
    keinem von beiden."""
    einheitlich = [minute(i, ventil=1.0 if i % 2 == 0 else None) for i in range(30)]
    assert [p.ventil for p in k.messpunkte(einheitlich)] == [1, 1]
    gewechselt = [minute(i, ventil=1.0 if i < 15 else 0.0) for i in range(30)]
    assert [p.ventil for p in k.messpunkte(gewechselt)] == [None, 0]
    assert [p.ventil for p in k.messpunkte([minute(i) for i in range(30)])] == [None, None]


def test_alle_heizzustaende_der_maschine_zaehlen_abtauen_und_kuehlen_nicht() -> None:
    for modus, erwartet in ((3.0, 2), (4.0, 2), (6.0, 2), (9.0, 0), (2.0, 0), (15.0, 0)):
        assert len(k.messpunkte([minute(i, modus=modus) for i in range(30)])) == erwartet


def test_minuten_mit_heizstab_gehoeren_nicht_in_die_kennlinie() -> None:
    """Am 14.11.2026 um 11:18 standen im Haus 8,84 kW am Zähler bei 64 Hz, eine Stunde nach
    3,16 kW bei 65 Hz: neben dem Verdichter lief etwas anderes, und die Arbeitszahl fiel auf
    1,6. Ein solches Fenster sagt nichts über die Wärmepumpe."""
    mit_stab = [minute(i, strom_kw=8.84, strom_maschine_kw=3.1) for i in range(30)]
    punkte, b = k.auswerten(mit_stab)
    assert punkte == [] and b.zusatz == 20 and b.anlauf == 10
    assert k.zusatz_kw(8.84, 3.1) == 5.74
    # Auch ohne Angabe der Maschine: so viel nimmt der Verdichter allein nicht auf.
    assert k.auswerten([minute(i, strom_kw=8.84) for i in range(30)])[1].zusatz == 20
    # Ohne Heizstab weicht der Zähler um Lüfter, Pumpe und Regler ab; das ist kein Zusatz.
    ohne = [minute(i, strom_kw=3.16, strom_maschine_kw=2.95) for i in range(30)]
    punkte, b = k.auswerten(ohne)
    assert len(punkte) == 2 and b.zusatz == 0
    assert k.zusatz_kw(3.16, 2.95) is None
    # Meldet die Maschine ihre Aufnahme nicht, lässt sich nichts erkennen; die Minute zählt.
    assert len(k.messpunkte([minute(i) for i in range(30)])) == 2
    assert k.zusatz_kw(8.84, None) is None and k.zusatz_kw(None, 3.1) is None


def test_meldet_die_maschine_grundsaetzlich_weniger_ist_das_kein_heizstab() -> None:
    """Ob die Maschine ihre ganze Aufnahme meldet oder nur die des Verdichters, ist nicht
    bekannt. Die erste Fassung verglich Zähler und Maschine unmittelbar: läge die Angabe der
    Maschine dauernd 1,5 kW unter dem Zähler, wäre jede Minute als Heizstab herausgefallen."""
    wenig = [minute(i, strom_kw=3.16, strom_maschine_kw=1.45) for i in range(60)]
    punkte, b = k.auswerten(wenig)
    assert len(punkte) == 5 and b.zusatz == 0
    assert b.verhaeltnis == pytest.approx(3.16 / 1.45)
    # Unter dreißig Minuten ist das Verhältnis nicht bestimmt; dann gilt nur die feste Grenze.
    assert k.verhaeltnis_zaehler_maschine(wenig[:29]) is None
    assert k.auswerten(wenig[:29])[1].zusatz == 0
    # Gemessen am Gewöhnlichen fällt ein Heizstab auch unter der festen Grenze auf: 5,0 kW am
    # Zähler, wo zu 1,45 kW der Maschine sonst 3,16 kW gehören.
    stab = [
        minute(i, strom_kw=5.0 if 40 <= i < 50 else 3.16, strom_maschine_kw=1.45) for i in range(60)
    ]
    punkte, b = k.auswerten(stab)
    assert b.zusatz == 10 and [p.at.minute for p in punkte] == [10, 20, 30, 50]
    assert k.zusatz_kw(5.0, 1.45, 3.16 / 1.45) == 1.84
    assert k.zusatz_kw(3.3, 1.45, 3.16 / 1.45) is None
    # Ohne das Verhältnis wird nur behauptet, was sicher ist.
    assert k.zusatz_kw(5.0, 1.45) is None and k.zusatz_kw(6.0, 1.45) == 4.55


def test_heizstab_mitten_im_lauf_unterbricht_ihn_nicht() -> None:
    # Zehn Minuten Heizstab mitten im Lauf: nur das betroffene Fenster fällt heraus, der Lauf
    # selbst ist nicht unterbrochen.
    teils = [
        minute(i, strom_kw=8.8 if 20 <= i < 30 else 3.16, strom_maschine_kw=3.0) for i in range(40)
    ]
    assert [p.at for p in k.messpunkte(teils)] == [
        T0 + timedelta(minutes=10),
        T0 + timedelta(minutes=30),
    ]
