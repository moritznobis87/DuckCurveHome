"""Der Rückblick paart abgelegte Läufe mit dem Ist und sortiert den Fehler nach Vorlaufzeit."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from hems_core.forecasting.rueckblick import (
    REIHEN,
    VORLAUF_KLASSEN,
    Probe,
    mittel_je_raster,
    proben,
    reihe_out,
    umgerechnet,
    wertung,
    wertung_je_vorlauf,
)

T0 = datetime(2026, 11, 6, 0, 0, tzinfo=UTC)


def _probe(stunde: float, prognose: float, ist: float, vorlauf: float) -> Probe:
    return Probe(ts=T0 + timedelta(hours=stunde), prognose=prognose, ist=ist, vorlauf_h=vorlauf)


def test_wertung_rechnet_vorzeichenrichtig() -> None:
    """Bias ist Prognose minus Ist. Zu hoch geraten ist positiv, und das muss sichtbar bleiben."""
    xs = [_probe(0, 3.0, 2.0, 1.0), _probe(1, 1.0, 2.0, 1.0)]
    w = wertung(xs)
    assert w.n == 2
    assert w.mae == 1.0
    assert w.bias == 0.0, "ein zu hoher und ein zu tiefer Fehler heben sich im Bias auf"
    assert w.rmse == 1.0, "im RMSE nicht - das ist der Grund, beide auszuweisen"


def test_leere_menge_gibt_nullen_und_keinen_fehler() -> None:
    w = wertung([])
    assert w.n == 0 and w.mae == 0.0 and w.p95 == 0.0


def test_p95_zeigt_den_rand_den_der_mittelwert_verdeckt() -> None:
    """Der Rand zählt: ein ruhiger Tag mit drei groben Stunden ist kein ruhiger Tag.

    Nächstgelegener Rang, nicht interpoliert: bei vierzig Proben ist das die 38. der Größe nach.
    Damit braucht es mindestens drei grobe Stunden, um den Rand zu erreichen - bei nur einer
    einzigen liegt sie oberhalb des Perzentils, und das ist richtig so: ein Ausreißer unter vierzig
    ist noch keine Erwartung.
    """
    xs = [_probe(i, 1.0, 1.0 + (0.05 if i < 37 else 3.0), 1.0) for i in range(40)]
    w = wertung(xs)
    assert w.mae < 0.3, "im Mittel sieht der Tag harmlos aus"
    assert w.p95 == 3.0, "am Rand nicht"


def test_je_vorlauf_behaelt_leere_klassen() -> None:
    """Eine fehlende Sprosse heißt „keine Läufe", nicht „keine Fehler"."""
    xs = [_probe(0, 2.0, 1.0, 0.5), _probe(1, 2.0, 1.0, 30.0)]
    je = wertung_je_vorlauf(xs)
    assert set(je) == {k for _, _, k in VORLAUF_KLASSEN}
    assert je["0-1h"].n == 1
    assert je["24-48h"].n == 1
    assert je["3-6h"].n == 0, "die Klasse bleibt stehen, damit die Lücke sichtbar ist"


def test_paarung_zaehlt_jeden_lauf_einzeln() -> None:
    """Drei Läufe über dasselbe Intervall sind drei Proben mit drei Vorlaufzeiten.

    Das ist kein Doppelzählen: bewertet werden Läufe, nicht Viertelstunden. Ohne das wäre die Frage
    „wird die Prognose besser, je näher die Lieferung kommt" nicht stellbar.
    """
    ziel = T0 + timedelta(hours=12)
    punkte = [
        (T0, ziel, 5.0),
        (T0 + timedelta(hours=6), ziel, 4.0),
        (T0 + timedelta(hours=11), ziel, 3.2),
    ]
    xs = proben(punkte, {ziel: 3.0})
    assert [p.vorlauf_h for p in xs] == [12.0, 6.0, 1.0]
    je = wertung_je_vorlauf(xs)
    assert je["12-24h"].mae == 2.0
    assert je["6-12h"].mae == 1.0
    assert je["1-3h"].mae == 0.2, "näher an der Lieferung kleiner - genau das soll man sehen"


def test_fehlendes_ist_erzeugt_keine_probe() -> None:
    """Eine Lücke in der Messung ist kein Fehler der Prognose."""
    ziel = T0 + timedelta(hours=1)
    assert proben([(T0, ziel, 5.0)], {}) == []


def test_schwelle_wirft_die_uebereinstimmung_zweier_nullen_weg() -> None:
    """Nachtstunden der PV tragen keine Information und würden jede Kennzahl beschönigen."""
    nacht = T0 + timedelta(hours=1)
    tag = T0 + timedelta(hours=12)
    punkte = [(T0, nacht, 0.0), (T0, tag, 4.0)]
    ist = {nacht: 0.0, tag: 3.0}
    assert len(proben(punkte, ist, schwelle=0.05)) == 1
    assert len(proben(punkte, ist)) == 2, "ohne Schwelle bleiben beide"


def test_fenster_schneidet_ab() -> None:
    drinnen = T0 + timedelta(hours=2)
    draussen = T0 + timedelta(hours=40)
    punkte = [(T0, drinnen, 1.0), (T0, draussen, 1.0)]
    ist = {drinnen: 1.0, draussen: 1.0}
    xs = proben(punkte, ist, von=T0, bis=T0 + timedelta(hours=24))
    assert [p.ts for p in xs] == [drinnen]


def test_umgerechnet_laesst_das_modell_herausfallen() -> None:
    """Dasselbe Modell auf beide Seiten: übrig bleibt der Fehler der Prognose, nicht der des Modells.

    Hier ein Bedarfsmodell mit 0,22 kW/K gegen 20 Grad innen. Zwei Kelvin Temperaturfehler sind
    0,44 kW Bedarfsfehler, und zwar unabhängig davon, ob das Modell richtig ist.
    """
    xs = [_probe(0, 3.0, 5.0, 2.0)]
    bedarf = umgerechnet(xs, lambda _ts, t: 0.22 * (20.0 - t))
    assert round(bedarf[0].fehler, 4) == 0.44
    assert bedarf[0].vorlauf_h == 2.0, "die Vorlaufzeit reist mit"


def test_reihe_out_haelt_leere_leiter_vollstaendig() -> None:
    pv = REIHEN[0]
    out = reihe_out(pv, [], laeufe=0)
    assert out.key == "pv.ac_kw"
    assert out.einheit == "kW"
    assert len(out.je_vorlauf) == len(VORLAUF_KLASSEN)
    assert out.gesamt.n == 0 and out.laeufe == 0


def test_die_temperatur_ist_die_waermeseite_des_katalogs() -> None:
    """Ohne Wärmemengenzähler ist der Temperaturfehler der messbare Teil des Bedarfsfehlers."""
    arten = {r.art: r for r in REIHEN}
    assert arten["weather"].ist_reihe == "outdoor_temp_c"
    assert arten["weather"].einheit == "K", "ein Temperaturfehler ist eine Differenz, kein Grad"


def test_das_ist_wird_auf_das_raster_des_anbieters_gemittelt() -> None:
    """Eine Stundenprognose gegen die erste Viertelstunde zu halten, schriebe Rauschen der Prognose zu."""
    rows = [(T0 + timedelta(minutes=i), float(i)) for i in range(60)]
    viertel = mittel_je_raster(rows, 15)
    stunde = mittel_je_raster(rows, 60)
    assert len(viertel) == 4
    assert viertel[T0] == 7.0, "Mittel von 0 bis 14"
    assert list(stunde) == [T0]
    assert stunde[T0] == 29.5, "Mittel der ganzen Stunde"


def test_luecken_werden_nicht_interpoliert() -> None:
    rows: list[tuple[datetime, float | None]] = [
        (T0, 10.0),
        (T0 + timedelta(minutes=1), None),
        (T0 + timedelta(minutes=30), 20.0),
    ]
    je_viertel = mittel_je_raster(rows, 15)
    assert je_viertel[T0] == 10.0, "der fehlende Wert zieht den Mittelwert nicht"
    assert T0 + timedelta(minutes=15) not in je_viertel, "die leere Viertelstunde entsteht nicht"


def test_die_temperatur_kommt_im_stundenraster() -> None:
    """Open-Meteo liefert stündlich; das steht in der Reihe und nicht in der Anwendungsschicht."""
    arten = {r.art: r for r in REIHEN}
    assert arten["weather"].raster_min == 60
    assert arten["pv"].raster_min == 15
