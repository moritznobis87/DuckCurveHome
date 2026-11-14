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
    # Fehlt in einer Minute der Rücklauf, ist das Fenster nicht vollständig.
    ohne = [minute(i, ruecklauf_c=None if i == 15 else 30.0) for i in range(30)]
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


def test_minuten_mit_heizstab_gehoeren_nicht_in_die_kennlinie() -> None:
    """Am 14.11.2026 um 11:18 standen im Haus 8,84 kW am Zähler bei 64 Hz, eine Stunde nach
    3,16 kW bei 65 Hz: neben dem Verdichter lief etwas anderes, und die Arbeitszahl fiel auf
    1,6. Ein solches Fenster sagt nichts über die Wärmepumpe."""
    mit_stab = [minute(i, strom_kw=8.84, strom_maschine_kw=3.1) for i in range(30)]
    assert k.messpunkte(mit_stab) == []
    assert k.zusatz_minuten(mit_stab) == 30
    assert k.zusatz_kw(8.84, 3.1) == 5.74
    # Ohne Heizstab weicht der Zähler um Lüfter, Pumpe und Regler ab; das ist kein Zusatz.
    ohne = [minute(i, strom_kw=3.16, strom_maschine_kw=2.95) for i in range(30)]
    assert len(k.messpunkte(ohne)) == 2 and k.zusatz_minuten(ohne) == 0
    assert k.zusatz_kw(3.16, 2.95) is None
    # Meldet die Maschine ihre Aufnahme nicht, lässt sich nichts erkennen; die Minute zählt.
    assert len(k.messpunkte([minute(i) for i in range(30)])) == 2
    assert k.zusatz_kw(8.84, None) is None and k.zusatz_kw(None, 3.1) is None
    # Zehn Minuten Heizstab mitten im Lauf: nur das betroffene Fenster fällt heraus, der Lauf
    # selbst ist nicht unterbrochen.
    teils = [
        minute(i, strom_kw=8.8 if 20 <= i < 30 else 3.16, strom_maschine_kw=3.0) for i in range(40)
    ]
    assert [p.at for p in k.messpunkte(teils)] == [
        T0 + timedelta(minutes=10),
        T0 + timedelta(minutes=30),
    ]
